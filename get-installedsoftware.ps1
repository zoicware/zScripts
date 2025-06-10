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

#another location
$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData'

$users = Get-ChildItem $regPath

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


if($ThirdPartyOnly){
    $installedApps = $installedApps | Where-Object {$_.Publisher -ne 'Microsoft Corporation' -and $_.Publisher -ne $null}
}

if(!($AllApps)){
  $installedApps = $installedApps | Where-Object {$_.SystemComponent -ne 1}
}

#filter out empty apps
$installedApps = $installedApps | Where-Object {$_.DisplayName -ne $null}

#filter out duplicates
$installedApps = $installedApps | Group-Object -Property UninstallString | ForEach-Object { $_.Group | Select-Object -First 1 }

return $installedApps


}



function Get-UninstallString {

param($app)

$uninstallString = $app.UninstallString
$uninstallStringQ = $app.QuietUninstallString

$obj = [pscustomobject]@{
                UninstallString = $null
                MsiExe = $null
                Silent = $null
       }

    if($uninstallString -like "MsiExec.exe*"){
       $silentUninstall = ($uninstallString -replace '/I' , '/X') + " /qn"
       $obj.UninstallString = $silentUninstall
       $obj.MsiExe = $true
       $obj.Silent = $true
       return $obj
    }else{

        if($uninstallStringQ){
        $obj.MsiExe = $false
        $obj.Silent = $true
        $obj.UninstallString = $uninstallStringQ
        return $obj
        }else{
        $obj.MsiExe = $false
        $obj.Silent = $false
        $obj.UninstallString = $uninstallString
        return $obj
    }

}



}

#example
Get-InstalledSoftware -ThirdPartyOnly

