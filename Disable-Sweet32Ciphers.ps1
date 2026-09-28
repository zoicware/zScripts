#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables DES, 3DES, IDEA and RC2 ciphers in SCHANNEL to mitigate Sweet32 (CVE-2016-2183 / CVE-2016-6329).

.DESCRIPTION
    1. Backs up the SCHANNEL\Ciphers registry key.
    2. Sets Enabled = 0 for each weak cipher under SCHANNEL\Ciphers.
    3. Disables any installed TLS cipher suites that use 3DES/DES/RC2/IDEA.

    A reboot is required for SCHANNEL registry changes to take effect.
    Compatible with Windows PowerShell 5.1.

.PARAMETER SkipBackup
    Skip the registry export.

.PARAMETER SkipCipherSuites
    Skip disabling cipher suites via Disable-TlsCipherSuite.
#>
[CmdletBinding()]
param(
    [switch]$SkipBackup,
    [switch]$SkipCipherSuites
)

$ErrorActionPreference = 'Stop'

$ciphersPath   = 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers'
$ciphersRegExe = 'HKLM\' + $ciphersPath

# Key names contain '/', which the PowerShell registry provider mishandles,
# so we use the .NET registry API directly.
$weakCiphers = @(
    'DES 56/56',
    'Triple DES 168',
    'Triple DES 168/168',
    'RC2 40/128',
    'RC2 56/128',
    'RC2 128/128',
    'IDEA 128/128'
)

# --- 1. Backup ---------------------------------------------------------------
if (-not $SkipBackup) {
    $backupFile = Join-Path $env:USERPROFILE ("SCHANNEL-Ciphers-backup-{0:yyyyMMdd-HHmmss}.reg" -f (Get-Date))
    $null = reg.exe query $ciphersRegExe 2>&1
    if ($LASTEXITCODE -eq 0) {
        reg.exe export $ciphersRegExe $backupFile /y | Out-Null
        Write-Host "Backup saved: $backupFile" -ForegroundColor Cyan
    } else {
        Write-Host 'No existing SCHANNEL\Ciphers key; nothing to back up.' -ForegroundColor DarkGray
    }
}

# --- 2. Disable ciphers in SCHANNEL -----------------------------------------
$hklm = [Microsoft.Win32.Registry]::LocalMachine
$root = $hklm.CreateSubKey($ciphersPath)   # opens if it exists, creates otherwise

foreach ($name in $weakCiphers) {
    try {
        $sub = $root.CreateSubKey($name)
        $sub.SetValue('Enabled', 0, [Microsoft.Win32.RegistryValueKind]::DWord)
        $sub.Close()
        Write-Host "[+] Disabled cipher: $name" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to disable '$name': $($_.Exception.Message)"
    }
}
$root.Close()

# --- 3. Disable matching TLS cipher suites ----------------------------------
if (-not $SkipCipherSuites) {
    if (Get-Command Disable-TlsCipherSuite -ErrorAction SilentlyContinue) {
        $pattern = '3DES|_DES_|DES_CBC|RC2|IDEA'
        $suites = Get-TlsCipherSuite | Where-Object { $_.Name -match $pattern }

        if (-not $suites) {
            Write-Host 'No 3DES/DES/RC2/IDEA cipher suites currently enabled.' -ForegroundColor DarkGray
        }
        foreach ($suite in $suites) {
            try {
                Disable-TlsCipherSuite -Name $suite.Name
                Write-Host "[+] Disabled cipher suite: $($suite.Name)" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to disable suite '$($suite.Name)': $($_.Exception.Message)"
            }
        }
    } else {
        Write-Warning 'Disable-TlsCipherSuite not available on this OS; skipped cipher suite step.'
    }
}

Write-Host "`nDone. Reboot required for changes to take effect." -ForegroundColor Yellow
