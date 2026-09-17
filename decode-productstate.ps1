function Convert-ProductState {
    param(
        [int]$stateInt
    )

    $hex = '0x{0:x}' -f $stateInt
    $sub = $hex.Substring(3, 2)

    #https://learn.microsoft.com/en-us/windows/win32/api/iwscapi/ne-iwscapi-wsc_security_product_state
    return $(switch ($sub) {
            '00' { 'OFF' }
            '01' { 'EXPIRED' }
            '10' { 'ON' }
            '11' { 'SNOOZED' }
            default { 'UNKNOWN' }
        })
}

$avs = Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct
foreach ($av in $avs) {
    Write-Host "Name: $($av.displayName)"
    Write-Host "Product State: $(Convert-ProductState $av.productState)"
}