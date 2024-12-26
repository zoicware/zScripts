If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}


Write-Host 'Installing Sysinternals Proc Monitor and Proc Explorer...' -ForegroundColor Green
$procMonURL = 'https://download.sysinternals.com/files/ProcessMonitor.zip'
$procExpURL = 'https://download.sysinternals.com/files/ProcessExplorer.zip'
$unWanted = @(
    'Procmon.exe',
    'Procmon64a.exe',
    'Eula.txt',
    'Procexp.exe',
    'Procexp64a.exe'
)
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $procMonURL -OutFile "$env:TEMP\ProcMon.zip"
Invoke-WebRequest -Uri $procExpURL -OutFile "$env:TEMP\ProcExp.zip"
#extract out 64bit version
Expand-Archive "$env:TEMP\ProcMon.zip" -DestinationPath "$env:USERPROFILE\Desktop"
Expand-Archive "$env:TEMP\ProcExp.zip" -DestinationPath "$env:USERPROFILE\Desktop" -ErrorAction SilentlyContinue
Get-ChildItem -Path "$env:USERPROFILE\Desktop" | ForEach-Object {
    if($_.Name -in $unWanted){
        Remove-Item $_.FullName -Force
    }
}

