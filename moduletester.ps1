$name       = "POSH 1903"
$database   = "CitrixWEM1903"
Remove-Module Citrix.WEMSDK -ErrorAction SilentlyContinue
Import-Module .\Citrix.WEMSDK.psd1
$dbconn = New-WEMDatabaseConnection -Server "ca002511" -Database "$($database)" -Verbose

#region WEMConfiguration
# New-WEMConfiguration
$conf = New-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"
New-WEMConfiguration -Connection $dbconn -Verbose -Name "Garbage Test"

# Get-WEMConfiguration
Get-WEMConfiguration -Connection $dbconn -Verbose | Format-Table
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"
$conf | Format-Table

# Set-WEMConfiguration
Get-WEMConfiguration -Connection $dbconn -Verbose -IdSite $conf.IdSite | Set-WEMConfiguration -Connection $dbconn -Verbose -Description "Test Description"
Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)" | Set-WEMConfiguration -Connection $dbconn -Verbose -Name "New Name" -Description "Set-WEMConfiguration"
Set-WEMConfiguration -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "$($Name)" -Description "Set-WEMConfiguration"

# Remove-WEMConfiguration
Get-WEMConfiguration -Connection $dbconn -Verbose -Name "Garbage Test" | Remove-WEMConfiguration -Connection $dbconn -Verbose

#endregion

#region WEMApplication
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMApplication
$conf | New-WEMApplication -Connection $dbconn -Verbose -Name "POSH Notepad" -TargetPath "C:\Windows\notepad.exe"
$conf | New-WEMApplication -Connection $dbconn -Verbose -Name "POSH Regedit" -TargetPath "C:\Windows\regedit.exe"
$conf | New-WEMApplication -Connection $dbconn -Verbose -Name "POSH Google" -TargetPath "https://www.google.com" -Type "URL"
$conf | New-WEMApplication -Connection $dbconn -Verbose -Name "POSH Update Log" -TargetPath "C:\Windows\WindowsUpdate.log" -Type "File / Folder"
$conf | New-WEMApplication -Connection $dbconn -Verbose -Name "POSH Test" -TargetPath "C:\Windows\explorer.exe"

# Get-WEMApplication
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category Application | Format-Table
$allApps = $conf | Get-WEMApplication -Connection $dbconn -Verbose
$appLog = $conf | Get-WEMApp -Connection $dbconn -Verbose -Name "*log"

$allApps | Select-Object IdSite, IdApplication, Name, Description

# Set-WEMApplication
$allApps | Set-WEMApplication -Connection $dbconn -Verbose -Description "Set-WEMApplication"
$appLog | Set-WEMApplication -Connection $dbconn -Verbose -StartMenuTarget "Start Menu\Programs\Logs" -SelfHealingEnabled $true

# Remove-WEMAction (Application)
Get-WEMApplication -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Application"

#endregion

$dbconn.Close()
$dbconn.Dispose()
