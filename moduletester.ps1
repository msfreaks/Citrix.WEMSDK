$name       = "POSH 1906"
$database   = "CitrixWEM1906"
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

#region WEMActions

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
$conf | New-WEMVirtualDrive -Connection $dbconn -Verbose -Name "POSH Virtual Drive 1" -TargetPath "D:\vdisks\posh1folder"
$conf | New-WEMVirtualDrive -Connection $dbconn -Verbose -Name "POSH Virtual Drive 2" -TargetPath "D:\vdisks\posh2folder"
$conf | New-WEMVirtualDrive -Connection $dbconn -Verbose -Name "POSH Virtual Home Drive" -TargetPath "D:\vdisks\##username##" -SetAsHomeDriveEnabled $true
$conf | New-WEMVirtualDrive -Connection $dbconn -Verbose -Name "POSH Test" -TargetPath "D:\vdisks\test"

# Get-WEMVirtualDrive
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "Virtual Drive" | Format-Table
$allDrives = $conf | Get-WEMVirtualDrive -Connection $dbconn -Verbose
$homeDrive = $conf | Get-WEMVirtualDrive -Connection $dbconn -Verbose | Where-Object { $_.SetAsHomeDriveEnabled }
$driveTest = $conf | Get-WEMVirtualDrive -Connection $dbconn -Verbose -Name "*test"

$allDrives | Select-Object IdSite, IdAction, Name, Description

