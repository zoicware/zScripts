#Microsoft WinVerifyTrust Signature Validation Vulnerability
$regPaths = @(
    'HKLM:\Software\Microsoft\Cryptography\Wintrust\Config',
    'HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config'
)
$valueName = 'EnableCertPaddingCheck'

Write-Host 'Checking for Microsoft WinVerifyTrust Signature Validation Vulnerability...' -ForegroundColor Green
foreach ($path in $regPaths) {
    try {
        Get-ItemProperty $path -Name $valueName -ErrorAction Stop
    }
    catch {
        Write-Host "Path: [$path] does not exist!" -ForegroundColor Yellow
        Write-Host 'Creating registry entry...' -ForegroundColor Green
        New-Item $path -Force | Out-Null
        New-ItemProperty -Path $path -Name $valueName -PropertyType Dword -Value 1 -Force 
    }
}

#Microsoft Windows Security Update Registry Key Configuration Missing (ADV180012) (Spectre/Meltdown Variant 4)
$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
$names = @('FeatureSettingsOverride', 'FeatureSettingsOverrideMask')

Write-Host 'Checking for Spectre/Meltdown Variant 4 [ADV180012]' -ForegroundColor Green
try {
    $result = Get-ItemProperty $regPath -Name $names -ErrorAction Stop
    if ($result.FeatureSettingsOverride -ne 8396872) {
        throw #go to catch since value does not have all combined mitigations 
    }
}
catch {
    Write-Host 'Spectre/Meltdown mitigations not enabled!' -ForegroundColor Yellow
    Write-Host 'Enabling mitigations...' -ForegroundColor Green
    foreach ($name in $names) {
        if ($name -like '*Mask') {
            $value = 3
        }
        else {
            $value = 8396872
        }
        New-ItemProperty $regPath -Name $name -PropertyType Dword -Value $value -Force
    }
}


#Birthday attacks against Transport Layer Security (TLS) ciphers with 64bit block size Vulnerability (Sweet32)
$weakCiphers = @(
    'DES 56/56',
    'Triple DES 168',
    'Triple DES 168/168',
    'RC2 40/128',
    'RC2 56/128',
    'RC2 128/128',
    'IDEA 128/128'
)
$ciphersPath = 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers'
Write-Host 'Disabling all weak ciphers (Sweet32 Vulnerability)...' -ForegroundColor Green
foreach ($cipher in $weakCiphers) {
    #using reg.exe instead of powershell since ciphers have a / in the name
    Reg.exe add "$ciphersPath\$cipher" /v Enabled /t REG_DWORD /d 0 /f
}

#disable matching tls ciphers
$ciphers = @('3DES', 'DES', 'DES_CBC', 'RC2', 'IDEA')
$suites = $ciphers | foreach-object { Get-TlsCipherSuite -Name $_ }
foreach ($suite in $suites) {
    if ($suite.Name) {
        Disable-TlsCipherSuite $suite.Name -ErrorAction SilentlyContinue #error here is from trying to disable the same cipher again since $suites can have overlapping names
    }
}   