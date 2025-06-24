If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}

function Manage-Updates {
    param (
        [switch]$Enable,
        [swtich]$Disable
    )


  if($Enable){
    Reg.exe delete 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'WUServer' /f *>$null
    Reg.exe delete 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'WUStatusServer' /f *>$null
    Reg.exe delete 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'UpdateServiceUrlAlternate' /f *>$null
    Reg.exe delete 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'SetProxyBehaviorForUpdateDetection' /f *>$null
    Reg.exe delete 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'SetDisableUXWUAccess' /f *>$null
    Reg.exe delete 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'DoNotConnectToWindowsUpdateInternetLocations' /f *>$null
    Reg.exe delete 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'ExcludeWUDriversInQualityUpdate' /f *>$null
    Reg.exe delete 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' /v 'NoAutoUpdate' /f *>$null
    Reg.exe delete 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' /v 'UseWUServer' /f *>$null
    Reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc' /v 'Start' /t REG_DWORD /d '3' /f *>$null
    Reg.exe delete 'HKU\S-1-5-20\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings' /v 'DownloadMode' /f *>$null
    Set-Service BITS -StartupType Automatic
Set-Service wuauserv -StartupType Manual
Set-Service DoSvc -StartupType Automatic

  }elseif($Disable){
  Stop-Service -Name UsoSvc -Force -ErrorAction SilentlyContinue
  Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
  Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
  Stop-Service -Name InstallService -Force -ErrorAction SilentlyContinue
  Stop-Service -Name dosvc -Force -ErrorAction SilentlyContinue
      Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'WUServer' /t REG_SZ /d 'https://DoNotUpdateWindows10.com/' /f *>$null
      Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'WUStatusServer' /t REG_SZ /d 'https://DoNotUpdateWindows10.com/' /f *>$null
      Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'UpdateServiceUrlAlternate' /t REG_SZ /d 'https://DoNotUpdateWindows10.com/' /f *>$null
      Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'SetProxyBehaviorForUpdateDetection' /t REG_DWORD /d '0' /f *>$null
      Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'SetDisableUXWUAccess' /t REG_DWORD /d '1' /f *>$null
      Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'DoNotConnectToWindowsUpdateInternetLocations' /t REG_DWORD /d '1' /f *>$null
      Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'ExcludeWUDriversInQualityUpdate' /t REG_DWORD /d '1' /f *>$null
      Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' /v 'NoAutoUpdate' /t REG_DWORD /d '1' /f *>$null
      Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' /v 'UseWUServer' /t REG_DWORD /d '1' /f *>$null
      Reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc' /v 'Start' /t REG_DWORD /d '4' /f *>$null
      Reg.exe add 'HKU\S-1-5-20\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings' /v 'DownloadMode' /t REG_DWORD /d '0' /f *>$null
      Reg.exe add 'HKLM\Software\Policies\Microsoft\WindowsStore' /v 'AutoDownload' /t REG_DWORD /d '2' /f *>$null
      Set-Service BITS -StartupType Disabled
Set-Service wuauserv -StartupType Disabled
Set-Service DoSvc -StartupType Disabled

  }

}


function Manage-Edge {
param (
    [switch]$Enable,
    [switch]$Disable

)


if($Enable){
Get-ScheduledTask -TaskName "MicrosoftEdgeUpdate*" | Enable-ScheduledTask
Set-Service -Name edgeupdate -StartupType Automatic 
Set-Service -Name edgeupdatem -StartupType Manual

}elseif($Disable){
Stop-Process -Name 'MicrosoftEdgeUpdate.exe' -Force -ErrorAction SilentlyContinue
Get-ScheduledTask -TaskName "MicrosoftEdgeUpdate*" | Disable-ScheduledTask 
Stop-Service -Name edgeupdate -Force
Stop-Service -Name edgeupdatem -Force
Set-Service -Name edgeupdate -StartupType Disabled 
Set-Service -Name edgeupdatem -StartupType Disabled
}




}

function Manage-Services {
    param (
    [switch]$Enable,
    [switch]$Disable
    )

     $services = @(
        'WSearch'
        'SysMain'
        'TrustedInstaller'
        'DPS' #prob need system priv
    )

    if($Enable){
    Set-Service -Name DPS -StartupType Automatic -ErrorAction SilentlyContinue
    Set-Service -Name TrustedInstaller -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name SysMain -StartupType Automatic -ErrorAction SilentlyContinue
    Set-Service -Name WSearch -StartupType Automatic -ErrorAction SilentlyContinue

    }elseif($Disable){
   
    foreach($svcName in $services){
    Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
    Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
    }

        Stop-Process -Name TiWorker -Force -ErrorAction SilentlyContinue
        Stop-Process -Name Widgets -Force -ErrorAction SilentlyContinue
        Stop-Process -Name WidgetService -Force -ErrorAction SilentlyContinue
    }
}


function Set-PowerPlan {
#set the plan to ultimate performance if the active plan is powersaver
$active = powercfg /getactive
if($active -like "*a1841308-3541-4fab-bc81-f71556f20b4a*"){
$guid = New-Guid
    powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $guid
    powercfg /setactive $guid
}

}


do{
Clear-Host
Write-Host "~ ~ ~ Game Mode ~ ~ ~" -ForegroundColor Cyan
Write-Host
Write-Host "[1] Enable Game Mode" -ForegroundColor Green
Write-Host "[2] Disable Game Mode" -ForegroundColor Red

$choice = Read-Host "Enter Option (1/2)"

if($choice -eq 1){
#enable game mode

#disable updates (kill services and processes)
#disable defender (hopefully without restart) (maybe user enters in game to add to exclusion)
#disable search indexing
#if power plan is power saver switch it to ultimate performance
#kill modules installer
#kill edge updater (maybe add other common browsers)



Manage-Updates -Disable
Manage-Edge -Disable
Set-PowerPlan
#need to disable defend first
Manage-Services -Disable

$done = $true
}elseif($choice -eq 2){


$done = $true
}else{
    Write-Host "[Error] Invalid Option...Enter 1 or 2" -ForegroundColor Red
    $done = $false
}

}while(!$done)


