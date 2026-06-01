If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}

$OutputPath = "$env:SystemDrive\"
$ReportName = "SystemInfoDump-$(New-Guid)"
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'   # suppress CIM progress bars

$ReportFile = Join-Path $OutputPath "$ReportName.html"
$StartTime = Get-Date
Write-Host '[*] Starting system report collection...' -ForegroundColor Cyan

# ─────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1TB) { '{0:N2} TB' -f ($Bytes / 1TB) }
    elseif ($Bytes -ge 1GB) { '{0:N2} GB' -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { '{0:N2} MB' -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { '{0:N2} KB' -f ($Bytes / 1KB) }
    else { "$Bytes B" }
}

function Format-Uptime {
    param([timespan]$Span)
    '{0}d {1}h {2}m {3}s' -f $Span.Days, $Span.Hours, $Span.Minutes, $Span.Seconds
}

function Html-Escape {
    param([string]$s)
    if (-not $s) { return '' }
    $s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;'
}

function Build-Table {
    param(
        [string]$Id,
        [string[]]$Headers,
        $Rows,
        [string]$EmptyMsg = 'No data collected.'
    )
    if (-not $Rows -or $Rows.Count -eq 0) {
        return "<p class='empty'>$EmptyMsg</p>"
    }
    $Rows = @($Rows)
    if ($Rows[0] -isnot [array]) {
        $Rows = @(, $Rows)
    }

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.Append("<div class='tbl-wrap'><table id='$Id'><thead><tr>")
    foreach ($h in $Headers) { $null = $sb.Append("<th>$(Html-Escape $h)</th>") }
    $null = $sb.Append('</tr></thead><tbody>')
    foreach ($row in $Rows) {
        $null = $sb.Append('<tr>')
        foreach ($cell in $row) { $null = $sb.Append("<td>$(Html-Escape ([string]$cell))</td>") }
        $null = $sb.Append('</tr>')
    }
    $null = $sb.Append('</tbody></table></div>')
    return $sb.ToString()
}

function Build-KVTable {
    param([hashtable]$Data, [string]$Id)
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.Append("<table class='kv' id='$Id'>")
    foreach ($key in ($Data.Keys | Sort-Object)) {
        $v = Html-Escape ([string]$Data[$key])
        $null = $sb.Append("<tr><th>$(Html-Escape $key)</th><td>$v</td></tr>")
    }
    $null = $sb.Append('</table>')
    return $sb.ToString()
}

function Get-InstalledApps {
    #gets installed apps from registry using the well known "uninstall" location (appwiz.cpl apps)
    #gets additional apps from lesser known location (dups are removed)
    param(
        [switch]$AllApps #show apps even if they are marked as a system component
    )


    $regPath64 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    $regPath32 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    $apps64 = Get-ChildItem $regPath64 
    $apps32 = Get-ChildItem $regPath32


    $installedApps = @()

    foreach ($app64 in $apps64) {
        $obj = Get-ItemProperty $app64.PSPath 
        $installedApps += $obj
    }

    foreach ($app32 in $apps32) {
        $obj = Get-ItemProperty $app32.PSPath 
        $installedApps += $obj
    }

    #another location
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData'

    $users = Get-ChildItem $regPath -ErrorAction SilentlyContinue
    if ($users) {
        foreach ($user in $users) {
            $hives = Get-ChildItem "$($user.PSPath)\Products" 

            foreach ($hive in $hives) {
                try {
                    $obj = Get-ItemProperty "$($hive.PSPath)\InstallProperties" -ErrorAction Stop
                    $installedApps += $obj
                }
                catch {}

            }

        }
    }

    #some apps dont make a uninstall key so we need to find the missing installed apps using get-package
    $additionalApps = @()
    $programs = get-package -ProviderName Programs
    foreach ($program in $programs) {
        $appObj = [PSCustomObject]@{
            DisplayName          = $null
            DisplayIcon          = $null
            UninstallString      = $null
            Publisher            = $null
            InstallSource        = $null
            InstallLocation      = $null
            QuietUninstallString = $null
        }

        $names = $program.meta.attributes.keys.localname
        #get the index of the names inorder to index into the "values" array
        $i = 0
        $foundIndexIcon = $null
        $foundIndexName = $null
        $foundIndexUninstall = $null
        $foundIndexPublisher = $null
        $foundIndexSource = $null
        $foundIndexLocation = $null
        $foundIndexQuietUninstall = $null
        foreach ($name in $names) {
            if ($name -eq 'DisplayIcon') {
                $foundIndexIcon = $i
            }
            elseif ($name -eq 'UninstallString') {
                $foundIndexUninstall = $i
            }
            elseif ($name -eq 'DisplayName') {
                $foundIndexname = $i
            }
            elseif ($name -eq 'Publisher') {
                $foundIndexPublisher = $i
            }
            elseif ($name -eq 'InstallSource') {
                $foundIndexSource = $i
            }
            elseif ($name -eq 'InstallLocation') {
                $foundIndexLocation = $i
            }
            elseif ($name -eq 'QuietUninstallString') {
                $foundIndexQuietUninstall = $i
            }
            $i++
            
        }
     

        if ($foundIndexName -ne $null) {
            $appObj.DisplayName = $program.meta.attributes.values[$foundIndexname]
        }

        if ($foundIndexUninstall -ne $null) {
            $appObj.UninstallString = $program.meta.attributes.values[$foundIndexUninstall]
        }

        if ($foundIndexPublisher -ne $null) {
            $appObj.Publisher = $program.meta.attributes.values[$foundIndexPublisher]
        }

        if ($foundIndexSource -ne $null) {
            $appObj.InstallSource = $program.meta.attributes.values[$foundIndexSource]
        }

        if ($foundIndexLocation -ne $null) {
            $appObj.InstallLocation = $program.meta.attributes.values[$foundIndexLocation]
        }



        $additionalApps += $appobj
    }
    
    #add the apps that install themselves to appdata and dont make a reg entry
    
    foreach ($app in $additionalApps) {
        if (!($app.UninstallString -in @($installedApps.UninstallString))) {
            $installedApps += $app
        }
    }
  
      

    #filter out empty apps
    $installedApps = $installedApps | Where-Object { $_.DisplayName -ne $null }

    #filter out duplicates
    $installedApps = $installedApps | Group-Object -Property UninstallString | ForEach-Object { $_.Group | Select-Object -First 1 }

    return $installedApps


}




Write-Host '  [+] OS & System...' -ForegroundColor Gray

# CIM is faster than WMI (uses DCOM vs WinRM/DCOM, but CIM defaults to WS-Man
# with fallback to DCOM — single Get-CimInstance call beats multiple gwmi calls)
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$cs = Get-CimInstance -ClassName Win32_ComputerSystem
$bios = Get-CimInstance -ClassName Win32_BIOS
$tzInfo = [System.TimeZoneInfo]::Local
$uptime = (Get-Date) - $os.LastBootUpTime
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion')
$OSBuildMinor = "$($key.GetValue('UBR'))"
$key.Close()

$osData = [ordered]@{
    'Hostname'             = $env:COMPUTERNAME
    'OS Name'              = $os.Caption
    'OS Version'           = $os.Version + ".$OSBuildMinor"
    'OS Architecture'      = $os.OSArchitecture
    'Service Pack'         = if ($os.ServicePackMajorVersion -gt 0) { "SP$($os.ServicePackMajorVersion)" } else { 'N/A' }
    'Install Date'         = $os.InstallDate.ToString('yyyy-MM-dd HH:mm:ss')
    'Last Boot'            = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
    'Uptime'               = $(Format-Uptime $uptime)
    'Registered Owner'     = $os.RegisteredUser
    'Registered Org'       = $os.Organization
    'Windows Directory'    = $os.WindowsDirectory
    'System Directory'     = $os.SystemDirectory
    'System Drive'         = $os.SystemDrive
    'Time Zone'            = $tzInfo.DisplayName
    'Locale'               = $os.Locale
    'MUI Languages'        = ($os.MUILanguages -join ', ')
    'Total Visible RAM'    = $(Format-Bytes ($os.TotalVisibleMemorySize * 1KB))
    'Free RAM'             = $(Format-Bytes ($os.FreePhysicalMemory * 1KB))
    'Total Virtual Memory' = $(Format-Bytes ($os.TotalVirtualMemorySize * 1KB))
    'Free Virtual Memory'  = $(Format-Bytes ($os.FreeVirtualMemory * 1KB))
    'Domain / Workgroup'   = if ($cs.PartOfDomain) { $cs.Domain } else { "WORKGROUP: $($cs.Workgroup)" }
    'Domain Role'          = $(switch ($cs.DomainRole) { 0 { 'Standalone Workstation' } 1 { 'Member Workstation' } 2 { 'Standalone Server' } 3 { 'Member Server' } 4 { 'Backup Domain Controller' } 5 { 'Primary Domain Controller' } })
    'BIOS Version'         = $bios.SMBIOSBIOSVersion
    'BIOS Date'            = $bios.ReleaseDate.ToString('yyyy-MM-dd')
    'BIOS Manufacturer'    = $bios.Manufacturer
    'Serial Number'        = $bios.SerialNumber
    'Secure Boot'          = $(try { (Confirm-SecureBootUEFI 2>$null) } catch { 'N/A' })
}

# ── Computer System ──────────────────────────────────────────────────────────
Write-Host '  [+] Computer Hardware...' -ForegroundColor Gray

$csData = [ordered]@{
    'Manufacturer'        = $cs.Manufacturer
    'Model'               = $cs.Model
    'System Type'         = $cs.SystemType
    'System SKU'          = $cs.SystemSKUNumber
    'Chassis Types'       = $(try { (Get-CimInstance Win32_SystemEnclosure).ChassisTypes -join ', ' } catch { 'N/A' })
    'Total Physical RAM'  = Format-Bytes ($cs.TotalPhysicalMemory)
    'Logical Processors'  = $cs.NumberOfLogicalProcessors
    'Physical Processors' = $cs.NumberOfProcessors
    'HyperVisor Present'  = $cs.HypervisorPresent
    'PCSystemType'        = switch ($cs.PCSystemType) { 0 { 'Unspecified' } 1 { 'Desktop' } 2 { 'Mobile' } 3 { 'Workstation' } 4 { 'Enterprise Server' } 5 { 'SOHO Server' } 6 { 'Appliance PC' } 7 { 'Performance Server' } 8 { 'Maximum' } default { $_ } }
    'Power Supply State'  = $(try { (Get-CimInstance Win32_SystemEnclosure).PowerSupplyState } catch { 'N/A' })
    'Wake-Up Type'        = switch ($cs.WakeUpType) { 0 { 'Reserved' } 1 { 'Other' } 2 { 'Unknown' } 3 { 'APM Timer' } 4 { 'Modem Ring' } 5 { 'LAN Remote' } 6 { 'Power Switch' } 7 { 'PCI PME#' } 8 { 'AC Power Restored' } default { $_ } }
}

# ── CPU ──────────────────────────────────────────────────────────────────────
Write-Host '  [+] CPU...' -ForegroundColor Gray

$cpus = Get-CimInstance -ClassName Win32_Processor
$cpuRows = foreach ($cpu in $cpus) {
    , @(
        $cpu.Name.Trim(),
        $cpu.Manufacturer,
        $cpu.NumberOfCores,
        $cpu.NumberOfLogicalProcessors,
        $cpu.ThreadCount,
        "$($cpu.MaxClockSpeed) MHz",
        (Format-Bytes ($cpu.L2CacheSize * 1KB)),
        (Format-Bytes ($cpu.L3CacheSize * 1KB)),
        $($cpu.Architecture -replace '0', 'x86' -replace '9', 'x64' -replace '12', 'ARM64'),
        $cpu.CurrentVoltage,
        $cpu.Status,
        $cpu.SocketDesignation,
        $cpu.Caption
    )
}
$cpuHeaders = @('Name', 'Manufacturer', 'Cores', 'Logical Procs', 'Threads', 'Max Speed', 'L2 Cache', 'L3 Cache', 'Architecture', 'Voltage', 'Status', 'Socket', 'Caption')

# ── RAM / Memory Modules ──────────────────────────────────────────────────────
Write-Host '  [+] RAM Modules...' -ForegroundColor Gray

$ramModules = Get-CimInstance -ClassName Win32_PhysicalMemory
$ramRows = foreach ($r in $ramModules) {
    , @(
        $r.BankLabel,
        $r.DeviceLocator,
        $(Format-Bytes $r.Capacity),
        "$($r.Speed) MHz",
        $r.Manufacturer,
        $r.PartNumber.Trim(),
        $r.SerialNumber,
        $(switch ($r.MemoryType) { 0 { 'Unknown' } 20 { 'DDR' } 21 { 'DDR2' } 22 { 'DDR2 FB-DIMM' } 24 { 'DDR3' } 26 { 'DDR4' } 34 { 'DDR5' } default { "Type $($r.MemoryType)" } }),
        $(switch ($r.FormFactor) { 8 { 'DIMM' } 12 { 'SO-DIMM' } 13 { 'TSOP' } default { "FF $($r.FormFactor)" } })
    )
}
$ramHeaders = @('Bank', 'Slot', 'Capacity', 'Speed', 'Manufacturer', 'Part Number', 'Serial', 'Type', 'Form Factor')

# ── Drives / Disks ────────────────────────────────────────────────────────────
Write-Host '  [+] Disks & Volumes...' -ForegroundColor Gray

# Get-CimInstance Win32_DiskDrive is faster than Get-Disk (requires Storage module)
$physDisks = Get-CimInstance -ClassName Win32_DiskDrive
$diskRows = foreach ($d in $physDisks) {
    , @(
        $d.Index,
        $d.Model,
        $d.Manufacturer,
        $d.InterfaceType,
        $(Format-Bytes $d.Size),
        $d.Partitions,
        $d.TotalCylinders,
        $d.TracksPerCylinder,
        $d.SectorsPerTrack,
        $d.BytesPerSector,
        $d.SerialNumber.Trim(),
        $d.FirmwareRevision,
        $d.Status,
        $d.MediaType
    )
}
$diskHeaders = @('Index', 'Model', 'Manufacturer', 'Interface', 'Size', 'Partitions', 'Cylinders', 'Tracks/Cyl', 'Sectors/Track', 'Bytes/Sector', 'Serial', 'Firmware', 'Status', 'Media Type')

# Logical Drives / Volumes — Get-CimInstance is faster than Get-PSDrive
$logicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk
$volRows = foreach ($v in $logicalDisks) {
    $pct = if ($v.Size -gt 0) { [math]::Round(($v.FreeSpace / $v.Size) * 100, 1) } else { 0 }
    , @(
        $v.DeviceID,
        $v.VolumeName,
        $v.FileSystem,
        $(switch ($v.DriveType) { 0 { 'Unknown' } 1 { 'No Root' } 2 { 'Removable' } 3 { 'Local' } 4 { 'Network' } 5 { 'Compact' } 6 { 'RAM' } default { $_ } }),
        $(Format-Bytes $v.Size),
        $(Format-Bytes $v.FreeSpace),
        "$pct%",
        $v.VolumeSerialNumber,
        $v.Description
    )
}
$volHeaders = @('Drive', 'Label', 'FS', 'Type', 'Total', 'Free', 'Free%', 'Volume Serial', 'Description')

# Partitions
$partRows = foreach ($p in (Get-CimInstance -ClassName Win32_DiskPartition)) {
    , @(
        $p.DiskIndex,
        $p.Index,
        $p.Name,
        $p.Type,
        $(Format-Bytes $p.Size),
        $(Format-Bytes ($p.StartingOffset)),
        $p.Bootable,
        $p.BootPartition,
        $p.PrimaryPartition,
        $p.BlockSize,
        $p.NumberOfBlocks
    )
}
$partHeaders = @('Disk', 'Part#', 'Name', 'Type', 'Size', 'Offset', 'Bootable', 'Boot Part', 'Primary', 'Block Size', 'Blocks')

# ── Network ───────────────────────────────────────────────────────────────────
Write-Host '  [+] Network...' -ForegroundColor Gray

# Get-CimInstance Win32_NetworkAdapterConfiguration is faster than Get-NetAdapter
# for full config detail in a single query
$netConfigs = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = True'
$netAdapters = Get-CimInstance -ClassName Win32_NetworkAdapter

$netRows = foreach ($n in $netConfigs) {
    $adapter = $netAdapters | Where-Object { $_.Index -eq $n.Index }
    , @(
        $n.Description,
        $adapter.NetConnectionID,
        $((Format-Bytes $adapter.Speed) + '/s'),
        $($n.DefaultIPGateway | Select-Object -first 1),
        $n.MACAddress,
        $n.DHCPEnabled,
        $n.DHCPServer,
        $n.DHCPLeaseObtained,
        $n.DHCPLeaseExpires,
        $adapter.NetEnabled,
        $n.WINSPrimaryServer
    )
}
$netHeaders = @('Adapter', 'Connection ID', 'Speed', 'Gateway', 'MAC', 'DHCP?', 'DHCP Server', 'Lease Obtained', 'Lease Expires', 'Enabled', 'WINS Primary')

# DNS Cache — faster via .NET/CIM than Resolve-DnsName loops
$dnsCache = @()
try {
    $dnsCache = Get-DnsClientCache | Select-Object Entry, RecordName, RecordType, Status, DataLength, Data, TimeToLive
}
catch {}

$dnsCacheRows = foreach ($d in $dnsCache) {
    , @($d.Entry, $d.RecordName, $d.RecordType, $d.Status, $d.DataLength, $d.Data, $d.TimeToLive)
}
$dnsCacheHeaders = @('Entry', 'Record Name', 'Type', 'Status', 'Data Length', 'Data', 'TTL')

# ── GPU / Video ───────────────────────────────────────────────────────────────
Write-Host '  [+] GPU...' -ForegroundColor Gray

$gpus = Get-CimInstance -ClassName Win32_VideoController
$gpuRows = foreach ($g in $gpus) {
    , @(
        $g.Name,
        $g.VideoProcessor,
        $g.AdapterCompatibility,
        $(Format-Bytes $g.AdapterRAM),
        "$($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution)",
        "$($g.CurrentRefreshRate) Hz",
        $g.CurrentBitsPerPixel,
        $g.VideoModeDescription,
        $g.DriverVersion,
        $g.DriverDate,
        $g.Status,
        $g.VideoArchitecture,
        $g.VideoMemoryType
    )
}
$gpuHeaders = @('Name', 'Processor', 'Compatibility', 'VRAM', 'Resolution', 'Refresh', 'BPP', 'Mode', 'Driver Ver', 'Driver Date', 'Status', 'Architecture', 'Memory Type')

# ── Monitors ─────────────────────────────────────────────────────────────────
$monitors = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorID
$monRows = foreach ($m in $monitors) {
    $mfr = ($m.ManufacturerName  | Where-Object { $_ }) -join ''
    $prod = ($m.ProductCodeID     | Where-Object { $_ }) -join ''
    $sn = ($m.SerialNumberID    | Where-Object { $_ }) -join ''
    $name = ($m.UserFriendlyName  | Where-Object { $_ }) -join ''
    , @(
        $mfr,
        $name,
        $sn,
        $prod,
        $m.InstanceName,
        $m.WeekOfManufacture,
        $m.YearOfManufacture
    )
}
$monHeaders = @('Manufacturer', 'Name', 'Serial', 'Product Code', 'Instance', 'Week', 'Year')

# ── Sound Devices ─────────────────────────────────────────────────────────────
$soundRows = foreach ($s in (Get-CimInstance -ClassName Win32_SoundDevice)) {
    , @($s.Name, $s.Manufacturer, $s.Status, $s.DeviceID, $s.ProductName)
}
$soundHeaders = @('Name', 'Manufacturer', 'Status', 'Device ID', 'Product Name')

# ── Devices (all) ─────────────────────────────────────────────────────────────
Write-Host '  [+] All Devices (PnP)...' -ForegroundColor Gray

# Get-PnpDevice is faster than Get-CimInstance Win32_PnPEntity for this query
# because it uses the StorageManagement module's native PnP provider
$allDevices = Get-PnpDevice -PresentOnly | Sort-Object Class, FriendlyName
$devRows = foreach ($d in $allDevices) {
    , @($d.FriendlyName, $d.Class, $d.InstanceId, $d.Status, $d.Problem, $d.ProblemDescription)
}
$devHeaders = @('Name', 'Class', 'Instance ID', 'Status', 'Problem Code', 'Problem Description')

# Problem Devices only
$problemDevices = $allDevices | Where-Object { $_.Status -ne 'OK' -and $_.Problem -ne 0 }
$probRows = foreach ($d in $problemDevices) {
    , @($d.FriendlyName, $d.Class, $d.InstanceId, $d.Status, $d.Problem, $d.ProblemDescription)
}

# ── Services ──────────────────────────────────────────────────────────────────
Write-Host '  [+] Services...' -ForegroundColor Gray

# Get-CimInstance Win32_Service returns richer data than Get-Service in one call
$services = Get-CimInstance -ClassName Win32_Service | Sort-Object StartMode, State, Name
$svcRows = foreach ($s in $services) {
    , @(
        $s.Name,
        $s.DisplayName,
        $s.State,
        $s.StartMode,
        $s.StartName,
        $s.PathName,
        $s.Description,
        $s.ProcessId,
        $s.DelayedAutoStart
    )
}
$svcHeaders = @('Name', 'Display Name', 'State', 'Start Mode', 'Logon As', 'Path', 'Description', 'PID', 'Delayed Auto Start')

# ── Drivers ───────────────────────────────────────────────────────────────────
Write-Host '  [+] Drivers...' -ForegroundColor Gray

# Win32_SystemDriver gives running kernel drivers without needing driverquery.exe
$drivers = Get-CimInstance -ClassName Win32_SystemDriver | Sort-Object State, Name
$drvRows = foreach ($d in $drivers) {
    , @(
        $d.Name,
        $d.DisplayName,
        $d.State,
        $d.StartMode,
        $d.PathName,
        $d.ServiceType,
        $d.Description,
        $d.AcceptStop,
        $d.AcceptPause
    )
}
$drvHeaders = @('Name', 'Display Name', 'State', 'Start Mode', 'Path', 'Type', 'Description', 'Accept Stop', 'Accept Pause')

# ── Processes ─────────────────────────────────────────────────────────────────
Write-Host '  [+] Processes...' -ForegroundColor Gray

# Get-CimInstance Win32_Process beats Get-Process for CSV columns like
# CommandLine, ParentProcessId without extra lookups
$processes = Get-CimInstance -ClassName Win32_Process | Sort-Object Name
$procRows = foreach ($p in $processes) {
    , @(
        $p.ProcessId,
        $p.ParentProcessId,
        $p.Name,
        $(Format-Bytes $p.WorkingSetSize),
        $(Format-Bytes $p.VirtualSize),
        $p.ThreadCount,
        $p.HandleCount,
        $p.CreationDate,
        $p.CommandLine,
        $p.ExecutablePath
    )
}
$procHeaders = @('PID', 'PPID', 'Name', 'Working Set', 'Virtual Mem', 'Threads', 'Handles', 'Created', 'Command Line', 'Path')

# ── Startup Items ─────────────────────────────────────────────────────────────
Write-Host '  [+] Startup...' -ForegroundColor Gray

$startupItems = Get-CimInstance -ClassName Win32_StartupCommand
$startRows = foreach ($s in $startupItems) {
    , @($s.Name, $s.Command, $s.Location, $s.User, $s.Caption)
}
$startHeaders = @('Name', 'Command', 'Location', 'User', 'Caption')

# ── Installed Applications (registry — fastest method) ────────────────────────
$appRows = @()

$apps = Get-InstalledApps -AllApps
$appRows = foreach ($a in $apps) {
    , @(
        $a.DisplayName,
        $a.DisplayVersion,
        $a.Publisher,
        $a.InstallDate,
        $a.InstallLocation,
        $a.UninstallString,
        (Format-Bytes ($a.EstimatedSize * 1KB))
    )
}

$appHeaders = @('Name', 'Version', 'Publisher', 'Install Date', 'Location', 'Uninstall String', 'Est. Size')

# ── AppX / Store Packages ─────────────────────────────────────────────────────
$appxRows = @()
Write-Host '  [+] AppX Packages...' -ForegroundColor Gray
# Get-AppxPackage is the only clean method for this; no faster alternative
$appx = Get-AppxPackage -AllUsers | Sort-Object Name
$appxRows = foreach ($a in $appx) {
    , @(
        $a.Name,
        $a.Version,
        $a.Publisher,
        $a.Architecture,
        $a.PackageUserInformation.UserSecurityId,
        $a.InstallLocation,
        $a.IsFramework,
        $a.IsResourcePackage,
        $a.SignatureKind
    )
}

$appxHeaders = @('Name', 'Version', 'Publisher', 'Architecture', 'Users', 'Install Location', 'Framework', 'Resource Pkg', 'Signature')

# ── Environment Variables ─────────────────────────────────────────────────────
Write-Host '  [+] Environment Variables...' -ForegroundColor Gray

$sysEnv = [System.Environment]::GetEnvironmentVariables('Machine')
$userEnv = [System.Environment]::GetEnvironmentVariables('User')

$envRows = foreach ($k in ($sysEnv.Keys  | Sort-Object)) { , @('System', $k, $sysEnv[$k]) }
$envRows += foreach ($k in ($userEnv.Keys | Sort-Object)) { , @('User', $k, $userEnv[$k]) }
$envHeaders = @('Scope', 'Variable', 'Value')

# ── Hotfixes / Windows Updates ────────────────────────────────────────────────
Write-Host '  [+] Hotfixes...' -ForegroundColor Gray

# Get-HotFix internally calls Win32_QuickFixEngineering; calling CIM directly
# is the same speed, so either is fine — using Get-HotFix for readability
$hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending
$hfRows = foreach ($h in $hotfixes) {
    , @($h.HotFixID, $h.Description, $h.InstalledBy, $h.InstalledOn, $h.Caption)
}
$hfHeaders = @('ID', 'Description', 'Installed By', 'Installed On', 'Caption')

# ── Scheduled Tasks ───────────────────────────────────────────────────────────
Write-Host '  [+] Scheduled Tasks...' -ForegroundColor Gray

$tasks = Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' } | Sort-Object TaskPath, TaskName
$taskRows = foreach ($t in $tasks) {
    $info = $t | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
    , @(
        $t.TaskName,
        $t.TaskPath,
        $t.State,
        $t.Description,
        $info.LastRunTime,
        $info.NextRunTime,
        $info.LastTaskResult,
        ($t.Actions | ForEach-Object { $_.Execute } | Select-Object -First 1)
    )
}
$taskHeaders = @('Task Name', 'Path', 'State', 'Description', 'Last Run', 'Next Run', 'Last Result', 'Executable')

# ── Open TCP/UDP Ports ────────────────────────────────────────────────────────
Write-Host '  [+] Network Connections...' -ForegroundColor Gray

$tcpConns = Get-NetTCPConnection | Sort-Object State, LocalPort
$tcpRows = foreach ($c in $tcpConns) {
    $proc = if ($c.OwningProcess -gt 0) { (Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue).Name } else { '' }
    , @($c.LocalAddress, $c.LocalPort, $c.RemoteAddress, $c.RemotePort, $c.State, $c.OwningProcess, $proc)
}
$tcpHeaders = @('Local Address', 'Local Port', 'Remote Address', 'Remote Port', 'State', 'PID', 'Process')

$udpEndpoints = Get-NetUDPEndpoint | Sort-Object LocalPort
$udpRows = foreach ($u in $udpEndpoints) {
    $proc = if ($u.OwningProcess -gt 0) { (Get-Process -Id $u.OwningProcess -ErrorAction SilentlyContinue).Name } else { '' }
    , @($u.LocalAddress, $u.LocalPort, $u.OwningProcess, $proc)
}
$udpHeaders = @('Local Address', 'Local Port', 'PID', 'Process')

# ── Shares ────────────────────────────────────────────────────────────────────
$shareRows = foreach ($s in (Get-CimInstance -ClassName Win32_Share)) {
    , @($s.Name, $s.Path, $s.Description, $s.Type, $s.MaximumAllowed, $s.Caption)
}
$shareHeaders = @('Name', 'Path', 'Description', 'Type', 'Max Allowed', 'Caption')

# ── Users & Groups ────────────────────────────────────────────────────────────
Write-Host '  [+] Users & Groups...' -ForegroundColor Gray

$localUsers = Get-LocalUser
$userRows = foreach ($u in $localUsers) {
    , @(
        $u.Name,
        $u.FullName,
        $u.Enabled,
        $u.AccountExpires,
        $u.LastLogon,
        $u.PasswordLastSet,
        $u.PasswordExpires,
        $u.PasswordRequired,
        $u.UserMayChangePassword,
        $u.Description,
        $u.SID
    )
}
$userHeaders = @('Name', 'Full Name', 'Enabled', 'Expires', 'Last Logon', 'Pwd Last Set', 'Pwd Expires', 'Pwd Required', 'User Can Change Pwd', 'Description', 'SID')

$localGroups = Get-LocalGroup
$grpRows = foreach ($g in $localGroups) {
    $members = (Get-LocalGroupMember $g.Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) -join '; '
    , @($g.Name, $g.Description, $g.SID, $members)
}
$grpHeaders = @('Group', 'Description', 'SID', 'Members')

# ── Event Log Summary ─────────────────────────────────────────────────────────
Write-Host '  [+] Event Log Summary...' -ForegroundColor Gray

# Get-WinEvent with -MaxEvents is fastest for a quick summary
$recentErrors = Get-WinEvent -FilterHashtable @{LogName = 'System', 'Application'; Level = 2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 200 -ErrorAction SilentlyContinue |
Sort-Object TimeCreated -Descending
$evtRows = foreach ($e in $recentErrors) {
    , @($e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'), $e.LogName, $e.Id, $e.LevelDisplayName, $e.ProviderName, ($e.Message -replace "`r`n", ' ' | Select-Object -First 1))
}
$evtHeaders = @('Time', 'Log', 'Event ID', 'Level', 'Source', 'Message')

# ── TPM ───────────────────────────────────────────────────────────────────────
$tpmData = [ordered]@{}
try {
    $tpm = Get-CimInstance -Namespace root/cimv2/security/microsofttpm -ClassName Win32_Tpm
    if ($tpm) {
        $tpmData = [ordered]@{
            'TPM Enabled'       = $tpm.IsEnabled_InitialValue
            'TPM Activated'     = $tpm.IsActivated_InitialValue
            'TPM Owned'         = $tpm.IsOwned_InitialValue
            'Spec Version'      = $tpm.SpecVersion
            'Manufacturer ID'   = $tpm.ManufacturerId
            'Manufacturer Info' = $tpm.ManufacturerIdTxt
            'Manufacturer Ver'  = $tpm.ManufacturerVersion
        }
    }
}
catch {}

# ── Battery ───────────────────────────────────────────────────────────────────
$batData = [ordered]@{}
try {
    $bat = Get-CimInstance -ClassName Win32_Battery
    if ($bat) {
        $batData = [ordered]@{
            'Name'                 = $bat.Name
            'Status'               = $bat.Status
            'Charge %'             = "$($bat.EstimatedChargeRemaining)%"
            'Est. Runtime'         = "$($bat.EstimatedRunTime) min"
            'Battery Status'       = switch ($bat.BatteryStatus) { 1 { 'Discharging' } 2 { 'On AC' } 3 { 'Full Charged' } 4 { 'Low' } 5 { 'Critical' } 6 { 'Charging' } 7 { 'Charging/High' } 8 { 'Charging/Low' } 9 { 'Charging/Critical' } 10 { 'Undefined' } 11 { 'Partially Charged' } default { $_ } }
            'Design Capacity'      = $bat.DesignCapacity
            'Full Charge Capacity' = $bat.FullChargeCapacity
            'Chemistry'            = switch ($bat.Chemistry) { 1 { 'Other' } 2 { 'Unknown' } 3 { 'Lead Acid' } 4 { 'Nickel Cadmium' } 5 { 'Nickel Metal Hydride' } 6 { 'Lithium-ion' } 7 { 'Zinc air' } 8 { 'Lithium Polymer' } default { $_ } }
        }
    }
}
catch {}

# Timing
$elapsed = (Get-Date) - $StartTime
Write-Host "  [+] Collection done in $($elapsed.TotalSeconds.ToString('N1'))s. Building HTML..." -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# HTML GENERATION
# ─────────────────────────────────────────────────────────────────────────────

$generatedAt = Get-Date -Format 'dddd, MMMM d yyyy  HH:mm:ss'

# Build nav items
$navItems = @(
    @{id = 'sec-os'; label = 'OS'; icon = '🖥️' }
    @{id = 'sec-hw'; label = 'Hardware'; icon = '🔧' }
    @{id = 'sec-cpu'; label = 'CPU'; icon = '⚡' }
    @{id = 'sec-ram'; label = 'RAM'; icon = '💾' }
    @{id = 'sec-disk'; label = 'Storage'; icon = '💿' }
    @{id = 'sec-gpu'; label = 'Display'; icon = '🖵' }
    @{id = 'sec-net'; label = 'Network'; icon = '🌐' }
    @{id = 'sec-procs'; label = 'Processes'; icon = '⚙️' }
    @{id = 'sec-services'; label = 'Services'; icon = '🔌' }
    @{id = 'sec-drivers'; label = 'Drivers'; icon = '📦' }
    @{id = 'sec-apps'; label = 'Apps'; icon = '📋' }
    @{id = 'sec-security'; label = 'Security'; icon = '🔒' }
    @{id = 'sec-sched'; label = 'Tasks'; icon = '📅' }
    @{id = 'sec-users'; label = 'Users'; icon = '👤' }
    @{id = 'sec-events'; label = 'Events'; icon = '📊' }
    @{id = 'sec-env'; label = 'Environment'; icon = '📝' }
)

$navHtml = $navItems | ForEach-Object {
    "<a href='#$($_.id)' class='nav-link'><span class='nav-icon'>$($_.icon)</span><span class='nav-text'>$($_.label)</span></a>"
}

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>System Report — $($env:COMPUTERNAME)</title>
<style>
:root {
  --bg0: #0d0f13;
  --bg1: #13161c;
  --bg2: #1a1e27;
  --bg3: #222737;
  --border: #2a2f3e;
  --border2: #353c50;
  --accent: #4fc3f7;
  --accent2: #81d4fa;
  --accent3: #00e5ff;
  --green: #69ff8f;
  --yellow: #ffd54f;
  --red: #ff5252;
  --orange: #ffb74d;
  --purple: #ce93d8;
  --text0: #e8eaf6;
  --text1: #b0bec5;
  --text2: #78909c;
  --font-mono: 'Cascadia Code', 'Fira Code', 'Consolas', monospace;
  --font-ui: 'Segoe UI Variable', 'Segoe UI', system-ui, sans-serif;
  --nav-w: 200px;
  --radius: 8px;
  --shadow: 0 4px 24px rgba(0,0,0,0.5);
}
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

html { scroll-behavior: smooth; }

body {
  background: var(--bg0);
  color: var(--text0);
  font-family: var(--font-ui);
  font-size: 13px;
  line-height: 1.5;
  display: flex;
  min-height: 100vh;
}

/* ─── Sidebar ─── */
#sidebar {
  width: var(--nav-w);
  min-width: var(--nav-w);
  background: var(--bg1);
  border-right: 1px solid var(--border);
  position: fixed;
  top: 0; left: 0; bottom: 0;
  overflow-y: auto;
  z-index: 100;
  display: flex;
  flex-direction: column;
}
#sidebar-header {
  padding: 18px 14px 14px;
  border-bottom: 1px solid var(--border);
  position: sticky;
  top: 0;
  background: var(--bg1);
  z-index: 1;
}
#sidebar-header .hostname {
  font-size: 12px;
  font-weight: 700;
  color: var(--accent3);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
#sidebar-header .gen-time {
  font-size: 10px;
  color: var(--text2);
  margin-top: 3px;
}
nav { padding: 8px 0; flex: 1; }
.nav-link {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 7px 14px;
  color: var(--text1);
  text-decoration: none;
  font-size: 12px;
  font-weight: 500;
  border-left: 2px solid transparent;
  transition: all 0.15s;
  white-space: nowrap;
}
.nav-link:hover { background: var(--bg2); color: var(--text0); border-left-color: var(--accent); }
.nav-link.active { background: var(--bg2); color: var(--accent); border-left-color: var(--accent3); }
.nav-icon { font-size: 13px; flex-shrink: 0; }

