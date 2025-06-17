function Get-InstalledSoftware {
#gets installed apps from registry using the well known "uninstall" location (appwiz.cpl apps)
#gets additional apps from lesser known location (dups are removed)
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
#create uninstall obj with silent msi args or silent uninstall string if it exists
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





function Run-Uninstallers {
#pass an array with uninstall string obj's from get-uninstallstring function
param([array]$uninstallStrings)


foreach($uninstallString in $uninstallStrings){

    if($uninstallString.MsiExe){
        $arguments = ($uninstallString.UninstallString -replace 'MsiExec.exe', '').Trim()
       # Start-Process MsiExec.exe -ArgumentList $arguments -Wait #wait for now might be able to uninstall multiple at once
    }else{

             #split path and args when path is surrounded by " or '
            $match = ([regex]'("[^"]+")(.*)').Matches($uninstallString.UninstallString)
            if (!$match.count) {
              #check for single quote if not "
              $match = ([regex]"('[^']+')(.*)").Matches($uninstallString.UninstallString)
            }
            if ($match.count) {
              $uninstallPath = ($match.captures.groups[1].value).Trim()
              $uninstallArgs = ($match.captures.groups[2].value).Trim()
            }else{

            #some will not have any " or ' 
            #some will be just a path with no args
            #might be a cleaner way to do this but the uninstall string is unpredictable

            #check if uninstall string is just a path
            if(Test-Path $uninstallString.UninstallString -ErrorAction Ignore){
                $uninstallPath = $uninstallString.UninstallString
                $uninstallArgs = $null
            }else{
                #path has args could be - or /
                #split the string on first arg char since splitting on the space could potentially split the path instead
                if($uninstallString.UninstallString -like '*-*'){
                    $uninstallPath, $uninstallArgs = $uninstallString.UninstallString -split '-' , 2
                    #add the arg char back
                    $uninstallArgs = "-$uninstallArgs"
                }
                elseif($uninstallString.UninstallString -like "*/*"){
                     $uninstallPath, $uninstallArgs = $uninstallString.UninstallString -split '/' , 2
                    #add the arg char back
                    $uninstallArgs = "/$uninstallArgs"
                }

            }

       }

           

            #test path incase uninstall exe has been removed but still exists in registry
            $rawPath = $uninstallPath -replace '"', '' -replace "'" , ''
            if(Test-Path $rawPath){
            
                if($uninstallArgs){
                    #Start-Process $uninstallPath -ArgumentList $uninstallArgs -Wait
                }else{
                    #Start-Process $uninstallPath -Wait
                }
            
            }
            

        }

    }


}




#-----------------------------------------------------------------------


#helper function to delete folders and files
function Remove-ItemForce {
    param($path)

    $isDir = $fase
    if(Test-Path "$path" -PathType Container){
        $isDir = $true
    }

    try{
       if($isDir){
        Remove-Item "$path" -Force -Recurse -ErrorAction Stop
       }else{
        Remove-Item "$path" -Force -ErrorAction Stop
       } 
    }catch{
        #need to takeown since admin priv failed
        if($isDir){
            takeown /f "$path" /r /d Y *>$null
            icacls "$path" /grant administrators:F /t *>$null
            Remove-Item "$path" -Force -Recurse -ErrorAction SilentlyContinue
        }else{
            takeown /f "$path" *>$null
            icacls "$path" /grant administrators:F /t *>$null
            Remove-Item "$path" -Force -ErrorAction SilentlyContinue
        }
        
    }

    if(Test-Path "$path" -ErrorAction Ignore){
        Write-Host "Unable to Remove $path" -ForegroundColor Red
        #create task to run on next restart to attempt to cleanup file(s)

        $regLocation = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        $script = "$env:TEMP\fileRemoval.ps1"
        $removalCode = "Remove-Item `"$path`" -Force -Recurse"
  
        if(!(Test-Path $script)){
        New-Item $script -Force | Out-Null
        }
        
    
        Add-Content $script -Value $removalCode -Force 
        $arguments = "-ep 4 -win 1 -c `"&$script; remove-item $script`""
        Set-ItemProperty $regLocation -Name "NextRun" -Value "Powershell.exe $arguments" -Force

    }else{
        Write-Host "Removed $path Successfully" -ForegroundColor Green
    }
}



# cleanup leftover files by searching common directories


function Cleanup-InstallDirs {
#pass app object from get-installedsoftware to check the Install location props
  param(
    $app,
    [switch]$QuickClean
 )


    #dirs that could contain leftover temp files 
    $installDirsCache = @(
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Downloads"
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
         $env:TEMP,
        "$env:SystemRoot\Temp",
        "$env:SystemRoot\Prefetch"

    )

    #less specfic locations takes more time to search but less opportunity for missed files
    $installDirsBroad = @(
        $env:ProgramData,
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $env:APPDATA, #roaming
        $env:LOCALAPPDATA   
    )

    $filter = "*" + ($app.DisplayName -split ' ')[0] + "*"
        #if the filter is just microsoft it will be too vauge
        if($filter -eq "*Microsoft*"){
        #get the next two words after microsoft
        $filter = "*" + ($app.DisplayName -split ' ',4)[1..2] + "*"
        }

    $foundDirs = @()
       
    if($QuickClean){
        #only search temp file dirs
       $foundDirs = ($installDirsCache | ForEach-Object {Get-ChildItem -Path $_ -Filter $filter -Recurse -ErrorAction SilentlyContinue}).FullName
        
    }else{
       #full cleanup
       #search temp dirs and install dirs
       $foundDirs = ($installDirsCache | ForEach-Object {Get-ChildItem -Path $_ -Filter $filter -Recurse -ErrorAction SilentlyContinue}).FullName
       $foundDirs += ($installDirsBroad | ForEach-Object {Get-ChildItem -Path $_ -Filter $filter -Recurse -ErrorAction SilentlyContinue}).FullName
       #match additional folders
       $folders = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Folders' 
       $members = $folders | Get-Member | Select-Object -Property Name
       $validFolders = @()
       foreach($member in $members){
            if(Test-Path $member.Name){
                $validFolders += $member.Name
            }
   
        }

        foreach($folder in $validFolders){
            if($folder -like $filter){
                $foundDirs += $folder
            }
        }
    }


    try{
    if(Test-Path $app.InstallSource -ErrorAction Ignore){
       # Remove-ItemForce $app.InstallSource 
    }

    if(Test-Path $app.InstallLocation -ErrorAction Ignore){
      # Remove-ItemForce $app.InstallLocation 
    }

    }catch{}

    

}





function Remove-RegLocation {
#removes the hkcu and hklm \ software entry for the app as this could contain app settings
    param($app)

 $locations = @(
        'HKCU:\Software',
        'HKLM:\SOFTWARE'
    )

 $name = ($app.DisplayName -split ' ')[0]
        #if the filter is just microsoft it will be too vauge
        if($name -eq "Microsoft"){
        #get the next two words after microsoft
        $name = ($app.DisplayName -split ' ',4)[1..2] -join ''
        $locations = @(
        'HKCU:\Software\Microsoft',
        'HKLM:\SOFTWARE\Microsoft'
    )
        }
   
   $foundPaths = ($locations | ForEach-Object { Get-ChildItem $_ } | Where-Object {$_.Name -like "*$name" }).PSPath

    foreach($path in $foundPaths){
       # Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }

}





#example
$installApps = Get-InstalledSoftware -AllApps
$uninstallStrings = @()

foreach($app in $installApps){
    Remove-RegLocation -app $app 
   # $uninstallStrings += Get-UninstallString -app $app
   pause
}



