If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}

Write-Host 'Enabling Loundness EQ For Eligible Devices...'
#get enabled sound devices
$deviceIDs = (Get-WmiObject -Class Win32_SoundDevice | Where-Object { $_.Status -eq 'OK' }).DeviceID
#get properties key for each render guid
$devicePaths = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\*\Properties'
#get win version
$OS = Get-CimInstance Win32_OperatingSystem
if ($OS.BuildNumber -gt 19045) {
    $win11 = $true
}
else {
    $win11 = $false
}
foreach ($deviceID in $deviceIDs) {
    foreach ($device in $devicePaths) {
        #match the correct render guid with device id
        if (($device.GetValueNames() | ForEach-Object { $device.GetValue($_) }) -like "*$deviceID") { 
            if ($win11) {
                #check for {b13412ee-07af-4c57-b08b-e327f8db085b} as it seems audio devices with a third party driver/enhancements will not have this guid
                if (test-path "$($device.PSParentPath)\FxProperties\{b13412ee-07af-4c57-b08b-e327f8db085b}") {
                    $fullPath = Join-Path -Path $device.PSParentPath.Replace('Microsoft.PowerShell.Core\Registry::', '') -ChildPath FxProperties
                    #user folder
                    $fullPathUser = "$fullPath\{b13412ee-07af-4c57-b08b-e327f8db085b}\User"
                    #need to use reg file because for some reason reg add is (access denied)
                    $regFile = New-Item "$env:TEMP\EQ.reg" -Force 
                    $regFileContent = @"
Windows Registry Editor Version 5.00
[$fullPath]
"{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},3"="{5860E1C5-F95C-4a7a-8EC8-8AEF24F379A1}"
"{01fb17e3-796c-4451-8163-68cdc1321a60},3"=hex:0b,00,00,00,01,00,00,00,00,00,\
00,00
"{5b64fcb1-8c32-4844-9dcb-15a45df000fc},3"=hex:0b,00,00,00,01,00,00,00,00,00,\
00,00
"{fc52a749-4be9-4510-896e-966ba6525980},3"=hex:0b,00,00,00,01,00,00,00,ff,ff,\
00,00
"{9c00eeed-edce-4cd8-ae08-cb05e8ef57a0},3"=hex:03,00,00,00,01,00,00,00,07,00,\
00,00
[$fullPathUser]
"{fc52a749-4be9-4510-896e-966ba6525980},3"=hex:0b,00,00,00,01,00,00,00,ff,ff,\
00,00
"{9c00eeed-edce-4cd8-ae08-cb05e8ef57a0},3"=hex:03,00,00,00,01,00,00,00,07,00,\
  00,00
"@
                    Set-Content $regFile -Value $regFileContent -Force 
                    regedit.exe /s $regFile
                    Start-Sleep 1
                } 
            }
            else {
                #apply for win 10 machines 
                $fullPath = Join-Path -Path $device.PSParentPath.Replace('Microsoft.PowerShell.Core\Registry::', '') -ChildPath FxProperties
                #need to use reg file because for some reason reg add is (access denied)
                $regFile = New-Item "$env:TEMP\EQ.reg" -Force 
                $regFileContent = @"
Windows Registry Editor Version 5.00
[$fullPath]
"{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},3"="{5860E1C5-F95C-4a7a-8EC8-8AEF24F379A1}"
"{fc52a749-4be9-4510-896e-966ba6525980},3"=hex:0b,00,00,00,01,00,00,00,ff,ff,\
  00,00
"{9c00eeed-edce-4cd8-ae08-cb05e8ef57a0},3"=hex:03,00,00,60,01,00,00,00,07,00,\
  00,00
"@
                Set-Content $regFile -Value $regFileContent -Force 
                regedit.exe /s $regFile
                Start-Sleep 1
            }
           
        } 
    }
}
#cleanup reg file
Remove-Item $regFile -Force -ErrorAction SilentlyContinue