/* ─── Main Content ─── */
#main {
  margin-left: var(--nav-w);
  flex: 1;
  padding: 28px 32px 60px;
  max-width: 100%;
  overflow: hidden;
}

/* ─── Page Header ─── */
#page-header {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 32px;
  padding-bottom: 20px;
  border-bottom: 1px solid var(--border);
}
#page-header .logo {
  width: 44px; height: 44px;
  background: linear-gradient(135deg, var(--accent) 0%, var(--accent3) 100%);
  border-radius: var(--radius);
  display: flex; align-items: center; justify-content: center;
  font-size: 22px;
  flex-shrink: 0;
  box-shadow: 0 0 20px rgba(79,195,247,0.3);
}
#page-header h1 {
  font-size: 22px;
  font-weight: 700;
  color: var(--text0);
  letter-spacing: -0.02em;
}
#page-header .subtitle {
  font-size: 12px;
  color: var(--text2);
  margin-top: 2px;
  font-family: var(--font-mono);
}

/* ─── Search ─── */
#search-wrap {
  margin-bottom: 28px;
  position: sticky;
  top: 0;
  z-index: 50;
  padding: 10px 0;
  background: var(--bg0);
}
#search {
  width: 100%;
  max-width: 520px;
  background: var(--bg2);
  border: 1px solid var(--border2);
  border-radius: 24px;
  padding: 8px 18px 8px 40px;
  color: var(--text0);
  font-size: 13px;
  font-family: var(--font-ui);
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='%2378909c' viewBox='0 0 16 16'%3E%3Cpath d='M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.867-3.834zm-5.242 1.656a5 5 0 1 1 0-10 5 5 0 0 1 0 10z'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: 14px center;
}
#search:focus { border-color: var(--accent); box-shadow: 0 0 0 3px rgba(79,195,247,0.15); }
#search::placeholder { color: var(--text2); }

