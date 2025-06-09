

function Get-InstalledSoftware {

param(
    [switch]$ThirdPartyOnly,
    [switch]$AllApps #show apps even if they are marked as a system component

)


$regPath64 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'

$regPath32 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

$apps64 = Get-ChildItem $regPath64 
$apps32 = Get-ChildItem $regPath32


$installedApps = @()

foreach($app64 in $apps64){

$values = Get-ItemProperty $app64.PSPath 

$obj = [pscustomobject]@{
    RegPath = $app64.Name
    DisplayName = $values.DisplayName
    InstallLocation = $values.InstallLocation
    InstallSource = $values.InstallSource
    Publisher = $values.Publisher
    UninstallString = $values.UninstallString
    QuietUninstallString = $values.QuietUninstallString
    DisplayIcon = $values.DisplayIcon
    SystemComponent = $values.SystemComponent
}

$installedApps += $obj

}



foreach($app32 in $apps32){

$values = Get-ItemProperty $app32.PSPath 

$obj = [pscustomobject]@{
    RegPath = $app32.Name
    DisplayName = $values.DisplayName
    InstallLocation = $values.InstallLocation
    InstallSource = $values.InstallSource
    Publisher = $values.Publisher
    UninstallString = $values.UninstallString
    QuietUninstallString = $values.QuietUninstallString
    DisplayIcon = $values.DisplayIcon
    SystemComponent = $values.SystemComponent
}

$installedApps += $obj

}





if($ThirdPartyOnly){
    $installedApps = $installedApps | Where-Object {$_.Publisher -ne 'Microsoft Corporation' -and $_.Publisher -ne $null}
}

if(!($AllApps)){
  $installedApps = $installedApps | Where-Object {$_.SystemComponent -ne 1}
}

#filter out empty apps
$installedApps = $installedApps | Where-Object {$_.DisplayName -ne $null}

return $installedApps


}


#more apps
#need to compare to other location 

$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData'

$users = Get-ChildItem $regPath

$installedApps = @()

foreach($user in $users){
$hives = Get-ChildItem "$($user.PSPath)\Products" 

foreach($hive in $hives){
try{

$props = Get-ItemProperty "$($hive.PSPath)\InstallProperties" -ErrorAction Stop
  $obj = [pscustomobject]@{
        DisplayName = $props.DisplayName
        InstallLocation = $props.InstallLocation
        InstallSource = $props.InstallSource
        UninstallString = $props.UninstallString
        Publisher = $props.Publisher
        SystemComponent = $props.SystemComponent
  }

  $installedApps += $obj

}catch{}
  

}

}

$installedApps


