
function Edit-Nip {
    param (
        [string]$nipPath,
        [string]$settingId,
        [string]$settingValue,
        [string]$valueType,
        [string]$settingNameInfo
    )
    #get nip content (profile inspector uses standard xml formatting)
    [xml]$nipContent = Get-Content $nipPath
    $settings = $nipContent.ArrayOfProfile.Profile.Settings
    #create new setting node
    $newSetting = $nipContent.CreateElement('ProfileSetting')
    $newsettingNameInfo = $nipContent.CreateElement('SettingNameInfo')
    if ($settingNameInfo) {
        $newsettingNameInfo.InnerText = $settingNameInfo
    }
    $newSetting.AppendChild($newsettingNameInfo) | Out-Null

    #create the new setting
    $newsettingID = $nipContent.CreateElement('SettingID')
    $newsettingID.InnerText = $settingId
    $newSetting.AppendChild($newsettingID) | Out-Null
    
    $newsettingValue = $nipContent.CreateElement('SettingValue')
    $newsettingValue.InnerText = $settingValue
    $newSetting.AppendChild($newsettingValue) | Out-Null
    
    $newvalueType = $nipContent.CreateElement('ValueType')
    $newvalueType.InnerText = $valueType
    $newSetting.AppendChild($newvalueType) | Out-Null
    
    #add new setting to nip
    $settings.AppendChild($newSetting) | Out-Null
    $nipContent.Save($nipPath)

    
}

#enable rebar
Edit-Nip -nipPath $someNipPath -settingId '983226' -settingValue '1' -valueType 'Dword'
Edit-Nip -nipPath $someNipPath -settingId '983227' -settingValue '1' -valueType 'Dword'
Edit-Nip -nipPath $someNipPath -settingId '983295' -settingValue 'AAAAQAAAAAA=' -valueType 'Binary'

#enable gsync
Edit-Nip -nipPath $someNipPath -settingId '278196567' -settingValue '1' -valueType 'Dword' -settingNameInfo 'Toggle the VRR global feature'
Edit-Nip -nipPath $someNipPath -settingId '278196727' -settingValue '1' -valueType 'Dword' -settingNameInfo 'VRR requested state'
Edit-Nip -nipPath $someNipPath -settingId '279476687' -settingValue '0' -valueType 'Dword' -settingNameInfo 'G-SYNC'
Edit-Nip -nipPath $someNipPath -settingId '294973784' -settingValue '1' -valueType 'Dword' -settingNameInfo 'Enable G-SYNC globally'

#enable dlss latest
Edit-Nip -nipPath $someNipPath -settingId '283385331' -settingValue '16777215' -valueType 'Dword' -settingNameInfo 'Override DLSS-SR presets'
Edit-Nip -nipPath $someNipPath -settingId '283385345' -settingValue '1' -valueType 'Dword' -settingNameInfo 'Enable DLSS-SR override'