/* ─── Sections ─── */
.section {
  margin-bottom: 40px;
  scroll-margin-top: 60px;
}
.section-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 14px;
}
.section-header h2 {
  font-size: 15px;
  font-weight: 700;
  color: var(--text0);
  letter-spacing: -0.01em;
}
.section-icon {
  font-size: 16px;
}
.section-badge {
  font-size: 10px;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 12px;
  background: var(--bg3);
  color: var(--text2);
  margin-left: auto;
  font-family: var(--font-mono);
}
.section-divider {
  height: 1px;
  background: var(--border);
  margin-bottom: 14px;
}

/* ─── Sub-sections ─── */
.subsection {
  margin-bottom: 22px;
}
.subsection-title {
  font-size: 11px;
  font-weight: 700;
  color: var(--text2);
  letter-spacing: 0.1em;
  text-transform: uppercase;
  margin-bottom: 8px;
}

/* ─── KV Table ─── */
table.kv {
  width: 100%;
  max-width: 860px;
  border-collapse: collapse;
  background: var(--bg1);
  border-radius: var(--radius);
  overflow: hidden;
  border: 1px solid var(--border);
}
table.kv tr:nth-child(even) { background: var(--bg2); }
table.kv th {
  text-align: left;
  padding: 6px 14px;
  width: 240px;
  color: var(--text2);
  font-size: 11.5px;
  font-weight: 600;
  white-space: nowrap;
  border-right: 1px solid var(--border);
}
table.kv td {
  padding: 6px 14px;
  color: var(--text0);
  font-size: 12px;
  font-family: var(--font-mono);
  word-break: break-all;
}

