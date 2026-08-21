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
    param([uint32]$FeatureId)
    $step1 = ($FeatureId -bxor 0x74161A4E) -band 0xFFFFFFFF
    $step2 = SwapBytes32 $step1
    $step3 = ($step2 -bxor 0x8FB23D4F) -band 0xFFFFFFFF
    $step4 = RotateRight32 -value $step3 -shift -1   # -1 & 31 = 31 -> rotate right 31 == rotate left 1
    $step5 = ($step4 -bxor 0x833EA8FF) -band 0xFFFFFFFF
    return [uint32]$step5
}

function Set-FeatureID {
    param(
        [switch]$enable,
        [switch]$disable,
        [uint32]$FeatureId
    )

    $regID = ObfuscateFeatureId $FeatureId
    # 1 = disabled 2 = enabled
    $value = @('1', '2')[[int]([bool]$enable)]
    Reg.exe add "HKLM\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\$regID" /v 'EnabledState' /t REG_DWORD /d "$value" /f 
}
