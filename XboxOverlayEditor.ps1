If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
  Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
  Exit	
}


Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Xbox Overlay Settings Editor"
        Width="820" Height="680"
        WindowStartupLocation="CenterScreen"
        Background="#0D0D0D"
        FontFamily="Segoe UI Variable Text, Segoe UI, Verdana"
        ResizeMode="CanResize"
        TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType"
        UseLayoutRounding="True"
        SnapsToDevicePixels="True">

  <Window.Resources>
    <Style TargetType="ScrollBar">
      <Setter Property="Background" Value="#1A1A1A"/>
      <Setter Property="Foreground" Value="#107C10"/>
    </Style>

    <Style TargetType="CheckBox" x:Key="GreenCheck">
      <Setter Property="Foreground" Value="#C8C8C8"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Margin" Value="0,3,0,3"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
    </Style>

    <Style TargetType="Border" x:Key="Card">
      <Setter Property="Background" Value="#141414"/>
      <Setter Property="BorderBrush" Value="#2A2A2A"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="6"/>
      <Setter Property="Margin" Value="0,0,0,10"/>
      <Setter Property="Padding" Value="14,10"/>
    </Style>

    <Style TargetType="Button" x:Key="PrimaryBtn">
      <Setter Property="Background" Value="#107C10"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Padding" Value="18,8"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="4"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#15A015"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter Property="Background" Value="#0A5E0A"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="Button" x:Key="PresetBtn">
      <Setter Property="Background" Value="#1E1E1E"/>
      <Setter Property="Foreground" Value="#C8C8C8"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Padding" Value="14,7"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush" Value="#333"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#2A2A2A"/>
                <Setter Property="BorderBrush" Value="#107C10"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter Property="Background" Value="#111"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="TextBlock" x:Key="SectionHeader">
      <Setter Property="Foreground" Value="#107C10"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Margin" Value="0,0,0,8"/>
    </Style>

    <Style TargetType="TextBlock" x:Key="WidgetTitle">
      <Setter Property="Foreground" Value="#E8E8E8"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,6"/>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#0A0A0A" Padding="20,16">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel>
          <TextBlock Text="XBOX OVERLAY" Foreground="#107C10" FontSize="10" FontWeight="Bold"/>
          <TextBlock Text="Settings Editor" Foreground="White" FontSize="22" FontWeight="Light"
                     Margin="0,2,0,0"/>
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse x:Name="StatusDot" Width="8" Height="8" Fill="#666" Margin="0,0,8,0"
                   VerticalAlignment="Center"/>
          <TextBlock x:Name="StatusLabel" Text="No file loaded" Foreground="#666"
                     FontSize="13" VerticalAlignment="Center"/>
        </StackPanel>
      </Grid>
    </Border>

    <Border Grid.Row="1" Background="#111" Padding="20,12" BorderBrush="#1E1E1E"
            BorderThickness="0,0,0,1">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock Text="Presets:" Foreground="#666" FontSize="13" VerticalAlignment="Center"
                     Margin="0,0,12,0"/>
          <Button x:Name="BtnUnpinAll"     Content="⊟ Unpin All"          Style="{StaticResource PresetBtn}"/>
          <Button x:Name="BtnPinFavorites" Content="★ Pin Favorites"      Style="{StaticResource PresetBtn}"/>
          <Button x:Name="BtnDisableAll"   Content="✕ Disable Everything" Style="{StaticResource PresetBtn}"/>
          <Button x:Name="BtnEnableAll"    Content="✓ Enable Everything"  Style="{StaticResource PresetBtn}"/>
          <Button x:Name="BtnSuppressAll"  Content="🔇 Suppress All"      Style="{StaticResource PresetBtn}"/>
        </StackPanel>
      </Grid>
    </Border>

    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto"
                  Padding="20,16,20,4" Background="#0D0D0D">
      <StackPanel x:Name="WidgetPanel"/>
    </ScrollViewer>

    <Border Grid.Row="3" Background="#0A0A0A" Padding="20,12">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="FooterMsg" Text="Load a settings file to begin editing."
                   Foreground="#555" FontSize="13" VerticalAlignment="Center"/>
        <StackPanel Grid.Column="1" Orientation="Horizontal">
          <Button x:Name="BtnSave" Content="💾  Save Changes" Style="{StaticResource PrimaryBtn}"
                  IsEnabled="False"/>
        </StackPanel>
      </Grid>
    </Border>
  </Grid>
</Window>
'@
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)