/* ─── Data Tables ─── */
.tbl-wrap {
  width: 100%;
  overflow-x: auto;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  background: var(--bg1);
}
.tbl-wrap table {
  border-collapse: collapse;
  width: 100%;
  min-width: 400px;
}
.tbl-wrap table thead tr {
  background: var(--bg3);
  border-bottom: 1px solid var(--border2);
}
.tbl-wrap table thead th {
  padding: 8px 12px;
  text-align: left;
  font-size: 11px;
  font-weight: 700;
  color: var(--text2);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  white-space: nowrap;
  cursor: pointer;
  user-select: none;
}
.tbl-wrap table thead th:hover { color: var(--accent); }
.tbl-wrap table thead th.sort-asc::after  { content: ' ↑'; color: var(--accent); }
.tbl-wrap table thead th.sort-desc::after { content: ' ↓'; color: var(--accent); }
.tbl-wrap table tbody tr {
  border-bottom: 1px solid var(--border);
  transition: background 0.1s;
}
.tbl-wrap table tbody tr:last-child { border-bottom: none; }
.tbl-wrap table tbody tr:hover { background: var(--bg3); }
.tbl-wrap table tbody td {
  padding: 6px 12px;
  font-size: 12px;
  color: var(--text1);
  font-family: var(--font-mono);
  white-space: nowrap;
  max-width: 360px;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tbl-wrap table tbody td:first-child { color: var(--text0); }

/* ─── Status Badges ─── */
.tbl-wrap td[data-val="Running"],
.tbl-wrap td[data-val="OK"],
.tbl-wrap td[data-val="True"],
.tbl-wrap td[data-val="Enabled"] { color: var(--green) !important; }
.tbl-wrap td[data-val="Stopped"],
.tbl-wrap td[data-val="False"],
.tbl-wrap td[data-val="Disabled"] { color: var(--text2) !important; }
.tbl-wrap td[data-val="Error"],
.tbl-wrap td[data-val="Degraded"] { color: var(--red) !important; }
.tbl-wrap td[data-val="Warning"],
.tbl-wrap td[data-val="Unknown"] { color: var(--yellow) !important; }

/* ─── Stat Cards ─── */
.stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 12px;
  margin-bottom: 20px;
}
.stat-card {
  background: var(--bg2);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 14px 16px;
  position: relative;
  overflow: hidden;
}
.stat-card::before {
  content: '';
  position: absolute;
  top: 0; left: 0; right: 0;
  height: 2px;
  background: linear-gradient(90deg, var(--accent), var(--accent3));
}
.stat-card .stat-label {
  font-size: 10px;
  font-weight: 700;
  color: var(--text2);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  margin-bottom: 6px;
}
.stat-card .stat-value {
  font-size: 18px;
  font-weight: 700;
  color: var(--text0);
  font-family: var(--font-mono);
  line-height: 1.2;
}
.stat-card .stat-sub {
  font-size: 11px;
  color: var(--text2);
  margin-top: 3px;
  font-family: var(--font-mono);
}