# Set-WEMVirtualDrive
$allDrives | ForEach-Object { Set-WEMVirtualDrive -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMVirtualDrive" }
Set-WEMVirtualDrive -Connection $dbconn -Verbose -IdAction $homeDrive.IdAction -TargetPath "D:\home\##username##"
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
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "Registry Value" | Format-Table
$allRegistryEntries = $conf | Get-WEMRegistryEntry -Connection $dbconn -Verbose
$registryEntryTest = $conf | Get-WEMRegistryEntry -Connection $dbconn -Verbose -Name "*test"

$allRegistryEntries | Select-Object IdSite, IdAction, Name, Description

# Set-WEMRegistryEntry
$allRegistryEntries | ForEach-Object { Set-WEMRegistryEntry -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMRegistryEntry" }
Set-WEMRegistryEntry -Connection $dbconn -Verbose -IdAction $registryEntryTest.IdAction -TargetName "Test updated" -TargetType "REG_EXPAND_SZ" -TargetValue "Test value" -RunOnce $false
Set-WEMRegistryEntry -Connection $dbconn -Verbose -IdAction $registryEntryTest.IdAction -State "Disabled"

# Remove-WEMAction (Registry Entry)
Get-WEMRegistryEntry -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Registry Value"

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

#region WEMPort
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMPort
$conf | New-WEMPort -Connection $dbconn -Verbose -Name "POSH Port COM1:" -PortName "COM1:" -TargetPath "Unknown COM port"
$conf | New-WEMPort -Connection $dbconn -Verbose -Name "POSH Port LPT4:" -PortName "LPT4:" -TargetPath "Unknown LPT port"
$conf | New-WEMPort -Connection $dbconn -Verbose -Name "POSH Test 1" -PortName "COM9:" -TargetPath "\\.\COM9"
$conf | New-WEMPort -Connection $dbconn -Verbose -Name "POSH Test 2" -PortName "LPT9:" -TargetPath "Unknown"

# Get-WEMPort
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "Port" | Format-Table
$allPorts = $conf | Get-WEMPort -Connection $dbconn -Verbose
$portTest = $conf | Get-WEMPort -Connection $dbconn -Verbose -Name "*test 1"

$allPorts | Select-Object IdSite, IdAction, Name, Description

# Set-WEMPort
$allPorts | ForEach-Object { Set-WEMPort -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMPort" }
Set-WEMPort -Connection $dbconn -Verbose -IdAction $portTest.IdAction -Name "POSH Test 1 - Update" -TargetPath "Updated"
Set-WEMPort -Connection $dbconn -Verbose -IdAction $portTest.IdAction -State "Disabled"

# Remove-WEMAction (Environment Variable)
Get-WEMPort -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Port"
Get-WEMPort -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test 2" | Remove-WEMPort -Connection $dbconn -Verbose

#endregion

#region WEMIniFileOperation
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMIniFileOperation
$conf | New-WEMIniFileOperation -Connection $dbconn -Verbose -Name "POSH Ini File Op 1" -TargetPath "C:\Windows\system.ini" -TargetSectionName "startup" -TargetValueName "init" -TargetValue "None"
$conf | New-WEMIniFileOperation -Connection $dbconn -Verbose -Name "POSH Ini File Op 2" -TargetPath "C:\Windows\system.ini" -TargetSectionName "startup" -TargetValueName "deinit"
$conf | New-WEMIniFileOperation -Connection $dbconn -Verbose -Name "POSH Test 1" -TargetPath "C:\Windows\system.ini" -TargetSectionName "Test" -TargetValueName "1" -TargetValue "A"
$conf | New-WEMIniFileOperation -Connection $dbconn -Verbose -Name "POSH Test 2" -TargetPath "C:\Windows\system.ini" -TargetSectionName "Test" -TargetValueName "2" -TargetValue "B"

# Get-WEMIniFileOperation
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "Ini File Operation" | Format-Table
$allIniFileOps = $conf | Get-WEMIniFileOperation -Connection $dbconn -Verbose
$iniFileOpTest = $conf | Get-WEMIniFileOperation -Connection $dbconn -Verbose -Name "*test 1"

$allIniFileOps | Select-Object IdSite, IdAction, Name, Description

# Set-WEMIniFileOperation
$allIniFileOps | ForEach-Object { Set-WEMIniFileOperation -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMIniFileOperation" }
Set-WEMIniFileOperation -Connection $dbconn -Verbose -IdAction $iniFileOpTest.IdAction -Name "POSH Test 1 - Update" -TargetValue "Updated"
Set-WEMIniFileOperation -Connection $dbconn -Verbose -IdAction $iniFileOpTest.IdAction -State "Disabled" -RunOnce $false

# Remove-WEMAction (Ini File Operation)
Get-WEMIniFileOperation -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $dbconn -Verbose -Category "Ini File Operation"
Get-WEMIniFilesOp -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test 2" | Remove-WEMIniFileOperation -Connection $dbconn -Verbose

#endregion

#region WEMExternalTask
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMExternalTask
$conf | New-WEMExternalTask -Connection $dbconn -Verbose -Name "POSH External Task 1" -TargetPath "C:\Windows\SetScreensaver.exe" -TargetArguments "-Seconds 600" -RunHidden $true
$conf | New-WEMExternalTask -Connection $dbconn -Verbose -Name "POSH External Task 2" -TargetPath "C:\Windows\Notepad.exe" -TargetArguments "'c:\temp\new file[]%.txt'" -WaitForFinish $false -TimeOut 120 -ExecuteOnlyAtLogon $true
$conf | New-WEMExternalTask -Connection $dbconn -Verbose -Name "POSH Test 1" -TargetPath "C:\Windows\System32\explorer.exe" -TargetArguments "C:"
$conf | New-WEMExternalTask -Connection $dbconn -Verbose -Name "POSH Test 2" -TargetPath "reg.exe"

# Get-WEMExternalTask
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "External Task" | Format-Table
$allExternalTasks = $conf | Get-WEMExternalTask -Connection $dbconn -Verbose
$externalTaskTest = $conf | Get-WEMExternalTask -Connection $dbconn -Verbose -Name "*test 1"

$allExternalTasks | Select-Object IdSite, IdAction, Name, Description

# Set-WEMExternalTask
$allExternalTasks | ForEach-Object { Set-WEMExternalTask -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMExternalTask" }
Set-WEMExternalTask -Connection $dbconn -Verbose -IdAction $externalTaskTest.IdAction -Name "POSH Test 1 - Update" -TargetPath "dir"
Set-WEMExternalTask -Connection $dbconn -Verbose -IdAction $externalTaskTest.IdAction -State "Disabled" -RunOnce $false -ExecuteOnlyAtLogon $true -ExecutionOrder 54

# Remove-WEMAction (External Task)
Get-WEMExtTask -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $dbconn -Verbose -Category "External Task"
Get-WEMExternalTask -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "*test 2" | Remove-WEMExternalTask -Connection $dbconn -Verbose

#endregion

#region WEMFileSystemOperation
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMFileSystemOperation
$conf | New-WEMFileSystemOperation -Connection $dbconn -Verbose -Name "POSH File System Operation 1" -SourcePath "\\server\share\file.ini" -TargetPath "C:\Windows\file.ini"
$conf | New-WEMFileSystemOperation -Connection $dbconn -Verbose -Name "POSH File System Operation 2" -SourcePath "C:\Temp" -ActionType "Create Directory"
$conf | New-WEMFileSystemOperation -Connection $dbconn -Verbose -Name "POSH Test 1" -SourcePath "\\server\share\malware.exe" -TargetPath "C:\Windows\System32\explorer.exe" -RunOnce $false -ExecutionOrder 69
$conf | New-WEMFileSystemOperation -Connection $dbconn -Verbose -Name "POSH Test 2" -SourcePath "\\server\share\malware.exe" -TargetPath "C:\Windows\System32\notepad.exe" -TargetOverwrite $false

# Get-WEMFileSystemOperation
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "File System Operation" | Format-Table
$allFileSystemOps = $conf | Get-WEMFileSystemOperation -Connection $dbconn -Verbose
$fileSystemOpsTest = $conf | Get-WEMFileSystemOp -Connection $dbconn -Verbose -Name "*test 1"

$allFileSystemOps | Select-Object IdSite, IdAction, Name, Description

# Set-WEMFileSystemOperation
$allFileSystemOps | ForEach-Object { Set-WEMFileSystemOperation -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMFileSystemOperation" }
Set-WEMFileSystemOperation -Connection $dbconn -Verbose -IdAction $fileSystemOpsTest.IdAction -Name "POSH Test 1 - Update" -TargetPath "C:\Windows\screensaver.exe"
Set-WEMFileSystemOperation -Connection $dbconn -Verbose -IdAction $fileSystemOpsTest.IdAction -State "Disabled" -RunOnce $True -ExecutionOrder 666

# Remove-WEMAction (File System Operation)
Get-WEMFileSystemOperation -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $dbconn -Verbose -Category "File System Operation"
Get-WEMFileSystemOperation -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "*test 2" | Remove-WEMFileSystemOperation -Connection $dbconn -Verbose

#endregion

#region WEMUserDSN
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMUserDSN
$conf | New-WEMUserDSN -Connection $dbconn -Verbose -Name "POSH User DSN 1" -TargetName "POSH DSN 1" -TargetDriverName "SQL Server" -TargetServer "ITWSQL" -TargetDatabaseName "CitrixWEM" -RunOnce $false
$conf | New-WEMUserDSN -Connection $dbconn -Verbose -Name "POSH User DSN 2" -TargetName "POSH DSN 2" -TargetDriverName "SQL Server" -TargetServer "ITWSQL" -TargetDatabaseName "ADFS" -RunOnce $true
$conf | New-WEMUserDSN -Connection $dbconn -Verbose -Name "POSH Test 1" -TargetName "POSH Test" -TargetDriverName "SQL Server" -TargetServer "ITWTEMP" -TargetDatabaseName "TEMPDB" -RunOnce $true
$conf | New-WEMUserDSN -Connection $dbconn -Verbose -Name "POSH Test 2" -TargetName "POSH Test 2" -TargetDriverName "SQL Server" -TargetServer "ITWTEMP" -TargetDatabaseName "TEMPDB" -RunOnce $true

# Get-WEMUserDSN
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "User DSN" | Format-Table
$allUserDSNs = $conf | Get-WEMUserDSN -Connection $dbconn -Verbose
$userDSNTest = $conf | Get-WEMUserDSN -Connection $dbconn -Verbose -Name "*test 1"

$allUserDSNs | Select-Object IdSite, IdAction, Name, Description

# Set-WEMUserDSN
$allUserDSNs | ForEach-Object { Set-WEMUserDSN -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMUserDSN" }
Set-WEMUserDSN -Connection $dbconn -Verbose -IdAction $userDSNTest.IdAction -Name "POSH Test 1 - Update" -TargetServer "ITWSQL" -TargetDatabaseName "TheDB" -RunOnce $false
Set-WEMUserDSN -Connection $dbconn -Verbose -IdAction $userDSNTest.IdAction -State "Disabled"

# Remove-WEMAction (User DSN)
Get-WEMUserDSN -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $dbconn -Verbose -Category "User DSN"
Get-WEMUserDSN -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test 2" | Remove-WEMUserDSN -Connection $dbconn -Verbose

#endregion

#region WEMFileAssociation
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMFileAssociation
$conf | New-WEMFileAssociation -Connection $dbconn -Verbose -Name "POSH File Association 1" -FileExtension "txt" -ProgramId "666" -Action "open" -IsDefault $true -TargetPath "c:\notepad++\notepad++.exe" -TargetCommand "%1"
$conf | New-WEMFileAssociation -Connection $dbconn -Verbose -Name "POSH File Association 2" -FileExtension "log" -ProgramId "789" -Action "edit" -IsDefault $false -TargetPath "c:\notepad++\notepad++.exe" -TargetCommand "%1"
$conf | New-WEMFileAssociation -Connection $dbconn -Verbose -Name "POSH Test 1" -FileExtension "nfo" -ProgramId "123" -Action "print" -TargetPath "c:\notepad++\notepad++.exe" -TargetCommand "%1"
$conf | New-WEMFileAssociation -Connection $dbconn -Verbose -Name "POSH Test 2" -FileExtension "csv" -ProgramId "450" -Action "open" -TargetPath "c:\notepad++\notepad++.exe" -TargetCommand "%1"

# Get-WEMFileAssociation
$conf | Get-WEMAction -Connection $dbconn -Verbose -Category "File Association" | Format-Table
$allFileAssocs = $conf | Get-WEMFileAssociation -Connection $dbconn -Verbose
$fileAssocTest = $conf | Get-WEMFileAssoc -Connection $dbconn -Verbose -Name "*test 1"

$allFileAssocs | Select-Object IdSite, IdAction, Name, Description

# Set-WEMFileAssociation
$allFileAssocs | ForEach-Object { Set-WEMFileAssociation -Connection $dbconn -Verbose -IdAction $_.IdAction -Description "Set-WEMFileAssociation" }
Set-WEMFileAssociation -Connection $dbconn -Verbose -IdAction $fileAssocTest.IdAction -Name "POSH Test 1 - Update" -Action "open" -IsDefault $true -TargetOverwrite $true -RunOnce $true 
Set-WEMFileAssoc -Connection $dbconn -Verbose -IdAction $fileAssocTest.IdAction -State "Disabled"

# Remove-WEMAction (File Association)
Get-WEMFileAssociation -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $dbconn -Verbose -Category "File Association"
Get-WEMFileAssociation -Connection $dbconn -Verbose -IdSite $conf.IdSite -Name "posh test 2" | Remove-WEMFileAssociation -Connection $dbconn -Verbose

#endregion

#endregion

#region WEMADObject
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMADObject
# NOTE: This test requires the ActiveDirectory module to be present!
$conf | New-WEMADObject -Connection $dbconn -Verbose -Name (Get-ADUser "amensc").SID
$conf | New-WEMADObject -Connection $dbconn -Verbose -Name (Get-ADUser "adm_amensc").SID
$conf | New-WEMADObject -Connection $dbconn -Verbose -Name (Get-ADGroup "Domain Users").SID
# Adding Domain Admins group as test for Remove-WEMADObject
$conf | New-WEMADObject -Connection $dbconn -Verbose -Name (Get-ADGroup "Domain Admins").SID

# Get-WEMADObject
$conf | Get-WEMADObject -Connection $dbconn -Verbose | Format-Table
$allADObjects = $conf | Get-WEMADObject -Connection $dbconn -Verbose
$allADObjects | Select-Object IdSite, IdADObject, Name, Type

# Set-WEMADObject
$allADObjects | ForEach-Object { Set-WEMADObject -Connection $dbconn -Verbose -IdADObject $_.IdADObject -Description "Set-WEMADObject" }
Set-WEMADObject -Connection $dbconn -Verbose -IdADObject (Get-WEMADObject -Connection $dbconn -Verbose -Name (Get-ADGroup "Domain Admins").SID).IdADObject -Name (Get-ADGroup "Enterprise Admins").SID -State "Disabled"

# Remove-WEMADObject
Remove-WEMADObject -Connection $dbconn -Verbose -IdADObject (Get-WEMADObject -Connection $dbconn -Verbose -Name (Get-ADGroup "Enterprise Admins").SID).IdADObject

#endregion

#region WEMCondition
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMCondition
$conf | New-WEMCondition -Connection $dbconn -Verbose -Name "POSH Condition 1" -Type "Client OS" -TestResult "Windows 10"
$conf | New-WEMCondition -Connection $dbconn -Verbose -Name "POSH Condition 2" -Type "Environment Variable Match" -TestValue "SystemRoot" -TestResult "C:\Windows"
$conf | New-WEMCondition -Connection $dbconn -Verbose -Name "POSH Test 1" -Type "Active Directory Attribute Match" -TestValue "mail" -TestResult "arjan.mensch@it-worxx.nl"
$conf | New-WEMCondition -Connection $dbconn -Verbose -Name "POSH Test 2" -Type "No Active Directory Group Match" -TestResult "Domain Admins"

# Get-WEMCondition
$conf | Get-WEMCondition -Connection $dbconn -Verbose | Format-Table
$allConditions = $conf | Get-WEMCondition -Connection $dbconn -Verbose
$allConditions | Select-Object IdSite, IdCondition, Name, Type, TestValue, TestResult | Format-Table

# Set-WEMCondition
$allConditions | Where-Object { $_.IdCondition -gt 1 } | ForEach-Object { Set-WEMCondition -Connection $dbconn -Verbose -IdCondition $_.IdCondition -Description "Set-WEMCondition" }
Set-WEMCondition -Connection $dbconn -Verbose -IdCondition (Get-WEMCondition -Connection $dbconn -Verbose -Name "POSH Test 1").IdCondition -State "Disabled"

# Remove-WEMCondition
Remove-WEMCondition -Connection $dbconn -Verbose -IdCondition (Get-WEMCondition -Connection $dbconn -Verbose -Name "POSH Test 1" -IdSite $conf.IdSite).IdCondition
Get-WemCondition -Connection $dbconn -Verbose -Name "*test 2" -IdSite $conf.IdSite | Remove-WEMCondition -Connection $dbconn -Verbose

#endregion

#region WEMRule
$conf = Get-WEMConfiguration -Connection $dbconn -Verbose -Name "$($name)"

# New-WEMRule
$conf | New-WEMRule -Connection $dbconn -Verbose -Name "POSH Rule 1" -Conditions (Get-WEMCondition -Connection $dbconn -Verbose -Name "POSH Condition 1")
$conf | New-WEMRule -Connection $dbconn -Verbose -Name "POSH Rule 2" -Conditions (Get-WEMCondition -Connection $dbconn -Verbose -Name "POSH Condition 2")
$conf | New-WEMRule -Connection $dbconn -Verbose -Name "POSH Rule 3" -Conditions (Get-WEMCondition -Connection $dbconn -Verbose -Name "POSH Condition *")
$conf | New-WEMRule -Connection $dbconn -Verbose -Name "POSH Test 1" -Conditions (Get-WEMCondition -Connection $dbconn -Verbose -IdCondition 1)

$conf | New-WEMCondition -Connection $dbconn -Verbose -Name "POSH Test 1" -Type "Active Directory Attribute Match" -TestValue "mail" -TestResult "arjan.mensch@it-worxx.nl"
$conf | New-WEMCondition -Connection $dbconn -Verbose -Name "POSH Test 2" -Type "No Active Directory Group Match" -TestResult "Domain Admins"
$conf | New-WEMRule -Connection $dbconn -Verbose -Name "POSH Test 2" -Conditions (Get-WEMCondition -Connection $dbconn -Verbose -Name "POSH Test *")

# Get-WEMRule
$conf | Get-WEMRule -Connection $dbconn -Verbose | Format-Table
$allRules = $conf | Get-WEMRule -Connection $dbconn -Verbose
$testRule = $conf | Get-WEMRule -Connection $dbconn -Verbose -Name "POSH Test 1"
$allRules | Select-Object IdSite, IdRule, Name, @{Name="ConditionName";Expression={ $_.Conditions | Select-Object Name} } | Format-Table

# Set-WEMRule
$allRules | Where-Object { $_.IdRule -gt 1 } | ForEach-Object { Set-WEMRule -Connection $dbconn -Verbose -IdRule $_.IdRule -Description "Set-WEMRule" }
$conditionArray = $testRule.Conditions
$conditionArray += Get-WEMCondition -Connection $dbconn -IdSite $conf.IdSite -Name "POSH Condition *" 
Set-WEMRule -Connection $dbconn -Verbose -IdRule $testRule.IdRule -State "Disabled" -Conditions $conditionArray
$conditionArray = $conditionArray | Where-Object { $_.Name -notlike "POSH Condition 1" }
Set-WEMRule -Connection $dbconn -Verbose -IdRule $testRule.IdRule -Conditions $conditionArray

# Remove-WEMRule
Remove-WEMRule -Connection $dbconn -Verbose -IdRule $testRule.IdRule
Remove-WEMCondition -Connection $dbconn -Verbose -IdCondition (Get-WEMCondition -Connection $dbconn -Name "POSH Test 1").IdCondition
Remove-WEMCondition -Connection $dbconn -Verbose -IdCondition (Get-WEMCondition -Connection $dbconn -Name "POSH Test 2").IdCondition

#endregion

#region WEMActionGroup
$conf = Get-WEMConfiguration -Connection $dbconn -Name "$($name)" -Verbose

# New-WEMActionGroup
$conf | New-WEMActionGroup -Connection $dbconn -Verbose -Name "POSH Action Group 1"
$conf | New-WEMActionGroup -Connection $dbconn -Verbose -Name "POSH Action Group 2"
$conf | New-WEMActionGroup -Connection $dbconn -Verbose -Name "POSH Test 1"

# Get-WEMActionGroup
$conf | Get-WEMActionGroup -Connection $dbconn -Verbose | Format-Table
$allActionGroups = $conf | Get-WEMActionGroup -Connection $dbconn -Verbose
$testActionGroup = $conf | Get-WEMActionGroup -Connection $dbconn -Verbose -Name "POSH Test 1"
$allActionGroups | Format-Table

# Set-WEMActionGroup
$allActionGroups | ForEach-Object { Set-WEMActionGroup -Connection $dbconn -Verbose -IdActionGroup $_.IdActionGroup -Description "Set-WEMActionGroup" }

$actionGroupId = (Get-WEMActionGroup -Connection $dbconn -IdSite $conf.IdSite -Name "POSH Action Group 1").IdActionGroup
$allApps | ForEach-Object { Set-WEMActionGroup -Connection $dbconn -Verbose -IdActionGroup $actionGroupId -AddApplication $_ -AssignmentProperties "CreateStartMenuLink", "PinToStartMenu" }
$allPrinters | ForEach-Object { Set-WEMActionGroup -Connection $dbconn -Verbose -IdActionGroup $actionGroupId -AddPrinter $_ }
Set-WEMActionGroup -Connection $dbconn -Verbose -IdActionGroup $actionGroupId -AddNetworkDrive $allDrives[0] -DriveLetter H
Set-WEMActionGroup -Connection $dbconn -Verbose -IdActionGroup $testActionGroup.IdActionGroup -AddNetworkDrive $allDrives[0] -DriveLetter H

# Remove-WEMActionGroup
Remove-WEMActionGroup -Connection $dbconn -Verbose -IdActionGroup $testActionGroup.IdActionGroup

#endregion

$allActions = $conf | Get-WEMAction -Connection $dbconn -Verbose
$allActions | Select-Object IdAction, IdSite, Category, Name, DisplayName, Description, State, Type, ActionType | Format-Table

$allADObjects = $conf | Get-WEMADObject -Connection $dbconn -Verbose
$allADObjects | Where-Object { $_.Type -notlike "BUILTIN" } | Select-Object IdADObject, IdSite, Name, Description, State, Type, Priority | Format-Table

$allConditions = $conf | Get-WEMCondition -Connection $dbconn -Verbose
$allConditions | Select-Object IdSite, IdCondition, Name, Type, TestValue, TestResult | Format-Table

$allRules = $conf | Get-WEMRule -Connection $dbconn -Verbose
$allRules | Select-Object IdSite, IdRule, Name, @{Name="ConditionName";Expression={ $_.Conditions | Select-Object Name} } | Format-Table

$allActionGroups = $conf | Get-WEMActionGroup -Connection $dbconn -Verbose
$allActionGroups | Format-Table

# Cleanup
# $conf | Remove-WEMConfiguration -Connection $dbconn
#$allActions | Remove-WEMAction -Connection $dbconn

$dbconn.Dispose()
