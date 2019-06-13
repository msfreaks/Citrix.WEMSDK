$name       = "POSH 1903"
$database   = "CitrixWEM1903"
Remove-Module Citrix.WEMSDK -ErrorAction SilentlyContinue
Import-Module .\Citrix.WEMSDK.psd1
$dbconn = New-WEMDatabaseConnection -Server "ca002511" -Database "$($database)" -Verbose

#region WEMConfiguration
# New-WEMConfiguration
$conf = New-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"
New-WEMConfiguration -Connection $dbconn -Verbose -Name "POSH Test"

# Get-WEMConfiguration
Get-WEMConfiguration -Connection $dbconn -Verbose | Format-Table
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"
$conf | Format-Table

# Set-WEMConfiguration
Get-WEMConfiguration -Connection $dbconn -Verbose -IdSite $conf.IdSite | Set-WEMConfiguration -Connection $dbconn -Verbose -Description "Test Description"
Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)" | Set-WEMConfiguration -Connection $dbconn -Verbose -Name "New Name" -Description "Set-WEMConfiguration"
Set-WEMConfiguration -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "$($Name)" -Description "Set-WEMConfiguration"

# Remove-WEMConfiguration
Get-WEMConfiguration -Connection $dbconn -Verbose -Name "Posh Test" | Remove-WEMConfiguration -Connection $dbconn -Verbose

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
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "Application" | Format-Table
$allApps = $conf | Get-WEMApplication -Connection $dbconn -Verbose
$appLog = $conf | Get-WEMApp -Connection $dbconn -Verbose -Name "*log"

$allApps | Select-Object IdSite, IdApplication, Name, Description

# Set-WEMApplication
$allApps | ForEach-Object { Set-WEMApplication -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMApplication" -SelfHealingEnabled $true }
Set-WEMApplication -Connection $dbconn -Verbose -IdAction $appLog.IdAction -StartMenuTarget "Start Menu\Programs\Logs" -SelfHealingEnabled $false

# Remove-WEMAction (Application)
Get-WEMApplication -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Application"

#endregion

#region WEMPrinter
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMPrinter
$conf | New-WEMPrinter -Connection $dbconn -Verbose -Name "POSH Printer 1" -TargetPath "\\server\printer1"
$conf | New-WEMPrinter -Connection $dbconn -Verbose -Name "POSH Printer 2" -TargetPath "\\server\printer2"
$conf | New-WEMPrinter -Connection $dbconn -Verbose -Name "POSH Test" -TargetPath "\\server\printertest"

# Get-WEMPrinter
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "Printer" | Format-Table
$allPrinters = $conf | Get-WEMPrinter -Connection $dbconn -Verbose
$printerTest = $conf | Get-WEMPrinter -Connection $dbconn -Verbose -Name "*test"

$allPrinters | Select-Object IdSite, IdApplication, Name, Description

# Set-WEMPrinters
$allPrinters | ForEach-Object { Set-WEMPrinter -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMPrinter" -SelfHealingEnabled $true }
Set-WEMPrinter -Connection $dbconn -Verbose -IdAction $printerTest.IdAction -State "Disabled"

# Remove-WEMAction (Application)
Get-WEMPrinter -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Printer"

#endregion

$allActions = $conf | Get-WEMAction -Connection $dbconn -Verbose
$allActions | Format-Table

#$allActions | Remove-WEMAction -Connection $dbconn
$dbconn.Close()
$dbconn.Dispose()