$btnSave = $window.FindName('BtnSave')
$btnUnpinAll = $window.FindName('BtnUnpinAll')
$btnPinFavorites = $window.FindName('BtnPinFavorites')
$btnDisableAll = $window.FindName('BtnDisableAll')
$btnEnableAll = $window.FindName('BtnEnableAll')
$btnSuppressAll = $window.FindName('BtnSuppressAll')
$widgetPanel = $window.FindName('WidgetPanel')
$statusDot = $window.FindName('StatusDot')
$statusLabel = $window.FindName('StatusLabel')
$footerMsg = $window.FindName('FooterMsg')

$script:jsonObj = $null
$script:filePath = ''
$script:checkboxMap = @{}   # "entity|prop" = CheckBox

function Build-WidgetUI {
  $widgetPanel.Children.Clear()
  $script:checkboxMap = @{}

  if ($null -eq $script:jsonObj) { return }

  $storage = $script:jsonObj.profile.settingsStorage
  $entities = $storage | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
  $widgets = $entities | Where-Object { $_ -like 'widget_*' } | Sort-Object
  $packages = $entities | Where-Object { $_ -like 'package_*' } | Sort-Object

  function Add-EntityCard($entityName, $labelPrefix) {
    $props = $storage.$entityName | Get-Member -MemberType NoteProperty

    if (-not $props) { return } #has no props nothing can be done so just early return

    $card = New-Object Windows.Controls.Border
    $card.SetResourceReference([Windows.Controls.Border]::StyleProperty, 'Card')

    $sp = New-Object Windows.Controls.StackPanel

    $header = New-Object Windows.Controls.Grid
    $col1 = New-Object Windows.Controls.ColumnDefinition; $col1.Width = '*'
    $header.ColumnDefinitions.Add($col1)

    $title = New-Object Windows.Controls.TextBlock
    $title.SetResourceReference([Windows.Controls.TextBlock]::StyleProperty, 'WidgetTitle')
    $title.Text = $entityName -replace '^widget_|^package_', '' #remove package or widget prefix
    $title.SetValue([Windows.Media.TextOptions]::TextFormattingModeProperty, [Windows.Media.TextFormattingMode]::Display)
    [Windows.Controls.Grid]::SetColumn($title, 0)

    $header.Children.Add($title)    | Out-Null
    $sp.Children.Add($header) | Out-Null

    $div = New-Object Windows.Controls.Separator
    $div.Background = [Windows.Media.SolidColorBrush][Windows.Media.ColorConverter]::ConvertFromString('#222')
    $div.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
    $sp.Children.Add($div) | Out-Null

    $propGrid = New-Object Windows.Controls.WrapPanel
    $propGrid.Orientation = 'Horizontal'

    foreach ($prop in $props) {
      $currentVal = $storage.$entityName.$($prop.Name)

      $cb = New-Object Windows.Controls.CheckBox
      $tb = New-Object Windows.Controls.TextBlock
      $tb.Text = $prop.Name
      $tb.SetValue([Windows.Media.TextOptions]::TextFormattingModeProperty, [Windows.Media.TextFormattingMode]::Display)
      $cb.Content = $tb
      $cb.SetResourceReference([Windows.Controls.CheckBox]::StyleProperty, 'GreenCheck')
      $cb.IsChecked = ($currentVal -eq $true)
      $cb.Width = 320

      $key = "$entityName|$($prop.Name)"
      $script:checkboxMap[$key] = $cb

      $propGrid.Children.Add($cb) | Out-Null
    }

    $sp.Children.Add($propGrid) | Out-Null
    $card.Child = $sp
    $widgetPanel.Children.Add($card) | Out-Null
  }

  $secW = New-Object Windows.Controls.TextBlock
  $secW.SetResourceReference([Windows.Controls.TextBlock]::StyleProperty, 'SectionHeader')
  $secW.Text = 'Widgets'
  $widgetPanel.Children.Add($secW) | Out-Null

  foreach ($w in $widgets) { Add-EntityCard $w '' }

  if ($packages.Count -gt 0) {
    $secP = New-Object Windows.Controls.TextBlock
    $secP.SetResourceReference([Windows.Controls.TextBlock]::StyleProperty, 'SectionHeader')
    $secP.Text = 'Packages'
    $secP.Margin = [Windows.Thickness]::new(0, 12, 0, 8)
    $widgetPanel.Children.Add($secP) | Out-Null

    foreach ($p in $packages) { Add-EntityCard $p '' }
  }
}

