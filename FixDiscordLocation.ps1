If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}

#fix discord not saving its last window location 

$settings = "$env:appdata\discord\settings.json"
if (!(Test-Path $settings)) {
    Write-Host 'Settings.json Does Not Exist... Creating File'
    New-Item $settings -Force | Out-Null
}
$settingsContent = Get-Content $settings -Raw | ConvertFrom-Json

$propsName = @(
    'IS_MAXIMIZED', 
    'IS_MINIMIZED', 
    'WINDOW_BOUNDS'
)

if (!($settingsContent)) {
    $settingsContent = New-Object -TypeName PSObject
    foreach ($prop in $propsName) {
        Write-Host "Adding Property: $prop"
        if ($prop -eq 'WINDOW_BOUNDS') {
            $value = @{
                x      = $null
                y      = $null
                width  = $null
                height = $null
            }
            Add-Member -Name $prop -Value $value -MemberType NoteProperty -InputObject $settingsContent
        }
        else {
            Add-Member -Name $prop -Value $false -MemberType NoteProperty -InputObject $settingsContent
        }  
    }
}
else {
    $props = Get-Member -Name $propsName -InputObject $settingsContent
    foreach ($prop in $propsName) {
        if ($prop -notin $props.Name) {
            Write-Host "Adding Property: $prop"
            if ($prop -eq 'WINDOW_BOUNDS') {
                $value = @{
                    x      = $null
                    y      = $null
                    width  = $null
                    height = $null
                }
                Add-Member -Name $prop -Value $value -MemberType NoteProperty -InputObject $settingsContent
            }
            else {
                Add-Member -Name $prop -Value $false -MemberType NoteProperty -InputObject $settingsContent
            }
            
        }
    }
}
$newContent = $settingsContent | ConvertTo-Json -Depth 10
Set-Content $settings -Value $newContent -Force