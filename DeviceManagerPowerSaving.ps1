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

$possibleValues = @(
    [pscustomobject]@{Name = 'AllowIdleIrpInD3'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{Name = 'SelectiveSuspendEnabled'; Value = 0; Type = 'Binary' }
    [pscustomobject]@{Name = 'DeviceIdleEnabled'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{Name = 'SelectiveSuspendOn'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{Name = 'DefaultIdleState'; Value = 0; Type = 'DWord' } #if this doesnt exist its the same as val = 0
    [pscustomobject]@{Name = 'DeviceIdleIgnoreWakeEnable'; Value = 0; Type = 'DWord' }
    [pscustomobject]@{Name = 'ForceSelectiveSuspend'; Value = 0; Type = 'DWord' } #only for bluetooth devices
    [pscustomobject]@{Name = 'IdleUsbSelectiveSuspendPolicy'; Value = $null; Type = 'DEL' } #del if exists https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-driver-installation-based-on-compatible-ids#configure-selective-suspend-for-usbsersys
)

$regPaths = Get-ChildItem 'HKLM:\SYSTEM\ControlSet001\Enum\USB' -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Device Parameters' } 

foreach ($regPath in $regPaths) {
    $props = Get-ItemProperty $regPath.PSPath | Get-Member -MemberType NoteProperty
    foreach ($value in $possibleValues) {
        if (@($props.Name) -contains $value.Name) {
            if ($value.Name -eq 'IdleUsbSelectiveSuspendPolicy') {
                Remove-ItemProperty -Path $regPath.PSPath -Name $value.Name -Force 
            }
            else {
                New-ItemProperty -Path $regPath.PSPath -Name $value.Name -Value $value.Value -PropertyType $value.Type -Force
            }
        }
    }
    #enable device manager checkbox for all
    New-ItemProperty -Path $regPath.PSPath -Name 'UserSetDeviceIdleEnabled' -Value 0 -PropertyType 'Dword' -Force
}