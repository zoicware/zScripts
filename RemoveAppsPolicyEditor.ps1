If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}

function Get-ProductKey {
    <#
    .SYNOPSIS
        Retrieves product keys and OS information from a local or remote system/s.
    .DESCRIPTION
        Retrieves the product key and OS information from a local or remote system/s using WMI and/or ProduKey. Attempts to
        decode the product key from the registry, shows product keys from SoftwareLicensingProduct (SLP), and attempts to use
        ProduKey as well. Enables RemoteRegistry service if required.
        Originally based on this script: https://gallery.technet.microsoft.com/scriptcenter/Get-product-keys-of-local-83b4ce97
    .NOTES   
        Author: Matthew Carras
    #>

    Begin {
        [uint32]$HKLM = 2147483650 # HKEY_LOCAL_MACHINE definition for GetStringValue($hklm, $subkey, $value)

        # Define local function to decode binary product key data in registry
        # VBS Source: https://forums.mydigitallife.net/threads/vbs-windows-oem-slp-key.25284/
        function DecodeProductKeyData {
            param(
                [Parameter(Mandatory = $true)]
                [byte[]]$BinaryValuePID
            )
            Begin {
                # for decoding product key
                $KeyOffset = 52
                $CHARS = 'BCDFGHJKMPQRTVWXY2346789' # valid characters in product key
                $insert = 'N' # for Win8 or 10+
            } #end Begin
            Process {
                $ProductKey = ''
                $isWin8_or_10 = [math]::floor($BinaryValuePID[66] / 6) -band 1
                $BinaryValuePID[66] = ($BinaryValuePID[66] -band 0xF7) -bor (($isWin8_or_10 -band 2) * 4)
                for ( $i = 24; $i -ge 0; $i-- ) {
                    $Cur = 0
                    for ( $X = $KeyOffset + 14; $X -ge $KeyOffset; $X-- ) {
                        $Cur = $Cur * 256
                        $Cur = $BinaryValuePID[$X] + $Cur
                        $BinaryValuePID[$X] = [math]::Floor([double]($Cur / 24))
                        $Cur = $Cur % 24
                    } #end for $X
                    $ProductKey = $CHARS[$Cur] + $ProductKey
                } #end for $i
                If ( $isWin8_or_10 -eq 1 ) {
                    $ProductKey = $ProductKey.Insert($Cur + 1, $insert)
                }
                $ProductKey = $ProductKey.Substring(1)
                for ($i = 5; $i -le 26; $i += 6) {
                    $ProductKey = $ProductKey.Insert($i, '-')
                }
                $ProductKey
            } #end Process
        } # end DecodeProductKeyData function
    } # end Begin
    Process {
        $ComputerName = [string[]]$Env:ComputerName
        $WmiSplat = @{ ErrorAction = 'Stop' } # Given to all WMI-related commands
        $remoteReg = Get-WmiObject -List -Namespace 'root\default' -ComputerName $ComputerName @WmiSplat | Where-Object { $_.Name -eq 'StdRegProv' }
        # Get OEM info from registry
        $regManufacturer = ($remoteReg.GetStringValue($HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation', 'Manufacturer')).sValue
        $regModel = ($remoteReg.GetStringValue($HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation', 'Model')).sValue
        If ( $regManufacturer -And -Not $OEMManufacturer ) {
            $OEMManufacturer = $regManufacturer
        }
        If ( $regModel -And -Not $OEMModel ) {
            $OEMModel = $regModel
        }
        # Get & Decode Product Keys from registry
        $getvalue = 'DigitalProductId'
        $regpath = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $key = ($remoteReg.GetBinaryValue($HKLM, $regpath, $getvalue)).uValue
        If ( $key ) {
            $ProductKey = DecodeProductKeyData $key
            $ProductName = ($remoteReg.GetStringValue($HKLM, $regpath, 'ProductName')).sValue
            If ( -Not $ProductName ) { $ProductName = '' }
        } # end if
        return $ProductKey
    } # end process
} # end function


# =======================================================
#                    BEGIN SCRIPT
# =======================================================

#check if os is 25h2
$os = Get-CimInstance Win32_OperatingSystem
if ($os.BuildNumber -lt 26200) {
    Write-Host 'Windows Version is Not Supported...' -ForegroundColor Red
    Write-Host 'This Policy Requires Windows 11 25H2 or Greater. Press Any Key to Exit' -ForegroundColor Red
    $host.UI.RawUI.ReadKey() *>$null
    exit
}
else {
    Write-Host '[+] Checking Windows Edition...' -ForegroundColor DarkGreen
    #check for enterprise or education edition as this is also required but can be changed 
    $edition = Get-WindowsEdition -Online
    Write-Host "[+] Edition Detected: $($edition.Edition)" -ForegroundColor DarkGreen
    if (!($edition.Edition -like '*Education*' -or $edition.Edition -like '*Enterprise*')) {
        Write-Host 'This Edition is NOT Supported...' -ForegroundColor Red
        Write-Host "[!] The Script Will Automatically Convert to the Enterprise Edition and Revert Back to $($edition.Edition)" -ForegroundColor Yellow

        #convert edition to enterprise
        $CurrentKey = Get-ProductKey
        if ($CurrentKey -eq '') {
            #pro key
            $CurrentKey = 'W269N-WFGWX-YVC9B-4J6C9-T83GX'
        }
        #activate using kms and a generic enterprise key
        Write-Host '[+] Converting Edition...' -ForegroundColor DarkGreen
        & cscript.exe /nologo C:\Windows\system32\slmgr.vbs /ipk NPPR9-FWDCX-D2C8J-H872K-2YT43 *>$null

        #revert back after the next restart
        $regLocation = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        $arguments = "-win 1 -ep bypass -c `"& cscript.exe /nologo C:\Windows\system32\slmgr.vbs /ipk $CurrentKey`"" 
        Set-ItemProperty $regLocation -Name 'NextRun' -Value "Powershell.exe $arguments" -Force
    }
    else {
        Write-Host '[+] Edition Supported... No Conversion Needed' -ForegroundColor DarkGreen
    }

    $removeAppsPath = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Appx\RemoveDefaultMicrosoftStorePackages'
    #enable policy 
    Reg.exe add $removeAppsPath /v 'Enabled' /t REG_DWORD /d '1' /f *>$null

    #all packages that can be selected from group policy 
    $defaultPackageOptions = @(
        'Clipchamp.Clipchamp_yxz26nhyzhsrt'
        'Microsoft.BingNews_8wekyb3d8bbwe'
        'Microsoft.BingWeather_8wekyb3d8bbwe'
        'Microsoft.Copilot_8wekyb3d8bbwe'
        'Microsoft.GamingApp_8wekyb3d8bbwe'
        'Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe'
        'Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe'
        'Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe'
        'Microsoft.OutlookForWindows_8wekyb3d8bbwe'
        'Microsoft.Paint_8wekyb3d8bbwe'
        'Microsoft.ScreenSketch_8wekyb3d8bbwe'
        'Microsoft.Todos_8wekyb3d8bbwe'
        'Microsoft.Windows.Photos_8wekyb3d8bbwe'
        'Microsoft.WindowsCalculator_8wekyb3d8bbwe'
        'Microsoft.WindowsCamera_8wekyb3d8bbwe'
        'Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe'
        'Microsoft.WindowsNotepad_8wekyb3d8bbwe'
        'Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe'
        'Microsoft.WindowsTerminal_8wekyb3d8bbwe'
        'Microsoft.Xbox.TCUI_8wekyb3d8bbwe'
        'Microsoft.XboxIdentityProvider_8wekyb3d8bbwe'
        'Microsoft.XboxSpeechToTextOverlay_8wekyb3d8bbwe'
        'Microsoft.ZuneMusic_8wekyb3d8bbwe'
        'MicrosoftCorporationII.QuickAssist_8wekyb3d8bbwe'
        'MSTeams_8wekyb3d8bbwe'
    )
    
    foreach ($packageFamilyName in $defaultPackageOptions) {
        #add app for removal
        Write-Host "[+] Adding $packageFamilyName..." -ForegroundColor DarkGreen
        Reg.exe add "$removeAppsPath\$packageFamilyName" /v 'RemovePackage' /t REG_DWORD /d '1' /f *>$null
    }

    Write-Host '[!] Restart to Remove Apps...' -ForegroundColor Yellow
    $choice = Read-Host 'Restart Now? [Y/N]'
    if ($choice.ToUpper() -eq 'Y') {
        Restart-Computer
    }
    else {
        Exit
    }

}