function Set-Status($ok, $msg) {
  if ($ok) {
    $statusDot.Fill = [Windows.Media.SolidColorBrush][Windows.Media.ColorConverter]::ConvertFromString('#107C10')
    $statusLabel.Foreground = [Windows.Media.SolidColorBrush][Windows.Media.ColorConverter]::ConvertFromString('#107C10')
  }
  else {
    $statusDot.Fill = [Windows.Media.SolidColorBrush][Windows.Media.ColorConverter]::ConvertFromString('#C42B1C')
    $statusLabel.Foreground = [Windows.Media.SolidColorBrush][Windows.Media.ColorConverter]::ConvertFromString('#C42B1C')
  }
  $statusLabel.Text = $msg
}

function Apply-CheckboxesToJson {
  foreach ($key in $script:checkboxMap.Keys) {
    $parts = $key -split '\|'
    $entity = $parts[0]
    $prop = $parts[1]
    $val = $script:checkboxMap[$key].IsChecked -eq $true
    $script:jsonObj.profile.settingsStorage.$entity.$prop = $val
  }
}


function Invoke-Preset([scriptblock]$filter) {
  if ($null -eq $script:jsonObj) { return }
  foreach ($key in $script:checkboxMap.Keys) {
    $prop = ($key -split '\|')[1]
    $cb = $script:checkboxMap[$key]
    $result = & $filter $prop $cb
    if ($null -ne $result) { $cb.IsChecked = $result }
  }
}


$btnSave.Add_Click({
    if ($null -eq $script:jsonObj -or $script:filePath -eq '') { return }
    try {
      Get-Process '*gamebar*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
      Apply-CheckboxesToJson
      $newContent = ConvertTo-Json $script:jsonObj -Depth 10 -Compress
      Set-Content $script:filePath -Value $newContent -Force
      Set-Status $true 'Saved ✓'
      $footerMsg.Text = "Saved to $($script:filePath)"
    }
    catch {
      [Windows.MessageBox]::Show("Failed to save:`n$_", 'Error', 'OK', 'Error')
      Set-Status $false 'Save failed'
    }
  })

$btnUnpinAll.Add_Click({
    Invoke-Preset {
      param($prop, $cb)
      if ($prop -like '*pinned*') { return $false }
      return $null
    }
  })

$btnPinFavorites.Add_Click({
    #find all widgets with isFavoirte set to true and pinned to true
    $favoriteEntities = @{}
    foreach ($key in $script:checkboxMap.Keys) {
      $parts = $key -split '\|'
      if ($parts[1] -eq 'isFavorite' -and $script:checkboxMap[$key].IsChecked) {
        $favoriteEntities[$parts[0]] = $true
      }
    }
    foreach ($key in $script:checkboxMap.Keys) {
      $parts = $key -split '\|'
      $entity = $parts[0]
      $prop = $parts[1]
      if ($prop -eq 'pinned' -and $favoriteEntities.ContainsKey($entity)) {
        $script:checkboxMap[$key].IsChecked = $true
      }
    }
  })


$btnDisableAll.Add_Click({
    Invoke-Preset { param($prop, $cb); return $false }
  })

$btnEnableAll.Add_Click({
    Invoke-Preset { param($prop, $cb); return $true }
  })

$btnSuppressAll.Add_Click({
    Invoke-Preset {
      param($prop, $cb)
      if ($prop -like 'suppress*') { return $true }
      return $null
    }
  })



$defaultFile = "$env:LOCALAPPDATA\Packages\Microsoft.XboxGamingOverlay_8wekyb3d8bbwe\LocalState\profileDataSettings.txt"
if (Test-Path $defaultFile) {
  try {
    Get-Process '*gamebar*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $raw = Get-Content $defaultFile -Raw -ErrorAction Stop
    $script:jsonObj = ConvertFrom-Json $raw -ErrorAction Stop
    $script:filePath = $defaultFile
    $window.Add_ContentRendered({
        Build-WidgetUI
        $btnSave.IsEnabled = $true
        Set-Status $true 'loaded overlay settings'
        $footerMsg.Text = "Editing: $script:filePath"
      })

    $window.ShowDialog() | Out-Null
  }
  catch { 
    [Windows.MessageBox]::Show(
      "Found the settings file but failed to load it:`n`n$err",
      'Load Error', 'OK', 'Error') 
  }
}
else {
  [Windows.MessageBox]::Show(
    'profileDataSettings.txt NOT Found! Xbox Overlay may be uninstalled.',
    'Load Error', 'OK', 'Error')
}

