If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}


$policyDefPath = "$env:SystemRoot\PolicyDefinitions"
$admxFiles = Get-ChildItem $policyDefPath -Filter '*.admx'

$policyObjects = @()
foreach ($file in $admxFiles) {
    $admxContent = [xml](Get-Content $file.fullname -Raw)
    $policies = ([xml]$admxContent.InnerXml).policyDefinitions.policies.policy
    foreach ($policy in $policies) {
        try {
            $elements = @()
            $policy.elements.enum.item | ForEach-Object {
                $displayName = $_.displayName
                $displayName = $displayName.split('.')[1].TrimEnd(')')
                $valueType = ($_.value | Get-Member -MemberType Property).Name
                $obj = [PSCustomObject]@{
                    DisplayName = $displayName
                    Value       = $_.value.$($valueType).value
                }
                $elements += $obj
            }
            
            $policyObj = [PSCustomObject]@{
                Name     = $policy.name
                RegKey   = "HKLM\$($policy.Key)"
                Support  = $policy.supportedOn.ref
                Elements = $elements | ForEach-Object { "$($_.DisplayName) = $($_.Value)" }
            }
    
            $policyObjects += $policyObj
    
        }
        catch {
            try {
                $items = $policy.elements.enum | ForEach-Object {
                    $_.item
                }
                $items | ForEach-Object {
                    $displayName = $_.displayName
                    $displayName = $displayName.split('.')[1].TrimEnd(')')
                    $valueType = ($_.value | Get-Member -MemberType Property).Name
                    $obj = [PSCustomObject]@{
                        DisplayName = $displayName
                        Value       = $_.value.$($valueType).value
                    }
                    $elements += $obj
                }
        
                $policyObj = [PSCustomObject]@{
                    Name     = $policy.name
                    RegKey   = "HKLM\$($policy.Key)"
                    Support  = $policy.supportedOn.ref
                    Elements = $elements | ForEach-Object { "$($_.DisplayName) = $($_.Value)" }
                }
        
                $policyObjects += $policyObj
            
            }
            catch {
                try {
                    $valueType = ($policy.enabledValue | Get-Member -MemberType Property -ErrorAction Stop).Name
                
                    $policyObj = [PSCustomObject]@{
                        Name     = $policy.name
                        RegKey   = "HKLM\$($policy.Key)"
                        Support  = $policy.supportedOn.ref
                        Elements = "EnabledValue = $($policy.enabledValue.$($valueType).value) , DisabledValue = $($policy.disabledValue.$($valueType).value)"
                    }
            
                    $policyObjects += $policyObj
                    
                }
                catch {
                    if ($policy.elements.text.valueName) {
                        $policyObj = [PSCustomObject]@{
                            Name     = $policy.name
                            RegKey   = "HKLM\$($policy.Key)"
                            Support  = $policy.supportedOn.ref
                            Elements = $policy.elements.text.valueName
                        }
                    }
                    elseif ($policy.valueName) {
                        $policyObj = [PSCustomObject]@{
                            Name     = $policy.name
                            RegKey   = "HKLM\$($policy.Key)"
                            Support  = $policy.supportedOn.ref
                            Elements = $policy.valueName
                        }
                    }
                    else {
                        try {
                            $type = ($policy.elements | Get-Member -MemberType Property -ErrorAction Stop).Name
                            $valueName = $policy.elements.$($type).valueName
                            $minValue = $policy.elements.$($type).minValue
                            $maxValue = $policy.elements.$($type).maxValue
    
                            $policyObj = [PSCustomObject]@{
                                Name     = $policy.name
                                RegKey   = "HKLM\$($policy.Key)"
                                Support  = $policy.supportedOn.ref
                                Elements = "$valueName, minValue = $minValue , maxValue = $maxValue"
                            }
                        }
                        catch {
                            $type = ($policy.disabledList.item.value | Get-Member -MemberType Property).Name

                            $enabledList = $policy.enabledList.item | ForEach-Object {
                                $val = $_.value.$($type).value
                                "$($_.valueName) = $val"
                            }

                            $disabledList = $policy.disabledList.item | ForEach-Object {
                                $val = $_.value.$($type).value
                                "$($_.valueName) = $val"
                            }
                            
                            $policyObj = [PSCustomObject]@{
                                Name     = $policy.name
                                RegKey   = "HKLM\$($policy.Key)"
                                Support  = $policy.supportedOn.ref
                                Elements = "EnabledList: $enabledList , DisabledList: $disabledList"
                            }

                        }
                       
                    }
                    
                    $policyObjects += $policyObj
                    
                }
                
            }
         
        }
       
    }
    
    
}


$policyObjects | Out-GridView 

pause