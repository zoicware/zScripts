If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}


Write-Host 'Running System File Checker...'
Start-Process sfc.exe -ArgumentList '/scannow' -NoNewWindow -Wait

Write-Host 'Try to Repair Windows Update...'
Stop-Service wuauserv -NoWait -Force -ErrorAction SilentlyContinue
Stop-Service BITS -NoWait -Force -ErrorAction SilentlyContinue
Remove-Item -Path C:\Windows\SoftwareDistribution -Recurse -Force -ErrorAction SilentlyContinue
Set-Service BITS -StartupType Automatic
Set-Service wuauserv -StartupType Manual
Set-Service DoSvc -StartupType Automatic
Start-Service wuauserv 
Start-Service BITS
Start-Service DoSvc

Write-Host 'Running DISM Health Commands...'
#in order
&DISM.exe /Online /Cleanup-Image /ScanHealth
&DISM.exe /Online /Cleanup-Image /CheckHealth
&DISM.exe /Online /Cleanup-Image /RestoreHealth

Write-Host 'Resetting Network Settings...'
#network stuff
ipconfig /release                          
ipconfig /renew                           
ipconfig /flushdns                        
netsh winsock reset                        
netsh int ip reset 

#store and uwp app stuff
Write-Host 'Repairing Windows Store and UWP Apps...'
if((Get-Service AppXSvc).StartType -eq 'Disabled'){
    Set-Service AppXSvc -StartupType Manual 
}
Start-Process wsreset.exe -NoNewWindow                              
Get-AppXPackage -AllUsers | ForEach-Object {
try{Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction Stop}catch{}} 


Write-Host 'Scan System Drive...'
chkdsk /scan 

Write-Host 'DONE!' -ForegroundColor Green
$input = Read-Host 'Press Any Key to Exit...'
if($input){
    exit
}