/* ─── Bar chart inline ─── */
.bar-cell {
  display: flex;
  align-items: center;
  gap: 8px;
}
.bar-track {
  flex: 1;
  height: 4px;
  background: var(--bg3);
  border-radius: 2px;
  overflow: hidden;
}
.bar-fill {
  height: 100%;
  border-radius: 2px;
  background: var(--accent);
}
.bar-fill.warn { background: var(--yellow); }
.bar-fill.crit { background: var(--red); }

.empty {
  color: var(--text2);
  font-style: italic;
  padding: 10px 0;
  font-size: 12px;
}

/* ─── Scrollbar ─── */
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--border2); border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: var(--text2); }

/* ─── Print ─── */
@media print {
  #sidebar { display: none !important; }
  #main { margin-left: 0; padding: 0; }
  #search-wrap { display: none; }
  body { font-size: 11px; }
}
</style>
</head>
<body>

<div id="sidebar">
  <div id="sidebar-header">
    <div class="hostname">$($env:COMPUTERNAME)</div>
    <div class="gen-time">$generatedAt</div>
  </div>
  <nav>
$($navHtml -join "`n")
  </nav>
</div>

<div id="main">
  <div id="page-header">
    <div class="logo">🖥</div>
    <div>
      <h1>System Report</h1>
      <div class="subtitle">$($env:COMPUTERNAME) &nbsp;·&nbsp; Generated $generatedAt &nbsp;·&nbsp; Collected in $($elapsed.TotalSeconds.ToString('N1'))s</div>
    </div>
  </div>

  <div id="search-wrap">
    <input id="search" type="search" placeholder="Filter tables by keyword…" autocomplete="off"/>
  </div>

  <!-- ── STAT CARDS ── -->
  <div class="stat-grid">
    <div class="stat-card">
      <div class="stat-label">OS</div>
      <div class="stat-value" style="font-size:13px">$(Html-Escape $os.Caption)</div>
      <div class="stat-sub">Build $($os.BuildNumber)</div>
    </div>
    <div class="stat-card">
      <div class="stat-label">Uptime</div>
      <div class="stat-value" style="font-size:14px">$(Format-Uptime $uptime)</div>
      <div class="stat-sub">Since $($os.LastBootUpTime.ToString('MMM d, HH:mm'))</div>
    </div>
    <div class="stat-card">
      <div class="stat-label">RAM</div>
      <div class="stat-value">$(Format-Bytes ($os.TotalVisibleMemorySize * 1KB))</div>
      <div class="stat-sub">$(Format-Bytes ($os.FreePhysicalMemory * 1KB)) free</div>
    </div>
    <div class="stat-card">
      <div class="stat-label">CPU</div>
      <div class="stat-value" style="font-size:13px">$($cpus[0].Name.Trim() -replace '\s{2,}',' ')</div>
      <div class="stat-sub">$($cs.NumberOfLogicalProcessors) logical cores</div>
    </div>
    <div class="stat-card">
      <div class="stat-label">Storage</div>
      <div class="stat-value">$(if($physDisks -isnot [array]){'1'}else{$physDisks.Count}) disk(s)</div>
      <div class="stat-sub">$(if($logicalDisks -isnot [array]){'1'}else{$logicalDisks.Count}) volume(s)</div>
    </div>
    <div class="stat-card">
      <div class="stat-label">Domain</div>
      <div class="stat-value" style="font-size:14px">$(if ($cs.PartOfDomain) { Html-Escape $cs.Domain } else { 'Workgroup' })</div>
      <div class="stat-sub">$(Html-Escape $cs.Manufacturer) $(Html-Escape $cs.Model)</div>
    </div>
  </div>

  <!-- ══════════════════════ SECTIONS ══════════════════════ -->

  <div class="section" id="sec-os">
    <div class="section-header"><span class="section-icon">🖥️</span><h2>Operating System</h2></div>
    <div class="section-divider"></div>
    $(Build-KVTable -Data $osData -Id 'tbl-os')
  </div>

  <div class="section" id="sec-hw">
    <div class="section-header"><span class="section-icon">🔧</span><h2>Computer System</h2></div>
    <div class="section-divider"></div>
    $(Build-KVTable -Data $csData -Id 'tbl-cs')
  </div>

  <div class="section" id="sec-cpu">
    <div class="section-header"><span class="section-icon">⚡</span><h2>Processor(s)</h2><span class="section-badge">$($cpus.Count) CPU(s)</span></div>
    <div class="section-divider"></div>
    $(Build-Table -Id 'tbl-cpu' -Headers $cpuHeaders -Rows $cpuRows)
  </div>

  <div class="section" id="sec-ram">
    <div class="section-header"><span class="section-icon">💾</span><h2>Memory</h2><span class="section-badge">$($ramModules.Count) module(s)</span></div>
    <div class="section-divider"></div>
    $(Build-Table -Id 'tbl-ram' -Headers $ramHeaders -Rows $ramRows)
  </div>

  <div class="section" id="sec-disk">
    <div class="section-header"><span class="section-icon">💿</span><h2>Storage</h2></div>
    <div class="section-divider"></div>
    <div class="subsection">
      <div class="subsection-title">Physical Disks ($($physDisks.Count))</div>
      $(Build-Table -Id 'tbl-phys' -Headers $diskHeaders -Rows $diskRows)
    </div>
    <div class="subsection">
      <div class="subsection-title">Logical Volumes ($($logicalDisks.Count))</div>
      $(Build-Table -Id 'tbl-vol' -Headers $volHeaders -Rows $volRows)
    </div>
    <div class="subsection">
      <div class="subsection-title">Partitions</div>
      $(Build-Table -Id 'tbl-part' -Headers $partHeaders -Rows $partRows)
    </div>
  </div>

  <div class="section" id="sec-gpu">
    <div class="section-header"><span class="section-icon">🖵</span><h2>Display / GPU</h2></div>
    <div class="section-divider"></div>
    <div class="subsection">
      <div class="subsection-title">Video Controllers</div>
      $(Build-Table -Id 'tbl-gpu' -Headers $gpuHeaders -Rows $gpuRows)
    </div>
    <div class="subsection">
      <div class="subsection-title">Monitors</div>
      $(Build-Table -Id 'tbl-mon' -Headers $monHeaders -Rows $monRows -EmptyMsg 'Monitor WMI data not available.')
    </div>
    <div class="subsection">
      <div class="subsection-title">Sound Devices</div>
      $(Build-Table -Id 'tbl-snd' -Headers $soundHeaders -Rows $soundRows)
    </div>
  </div>

  <div class="section" id="sec-net">
    <div class="section-header"><span class="section-icon">🌐</span><h2>Network</h2></div>
    <div class="section-divider"></div>
    <div class="subsection">
      <div class="subsection-title">Adapters (IP Enabled)</div>
      $(Build-Table -Id 'tbl-net' -Headers $netHeaders -Rows $netRows)
    </div>
    <div class="subsection">
      <div class="subsection-title">TCP Connections</div>
      $(Build-Table -Id 'tbl-tcp' -Headers $tcpHeaders -Rows $tcpRows)
    </div>
    <div class="subsection">
      <div class="subsection-title">UDP Endpoints</div>
      $(Build-Table -Id 'tbl-udp' -Headers $udpHeaders -Rows $udpRows)
    </div>
    <div class="subsection">
      <div class="subsection-title">DNS Client Cache</div>
      $(Build-Table -Id 'tbl-dns' -Headers $dnsCacheHeaders -Rows $dnsCacheRows -EmptyMsg 'DNS cache empty or not accessible.')
    </div>
    <div class="subsection">
      <div class="subsection-title">Shared Folders</div>
      $(Build-Table -Id 'tbl-shares' -Headers $shareHeaders -Rows $shareRows)
    </div>
  </div>

  <div class="section" id="sec-procs">
    <div class="section-header"><span class="section-icon">⚙️</span><h2>Running Processes</h2><span class="section-badge">$($processes.Count) processes</span></div>
    <div class="section-divider"></div>
    $(Build-Table -Id 'tbl-proc' -Headers $procHeaders -Rows $procRows)
  </div>

  <div class="section" id="sec-services">
    <div class="section-header"><span class="section-icon">🔌</span><h2>Services</h2><span class="section-badge">$($services.Count) total</span></div>
    <div class="section-divider"></div>
    $(Build-Table -Id 'tbl-svc' -Headers $svcHeaders -Rows $svcRows)
  </div>

  <div class="section" id="sec-drivers">
    <div class="section-header"><span class="section-icon">📦</span><h2>Drivers</h2><span class="section-badge">$($drivers.Count) drivers</span></div>
    <div class="section-divider"></div>
    $(Build-Table -Id 'tbl-drv' -Headers $drvHeaders -Rows $drvRows)
  </div>

  <div class="section" id="sec-apps">
    <div class="section-header"><span class="section-icon">📋</span><h2>Installed Software</h2></div>
    <div class="section-divider"></div>
