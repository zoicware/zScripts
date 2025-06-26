#unhides all packages from dism /online /get-packages
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages"

Get-ChildItem $regPath | ForEach-Object {
   $value = Get-ItemPropertyValue "registry::$($_.Name)" -Name Visibility
   if($value -eq 2){
       Set-ItemProperty "registry::$($_.Name)" -Name Visibility -Value 1 -Force
   }
}
