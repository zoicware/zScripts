function Run-Trusted([String]$command) {

    try {
        Stop-Service -Name TrustedInstaller -Force -ErrorAction Stop -WarningAction Stop
    }
    catch {
        taskkill /im trustedinstaller.exe /f >$null
    }
    #get bin path to revert later
    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='TrustedInstaller'"
    $DefaultBinPath = $service.PathName
    #make sure path is valid and the correct location
    $trustedInstallerPath = "$env:SystemRoot\servicing\TrustedInstaller.exe"
    if ($DefaultBinPath -ne $trustedInstallerPath) {
        $DefaultBinPath = $trustedInstallerPath
    }
    #convert command to base64 to avoid errors with spaces
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
    $base64Command = [Convert]::ToBase64String($bytes)
    #change bin to command
    sc.exe config TrustedInstaller binPath= "cmd.exe /c powershell.exe -encodedcommand $base64Command" | Out-Null
    #run the command
    sc.exe start TrustedInstaller | Out-Null
    #set bin back to default
    sc.exe config TrustedInstaller binpath= "`"$DefaultBinPath`"" | Out-Null
    try {
        Stop-Service -Name TrustedInstaller -Force -ErrorAction Stop -WarningAction Stop
    }
    catch {
        taskkill /im trustedinstaller.exe /f >$null
    }
  
}

#stop cam service and remove the database to allow these reg keys to apply 
Stop-Process -name SystemSettings -Force -ErrorAction SilentlyContinue
Stop-Service -Name 'camsvc' -Force -ErrorAction SilentlyContinue 
$command = "Remove-item `"$env:ProgramData\Microsoft\Windows\CapabilityAccessManager\CapabilityConsentStorage.db*`" -Force"
Run-Trusted -command $command

# Define the registry path and setup variables
$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore'
$regPath2 = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore'

$paths = (Get-ChildItem $regPath | Where-Object { $_.pspath -notlike '*microphone*' -and $_.pspath -notlike '*graphicsCaptureProgrammatic*' -and $_.pspath -notlike '*graphicsCaptureWithoutBorder*' }).PSPath
$userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$regContent = "Windows Registry Editor Version 5.00`n"
Remove-Item "$env:temp\AppPerms.reg" -Force -ErrorAction SilentlyContinue
New-Item "$env:temp\AppPerms.reg" -Force | Out-Null

#passkeys seems to not be added to the registry till you view it in settings so add them to be sure
$passkeyPaths = 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\passkeys' , 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\passkeysEnumeration'
if ($paths -notcontains $passkeyPaths) {
    $paths += $passkeyPaths
}

#music lib is another one that isnt in registry till you view it
$musicLib = 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\musicLibrary' 
if ($paths -notcontains $musicLib) {
    $paths += $musicLib
}

#same thing as above with downloads folder
$downloads = 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\downloadsFolder' 
if ($paths -notcontains $downloads) {
    $paths += $downloads
}

foreach ($path in $paths) {
    $name = split-path $path -Leaf

    # get the FileTime value and convert to hex for .reg format
    $fileTime = (Get-Date).ToFileTime()
    $bytes = [System.BitConverter]::GetBytes([int64]$fileTime)
    $hexString = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ','

    if (Test-Path "$regPath2\$name") {
        #setting has hkcu location too
        $regContent += @"

        [HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$name]
        "Value"="Deny"
        "LastSetTime"=hex(b):$hexString

        [HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$name]
        "Value"="Deny"
        "LastSetTime"=hex(b):$hexString

        [HKEY_USERS\$userSid\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$name]
        "Value"="Deny"
        "LastSetTime"=hex(b):$hexString
        
"@
    }
    else {
        $regContent += @"

        [HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$name]
        "Value"="Deny"
        "LastSetTime"=hex(b):$hexString

"@
    }

    #run binary to apply on newest 25h2 builds 
    start-process SystemSettingsAdminFlows.exe -args "SetCamSystemGlobal $name 0"

}

$regContent | Out-File "$env:temp\AppPerms.reg" -Append
regedit.exe /s "$env:temp\AppPerms.reg"

#stop cam service and remove the database to allow these reg keys to apply 
Stop-Service -Name 'camsvc' -Force -ErrorAction SilentlyContinue 
$command = "Remove-item `"$env:ProgramData\Microsoft\Windows\CapabilityAccessManager\CapabilityConsentStorage.db*`" -Force"
Run-Trusted -command $command

#other location settings to disable 
Reg.exe add 'HKCU\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\UserLocationOverridePrivacySetting' /v 'Value' /t REG_DWORD /d '0' /f
#set all 3 locations to ensure it sticks 
Reg.exe add "HKU\$userSid\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v 'ShowGlobalPrompts' /t REG_DWORD /d '0' /f
Reg.exe add 'HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' /v 'ShowGlobalPrompts' /t REG_DWORD /d '0' /f
Reg.exe add 'HKLM\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' /v 'ShowGlobalPrompts' /t REG_DWORD /d '0' /f

