#---------------- WIP ------------------
#auto logon / nuke any password or pin requirement

#get if user is ms account (doesnt work on domain joined rn)
$user = Get-LocalUser -Name $env:UserName

#if above fails 
[System.Security.Principal.WindowsIdentity]::GetCurrent().AuthenticationType #ms account = CloudAP


#remove pin (so they say)
Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' /v 'AllowDomainPINLogon' /d 0 /t REG_DWORD /f 
Reg.exe add 'HKLM\SOFTWARE\Microsoft\PolicyManager\default\Settings\AllowSignInOptions' /v 'value' /d 0 /t REG_DWORD /f
Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Biometrics' /v 'Enabled' /d 0 /t REG_DWORD /f
Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\PassportforWork' /v 'Enabled' /d 0 /t REG_DWORD /f

$path = "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\Microsoft\NGC"
takeown /f $path /r /d y 
icacls $path /grant administrators:F /t  
Remove-item $path -Recurse -Force
New-Item $path -ItemType Directory | Out-Null
icacls $path /T /Q /C /RESET

#disable password
Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device' /v 'DevicePasswordLessBuildVersion' /d 0 /t REG_DWORD /f 
Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' /v 'DisableLockWorkstation' /d 1 /t REG_DWORD /f
Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' /v 'ForceUnlockLogon' /d 0 /t REG_DWORD /f

#auto login for ms account
Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' /v 'AutoAdminLogon' /d '1' /t REG_SZ /f #think this is reg_sz
Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' /v 'DefaultUserName' /d $env:UserName /t REG_SZ /f #think we can just use the username env var
#needs password for ms account/user in plain text 
#avoid having the user input this might be able to steal it with a bit of work
Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' /v 'DefaultPassword' /d 'plaintextpass' /t REG_SZ /f


#remove password requirements/complexity
#using scedit which is tied to group policy

$cfgPath = "$env:temp\secedit.cfg"
$dbPath = "$env:temp\secedit.sdb"
secedit /export /cfg $cfgPath
$cfg = Get-Content $cfgPath

$cfg = $cfg -replace 'PasswordComplexity = 1', 'PasswordComplexity = 0'
$cfg = $cfg -replace 'MinimumPasswordLength = \d+', 'MinimumPasswordLength = 0'
$cfg = $cfg -replace 'MaximumPasswordAge = \d+', 'MaximumPasswordAge = -1'
$cfg = $cfg -replace 'MinimumPasswordAge = \d+', 'MinimumPasswordAge = 0'
$cfg = $cfg -replace 'PasswordHistoryCount = \d+', 'PasswordHistoryCount = 0'

$cfg | Out-File $cfgPath -Encoding ascii

secedit /configure /db $dbPath /cfg $cfgPath /areas SECURITYPOLICY

gpupdate /force

Remove-Item $cfgPath, $dbPath  -ErrorAction SilentlyContinue

#set secure autologin
#https://gist.github.com/RezaAmbler/bc91bfeb57458bb9a9bc

