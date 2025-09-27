If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}

#Script from: https://github.com/Andrew-J-Larson/OS-Scripts/blob/main/Windows/Wrapper-Functions/Download-AppxPackage-Function.ps1
# [EXAMPLE] 
# Download-AppxPackage -PackageFamilyName 'Clipchamp.Clipchamp_yxz26nhyzhsrt' -outputDir 'C:\'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms


$window = New-Object System.Windows.Window
$window.Title = 'AppX Package Downloader'
$window.Width = 500
$window.Height = 300
$window.ResizeMode = 'NoResize'
$window.WindowStartupLocation = 'CenterScreen'

$grid = New-Object System.Windows.Controls.Grid
$window.Content = $grid

for ($i = 0; $i -lt 6; $i++) {
    $rowDef = New-Object System.Windows.Controls.RowDefinition
    if ($i -eq 4 -or $i -eq 5) {
        $rowDef.Height = 'Auto'
    }
    else {
        $rowDef.Height = 'Auto'
    }
    $grid.RowDefinitions.Add($rowDef)
}


$colDef1 = New-Object System.Windows.Controls.ColumnDefinition
$colDef1.Width = 'Auto'
$colDef2 = New-Object System.Windows.Controls.ColumnDefinition
$colDef2.Width = '*'
$colDef3 = New-Object System.Windows.Controls.ColumnDefinition
$colDef3.Width = 'Auto'
$grid.ColumnDefinitions.Add($colDef1)
$grid.ColumnDefinitions.Add($colDef2)
$grid.ColumnDefinitions.Add($colDef3)

$lblOutputDir = New-Object System.Windows.Controls.Label
$lblOutputDir.Content = 'Output Directory:'
$lblOutputDir.Margin = '10,10,5,5'
[System.Windows.Controls.Grid]::SetRow($lblOutputDir, 0)
[System.Windows.Controls.Grid]::SetColumn($lblOutputDir, 0)
$grid.Children.Add($lblOutputDir)

$txtOutputDir = New-Object System.Windows.Controls.TextBox
$txtOutputDir.Text = 'C:\'
$txtOutputDir.Margin = '5,10,5,5'
$txtOutputDir.Height = 25
$txtOutputDir.VerticalContentAlignment = 'Center'
[System.Windows.Controls.Grid]::SetRow($txtOutputDir, 0)
[System.Windows.Controls.Grid]::SetColumn($txtOutputDir, 1)
$grid.Children.Add($txtOutputDir)

$btnBrowse = New-Object System.Windows.Controls.Button
$btnBrowse.Content = 'Browse...'
$btnBrowse.Width = 75
$btnBrowse.Height = 25
$btnBrowse.Margin = '5,10,10,5'
[System.Windows.Controls.Grid]::SetRow($btnBrowse, 0)
[System.Windows.Controls.Grid]::SetColumn($btnBrowse, 2)
$grid.Children.Add($btnBrowse)

$lblPackageName = New-Object System.Windows.Controls.Label
$lblPackageName.Content = 'Package Family Name:'
$lblPackageName.Margin = '10,5,5,5'
[System.Windows.Controls.Grid]::SetRow($lblPackageName, 1)
[System.Windows.Controls.Grid]::SetColumn($lblPackageName, 0)
$grid.Children.Add($lblPackageName)

$txtPackageName = New-Object System.Windows.Controls.TextBox
$txtPackageName.Text = 'Microsoft.WindowsStore_8wekyb3d8bbwe'
$txtPackageName.Margin = '5,5,10,5'
$txtPackageName.Height = 25
$txtPackageName.VerticalContentAlignment = 'Center'
[System.Windows.Controls.Grid]::SetRow($txtPackageName, 1)
[System.Windows.Controls.Grid]::SetColumn($txtPackageName, 1)
[System.Windows.Controls.Grid]::SetColumnSpan($txtPackageName, 2)
$grid.Children.Add($txtPackageName)

$lblStatus = New-Object System.Windows.Controls.Label
$lblStatus.Content = 'Status:'
$lblStatus.Margin = '10,5,5,5'
[System.Windows.Controls.Grid]::SetRow($lblStatus, 2)
[System.Windows.Controls.Grid]::SetColumn($lblStatus, 0)
$grid.Children.Add($lblStatus)

