<#
        .SYNOPSIS
        Pass PowerShell Commands to Run with Trusted Installer Privileges
 
        .DESCRIPTION
        This function uses the binary path of TrustedInstaller service to run a powershell command.
 
        .PARAMETER Command
        String that contains the command to run.
 
        .EXAMPLE
        Run-Trusted -command "Remove-item 'C:\Users\Admin\Desktop\test space.txt'"
        # Delete file with path that contains space
 
        .EXAMPLE
        Run-Trusted -command "Regedit.exe /S 'C:\Users\Admin\Desktop\Reg Space.reg'"
        # Import a registry file with space
 
        .NOTES
        Author: Zoic
        Twitter: https://twitter.com/1zoic
        GitHub: https://github.com/zoicware
    #>

function Run-Trusted([String]$command) {

    Stop-Service -Name TrustedInstaller -Force -ErrorAction SilentlyContinue
    #get bin path to revert later
    $service = Get-WmiObject -Class Win32_Service -Filter "Name='TrustedInstaller'"
    $DefaultBinPath = $service.PathName
    #convert command to base64 to avoid errors with spaces
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
    $base64Command = [Convert]::ToBase64String($bytes)
    #change bin to command
    sc.exe config TrustedInstaller binPath= "cmd.exe /c powershell.exe -encodedcommand $base64Command" | Out-Null
    #run the command
    sc.exe start TrustedInstaller | Out-Null
    #set bin back to default
    sc.exe config TrustedInstaller binpath= "`"$DefaultBinPath`"" | Out-Null
    Stop-Service -Name TrustedInstaller -Force -ErrorAction SilentlyContinue

}