<div class='subsection'>
      <div class='subsection-title'>Win32 Applications — Registry ($($appRows.Count) entries)</div>
      $(Build-Table -Id 'tbl-apps' -Headers $appHeaders -Rows $appRows -EmptyMsg 'No registry apps found.')
    </div>
    <div class='subsection'>
      <div class='subsection-title'>AppX / Store Packages ($($appxRows.Count) packages)</div>
      $(Build-Table -Id 'tbl-appx' -Headers $appxHeaders -Rows $appxRows -EmptyMsg 'No AppX packages found.')
    </div>
    <div class="subsection">
      <div class="subsection-title">Startup Programs</div>
      $(Build-Table -Id 'tbl-start' -Headers $startHeaders -Rows $startRows)
    </div>
  </div>

  <div class="section" id="sec-security">
    <div class="section-header"><span class="section-icon">🔒</span><h2>Security</h2></div>
    <div class="section-divider"></div>
    <div class="subsection">
      <div class="subsection-title">TPM</div>
      $(if ($tpmData.Count -gt 0) { Build-KVTable -Data $tpmData -Id 'tbl-tpm' } else { "<p class='empty'>TPM not present or not accessible.</p>" })
    </div>
$(if ($batData.Count -gt 0) {
"    <div class='subsection'>
      <div class='subsection-title'>Battery</div>
      $(Build-KVTable -Data $batData -Id 'tbl-bat')
    </div>"
})
    <div class="subsection">
      <div class="subsection-title">Hotfixes / Windows Updates ($($hotfixes.Count))</div>
      $(Build-Table -Id 'tbl-hf' -Headers $hfHeaders -Rows $hfRows)
    </div>
    <div class="subsection">
      <div class="subsection-title">All PnP Devices ($($allDevices.Count))</div>
      $(Build-Table -Id 'tbl-dev' -Headers $devHeaders -Rows $devRows)
    </div>
    <div class="subsection">
      <div class="subsection-title">⚠ Problem Devices ($($probRows.Count))</div>
      $(Build-Table -Id 'tbl-prob' -Headers $devHeaders -Rows $probRows -EmptyMsg '✅ No problem devices found.')
    </div>
  </div>

  <div class="section" id="sec-sched">
    <div class="section-header"><span class="section-icon">📅</span><h2>Scheduled Tasks</h2><span class="section-badge">$($tasks.Count) active</span></div>
    <div class="section-divider"></div>
    $(Build-Table -Id 'tbl-task' -Headers $taskHeaders -Rows $taskRows)
  </div>

  <div class="section" id="sec-users">
    <div class="section-header"><span class="section-icon">👤</span><h2>Users &amp; Groups</h2></div>
    <div class="section-divider"></div>
    <div class="subsection">
      <div class="subsection-title">Local Users ($($localUsers.Count))</div>
      $(Build-Table -Id 'tbl-users' -Headers $userHeaders -Rows $userRows)
    </div>
    <div class="subsection">
      <div class="subsection-title">Local Groups ($($localGroups.Count))</div>
      $(Build-Table -Id 'tbl-grps' -Headers $grpHeaders -Rows $grpRows)
    </div>
  </div>

  <div class="section" id="sec-events">
    <div class="section-header"><span class="section-icon">📊</span><h2>Recent Errors (Last 7 Days)</h2><span class="section-badge">$($recentErrors.Count) events</span></div>
    <div class="section-divider"></div>
    $(Build-Table -Id 'tbl-evt' -Headers $evtHeaders -Rows $evtRows -EmptyMsg 'No errors in System or Application logs in the past 7 days.')
  </div>

  <div class="section" id="sec-env">
    <div class="section-header"><span class="section-icon">📝</span><h2>Environment Variables</h2><span class="section-badge">$($envRows.Count) variables</span></div>
    <div class="section-divider"></div>
    $(Build-Table -Id 'tbl-env' -Headers $envHeaders -Rows $envRows)
  </div>

