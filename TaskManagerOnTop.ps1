#set task manager to always ontop win11

$settingsFile = "$env:LOCALAPPDATA\Microsoft\Windows\TaskManager\settings.json"

#kill taskmanager if its open
Stop-Process -Name Taskmgr -Force -ErrorAction SilentlyContinue

$jsonContent = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
#add always ontop property
$jsonContent | Add-Member -NotePropertyName 'AlwaysOnTop' -NotePropertyValue $true -Force

$jsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsFile
