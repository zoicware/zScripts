function Create-RegKey {
    <#
.SYNOPSIS
    Creates a registry key in the specified hive.

.DESCRIPTION
    The Create-RegKey function creates a registry key in one of the specified hives: HKLM, HKCU, HKCR, HKU, or HKCC.
    It uses the Windows API to perform the operation, ensuring compatibility and reliability.

.PARAMETER Hive
    Specifies the registry hive where the key will be created. Valid values are:
    - HKLM (HKEY_LOCAL_MACHINE)
    - HKCU (HKEY_CURRENT_USER)
    - HKCR (HKEY_CLASSES_ROOT)
    - HKU (HKEY_USERS)
    - HKCC (HKEY_CURRENT_CONFIG)

.PARAMETER Subkey
    Specifies the subkey to be created under the specified hive.

.EXAMPLE
    Create-RegKey -Hive HKLM -Subkey "SOFTWARE\MyCompany\MyApp"
    Creates a registry key at HKEY_LOCAL_MACHINE\SOFTWARE\MyCompany\MyApp.

.NOTES
    The function uses the RegCreateKeyEx function from the advapi32.dll library.

#>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('HKLM', 'HKCU', 'HKCR', 'HKU', 'HKCC')]
        [string]$Hive,
        [Parameter(Mandatory = $true)]
        [string]$Subkey

    )

    $fullCode = @'
    using System;
    using System.Runtime.InteropServices;

    namespace RegNamespace
    {
        public enum RegOption : uint
        {
            NonVolatile = 0x00000000,
            Volatile = 0x00000001,
            CreateLink = 0x00000002,
            BackupRestore = 0x00000004,
            OpenLink = 0x00000008
        }

        public enum RegSAM : uint
        {
            QueryValue = 0x0001,
            SetValue = 0x0002,
            CreateSubKey = 0x0004,
            EnumerateSubKeys = 0x0008,
            Notify = 0x0010,
            CreateLink = 0x0020,
            Wow6464Key = 0x0100,
            Wow6432Key = 0x0200,
            Wow64Res = 0x0300,
            Read = 0x20019,
            Write = 0x20006,
            Execute = 0x20019,
            AllAccess = 0xF003F
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct SECURITY_ATTRIBUTES
        {
            public int nLength;
            public IntPtr lpSecurityDescriptor;
            public int bInheritHandle;
        }

        public enum RegResult : uint
        {
            CreatedNewKey = 0x00000001,
            OpenedExistingKey = 0x00000002
        }

        public class CreateReg
        {
            [DllImport("advapi32.dll", SetLastError=true)]
            public static extern int RegCreateKeyEx(
                IntPtr hKey,
                string lpSubKey,
                IntPtr Reserved,
                string lpClass,
                RegOption dwOptions,
                RegSAM samDesired,
                ref SECURITY_ATTRIBUTES lpSecurityAttributes,
                out IntPtr phkResult,
                out RegResult lpdwDisposition);
        }
    }
'@
   
    try {
        Add-Type -TypeDefinition $fullCode -Language CSharp
    }
    catch {
        #hide error when type is already defined
    }
       
    
    
    if ($Hive -eq 'HKLM') {
        $HIVE_CHOICE = [System.IntPtr]2147483650
    }
    elseif ($Hive -eq 'HKCU') {
        $HIVE_CHOICE = [System.IntPtr]2147483649
    }
    elseif ($Hive -eq 'HKCR') {
        $HIVE_CHOICE = [System.IntPtr]2147483648
    }
    elseif ($Hive -eq 'HKU') {
        $HIVE_CHOICE = [System.IntPtr]2147483651
    }
    else {
        $HIVE_CHOICE = [System.IntPtr]2147483653
    }

    
    $KEY_WRITE = [RegNamespace.RegSAM]::Write
    $REG_OPTION_NON_VOLATILE = [RegNamespace.RegOption]::NonVolatile

    $securityAttributes = New-Object RegNamespace.SECURITY_ATTRIBUTES
    $securityAttributes.nLength = [System.Runtime.InteropServices.Marshal]::SizeOf([type][RegNamespace.SECURITY_ATTRIBUTES])
    $securityAttributes.lpSecurityDescriptor = [IntPtr]::Zero
    $securityAttributes.bInheritHandle = 0

    $phkResult = [IntPtr]::Zero
    $lpdwDisposition = [RegNamespace.RegResult]::CreatedNewKey

    $result = [RegNamespace.CreateReg]::RegCreateKeyEx(
        $HIVE_CHOICE,
        $Subkey,
        [IntPtr]::Zero,
        $null,
        $REG_OPTION_NON_VOLATILE,
        $KEY_WRITE,
        [ref]$securityAttributes,
        [ref]$phkResult,
        [ref]$lpdwDisposition
    )

    if ($result -eq 0) {
        Write-Output 'Registry Key Created Successfully'
    }
    else {
        Write-Output "An Error Occurred When Creating the Registry Key ERROR [$result]"
    }
    

}
Export-ModuleMember -Function Create-RegKey 

function Delete-RegKey {
    <#
.SYNOPSIS
    Deletes a registry key in the specified hive.

.DESCRIPTION
    The Delete-RegKey function deletes a registry key in one of the specified hives: HKLM, HKCU, HKCR, HKU, or HKCC.
    It uses the Windows API to perform the operation, ensuring compatibility and reliability.

.PARAMETER Hive
    Specifies the registry hive where the key will be deleted. Valid values are:
    - HKLM (HKEY_LOCAL_MACHINE)
    - HKCU (HKEY_CURRENT_USER)
    - HKCR (HKEY_CLASSES_ROOT)
    - HKU (HKEY_USERS)
    - HKCC (HKEY_CURRENT_CONFIG)

.PARAMETER Subkey
    Specifies the subkey to be deleted under the specified hive.

.EXAMPLE
    Delete-RegKey -Hive HKLM -Subkey "SOFTWARE\MyCompany\MyApp"
    Deletes a registry key at HKEY_LOCAL_MACHINE\SOFTWARE\MyCompany\MyApp.

.NOTES
    The function uses the RegDeleteKeyEx function from the advapi32.dll library.

#>

    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('HKLM', 'HKCU', 'HKCR', 'HKU', 'HKCC')]
        [string]$Hive,
        [Parameter(Mandatory = $true)]
        [string]$Subkey
    )
  
   
       
    $fullCode = @'
    using System;
    using System.Runtime.InteropServices;

    namespace RegNamespace
    {
        public enum RegSAM : uint
    {
        QueryValue = 0x0001,
        SetValue = 0x0002,
        CreateSubKey = 0x0004,
        EnumerateSubKeys = 0x0008,
        Notify = 0x0010,
        CreateLink = 0x0020,
        Wow6464Key = 0x0100,
        Wow6432Key = 0x0200,
        Wow64Res = 0x0300,
        Read = 0x20019,
        Write = 0x20006,
        Execute = 0x20019,
        AllAccess = 0xF003F
    }

    public class DeleteReg
            {
                [DllImport("advapi32.dll", EntryPoint = "RegDeleteKeyEx", SetLastError = true)]
                public static extern int RegDeleteKeyEx(
                    UIntPtr hKey,
                    string lpSubKey,
                    uint samDesired, 
                    uint Reserved);
            }
    }

'@

    try {
        Add-Type -TypeDefinition $fullCode -Language CSharp
    }
    catch {
        #hide error when type is already defined
    }



    #Define Constants
    $samDesired = [RegNamespace.RegSAM]::AllAccess
    $reserved = 0

    if ($Hive -eq 'HKLM') {
        $HIVE_CHOICE = [System.UIntPtr]::new(2147483650)
    }
    elseif ($Hive -eq 'HKCU') {
        $HIVE_CHOICE = [System.UIntPtr]::new(2147483649)
    }
    elseif ($Hive -eq 'HKCR') {
        $HIVE_CHOICE = [System.UIntPtr]::new(2147483648)
    }
    elseif ($Hive -eq 'HKU') {
        $HIVE_CHOICE = [System.UIntPtr]::new(2147483651)
    }
    else {
        $HIVE_CHOICE = [System.UIntPtr]::new(2147483653)
    }

    $result = [RegNamespace.DeleteReg]::RegDeleteKeyEx(
        $HIVE_CHOICE,
        $Subkey,
        $samDesired,
        $reserved
    )

    if ($result -eq 0) {
        Write-Output 'Registry Key Deleted Successfully'
    }
    else {
        Write-Output "An Error Occured When Deleting the Registry Key ERROR [$result]"
    }
}
Export-ModuleMember -Function Delete-RegKey


function Set-RegKeyValue {
    <#
.SYNOPSIS
    Sets a registry key value with the specified data type.

.DESCRIPTION
    The Set-RegKeyValue function sets a registry key value in the specified hive and subkey with the provided value name, value data, and value type. 
    It supports various data types including Binary, DWord, ExpandString, MultiString, QWord, and String.

.PARAMETER Hive
    The registry hive where the key is located. Valid values are HKLM, HKCU, HKCR, HKU, and HKCC.

.PARAMETER ValueName
    The name of the registry value to set.

.PARAMETER Subkey
    The subkey under the specified hive where the value is located.

.PARAMETER ValueData
    The data to set for the registry value. The data type must match the specified ValueType.

.PARAMETER ValueType
    The type of the registry value. Valid values are Binary, DWord, ExpandString, MultiString, QWord, and String.

.EXAMPLE
    Set-RegKeyValue -Hive HKLM -Subkey 'Software\TEST' -ValueName 'TestString' -ValueType String -ValueData "test key"
    This example sets a string value named 'TestString' with the data 'test key' in the 'Software\TEST' subkey of the HKLM hive.

.EXAMPLE
    Set-RegKeyValue -Hive HKLM -Subkey 'Software\TEST' -ValueName 'TestQWord' -ValueType QWord -ValueData 1234567890123456789
    This example sets a QWord value named 'TestQWord' with the data '1234567890123456789' in the 'Software\TEST' subkey of the HKLM hive.
#>
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('HKLM', 'HKCU', 'HKCR', 'HKU', 'HKCC')]
        [string]$Hive,
        [string]$ValueName,
        [string]$Subkey,
        $ValueData,
        [ValidateSet('Binary', 'DWord', 'ExpandString', 'MultiString', 'QWord', 'String')]
        [string]$ValueType
    )

    $fullCode = @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace RegNamespace
{
    public enum RegistryValueKind
    {
        String = 1,
        ExpandString = 2,
        Binary = 3,
        DWord = 4,
        MultiString = 7,
        QWord = 11
    }

    public class SetRegValue
    {
        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern int RegOpenKeyEx(
            UIntPtr hKey,
            [MarshalAs(UnmanagedType.LPStr)]
            string lpSubKey,
            uint ulOptions,
            int samDesired,
            out UIntPtr phkResult);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern uint RegSetValueEx(
            UIntPtr hKey,
            [MarshalAs(UnmanagedType.LPStr)]
            string lpValueName,
            int Reserved,
            RegistryValueKind dwType,
            IntPtr lpData,
            int cbData);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern int RegCloseKey(UIntPtr hKey);

        public static uint SetValue(UIntPtr hKey, string lpSubKey, string lpValueName, RegistryValueKind dwType, byte[] data)
        {
            UIntPtr subKeyHandle;
            int result = RegOpenKeyEx(hKey, lpSubKey, 0, 0x20006, out subKeyHandle); // KEY_SET_VALUE

            if (result != 0)
            {
                return (uint)result;
            }

            GCHandle handle = GCHandle.Alloc(data, GCHandleType.Pinned);
            try
            {
                uint setResult = RegSetValueEx(subKeyHandle, lpValueName, 0, dwType, handle.AddrOfPinnedObject(), data.Length);
                RegCloseKey(subKeyHandle);
                return setResult;
            }
            finally
            {
                handle.Free();
            }
        }
    }
}
'@

    try {
        Add-Type -TypeDefinition $fullCode -Language CSharp
    }
    catch {
        # Ignore duplicate error
    }

    if ($Hive -eq 'HKLM') {
        $HIVE_CHOICE = [System.UIntPtr]::new(2147483650)
    }
    elseif ($Hive -eq 'HKCU') {
        $HIVE_CHOICE = [System.UIntPtr]::new(2147483649)
    }
    elseif ($Hive -eq 'HKCR') {
        $HIVE_CHOICE = [System.UIntPtr]::new(2147483648)
    }
    elseif ($Hive -eq 'HKU') {
        $HIVE_CHOICE = [System.UIntPtr]::new(2147483651)
    }
    else {
        $HIVE_CHOICE = [System.UIntPtr]::new(2147483653)
    }

    
    $dwType = [RegNamespace.RegistryValueKind]::$ValueType
    
    switch ($ValueType) {
        'Binary' {
            $Valuedata = [System.Convert]::FromBase64String($ValueData)
        }
        'DWord' {
            $Valuedata = [BitConverter]::GetBytes([int]$ValueData)
        }
        'ExpandString' {
            $Valuedata = [System.Text.Encoding]::UTF8.GetBytes($ValueData)
        }
        'String' {
            $Valuedata = [System.Text.Encoding]::UTF8.GetBytes($ValueData)
        }
        'MultiString' {
            $Valuedata = [System.Text.Encoding]::UTF8.GetBytes(($ValueData -join "`0") + "`0")
        }
        'QWord' {
            $Valuedata = [BitConverter]::GetBytes([long]$ValueData)
        }
    }

    $result = [RegNamespace.SetRegValue]::SetValue($HIVE_CHOICE, $Subkey, $ValueName, $dwType, $ValueData)

    if ($result -eq 0) {
        Write-Output 'Registry Value Set Successfully'
    }
    else {
        Write-Output "An Error Occurred When Setting the Registry Value ERROR [$result]"
    }



}
Export-ModuleMember -Function Set-RegKeyValue