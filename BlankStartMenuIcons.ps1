If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}

#removes the text under start menu pinned items 
#if you prefer to just have the icons simply put all the pinned shortcut into a folder
#run this script to rename all of the shortcuts at once 

$shortcuts = (Get-ChildItem $PSScriptRoot -Filter '*.lnk').FullName
$blankChar = [char]0x2800
$multiplier = 1
foreach ($shortcut in $shortcuts) {
    $blankName = "$blankChar" * $multiplier
    Rename-Item $shortcut -NewName "$blankName.lnk" -Force
    $multiplier++
}