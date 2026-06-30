# Mirrors Albacore.ViVe.ObfuscationHelpers (ViveTool)
function SwapBytes32 {
    param([uint32]$x)
    $x = (($x -shr 16) -band 0xFFFFFFFF) -bor (($x -shl 16) -band 0xFFFFFFFF)
    return ((($x -band 0xFF00FF00) -shr 8) -bor (($x -band 0x00FF00FF) -shl 8)) -band 0xFFFFFFFF
}

function RotateRight32 {
    param([uint32]$value, [int]$shift)
    #masks the shift amount to 0-31 for uint operands (shift & 31)
    $s = (($shift % 32) + 32) % 32
    if ($s -eq 0) { return $value }
    return ((($value -shr $s) -bor ($value -shl (32 - $s))) -band 0xFFFFFFFF)
}

function ObfuscateFeatureId {
    param([Parameter(Mandatory)][uint32]$FeatureId)
    $step1 = ($FeatureId -bxor 0x74161A4E) -band 0xFFFFFFFF
    $step2 = SwapBytes32 $step1
    $step3 = ($step2 -bxor 0x8FB23D4F) -band 0xFFFFFFFF
    $step4 = RotateRight32 -value $step3 -shift -1   # -1 & 31 = 31 -> rotate right 31 == rotate left 1
    $step5 = ($step4 -bxor 0x833EA8FF) -band 0xFFFFFFFF
    return [uint32]$step5
}


$settingsJSON = (Get-ChildItem -Path "$env:windir\SystemApps" -Recurse).FullName | Where-Object { $_ -like '*wsxpacks\Account\SettingsExtensions.json' }

#takeownership
#takeown /f $settingsJSON *>$null
#icacls $settingsJSON /grant *S-1-5-32-544:F /t *>$null

$jsonContent = Get-Content $settingsJSON | ConvertFrom-Json
$list = 'CopilotSubscriptionCard', 'CopilotSubscriptionCard_Enterprise'

#grab the velocity id and apply it to registry
#this prevents the file from being overwritten/repaired resulting in these cards coming back
if ($jsonContent.addedHomeCards) {
    $veloIDs = $jsonContent.addedHomeCards | Where-Object { $list -contains $_.cardID } | ForEach-Object { $_.conditions.velocityKey } 
    if ($veloIDs) {
        foreach ($veloID in $veloIDs) {
            #convert feature id to obfuscated reg id
            $regID = ObfuscateFeatureId $veloID.id
            #$value = if($veloID.default -eq 'enabled'){'0'}
            Reg.exe add "HKLM\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\$regID" /v 'EnabledState' /t REG_DWORD /d '0' /f
        }
    }

    #remove the cards from the json
    $jsonContent.addedHomeCards = $jsonContent.addedHomeCards | Where-Object { $list -notcontains $_.cardId }
}


$newContent = $jsonContent | ConvertTo-Json -Depth 100
Set-Content -Path $settingsJSON -Value $newContent -Force