$txtStatus = New-Object System.Windows.Controls.TextBox
$txtStatus.Text = 'Ready to download...'
$txtStatus.Margin = '5,5,10,5'
$txtStatus.Height = 80
$txtStatus.IsReadOnly = $true
$txtStatus.VerticalScrollBarVisibility = 'Auto'
$txtStatus.TextWrapping = 'Wrap'
$txtStatus.VerticalContentAlignment = 'Top'
[System.Windows.Controls.Grid]::SetRow($txtStatus, 2)
[System.Windows.Controls.Grid]::SetColumn($txtStatus, 1)
[System.Windows.Controls.Grid]::SetColumnSpan($txtStatus, 2)
$grid.Children.Add($txtStatus)

$stackPanel = New-Object System.Windows.Controls.StackPanel
$stackPanel.Orientation = 'Horizontal'
$stackPanel.HorizontalAlignment = 'Center'
$stackPanel.Margin = '10,20,10,10'
[System.Windows.Controls.Grid]::SetRow($stackPanel, 3)
[System.Windows.Controls.Grid]::SetColumn($stackPanel, 0)
[System.Windows.Controls.Grid]::SetColumnSpan($stackPanel, 3)
$grid.Children.Add($stackPanel)

$btnDownload = New-Object System.Windows.Controls.Button
$btnDownload.Content = 'Download Only'
$btnDownload.Width = 120
$btnDownload.Height = 30
$btnDownload.Margin = '5,0,5,0'
$stackPanel.Children.Add($btnDownload)

$btnDownloadInstall = New-Object System.Windows.Controls.Button
$btnDownloadInstall.Content = 'Download & Install'
$btnDownloadInstall.Width = 120
$btnDownloadInstall.Height = 30
$btnDownloadInstall.Margin = '5,0,5,0'
$stackPanel.Children.Add($btnDownloadInstall)

$progressBar = New-Object System.Windows.Controls.ProgressBar
$progressBar.Height = 20
$progressBar.Margin = '10,5,10,10'
$progressBar.IsIndeterminate = $false
$progressBar.Visibility = 'Hidden'
[System.Windows.Controls.Grid]::SetRow($progressBar, 4)
[System.Windows.Controls.Grid]::SetColumn($progressBar, 0)
[System.Windows.Controls.Grid]::SetColumnSpan($progressBar, 3)
$grid.Children.Add($progressBar)

$btnBrowse.Add_Click({
        function Show-ModernFilePicker {
            param(
                [ValidateSet('Folder', 'File')]
                $Mode,
                [string]$fileType
    
            )
    
            if ($Mode -eq 'Folder') {
                $Title = 'Select Folder'
                $modeOption = $false
                $Filter = "Folders|`n"
            }
            else {
                $Title = 'Select File'
                $modeOption = $true
                if ($fileType) {
                    $Filter = "$fileType Files (*.$fileType) | *.$fileType|All files (*.*)|*.*"
                }
                else {
                    $Filter = 'All Files (*.*)|*.*'
                }
            }
            #modern file dialog
            #modified code from: https://gist.github.com/IMJLA/1d570aa2bb5c30215c222e7a5e5078fd
            $AssemblyFullName = 'System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'
            $Assembly = [System.Reflection.Assembly]::Load($AssemblyFullName)
            $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $OpenFileDialog.AddExtension = $modeOption
            $OpenFileDialog.CheckFileExists = $modeOption
            $OpenFileDialog.DereferenceLinks = $true
            $OpenFileDialog.Filter = $Filter
            $OpenFileDialog.Multiselect = $false
            $OpenFileDialog.Title = $Title
            $OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    
            $OpenFileDialogType = $OpenFileDialog.GetType()
            $FileDialogInterfaceType = $Assembly.GetType('System.Windows.Forms.FileDialogNative+IFileDialog')
            $IFileDialog = $OpenFileDialogType.GetMethod('CreateVistaDialog', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $null)
            $null = $OpenFileDialogType.GetMethod('OnBeforeVistaDialog', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $IFileDialog)
            if ($Mode -eq 'Folder') {
                [uint32]$PickFoldersOption = $Assembly.GetType('System.Windows.Forms.FileDialogNative+FOS').GetField('FOS_PICKFOLDERS').GetValue($null)
                $FolderOptions = $OpenFileDialogType.GetMethod('get_Options', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $null) -bor $PickFoldersOption
                $null = $FileDialogInterfaceType.GetMethod('SetOptions', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $FolderOptions)
            }
      
      
    
            $VistaDialogEvent = [System.Activator]::CreateInstance($AssemblyFullName, 'System.Windows.Forms.FileDialog+VistaDialogEvents', $false, 0, $null, $OpenFileDialog, $null, $null).Unwrap()
            [uint32]$AdviceCookie = 0
            $AdvisoryParameters = @($VistaDialogEvent, $AdviceCookie)
            $AdviseResult = $FileDialogInterfaceType.GetMethod('Advise', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $AdvisoryParameters)
            $AdviceCookie = $AdvisoryParameters[1]
            $Result = $FileDialogInterfaceType.GetMethod('Show', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, [System.IntPtr]::Zero)
            $null = $FileDialogInterfaceType.GetMethod('Unadvise', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $AdviceCookie)
            if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
                $FileDialogInterfaceType.GetMethod('GetResult', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $null)
            }
    
            return $OpenFileDialog.FileName
        }
    
        $txtOutputDir.Text = show-ModernFilePicker -Mode 'Folder'
        if ( -not $txtOutputDir.Text ) {
            $txtOutputDir.Text = 'C:\'
        }
    })

