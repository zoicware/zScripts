If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}


#define paths 
$sysDrive = $env:SystemDrive + '\'
$webPath = "$($sysDrive)Windows\Web"
$contentDelivPath = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets"
$systemAppPath = "$($sysDrive)Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\DesktopSpotlight\Assets\Images"
$irisServicePath = "$env:LOCALAPPDATA\Packages\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\LocalCache\Microsoft\IrisService"

#test paths and add valid ones to an array
$validPaths = @()
if (Test-Path $webPath) {
    $validPaths += $webPath
}
if (Test-Path $contentDelivPath) {
    $validPaths += $contentDelivPath
}
if (Test-Path $systemAppPath) {
    $validPaths += $systemAppPath
}
if (Test-Path $irisServicePath) {
    $validPaths += $irisServicePath
}

Write-Host 'Exporting Wallpapers from:'
foreach ($path in $validPaths) {
    Write-Host $path -ForegroundColor Green
}

#create export dir on desktop
$exportPath = New-Item "$env:USERPROFILE\Desktop\ExportedWallpapers" -ItemType Directory -Force 



#export images 
foreach ($path in $validPaths) {
    if ($path -like '*ContentDeliveryManager*') {
        #add .jpg extension
        $files = Get-ChildItem -Path $path -File -Force
        foreach ($file in $files.FullName) {
            $copiedFile = Copy-Item $file -Destination $exportPath -Force -PassThru
            Rename-Item $copiedFile.FullName -NewName "$($copiedFile.Name).jpg" -Force
        }
    }
    elseif ($path -like '*Web*') {
        $files = Get-ChildItem -Path $path -File -Recurse -Force
        foreach ($file in $files.FullName) {
            Copy-Item $file -Destination $exportPath -Force
        }
    }
    elseif ($path -like '*DesktopSpotlight*') {
        $files = Get-ChildItem -Path $path -File -Force -Filter '*.jpg'
        foreach ($file in $files.FullName) {
            Copy-Item $file -Destination $exportPath -Force
        }
    }
    elseif ($path -like '*IrisService*') {
        $dirs = Get-ChildItem -Path $path -Directory -Force
        foreach ($dir in $dirs.FullName) {
            $files = Get-ChildItem -Path $dir -File -Force
            foreach ($file in $files.FullName) {
                Copy-Item $file -Destination $exportPath -Force
            }
        }
    }
}

#add for checking image height
Add-Type -AssemblyName System.Drawing
#remove icon image from export
$exportedFiles = Get-ChildItem -Path $exportPath -File -Force
foreach ($file in $exportedFiles.FullName) {
    try {
        $image = [System.Drawing.Image]::FromFile($file)
        if ($image.Height -eq 64) {
            $image.Dispose()
            Remove-Item $file -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        $image.Dispose()
    }
    finally {
        $image.Dispose()
    }
    
}


 