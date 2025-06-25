$jsonContent = "$env:ProgramData\Microsoft\Diagnosis\DownloadedSettings\utc.app.json"
$domains = @()
if(Test-Path $jsonContent){
    $ConvertedContent = Get-Content $jsonContent -Raw | ConvertFrom-Json
    $lines = $ConvertedContent.settings -split ':' | Where-Object {$_ -match '\/\/[a-zA-Z0-9.-]+\.data\.microsoft\.com\S*'}
    foreach($line in $lines){
        if($line -notlike "*; UTC" -and $line -notlike "*settings*"){
            $cleanLine = ($line -replace '//' ,'' -replace '/collect/v1|https' ,'' -replace '/OneCollector/1.0|https' ,'' -replace '/|' ,'').TrimEnd('|')
            $domains += $cleanLine
        }

    }
    $uDomains = $domains | Sort-Object -Unique
    Write-Host $uDomains

}
