$downloadLink = Invoke-WebRequest 'https://www.amd.com/en/support/download/drivers.html' -UseBasicParsing | 
Select-Object -ExpandProperty Links | 
Where-Object { $_.href -match 'drivers\.amd\.com/drivers/installer/.*/whql/amd-software-adrenalin-edition-.*-minimalsetup-.*_web\.exe' } | Select-Object href

$headers = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    'Accept'     = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    'Referer'    = 'https://www.amd.com/'
}

Invoke-WebRequest $downloadLink.href -UseBasicParsing -Headers $headers -OutFile 'C:\amd-driver.exe'