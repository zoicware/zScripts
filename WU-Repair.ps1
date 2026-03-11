If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}

#repair windows update from various potential issues 
$tempDir = (([System.IO.Path]::GetTempPath())).trimend('\')

Write-Host 'Stopping Windows Update Services...' -ForegroundColor Green
Stop-Service BITS -Force -ErrorAction SilentlyContinue
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service DoSvc -Force -ErrorAction SilentlyContinue
Stop-Service UsoSvc -Force -ErrorAction SilentlyContinue
Stop-Service WaaSMedicSvc -Force -ErrorAction SilentlyContinue
taskkill.exe /im 'wuaucltcore.exe' /f *>$null
taskkill.exe /im 'TiWorker.exe' /f *>$null
Get-BitsTransfer -AllUsers | Remove-BitsTransfer 

Write-Host 'Removing Windows Update Cache...' -ForegroundColor Green
Remove-Item -Path "$env:windir\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:windir\Logs\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue
reg.exe delete 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' /f *>$null
reg.exe delete 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting' /f *>$null
Remove-Item "$env:ProgramData\Application Data\Microsoft\Network\Downloader\*.*" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:windir\System32\catroot2" -Force -Recurse -ErrorAction SilentlyContinue
Rename-Item "$env:windir\WinSxS\pending.xml" -NewName 'pending.xml.old' -Force -ErrorAction SilentlyContinue
$temp1 = "$env:windir\Temp"
$temp2 = $tempDir
$tempFiles = (Get-ChildItem -Path "$temp1" , "$temp2" -Recurse -Force).FullName
foreach ($file in $tempFiles) {
    Remove-Item -Path "$file" -Recurse -Force -ErrorAction SilentlyContinue
}
#run disk cleanup 
$options = @(
    'Active Setup Temp Folders'
    'Delivery Optimization Files'
    'Downloaded Program Files'
    'Internet Cache Files'
    'Setup Log Files'
    'Temporary Files'
    'Windows Error Reporting Files'
    'Offline Pages Files'
    'Recycle Bin'
    'Temporary Setup Files'
    'Update Cleanup'
    'Upgrade Discarded Files'
    'Windows Defender'
    'Windows ESD installation files'
    'Windows Reset Log Files'
    'Windows Upgrade Log Files'
    'Previous Installations'
)
$key = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
foreach ($option in $options) {
    reg.exe add "$key\$option" /v StateFlags0069 /t REG_DWORD /d 00000002 /f >$null
}

#credits to @instead1337 for monitoring logic
$timeout = 600
$cleanupProcess = Start-Process cleanmgr.exe -ArgumentList '/sagerun:69' -Wait:$false -PassThru
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$lastCpuUsage = 0
$lastMemoryUsage = 0

while ($cleanupProcess -and !$cleanupProcess.HasExited -and $stopwatch.Elapsed.TotalSeconds -lt $timeout) {
    Start-Sleep -Seconds 10
    $process = Get-Process -Id $cleanupProcess.Id -EA SilentlyContinue
    if ($process) {
        $cpuUsage = $process.CPU
        $memoryUsage = $process.WS
        if ($cpuUsage -eq $lastCpuUsage -and $memoryUsage -eq $lastMemoryUsage) {
            if ($cleanupProcess.MainWindowHandle) {
                $cleanupProcess.CloseMainWindow() | Out-Null
                Start-Sleep -Seconds 5
                if (!$cleanupProcess.HasExited) { $cleanupProcess | Stop-Process -EA SilentlyContinue }
            }
            else {
                $cleanupProcess | Stop-Process -EA SilentlyContinue
            }
        }
        $lastCpuUsage = $cpuUsage
        $lastMemoryUsage = $memoryUsage
    }
        
}

Write-Host 'Setting Windows Update Services StartType...' -ForegroundColor Green
Set-Service BITS -StartupType Automatic -ErrorAction SilentlyContinue
Set-Service wuauserv -StartupType Manual -ErrorAction SilentlyContinue
Set-Service UsoSvc -StartupType Manual -ErrorAction SilentlyContinue
Set-Service DoSvc -StartupType Automatic -ErrorAction SilentlyContinue
Set-Service AppReadiness -StartupType Manual -ErrorAction SilentlyContinue
Set-Service CryptSvc -StartupType Automatic -ErrorAction SilentlyContinue
Set-Service WaaSMedicSvc -StartupType Manual -ErrorAction SilentlyContinue

Write-Host 'Running DISM Repair...' -ForegroundColor Green
Write-Host 'DISM can take a very long time please let this process finish...' -ForegroundColor DarkYellow
Write-Host '[TIP!] You can view the process in task manager by finding "Windows Module Installer Worker"' -ForegroundColor DarkYellow
Add-AppxPackage -RegisterByFamilyName -MainPackage 'MicrosoftWindows.Client.CBS_cw5n1h2txyewy' 
Dism.exe /Online /Cleanup-Image /RestoreHealth
Dism.exe /Online /Cleanup-Image /StartComponentCleanup /Resetbase
sfc.exe /scannow

Write-Host 'Starting Windows Update Services...' -ForegroundColor Green
Start-Service BITS *>$null
Start-Service DoSvc *>$null
Start-Service CryptSvc *>$null

Add-Type -AssemblyName System.Windows.Forms
$result = [System.Windows.Forms.MessageBox]::Show(
    "A restart is required to finish.`n`nWould you like to restart now?",
    'Restart Required',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question
)

if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
    Restart-Computer -Force
}
