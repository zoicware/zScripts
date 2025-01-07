If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) 
{	Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	}


$key64 = 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
$key86 = 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

$subkeys64 = Get-ChildItem -Path $key64 
$subkeys86 = Get-ChildItem -Path $key86
Write-Host 'Hiding Runtimes for x64' -ForegroundColor Green
foreach($key in $subkeys64){
    if($key.GetValue('DisplayName') -like "Microsoft Visual C++*"){
        Reg.exe add "$($key.Name)" /v "SystemComponent" /t REG_DWORD /d "1" /f
    }
}
Write-Host 'Hiding Runtimes for x86' -ForegroundColor Green
foreach($key in $subkeys86){
    if($key.GetValue('DisplayName') -like "Microsoft Visual C++*"){
        Reg.exe add "$($key.Name)" /v "SystemComponent" /t REG_DWORD /d "1" /f
    }
}