$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start\TileProperties'
# get all apps from registry and create a custom obj to track each
$apps = Get-ChildItem $regPath -recurse | Select-Object pspath
$appObjs = @()
foreach ($app in $apps) {
    $key = Get-ItemProperty $app.pspath
    if ($key.pschildname) {
        $Obj = [PSCustomObject]@{
            Name     = $key.pschildname
            Category = $key.category
            Path     = $key.pspath
        }
        $appObjs += $Obj
    }
}
# we need to link the category index value to the category name
# assuming that the index value is the same for all systems we can use a hashtable to link them
# otherwise we need to find where these are being linked (maybe database file)

# key = category friendly name
# value = category index
# (values in decimal)
# unknown values 2,0,5,17,8
$categoryLinks = @{
    'Productivity'      = 13 
    'Utilities & Tools' = 9 
    'Creativity'        = 7 # also 23?
    'Entertainment'     = 16 # also 3?
    'Accessibility'     = 1
    'Developer Tools'   = 15
    'Other'             = 25
}

# get and display categories
# ==================================================================================================
foreach ($app in $appObjs) {
    Write-Host "App Internal Name: $($app.Name)" -ForegroundColor Green
    $category = $categoryLinks.GetEnumerator() | Where-Object { $_.value -eq $app.Category }
    if ($category) {
        Write-Host "Category: $($category.Key)" -ForegroundColor Yellow
    }
    else {
        Write-Host 'Unknown Category' -ForegroundColor Red
    }
}
# ==================================================================================================


# set all to a certain category
# a blank 'other' category is left
foreach ($app in $appObjs) {
    Set-ItemProperty $app.Path -Name 'Category' -Value 9
}

# leave only 'Other' category 
foreach ($app in $appObjs) {
    Remove-Item $app.Path -Force
}

# reset to default
Remove-Item $regPath -Force -Recurse

# apply changes
Stop-Process -Name explorer