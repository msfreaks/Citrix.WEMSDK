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

$allApps | Select-Object IdSite, IdAction, Name, Description

# Set-WEMApplication
$allApps | ForEach-Object { Set-WEMApplication -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMApplication" -SelfHealingEnabled $true }
Set-WEMApplication -Connection $dbconn -Verbose -IdAction $appLog.IdAction -StartMenuTarget "Start Menu\Programs\Logs" -SelfHealingEnabled $false

# Remove-WEMAction (Application)
Get-WEMApplication -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Application"
$conf | New-WEMApplication -Connection $dbconn -Verbose -Name "POSH Test" -TargetPath "C:\Windows\explorer.exe"
Remove-WEMApplication -Connection $dbconn -Verbose -IdAction (Get-WEMAction -Connection $dbconn -Verbose -Name "POSH Test").IdAction

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

$allPrinters | Select-Object IdSite, IdAction, Name, Description

# Set-WEMPrinters
$allPrinters | ForEach-Object { Set-WEMPrinter -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMPrinter" -SelfHealingEnabled $true }
Set-WEMPrinter -Connection $dbconn -Verbose -IdAction $printerTest.IdAction -State "Disabled"

# Remove-WEMAction (Printer)
Get-WEMPrinter -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Printer"

#endregion

#region WEMNetworkDrive
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMNetworkDrive
$conf | New-WEMNetworkDrive -Connection $dbconn -Verbose -Name "POSH Network Drive 1" -TargetPath "\\server\share1"
$conf | New-WEMNetworkDrive -Connection $dbconn -Verbose -Name "POSH Network Drive 2" -TargetPath "\\server\share3"
$conf | New-WEMNetworkDrive -Connection $dbconn -Verbose -Name "POSH Home Drive" -TargetPath "\\server\home" -SetAsHomeDriveEnabled $true
$conf | New-WEMNetworkDrive -Connection $dbconn -Verbose -Name "POSH Test" -TargetPath "\\server\test"

# Get-WEMNetworkDrive
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "Network Drive" | Format-Table
$allDrives = $conf | Get-WEMNetworkDrive -Connection $dbconn -Verbose
$homeDrive = $conf | Get-WEMNetDrive -Connection $dbconn -Verbose | Where-Object { $_.SetAsHomeDriveEnabled }
$driveTest = $conf | Get-WEMNetworkDrive -Connection $dbconn -Verbose -Name "*test"

$allDrives | Select-Object IdSite, IdAction, Name, Description

# Set-WEMNetworkDrive
$allDrives | ForEach-Object { Set-WEMNetworkDrive -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMNetworkDrive" -DisplayName $_.Name -SelfHealingEnabled $true }
Set-WEMNetworkDrive -Connection $dbconn -Verbose -IdAction $homeDrive.IdAction -TargetPath "\\server\home\##username##"
Set-WEMNetworkDrive -Connection $dbconn -Verbose -IdAction $driveTest.IdAction -State "Disabled"

# Remove-WEMAction (Network Drive)
Get-WEMNetworkDrive -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Network Drive"

#endregion

#region WEMVirtualDrive
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMVirtualDrive
$conf | New-WEMVirtualDrive -Connection $dbconn -Verbose -Name "POSH Virtual Drive 1" -TargetPath "\\server\vdisks\posh1.vhdx"
$conf | New-WEMVirtualDrive -Connection $dbconn -Verbose -Name "POSH Virtual Drive 2" -TargetPath "\\server\vdisks\posh2.vhdx"
$conf | New-WEMVirtualDrive -Connection $dbconn -Verbose -Name "POSH Virtual Home Drive" -TargetPath "\\server\vdisks\##username##" -SetAsHomeDriveEnabled $true
$conf | New-WEMVirtualDrive -Connection $dbconn -Verbose -Name "POSH Test" -TargetPath "\\server\vdisks\test.vhdx"

# Get-WEMVirtualDrive
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "Virtual Drive" | Format-Table
$allDrives = $conf | Get-WEMVirtualDrive -Connection $dbconn -Verbose
$homeDrive = $conf | Get-WEMVirtualDrive -Connection $dbconn -Verbose | Where-Object { $_.SetAsHomeDriveEnabled }
$driveTest = $conf | Get-WEMVirtualDrive -Connection $dbconn -Verbose -Name "*test"

$allDrives | Select-Object IdSite, IdAction, Name, Description

# Set-WEMVirtualDrive
$allDrives | ForEach-Object { Set-WEMVirtualDrive -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMVirtualDrive" }
Set-WEMVirtualDrive -Connection $dbconn -Verbose -IdAction $homeDrive.IdAction -TargetPath "\\server\home\##username##.vhdx"
Set-WEMVirtualDrive -Connection $dbconn -Verbose -IdAction $driveTest.IdAction -State "Disabled"

# Remove-WEMAction (Virtual Drive)
Get-WEMVirtualDrive -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Virtual Drive"

#endregion

#region WEMRegistryEntry
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMRegistryEntry
$conf | New-WEMRegistryEntry -Connection $dbconn -Verbose -Name "POSH Registry Entry 1" -TargetPath "Citrix.WEMSDK\POSH" -TargetName "REG_SZ test" -TargetType "REG_SZ" -TargetValue "This is a string value"
$conf | New-WEMRegistryEntry -Connection $dbconn -Verbose -Name "POSH Registry Entry 2" -TargetPath "Citrix.WEMSDK\POSH" -TargetName "REG_DWORD test" -TargetType "REG_DWORD" -TargetValue "49152"
$conf | New-WEMRegistryEntry -Connection $dbconn -Verbose -Name "POSH Registry Entry 3" -TargetPath "Citrix.WEMSDK\POSH" -TargetName "REG_QWORD test" -TargetType "REG_QDWORD" -TargetValue "00,00,0d,00,00,00,00,00"
$conf | New-WEMRegistryEntry -Connection $dbconn -Verbose -Name "POSH Test" -TargetPath "Citrix.WEMSDK\POSH\Test" -TargetName "Test" -TargetType "REG_SZ" -TargetValue ""

# Get-WEMRegistryEntry
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "Registry Entry" | Format-Table
$allRegistryEntries = $conf | Get-WEMRegistryEntry -Connection $dbconn -Verbose
$registryEntryTest = $conf | Get-WEMRegistryEntry -Connection $dbconn -Verbose -Name "*test"

$allRegistryEntries | Select-Object IdSite, IdAction, Name, Description

# Set-WEMRegistryEntry
$allRegistryEntries | ForEach-Object { Set-WEMRegistryEntry -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMRegistryEntry" }
Set-WEMRegistryEntry -Connection $dbconn -Verbose -IdAction $registryEntryTest.IdAction -TargetName "Test updated" -TargetType "REG_EXPAND_SZ" -TargetValue "Test value" -RunOnce $false
Set-WEMRegistryEntry -Connection $dbconn -Verbose -IdAction $registryEntryTest.IdAction -State "Disabled"

# Remove-WEMAction (Registry Entry)
Get-WEMRegistryEntry -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Registry Entry"

#endregion

#region WEMEnvironmentVariable
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMEnvironmentVariable
$conf | New-WEMEnvironmentVariable -Connection $dbconn -Verbose -Name "POSH Environment Variable 1" -VariableName "POSHModule" -VariableValue "Citrix.WEMSDK"
$conf | New-WEMEnvironmentVariable -Connection $dbconn -Verbose -Name "POSH Test" -VariableName "POSHTest"
$conf | New-WEMEnvironmentVariable -Connection $dbconn -Verbose -Name "POSH Test 2" -VariableName "POSHTest 2"

# Get-WEMEnvironmentVariable
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "Environment Variable" | Format-Table
$allEnvironmentVariables = $conf | Get-WEMEnvironmentVariable -Connection $dbconn -Verbose
$environmentVariableTest = $conf | Get-WEMEnvironmentVariable -Connection $dbconn -Verbose -Name "*test"

$allEnvironmentVariables | Select-Object IdSite, IdAction, Name, Description

# Set-WEMEnvironmentVariable
$i=1 ; $allEnvironmentVariables | ForEach-Object { Set-WEMEnvironmentVariable -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMEnvironmentVariable" -ExecutionOrder $i; $i++ }
Set-WEMEnvironmentVariable -Connection $dbconn -Verbose -IdAction $environmentVariableTest.IdAction -VariableName "POSHTested" -VariableValue "Updated"
Set-WEMEnvironmentVariable -Connection $dbconn -Verbose -IdAction $environmentVariableTest.IdAction -State "Disabled"

# Remove-WEMAction (Environment Variable)
Get-WEMEnvironmentVariable -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Environment Variable"
Get-WEMEnvironmentVariable -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test 2" | Remove-WEMEnvironmentVariable -Connection $dbconn -Verbose

#endregion

$allActions = $conf | Get-WEMAction -Connection $dbconn -Verbose
$allActions | Select-Object IdAction, IdSite, Category, Name, DisplayName, Description, State, Type, ActionType | Format-Table

# Cleanup
# $conf | Remove-WEMConfiguration -Connection $dbconn
#$allActions | Remove-WEMAction -Connection $dbconn

$dbconn.Dispose()
