$name = "POSH Test 14"
$database = "CitrixWEM-CTA"
Remove-Module Citrix.WEMSDK -ErrorAction SilentlyContinue
Import-Module .\Citrix.WEMSDK.psd1

# New-WEMDatabaseConnection
$dbconn = New-WEMDatabaseConnection -Server "ca002511" -Database "$($database)" -Verbose

# New-WEMConfiguration
New-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# Get-WEMConfiguration
Get-WEMConfiguration -Connection $dbconn -Verbose | Format-Table
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"
$conf | Format-Table
Get-WEMConfiguration -Connection $dbconn -Verbose -IdSite $conf.IdSite | Format-Table

# Set-WEMConfiguration
Get-WEMConfiguration -Connection $dbconn -Verbose -IdSite $conf.IdSite | Set-WEMConfiguration -Verbose -Description "New description" -Connection $dbconn
Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)" | Set-WEMConfiguration -Verbose -Name "New Name" -Description "New description 2" -Connection $dbconn
Get-WEMConfiguration -Connection $dbconn -Verbose -Name "New Name" | Set-WEMConfiguration -Verbose -Name "$($name)" -Description $null -Connection $dbconn

# Remove-WEMConfiguration
Remove-WEMConfiguration -Connection $dbconn -Verbose -IdSite $conf.IdSite

# Get-WEMApp
$apps = Get-WEMApp -Connection $dbconn -Verbose -IdSite 7 -Name "*2016*"
$apps = Get-WEMApp -Connection $dbconn -Verbose -Name "*2016*"

$dbconn.Close()
$dbconn.Dispose()
