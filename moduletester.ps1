$name = "POSH Test 14"
$database = "CitrixWEM-CTA"
Remove-Module Citrix.WEMSDK -ErrorAction SilentlyContinue
Import-Module .\Citrix.WEMSDK.psd1
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
$apps = Get-WEMAction -Connection $dbconn -Verbose -IdSite 12 -Name "*2016*" -Category Application
$apps | Select-Object IdSite, IdApplication, Name, Description
$apps = Get-WEMAction -Connection $dbconn -Verbose -Name "*2016*"
$apps | Select-Object IdSite, IdApplication, Name, Description
$apps = Get-WEMAction -Connection $dbconn -Verbose -IdSite 8
Get-WEMAction -Verbose -Connection $dbconn -IdAction 32
Get-WEMAction -Connection $dbconn -Verbose | Where-Object {$_.Category -like "network drive" -and $_.SetAsHomeDriveEnabled}
Get-WEMAction -Connection $dbconn -Category "Network Drive" -Verbose | Where-Object {$_.SetAsHomeDriveEnabled}


# Set-WEMApplication
Set-WEMApp -Verbose -Connection $dbconn -IdApplication 32 -Name "Test" -Description "Test DESC" -CreateShortcutInUserFavoritesFolder $true
Get-WEMAction -Verbose -Connection $dbconn -IdApplication 32 | Set-WEMApp -Verbose -Connection $dbconn -IdApplication 32 -Name "Test" -Description "Test DESC" -CreateShortcutInUserFavoritesFolder $false

# New-WEMNetworkDrive
$conf | New-WEMNetworkDrive -Connection $dbconn -Name "POSH Drive 3" -TargetPath "server\poshshare"

# Set-WEMNetworkDrive
Get-WEMNetworkDrive -Connection $dbconn -Name "POSH Drive 3" -Verbose | Set-WEMNetworkDrive -Connection $dbconn -TargetPath "\\server\poshshare" -Verbose
$dbconn.Close()
$dbconn.Dispose()
