function Set-UwpAppRegistryEntry {
    # modified to work in windows powershell from https://github.com/agadiffe/WindowsMize/blob/fe78912ccb1c83d440bd2123f5e43a6156fab31a/src/modules/applications/settings/public/Set-UwpAppSetting.ps1
    <# 
    .SYNOPSIS
        Modifies UWP app registry entries in the settings.dat file.
    
    .EXAMPLE
        PS> $setting = [PSCustomObject]@{
                Name  = 'VideoAutoplay'
                Value = '0'
                Type  = '5f5e10b'
            }
        PS> $setting | Set-UwpAppRegistryEntry -FilePath $FilePath
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        $InputObject,

        [Parameter(Mandatory)]
        [string] $FilePath
    )

    begin {
        $AppSettingsRegPath = 'HKEY_USERS\APP_SETTINGS'
        $RegContent = "Windows Registry Editor Version 5.00`n"

        reg.exe UNLOAD $AppSettingsRegPath 2>&1 | Out-Null

        #load settings early to prevent search host from spawning again
        #retry loading until it works... 30 max tries just to prevent this from infinite looping 
        #should never reach 30 or anywhere close
        $max = 30
        $attempts = 0
        do {
            Stop-Process -Name 'SearchHost' -Force -ErrorAction SilentlyContinue
            Start-Sleep 0.25
            reg.exe LOAD $AppSettingsRegPath $FilePath *>$null
            $attempts++
        }while ($LASTEXITCODE -ne 0 -and $attempts -le $max)

        if ($attempts -ge $max) {
            Write-Status -msg 'Max attempts reached while trying to load settings.dat' -errorOutput
            return
        }
      
    }

    process {
        $Value = $InputObject.Value
        $Value = switch ($InputObject.Type) {
            '5f5e10b' { 
                # Single byte for boolean
                '{0:x2}' -f [byte][int]$Value
            }
            '5f5e10c' { 
                # Unicode string 
                $bytes = [System.Text.Encoding]::Unicode.GetBytes($Value + "`0")
                ($bytes | ForEach-Object { '{0:x2}' -f $_ }) -join ' ' 
            }
            '5f5e104' { 
                # Int32
                $bytes = [BitConverter]::GetBytes([int]$Value)
                ($bytes | ForEach-Object { '{0:x2}' -f $_ }) -join ' '
            }
            '5f5e105' { 
                # UInt32
                $bytes = [BitConverter]::GetBytes([uint32]$Value)
                ($bytes | ForEach-Object { '{0:x2}' -f $_ }) -join ' '
            }
            '5f5e106' { 
                # Int64
                $bytes = [BitConverter]::GetBytes([int64]$Value)
                ($bytes | ForEach-Object { '{0:x2}' -f $_ }) -join ' '
            }
        }

        $Value = $Value -replace '\s+', ','
    
        # create timestamp for remaining bytes
        $timestampBytes = [BitConverter]::GetBytes([int64](Get-Date).ToFileTime())
        $Timestamp = ($timestampBytes | ForEach-Object { '{0:x2}' -f $_ }) -join ','
    
        # build registry content
        if ($InputObject.Path) {
            $RegKey = $InputObject.Path
        }
        else {
            $RegKey = 'LocalState'
        }
        $RegContent += "`n[$AppSettingsRegPath\$RegKey]
        ""$($InputObject.Name)""=hex($($InputObject.Type)):$Value,$Timestamp`n" -replace '(?m)^ *'
    }

    end {
        $SettingRegFilePath = "$($tempDir)uwp_app_settings.reg"
        $RegContent | Out-File -FilePath $SettingRegFilePath

        reg.exe IMPORT $SettingRegFilePath 2>&1 | Out-Null
        reg.exe UNLOAD $AppSettingsRegPath | Out-Null

        Remove-Item -Path $SettingRegFilePath
    }
}


$settingsDat = "$env:LOCALAPPDATA\Packages\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\Settings\settings.dat"

if (Test-Path $settingsDat) {
    Stop-Process -name 'SearchHost', 'AppActions' -Force -ErrorAction SilentlyContinue
    $apps = @(
        'Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe' 
        'Microsoft.Office.ActionsServer_8wekyb3d8bbwe' 
        'MSTeams_8wekyb3d8bbwe' 
        'Microsoft.Paint_8wekyb3d8bbwe' 
        'Microsoft.Windows.Photos_8wekyb3d8bbwe'
        'MicrosoftWindows.Client.CBS_cw5n1h2txyewy' #describe image (system)
    )

    foreach ($app in $apps) {
        $setting = [PSCustomObject]@{
            Name  = $app
            Path  = 'LocalState\DisabledApps'
            Value = '1' 
            Type  = '5f5e10b'
        }
        $setting | Set-UwpAppRegistryEntry -FilePath $settingsDat
    }
     
}