#disable allow device to be turned off to save power for every device that has this option in device manager
#reg key idleinworkingstate and object method need to be applied to work properly 
$devices = Get-CimInstance MSPower_DeviceEnable -Namespace root\wmi 
$basePath = 'HKLM\SYSTEM\ControlSet001\Enum'
foreach ($device in $devices) {
    $device.Enable = $false
    Set-CimInstance -InputObject $device
    $instanceID = ($device.InstanceName) -replace '_0$', '' #trim _0 off
    reg add "$basePath\$instanceID\Device Parameters\WDF" /v 'IdleInWorkingState' /t REG_DWORD /d '0' /f 
}


#disable wake for all devices that have it enabled
$devices = powercfg -devicequery wake_armed
foreach ($line in $devices) {
    if ($line -ne 'NONE') {
        powercfg -devicedisablewake "$line" *>$null
    }
}

#powercfg -devicequery wake_programmable