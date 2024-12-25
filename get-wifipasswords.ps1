If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}

        try {
            #export wlan profiles with netsh 
            $ExportPath = New-Item -Path $HOME -Name 'GetWifiPassword' -ItemType Directory -Force
            $CurrentPath = (Get-Location).path
            Set-Location $ExportPath
            netsh wlan export profile key=clear >$null
            $XmlFilePaths = (Get-ChildItem -Path $ExportPath -File).FullName
        }
        catch {
            Write-Error "Failed to export Wifi profiles: $($_.Exception.Message)"
            return
        }
        
    
        foreach ($XmlFilePath in $XmlFilePaths) {
            try {
                $XmlContent = Get-Content $XmlFilePath
                $Xml = [xml]$XmlContent
                
            #output ssid and password
              [PSCustomObject]@{
                  Name     = $Xml.WLANProfile.Name
                  Password = $Xml.WLANProfile.MSM.Security.SharedKey.KeyMaterial
              } 
            }
            catch {
                Write-Error "Failed to read Wifi profile from '$XmlFilePath': $($_.Exception.Message)"
            }
        }
    
    
        #cleanup xml files
        Set-Location $CurrentPath
        Remove-Item $ExportPath -Recurse -Force
    
