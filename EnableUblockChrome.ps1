If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}
#edits chrome's local state.json file to add manifest v2 extension 
$config = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"

$jsonContent = Get-Content $config | ConvertFrom-Json

if (($jsonContent.browser | Get-Member -MemberType NoteProperty enabled_labs_experiments) -eq $null) {
    Write-Host 'Adding enabled_labs_experiments Property...'
    $jsonContent.browser | Add-Member -MemberType NoteProperty -Name enabled_labs_experiments -Value @()
}

#add chrome flags to allow ublock extension 
$jsonContent.browser.enabled_labs_experiments = @(
    'allow-legacy-mv2-extensions@1',
    'extension-manifest-v2-deprecation-disabled@2',
    'extension-manifest-v2-deprecation-unsupported@2',
    'extension-manifest-v2-deprecation-warning@2',
    'temporary-unexpire-flags-m137@1'
) 

$newContent = $jsonContent | ConvertTo-Json -Compress -Depth 10 
Write-Host 'Adding Chrome Flags to Config...'
Set-Content $config -Value $newContent -Encoding UTF8 -Force