If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}


$jsonPath = "$env:systemroot\System32\IntegratedServicesRegionPolicySet.json"
if (!(Test-Path $jsonPath)) {
    $jsonPath = "$env:windir\System32\IntegratedServicesRegionPolicySet.json"
}

$policies = @()
if (Test-Path $jsonPath) {
    takeown /f $jsonPath *>$null
    icacls $jsonPath /grant *S-1-5-32-544:F /t *>$null
    $jsonContent = Get-Content $jsonPath -Raw | ConvertFrom-Json
  
    foreach ($policy in $jsonContent.policies) {
        $jsonObj = [PSCustomObject]@{
            PolicyName         = $policy.'$comment'
            PolicyGUID         = $policy.guid
            PolicyDefaultState = $policy.defaultState
        }
        
        $policies += $jsonObj
    }
   
    $selectedPolicies = $policies | Out-GridView -PassThru
    $foundPolicies = $jsonContent.policies | Where-Object { $_.guid -in $selectedPolicies.PolicyGUID }
    foreach ($policy in $foundPolicies) {
        $defaultState = $policy.defaultState
        if ($defaultState -eq 'enabled') {
            Write-Host "Setting [$($policy.'$comment')] to Disabled..." -ForegroundColor Green
            $policy.defaultState = 'disabled'
        }
        else {
            Write-Host "Setting [$($policy.'$comment')] to Enabled..." -ForegroundColor Green
            $policy.defaultState = 'enabled'
        }
    }
    $newJSONContent = $jsonContent | ConvertTo-Json -Depth 100
    Set-Content $jsonPath -Value $newJSONContent -Force
}
else {
    Write-Host 'IntegratedServicesRegionPolicySet.json NOT Found...' -ForegroundColor Red
    pause
}