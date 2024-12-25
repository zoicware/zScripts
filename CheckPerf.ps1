If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}

Write-Host "Running [winsat formal]..." -ForegroundColor Green
                   
winsat formal                              
Write-host "Saved to [$env:SystemRoot\performance\winsat\datastore] as XML" -ForegroundColor Green

Write-host "Get Overall Rating..." -ForegroundColor Green
Get-CimInstance Win32_WinSAT

Write-Host 'Continue With Additional Checks?' -ForegroundColor Green
pause
Write-Host 'Running Network Checks...' -ForegroundColor Green
Write-Host 'Ping and Trace Hops Google [8.8.8.8]' -ForegroundColor Green
ping 8.8.8.8
tracert 8.8.8.8
pause
Write-Host 'Getting Perf Info For Each Core...' -ForegroundColor Green
Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor | Where-Object {$_.Name -ne "_Total"} 
pause
Write-Host 'Running Perfmon /report...' -ForegroundColor Green
sleep 1
perfmon /report