</div><!-- /main -->

<script>
// ── Sort tables ──
document.querySelectorAll('.tbl-wrap table').forEach(tbl => {
  const ths = tbl.querySelectorAll('thead th');
  ths.forEach((th, i) => {
    let asc = true;
    th.addEventListener('click', () => {
      ths.forEach(t => t.classList.remove('sort-asc','sort-desc'));
      th.classList.add(asc ? 'sort-asc' : 'sort-desc');
      const tbody = tbl.querySelector('tbody');
      const rows  = [...tbody.querySelectorAll('tr')];
      rows.sort((a, b) => {
        const av = a.cells[i]?.textContent.trim() || '';
        const bv = b.cells[i]?.textContent.trim() || '';
        const an = parseFloat(av.replace(/[^0-9.\-]/g,'')), bn = parseFloat(bv.replace(/[^0-9.\-]/g,''));
        if (!isNaN(an) && !isNaN(bn)) return asc ? an-bn : bn-an;
        return asc ? av.localeCompare(bv) : bv.localeCompare(av);
      });
      rows.forEach(r => tbody.appendChild(r));
      asc = !asc;
    });
  });
});

// ── Status coloring ──
document.querySelectorAll('.tbl-wrap td').forEach(td => {
  td.dataset.val = td.textContent.trim();
});

// ── Search / Filter ──
const searchInput = document.getElementById('search');
searchInput.addEventListener('input', () => {
  const q = searchInput.value.toLowerCase().trim();
  document.querySelectorAll('.tbl-wrap table tbody tr').forEach(row => {
    row.style.display = (!q || row.textContent.toLowerCase().includes(q)) ? '' : 'none';
  });
});

// ── Active nav on scroll ──
const sections = document.querySelectorAll('.section[id]');
const navLinks  = document.querySelectorAll('.nav-link');
const observer  = new IntersectionObserver(entries => {
  entries.forEach(e => {
    if (e.isIntersecting) {
      navLinks.forEach(l => {
        l.classList.toggle('active', l.getAttribute('href') === '#'+e.target.id);
      });
    }
  });
}, { threshold: 0.15, rootMargin: '-60px 0px -70% 0px' });
sections.forEach(s => observer.observe(s));
</script>
</body>
</html>
"@

# ─────────────────────────────────────────────────────────────────────────────
# WRITE FILE
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
[System.IO.File]::WriteAllText($ReportFile, $html, [System.Text.Encoding]::UTF8)
Write-Host "Report written: $ReportFile" -ForegroundColor Green
Start-Process $ReportFile