function Update-Status {
    param([string]$Message)
    
    $txtStatus.Dispatcher.Invoke([Action] {
            $txtStatus.Text += "$Message`r`n"
            $txtStatus.ScrollToEnd()
        })
}

function Set-ProgressBarVisibility {
    param([bool]$Visible, [bool]$Indeterminate = $true)
    
    $progressBar.Dispatcher.Invoke([Action] {
            if ($Visible) {
                $progressBar.Visibility = 'Visible'
                $progressBar.IsIndeterminate = $Indeterminate
            }
            else {
                $progressBar.Visibility = 'Hidden'
            }
        })
}

function Set-ButtonsEnabled {
    param([bool]$Enabled)
    
    $btnDownload.Dispatcher.Invoke([Action] {
            $btnDownload.IsEnabled = $Enabled
            $btnDownloadInstall.IsEnabled = $Enabled
        })
}

$btnDownload.Add_Click({
        if ([string]::IsNullOrWhiteSpace($txtPackageName.Text)) {
            [System.Windows.MessageBox]::Show('Please enter a Package Family Name.', 'Error', 'OK', 'Error')
            return
        }
    
        $txtStatus.Text = ''
        Update-Status 'Starting download...'
        Set-ProgressBarVisibility -Visible $true
        Set-ButtonsEnabled -Enabled $false
    
        # Run download in background
        $runspace = [powershell]::Create()
        $runspace.AddScript({
                param($PackageName, $OutputDir, $UpdateStatus, $SetProgressBar, $SetButtons)

                function Download-AppxPackage {
                    param(
                        # there has to be an alternative, as sometimes the API fails on PackageFamilyName
                        [string]$PackageFamilyName,
                        [string]$ProductId,
                        [string]$outputDir
                    )
                    if (-Not ($PackageFamilyName -Or $ProductId)) {
                        # can't do anything without at least one
                        Write-Error 'Missing either PackageFamilyName or ProductId.'
                        return $null
                    }
                  
                    try {
                        $UserAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::Chrome # needed as sometimes the API will block things when it knows requests are coming from PowerShell
                    }
                    catch {
                        #ignore error
                    }
                  
                    $DownloadedFiles = @()
                    $errored = $false
                    $allFilesDownloaded = $true
                  
                    $apiUrl = 'https://store.rg-adguard.net/api/GetFiles'
                    $versionRing = 'Retail'
                  
                    $architecture = switch ($env:PROCESSOR_ARCHITECTURE) {
                        'x86' { 'x86' }
                        { @('x64', 'amd64') -contains $_ } { 'x64' }
                        'arm' { 'arm' }
                        'arm64' { 'arm64' }
                        default { 'neutral' } # should never get here
                    }
                  
                    if (Test-Path $outputDir -PathType Container) {
                        New-Item -Path "$outputDir\$PackageFamilyName" -ItemType Directory -Force | Out-Null
                        $downloadFolder = "$outputDir\$PackageFamilyName"
                    }
                    else {
                        $downloadFolder = Join-Path $env:TEMP $PackageFamilyName
                        if (!(Test-Path $downloadFolder -PathType Container)) {
                            New-Item $downloadFolder -ItemType Directory -Force | Out-Null
                        }
                    }
                    
                    $body = @{
                        type = if ($ProductId) { 'ProductId' } else { 'PackageFamilyName' }
                        url  = if ($ProductId) { $ProductId } else { $PackageFamilyName }
                        ring = $versionRing
                        lang = 'en-US'
                    }
                  
                    # required due to the api being protected behind Cloudflare now
                    if (-Not $apiWebSession) {
                        $global:apiWebSession = $null
                        $apiHostname = (($apiUrl.split('/'))[0..2]) -Join '/'
                        Invoke-WebRequest -Uri $apiHostname -UserAgent $UserAgent -SessionVariable $apiWebSession -UseBasicParsing
                    }
                  
                    $raw = $null
                    try {
                        $raw = Invoke-RestMethod -Method Post -Uri $apiUrl -ContentType 'application/x-www-form-urlencoded' -Body $body -UserAgent $UserAgent -WebSession $apiWebSession
                    }
                    catch {
                        $errorMsg = 'An error occurred: ' + $_
                        Write-Host $errorMsg
                        $errored = $true
                        return $false
                    }
                  
                    # hashtable of packages by $name
                    #  > values = hashtables of packages by $version
                    #    > values = arrays of packages as objects (containing: url, filename, name, version, arch, publisherId, type)
                    [Collections.Generic.Dictionary[string, Collections.Generic.Dictionary[string, array]]] $packageList = @{}
                    # populate $packageList
                    $patternUrlAndText = '<tr style.*<a href=\"(?<url>.*)"\s.*>(?<text>.*\.(app|msi)x.*)<\/a>'
                    $raw | Select-String $patternUrlAndText -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object {
                        $url = ($_.Groups['url']).Value
                        $text = ($_.Groups['text']).Value
                        $textSplitUnderscore = $text.split('_')
                        $name = $textSplitUnderscore.split('_')[0]
                        $version = $textSplitUnderscore.split('_')[1]
                        $arch = ($textSplitUnderscore.split('_')[2]).ToLower()
                        $publisherId = ($textSplitUnderscore.split('_')[4]).split('.')[0]
                        $textSplitPeriod = $text.split('.')
                        $type = ($textSplitPeriod[$textSplitPeriod.length - 1]).ToLower()
                  
                        # create $name hash key hashtable, if it doesn't already exist
                        if (!($packageList.keys -match ('^' + [Regex]::escape($name) + '$'))) {
                            $packageList["$name"] = @{}
                        }
                        # create $version hash key array, if it doesn't already exist
                        if (!(($packageList["$name"]).keys -match ('^' + [Regex]::escape($version) + '$'))) {
                            ($packageList["$name"])["$version"] = @()
                        }
                   
                        # add package to the array in the hashtable
                        ($packageList["$name"])["$version"] += @{
                            url         = $url
                            filename    = $text
                            name        = $name
                            version     = $version
                            arch        = $arch
                            publisherId = $publisherId
                            type        = $type
                        }
                    }
                  
                    # an array of packages as objects, meant to only contain one of each $name
                    $latestPackages = @()
                    # grabs the most updated package for $name and puts it into $latestPackages
                    $packageList.GetEnumerator() | ForEach-Object { ($_.value).GetEnumerator() | Select-Object -Last 1 } | ForEach-Object {
                        $packagesByType = $_.value
                        $msixbundle = ($packagesByType | Where-Object { $_.type -match '^msixbundle$' })
                        $appxbundle = ($packagesByType | Where-Object { $_.type -match '^appxbundle$' })
                        $msix = ($packagesByType | Where-Object { ($_.type -match '^msix$') -And ($_.arch -match ('^' + [Regex]::Escape($architecture) + '$')) })
                        $appx = ($packagesByType | Where-Object { ($_.type -match '^appx$') -And ($_.arch -match ('^' + [Regex]::Escape($architecture) + '$')) })
                        if ($msixbundle) { $latestPackages += $msixbundle }
                        elseif ($appxbundle) { $latestPackages += $appxbundle }
                        elseif ($msix) { $latestPackages += $msix }
                        elseif ($appx) { $latestPackages += $appx }
                    }
                  
                    # download packages
                    $latestPackages | ForEach-Object {
                        $url = $_.url
                        $filename = $_.filename
                        # TODO: may need to include detection in the future of expired package download URLs..... in the case that downloads take over 10 minutes to complete
                  
                        $downloadFile = Join-Path $downloadFolder $filename
                  
                        # If file already exists, ask to replace it
                        if (Test-Path $downloadFile) {
                            Write-Host "`"${filename}`" already exists at `"${downloadFile}`"."
                            $confirmation = ''
                            while (!(($confirmation -eq 'Y') -Or ($confirmation -eq 'N'))) {
                                $confirmation = Read-Host "`nWould you like to re-download and overwrite the file at `"${downloadFile}`" (Y/N)?"
                                $confirmation = $confirmation.ToUpper()
                            }
                            if ($confirmation -eq 'Y') {
                                Remove-Item -Path $downloadFile -Force
                            }
                            else {
                                $DownloadedFiles += $downloadFile
                            }
                        }
                  
                        if (!(Test-Path $downloadFile)) {
                            Write-Host "Attempting download of `"${filename}`" to `"${downloadFile}`" . . ."
                            $fileDownloaded = $null
                            $PreviousProgressPreference = $ProgressPreference
                            $ProgressPreference = 'SilentlyContinue' # avoids slow download when using Invoke-WebRequest
                            try {
                                Invoke-WebRequest -Uri $url -OutFile $downloadFile
                                $fileDownloaded = $?
                            }
                            catch {
                                $ProgressPreference = $PreviousProgressPreference # return ProgressPreference back to normal
                                $errorMsg = 'An error occurred: ' + $_
                                Write-Host $errorMsg
                                $errored = $true
                                break $false
                            }
                            $ProgressPreference = $PreviousProgressPreference # return ProgressPreference back to normal
                            if ($fileDownloaded) { $DownloadedFiles += $downloadFile }
                            else { $allFilesDownloaded = $false }
                        }
                    }
                  
                    if ($errored) { Write-Host 'Completed with some errors.' }
                    if (-Not $allFilesDownloaded) { Write-Host 'Warning: Not all packages could be downloaded.' }
                    return $DownloadedFiles
                }
        
                try {
                    & $UpdateStatus "Downloading package: $PackageName"
                    $downloadedFiles = Download-AppxPackage -PackageFamilyName $PackageName -outputDir $OutputDir
            
                    if ($downloadedFiles -and $downloadedFiles.Count -gt 0) {
                        & $UpdateStatus 'Download completed successfully!'
                        & $UpdateStatus 'Files downloaded:'
                        foreach ($file in $downloadedFiles) {
                            & $UpdateStatus "  - $file"
                        }
                    }
                    else {
                        & $UpdateStatus 'Download failed or no files were downloaded.'
                    }
                }
                catch {
                    & $UpdateStatus "Error during download: $_"
                }
                finally {
                    & $SetProgressBar $false
                    & $SetButtons $true
                }
            })
    
        $runspace.AddArgument($txtPackageName.Text)
        $runspace.AddArgument($txtOutputDir.Text)
        $runspace.AddArgument(${function:Update-Status})
        $runspace.AddArgument(${function:Set-ProgressBarVisibility})
        $runspace.AddArgument(${function:Set-ButtonsEnabled})
    
        $runspace.BeginInvoke()
    })

$btnDownloadInstall.Add_Click({
        if ([string]::IsNullOrWhiteSpace($txtPackageName.Text)) {
            [System.Windows.MessageBox]::Show('Please enter a Package Family Name.', 'Error', 'OK', 'Error')
            return
        }
    
        $txtStatus.Text = ''
        Update-Status 'Starting download and installation...'
        Set-ProgressBarVisibility -Visible $true
        Set-ButtonsEnabled -Enabled $false
    
        # Run download and install in background
        $runspace = [powershell]::Create()
        $runspace.AddScript({
                param($PackageName, $OutputDir, $UpdateStatus, $SetProgressBar, $SetButtons)

                function Download-AppxPackage {
                    param(
                        # there has to be an alternative, as sometimes the API fails on PackageFamilyName
                        [string]$PackageFamilyName,
                        [string]$ProductId,
                        [string]$outputDir
                    )
                    if (-Not ($PackageFamilyName -Or $ProductId)) {
                        # can't do anything without at least one
                        Write-Error 'Missing either PackageFamilyName or ProductId.'
                        return $null
                    }
                  
                    try {
                        $UserAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::Chrome # needed as sometimes the API will block things when it knows requests are coming from PowerShell
                    }
                    catch {
                        #ignore error
                    }
                  
                    $DownloadedFiles = @()
                    $errored = $false
                    $allFilesDownloaded = $true
                  
                    $apiUrl = 'https://store.rg-adguard.net/api/GetFiles'
                    $versionRing = 'Retail'
                  
                    $architecture = switch ($env:PROCESSOR_ARCHITECTURE) {
                        'x86' { 'x86' }
                        { @('x64', 'amd64') -contains $_ } { 'x64' }
                        'arm' { 'arm' }
                        'arm64' { 'arm64' }
                        default { 'neutral' } # should never get here
                    }
                  
                    if (Test-Path $outputDir -PathType Container) {
                        New-Item -Path "$outputDir\$PackageFamilyName" -ItemType Directory -Force | Out-Null
                        $downloadFolder = "$outputDir\$PackageFamilyName"
                    }
                    else {
                        $downloadFolder = Join-Path $env:TEMP $PackageFamilyName
                        if (!(Test-Path $downloadFolder -PathType Container)) {
                            New-Item $downloadFolder -ItemType Directory -Force | Out-Null
                        }
                    }
                    
                    $body = @{
                        type = if ($ProductId) { 'ProductId' } else { 'PackageFamilyName' }
                        url  = if ($ProductId) { $ProductId } else { $PackageFamilyName }
                        ring = $versionRing
                        lang = 'en-US'
                    }
                  
                    # required due to the api being protected behind Cloudflare now
                    if (-Not $apiWebSession) {
                        $global:apiWebSession = $null
                        $apiHostname = (($apiUrl.split('/'))[0..2]) -Join '/'
                        Invoke-WebRequest -Uri $apiHostname -UserAgent $UserAgent -SessionVariable $apiWebSession -UseBasicParsing
                    }
                  
                    $raw = $null
                    try {
                        $raw = Invoke-RestMethod -Method Post -Uri $apiUrl -ContentType 'application/x-www-form-urlencoded' -Body $body -UserAgent $UserAgent -WebSession $apiWebSession
                    }
                    catch {
                        $errorMsg = 'An error occurred: ' + $_
                        Write-Host $errorMsg
                        $errored = $true
                        return $false
                    }
                  
                    # hashtable of packages by $name
                    #  > values = hashtables of packages by $version
                    #    > values = arrays of packages as objects (containing: url, filename, name, version, arch, publisherId, type)
                    [Collections.Generic.Dictionary[string, Collections.Generic.Dictionary[string, array]]] $packageList = @{}
                    # populate $packageList
                    $patternUrlAndText = '<tr style.*<a href=\"(?<url>.*)"\s.*>(?<text>.*\.(app|msi)x.*)<\/a>'
                    $raw | Select-String $patternUrlAndText -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object {
                        $url = ($_.Groups['url']).Value
                        $text = ($_.Groups['text']).Value
                        $textSplitUnderscore = $text.split('_')
                        $name = $textSplitUnderscore.split('_')[0]
                        $version = $textSplitUnderscore.split('_')[1]
                        $arch = ($textSplitUnderscore.split('_')[2]).ToLower()
                        $publisherId = ($textSplitUnderscore.split('_')[4]).split('.')[0]
                        $textSplitPeriod = $text.split('.')
                        $type = ($textSplitPeriod[$textSplitPeriod.length - 1]).ToLower()
                  
                        # create $name hash key hashtable, if it doesn't already exist
                        if (!($packageList.keys -match ('^' + [Regex]::escape($name) + '$'))) {
                            $packageList["$name"] = @{}
                        }
                        # create $version hash key array, if it doesn't already exist
                        if (!(($packageList["$name"]).keys -match ('^' + [Regex]::escape($version) + '$'))) {
                            ($packageList["$name"])["$version"] = @()
                        }
                   
                        # add package to the array in the hashtable
                        ($packageList["$name"])["$version"] += @{
                            url         = $url
                            filename    = $text
                            name        = $name
                            version     = $version
                            arch        = $arch
                            publisherId = $publisherId
                            type        = $type
                        }
                    }
                  
                    # an array of packages as objects, meant to only contain one of each $name
                    $latestPackages = @()
                    # grabs the most updated package for $name and puts it into $latestPackages
                    $packageList.GetEnumerator() | ForEach-Object { ($_.value).GetEnumerator() | Select-Object -Last 1 } | ForEach-Object {
                        $packagesByType = $_.value
                        $msixbundle = ($packagesByType | Where-Object { $_.type -match '^msixbundle$' })
                        $appxbundle = ($packagesByType | Where-Object { $_.type -match '^appxbundle$' })
                        $msix = ($packagesByType | Where-Object { ($_.type -match '^msix$') -And ($_.arch -match ('^' + [Regex]::Escape($architecture) + '$')) })
                        $appx = ($packagesByType | Where-Object { ($_.type -match '^appx$') -And ($_.arch -match ('^' + [Regex]::Escape($architecture) + '$')) })
                        if ($msixbundle) { $latestPackages += $msixbundle }
                        elseif ($appxbundle) { $latestPackages += $appxbundle }
                        elseif ($msix) { $latestPackages += $msix }
                        elseif ($appx) { $latestPackages += $appx }
                    }
                  
                    # download packages
                    $latestPackages | ForEach-Object {
                        $url = $_.url
                        $filename = $_.filename
                        # TODO: may need to include detection in the future of expired package download URLs..... in the case that downloads take over 10 minutes to complete
                  
                        $downloadFile = Join-Path $downloadFolder $filename
                  
                        # If file already exists, ask to replace it
                        if (Test-Path $downloadFile) {
                            Write-Host "`"${filename}`" already exists at `"${downloadFile}`"."
                            $confirmation = ''
                            while (!(($confirmation -eq 'Y') -Or ($confirmation -eq 'N'))) {
                                $confirmation = Read-Host "`nWould you like to re-download and overwrite the file at `"${downloadFile}`" (Y/N)?"
                                $confirmation = $confirmation.ToUpper()
                            }
                            if ($confirmation -eq 'Y') {
                                Remove-Item -Path $downloadFile -Force
                            }
                            else {
                                $DownloadedFiles += $downloadFile
                            }
                        }
                  
                        if (!(Test-Path $downloadFile)) {
                            Write-Host "Attempting download of `"${filename}`" to `"${downloadFile}`" . . ."
                            $fileDownloaded = $null
                            $PreviousProgressPreference = $ProgressPreference
                            $ProgressPreference = 'SilentlyContinue' # avoids slow download when using Invoke-WebRequest
                            try {
                                Invoke-WebRequest -Uri $url -OutFile $downloadFile
                                $fileDownloaded = $?
                            }
                            catch {
                                $ProgressPreference = $PreviousProgressPreference # return ProgressPreference back to normal
                                $errorMsg = 'An error occurred: ' + $_
                                Write-Host $errorMsg
                                $errored = $true
                                break $false
                            }
                            $ProgressPreference = $PreviousProgressPreference # return ProgressPreference back to normal
                            if ($fileDownloaded) { $DownloadedFiles += $downloadFile }
                            else { $allFilesDownloaded = $false }
                        }
                    }
                  
                    if ($errored) { Write-Host 'Completed with some errors.' }
                    if (-Not $allFilesDownloaded) { Write-Host 'Warning: Not all packages could be downloaded.' }
                    return $DownloadedFiles
                }
        
                try {
                    & $UpdateStatus "Downloading package: $PackageName"
                    $downloadedFiles = Download-AppxPackage -PackageFamilyName $PackageName -outputDir $OutputDir
            
                    if ($downloadedFiles -and $downloadedFiles.Count -gt 0) {
                        & $UpdateStatus 'Download completed successfully!'
                        & $UpdateStatus 'Files downloaded:'
                        foreach ($file in $downloadedFiles) {
                            & $UpdateStatus "  - $file"
                        }
                
                        & $UpdateStatus "`nStarting installation..."
                        $bundle = $downloadedFiles | Where-Object { $_ -match '\.appxbundle$' -or $_ -match '\.msixbundle$' } | Select-Object -First 1
                        if ($bundle) {
                            Add-AppPackage $bundle
                        }
                        & $UpdateStatus 'Installation process completed!'
                    }
                    else {
                        & $UpdateStatus 'Download failed or no files were downloaded.'
                    }
                }
                catch {
                    & $UpdateStatus "Error during process: $_"
                }
                finally {
                    & $SetProgressBar $false
                    & $SetButtons $true
                }
            })
    
        $runspace.AddArgument($txtPackageName.Text)
        $runspace.AddArgument($txtOutputDir.Text)
        $runspace.AddArgument(${function:Update-Status})
        $runspace.AddArgument(${function:Set-ProgressBarVisibility})
        $runspace.AddArgument(${function:Set-ButtonsEnabled})
    
        $runspace.BeginInvoke()
    })

$window.ShowDialog()