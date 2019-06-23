$name       = "POSH 1906"
$database   = "CitrixWEM1906"
Remove-Module Citrix.WEMSDK -ErrorAction SilentlyContinue
Import-Module .\Citrix.WEMSDK.psd1
$db     = New-WEMDatabaseConnection -Server "ca002511" -Database "$($database)" -Verbose

#region WEMConfiguration
# New-WEMConfiguration
$conf = New-WEMConfiguration -Connection $db -Verbose -Name "$($name)"
New-WEMConfiguration -Connection $db -Verbose -Name "POSH Test"

# Get-WEMConfiguration
Get-WEMConfiguration -Connection $db -Verbose | Format-Table
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"
$conf | Format-Table

# Set-WEMConfiguration
Get-WEMConfiguration -Connection $db -Verbose -IdSite $conf.IdSite | Set-WEMConfiguration -Connection $db -Verbose -Description "Test Description"
Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)" | Set-WEMConfiguration -Connection $db -Verbose -Name "New Name" -Description "Set-WEMConfiguration"
Set-WEMConfiguration -Connection $db -Verbose -IdSite $conf.IdSite -Name "$($Name)" -Description "Set-WEMConfiguration"

# Remove-WEMConfiguration
Get-WEMConfiguration -Connection $db -Verbose -Name "Posh Test" | Remove-WEMConfiguration -Connection $db -Verbose

#endregion

#region WEMActions

#region WEMApplication
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMApplication
$conf | New-WEMApplication -Connection $db -Verbose -Name "POSH Notepad" -TargetPath "C:\Windows\notepad.exe"
$conf | New-WEMApplication -Connection $db -Verbose -Name "POSH Regedit" -TargetPath "C:\Windows\regedit.exe"
$conf | New-WEMApplication -Connection $db -Verbose -Name "POSH Google" -TargetPath "https://www.google.com" -Type "URL"
$conf | New-WEMApplication -Connection $db -Verbose -Name "POSH Update Log" -TargetPath "C:\Windows\WindowsUpdate.log" -Type "File / Folder"
$conf | New-WEMApplication -Connection $db -Verbose -Name "POSH Test" -TargetPath "C:\Windows\explorer.exe"

# Get-WEMApplication
$conf | Get-WEMAction -Connection $db -Verbose -Category "Application" | Format-Table
$allApps = $conf | Get-WEMApplication -Connection $db -Verbose
$appLog = $conf | Get-WEMApp -Connection $db -Verbose -Name "*log"

$allApps | Select-Object IdSite, IdAction, Name, Description

# Set-WEMApplication
$allApps | ForEach-Object { Set-WEMApplication -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMApplication" -SelfHealingEnabled $true }
Set-WEMApplication -Connection $db -Verbose -IdAction $appLog.IdAction -StartMenuTarget "Start Menu\Programs\Logs" -SelfHealingEnabled $false

# Remove-WEMAction (Application)
Get-WEMApplication -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $db -Verbose -Category "Application"
$conf | New-WEMApplication -Connection $db -Verbose -Name "POSH Test" -TargetPath "C:\Windows\explorer.exe"
Remove-WEMApplication -Connection $db -Verbose -IdAction (Get-WEMAction -Connection $db -Verbose -Name "POSH Test").IdAction

$allApps = $conf | Get-WEMApplication -Connection $db -Verbose
#endregion

#region WEMPrinter
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMPrinter
$conf | New-WEMPrinter -Connection $db -Verbose -Name "POSH Printer 1" -TargetPath "\\server\printer1"
$conf | New-WEMPrinter -Connection $db -Verbose -Name "POSH Printer 2" -TargetPath "\\server\printer2"
$conf | New-WEMPrinter -Connection $db -Verbose -Name "POSH Test" -TargetPath "\\server\printertest"

# Get-WEMPrinter
$conf | Get-WEMAction -Connection $db -Verbose -Category "Printer" | Format-Table
$allPrinters = $conf | Get-WEMPrinter -Connection $db -Verbose
$printerTest = $conf | Get-WEMPrinter -Connection $db -Verbose -Name "*test"

$allPrinters | Select-Object IdSite, IdAction, Name, Description

# Set-WEMPrinters
$allPrinters | ForEach-Object { Set-WEMPrinter -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMPrinter" -SelfHealingEnabled $true }
Set-WEMPrinter -Connection $db -Verbose -IdAction $printerTest.IdAction -State "Disabled"

# Remove-WEMAction (Printer)
Get-WEMPrinter -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $db -Verbose -Category "Printer"

$allPrinters = $conf | Get-WEMPrinter -Connection $db -Verbose

#endregion

#region WEMNetworkDrive
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMNetworkDrive
$conf | New-WEMNetworkDrive -Connection $db -Verbose -Name "POSH Network Drive 1" -TargetPath "\\server\share1"
$conf | New-WEMNetworkDrive -Connection $db -Verbose -Name "POSH Network Drive 2" -TargetPath "\\server\share3"
$conf | New-WEMNetworkDrive -Connection $db -Verbose -Name "POSH Home Drive" -TargetPath "\\server\home" -SetAsHomeDriveEnabled $true
$conf | New-WEMNetworkDrive -Connection $db -Verbose -Name "POSH Test" -TargetPath "\\server\test"

# Get-WEMNetworkDrive
$conf | Get-WEMAction -Connection $db -Verbose -Category "Network Drive" | Format-Table
$allDrives = $conf | Get-WEMNetworkDrive -Connection $db -Verbose
$homeDrive = $conf | Get-WEMNetDrive -Connection $db -Verbose | Where-Object { $_.SetAsHomeDriveEnabled }
$driveTest = $conf | Get-WEMNetworkDrive -Connection $db -Verbose -Name "*test"

$allDrives | Select-Object IdSite, IdAction, Name, Description

# Set-WEMNetworkDrive
$allDrives | ForEach-Object { Set-WEMNetworkDrive -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMNetworkDrive" -DisplayName $_.Name -SelfHealingEnabled $true }
Set-WEMNetworkDrive -Connection $db -Verbose -IdAction $homeDrive.IdAction -TargetPath "\\server\home\##username##"
Set-WEMNetworkDrive -Connection $db -Verbose -IdAction $driveTest.IdAction -State "Disabled"

# Remove-WEMAction (Network Drive)
Get-WEMNetworkDrive -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $db -Verbose -Category "Network Drive"

$allDrives = $conf | Get-WEMNetworkDrive -Connection $db -Verbose

#endregion

#region WEMVirtualDrive
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMVirtualDrive
$conf | New-WEMVirtualDrive -Connection $db -Verbose -Name "POSH Virtual Drive 1" -TargetPath "D:\vdisks\posh1folder"
$conf | New-WEMVirtualDrive -Connection $db -Verbose -Name "POSH Virtual Drive 2" -TargetPath "D:\vdisks\posh2folder"
$conf | New-WEMVirtualDrive -Connection $db -Verbose -Name "POSH Virtual Home Drive" -TargetPath "D:\vdisks\##username##" -SetAsHomeDriveEnabled $true
$conf | New-WEMVirtualDrive -Connection $db -Verbose -Name "POSH Test" -TargetPath "D:\vdisks\test"

# Get-WEMVirtualDrive
$conf | Get-WEMAction -Connection $db -Verbose -Category "Virtual Drive" | Format-Table
$allVDrives = $conf | Get-WEMVirtualDrive -Connection $db -Verbose
$homeDrive = $conf | Get-WEMVirtualDrive -Connection $db -Verbose | Where-Object { $_.SetAsHomeDriveEnabled }
$driveTest = $conf | Get-WEMVirtualDrive -Connection $db -Verbose -Name "*test"

$allVDrives | Select-Object IdSite, IdAction, Name, Description

# Set-WEMVirtualDrive
$allVDrives | ForEach-Object { Set-WEMVirtualDrive -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMVirtualDrive" }
Set-WEMVirtualDrive -Connection $db -Verbose -IdAction $homeDrive.IdAction -TargetPath "D:\home\##username##"
Set-WEMVirtualDrive -Connection $db -Verbose -IdAction $driveTest.IdAction -State "Disabled"

# Remove-WEMAction (Virtual Drive)
Get-WEMVirtualDrive -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $db -Verbose -Category "Virtual Drive"

$allVDrives = $conf | Get-WEMVirtualDrive -Connection $db -Verbose

#endregion

#region WEMRegistryEntry
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMRegistryEntry
$conf | New-WEMRegistryEntry -Connection $db -Verbose -Name "POSH Registry Entry 1" -TargetPath "Citrix.WEMSDK\POSH" -TargetName "REG_SZ test" -TargetType "REG_SZ" -TargetValue "This is a string value"
$conf | New-WEMRegistryEntry -Connection $db -Verbose -Name "POSH Registry Entry 2" -TargetPath "Citrix.WEMSDK\POSH" -TargetName "REG_DWORD test" -TargetType "REG_DWORD" -TargetValue "49152"
$conf | New-WEMRegistryEntry -Connection $db -Verbose -Name "POSH Registry Entry 3" -TargetPath "Citrix.WEMSDK\POSH" -TargetName "REG_QWORD test" -TargetType "REG_QDWORD" -TargetValue "00,00,0d,00,00,00,00,00"
$conf | New-WEMRegistryEntry -Connection $db -Verbose -Name "POSH Test" -TargetPath "Citrix.WEMSDK\POSH\Test" -TargetName "Test" -TargetType "REG_SZ" -TargetValue ""

# Get-WEMRegistryEntry
$conf | Get-WEMAction -Connection $db -Verbose -Category "Registry Value" | Format-Table
$allRegistryEntries = $conf | Get-WEMRegistryEntry -Connection $db -Verbose
$registryEntryTest = $conf | Get-WEMRegistryEntry -Connection $db -Verbose -Name "*test"

$allRegistryEntries | Select-Object IdSite, IdAction, Name, Description

# Set-WEMRegistryEntry
$allRegistryEntries | ForEach-Object { Set-WEMRegistryEntry -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMRegistryEntry" }
Set-WEMRegistryEntry -Connection $db -Verbose -IdAction $registryEntryTest.IdAction -TargetName "Test updated" -TargetType "REG_EXPAND_SZ" -TargetValue "Test value" -RunOnce $false
Set-WEMRegistryEntry -Connection $db -Verbose -IdAction $registryEntryTest.IdAction -State "Disabled"

# Remove-WEMAction (Registry Entry)
Get-WEMRegistryEntry -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $db -Verbose -Category "Registry Value"

$allRegistryEntries = $conf | Get-WEMRegistryEntry -Connection $db -Verbose

#endregion

#region WEMEnvironmentVariable
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMEnvironmentVariable
$conf | New-WEMEnvironmentVariable -Connection $db -Verbose -Name "POSH Environment Variable 1" -VariableName "POSHModule" -VariableValue "Citrix.WEMSDK"
$conf | New-WEMEnvironmentVariable -Connection $db -Verbose -Name "POSH Test" -VariableName "POSHTest"
$conf | New-WEMEnvironmentVariable -Connection $db -Verbose -Name "POSH Test 2" -VariableName "POSHTest 2"

# Get-WEMEnvironmentVariable
$conf | Get-WEMAction -Connection $db -Verbose -Category "Environment Variable" | Format-Table
$allEnvironmentVariables = $conf | Get-WEMEnvironmentVariable -Connection $db -Verbose
$environmentVariableTest = $conf | Get-WEMEnvironmentVariable -Connection $db -Verbose -Name "*test"

$allEnvironmentVariables | Select-Object IdSite, IdAction, Name, Description

# Set-WEMEnvironmentVariable
$i=1 ; $allEnvironmentVariables | ForEach-Object { Set-WEMEnvironmentVariable -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMEnvironmentVariable" -ExecutionOrder $i; $i++ }
Set-WEMEnvironmentVariable -Connection $db -Verbose -IdAction $environmentVariableTest.IdAction -VariableName "POSHTested" -VariableValue "Updated"
Set-WEMEnvironmentVariable -Connection $db -Verbose -IdAction $environmentVariableTest.IdAction -State "Disabled"

# Remove-WEMAction (Environment Variable)
Get-WEMEnvironmentVariable -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test" | Remove-WEMAction -Connection $db -Verbose -Category "Environment Variable"
Get-WEMEnvironmentVariable -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test 2" | Remove-WEMEnvironmentVariable -Connection $db -Verbose

$allEnvironmentVariables = $conf | Get-WEMEnvironmentVariable -Connection $db -Verbose

#endregion

#region WEMPort
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMPort
$conf | New-WEMPort -Connection $db -Verbose -Name "POSH Port COM1:" -PortName "COM1:" -TargetPath "Unknown COM port"
$conf | New-WEMPort -Connection $db -Verbose -Name "POSH Port LPT4:" -PortName "LPT4:" -TargetPath "Unknown LPT port"
$conf | New-WEMPort -Connection $db -Verbose -Name "POSH Test 1" -PortName "COM9:" -TargetPath "\\.\COM9"
$conf | New-WEMPort -Connection $db -Verbose -Name "POSH Test 2" -PortName "LPT9:" -TargetPath "Unknown"

# Get-WEMPort
$conf | Get-WEMAction -Connection $db -Verbose -Category "Port" | Format-Table
$allPorts = $conf | Get-WEMPort -Connection $db -Verbose
$portTest = $conf | Get-WEMPort -Connection $db -Verbose -Name "*test 1"

$allPorts | Select-Object IdSite, IdAction, Name, Description

# Set-WEMPort
$allPorts | ForEach-Object { Set-WEMPort -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMPort" }
Set-WEMPort -Connection $db -Verbose -IdAction $portTest.IdAction -Name "POSH Test 1 - Update" -TargetPath "Updated"
Set-WEMPort -Connection $db -Verbose -IdAction $portTest.IdAction -State "Disabled"

# Remove-WEMAction (Environment Variable)
Get-WEMPort -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $db -Verbose -Category "Port"
Get-WEMPort -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test 2" | Remove-WEMPort -Connection $db -Verbose

$allPorts = $conf | Get-WEMPort -Connection $db -Verbose

#endregion

#region WEMIniFileOperation
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMIniFileOperation
$conf | New-WEMIniFileOperation -Connection $db -Verbose -Name "POSH Ini File Op 1" -TargetPath "C:\Windows\system.ini" -TargetSectionName "startup" -TargetValueName "init" -TargetValue "None"
$conf | New-WEMIniFileOperation -Connection $db -Verbose -Name "POSH Ini File Op 2" -TargetPath "C:\Windows\system.ini" -TargetSectionName "startup" -TargetValueName "deinit"
$conf | New-WEMIniFileOperation -Connection $db -Verbose -Name "POSH Test 1" -TargetPath "C:\Windows\system.ini" -TargetSectionName "Test" -TargetValueName "1" -TargetValue "A"
$conf | New-WEMIniFileOperation -Connection $db -Verbose -Name "POSH Test 2" -TargetPath "C:\Windows\system.ini" -TargetSectionName "Test" -TargetValueName "2" -TargetValue "B"

# Get-WEMIniFileOperation
$conf | Get-WEMAction -Connection $db -Verbose -Category "Ini File Operation" | Format-Table
$allIniFileOps = $conf | Get-WEMIniFileOperation -Connection $db -Verbose
$iniFileOpTest = $conf | Get-WEMIniFileOperation -Connection $db -Verbose -Name "*test 1"

$allIniFileOps | Select-Object IdSite, IdAction, Name, Description

# Set-WEMIniFileOperation
$allIniFileOps | ForEach-Object { Set-WEMIniFileOperation -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMIniFileOperation" }
Set-WEMIniFileOperation -Connection $db -Verbose -IdAction $iniFileOpTest.IdAction -Name "POSH Test 1 - Update" -TargetValue "Updated"
Set-WEMIniFileOperation -Connection $db -Verbose -IdAction $iniFileOpTest.IdAction -State "Disabled" -RunOnce $false

# Remove-WEMAction (Ini File Operation)
Get-WEMIniFileOperation -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $db -Verbose -Category "Ini File Operation"
Get-WEMIniFilesOp -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test 2" | Remove-WEMIniFileOperation -Connection $db -Verbose

$allIniFileOps = $conf | Get-WEMIniFileOperation -Connection $db -Verbose

#endregion

#region WEMExternalTask
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMExternalTask
$conf | New-WEMExternalTask -Connection $db -Verbose -Name "POSH External Task 1" -TargetPath "C:\Windows\SetScreensaver.exe" -TargetArguments "-Seconds 600" -RunHidden $true
$conf | New-WEMExternalTask -Connection $db -Verbose -Name "POSH External Task 2" -TargetPath "C:\Windows\Notepad.exe" -TargetArguments "'c:\temp\new file[]%.txt'" -WaitForFinish $false -TimeOut 120 -ExecuteOnlyAtLogon $true
$conf | New-WEMExternalTask -Connection $db -Verbose -Name "POSH Test 1" -TargetPath "C:\Windows\System32\explorer.exe" -TargetArguments "C:"
$conf | New-WEMExternalTask -Connection $db -Verbose -Name "POSH Test 2" -TargetPath "reg.exe"

# Get-WEMExternalTask
$conf | Get-WEMAction -Connection $db -Verbose -Category "External Task" | Format-Table
$allExternalTasks = $conf | Get-WEMExternalTask -Connection $db -Verbose
$externalTaskTest = $conf | Get-WEMExternalTask -Connection $db -Verbose -Name "*test 1"

$allExternalTasks | Select-Object IdSite, IdAction, Name, Description

# Set-WEMExternalTask
$allExternalTasks | ForEach-Object { Set-WEMExternalTask -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMExternalTask" }
Set-WEMExternalTask -Connection $db -Verbose -IdAction $externalTaskTest.IdAction -Name "POSH Test 1 - Update" -TargetPath "dir"
Set-WEMExternalTask -Connection $db -Verbose -IdAction $externalTaskTest.IdAction -State "Disabled" -RunOnce $false -ExecuteOnlyAtLogon $true -ExecutionOrder 54

# Remove-WEMAction (External Task)
Get-WEMExtTask -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $db -Verbose -Category "External Task"
Get-WEMExternalTask -Connection $db -Verbose -IdSite $conf.IdSite -Name "*test 2" | Remove-WEMExternalTask -Connection $db -Verbose

$allExternalTasks = $conf | Get-WEMExternalTask -Connection $db -Verbose

#endregion

#region WEMFileSystemOperation
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMFileSystemOperation
$conf | New-WEMFileSystemOperation -Connection $db -Verbose -Name "POSH File System Operation 1" -SourcePath "\\server\share\file.ini" -TargetPath "C:\Windows\file.ini"
$conf | New-WEMFileSystemOperation -Connection $db -Verbose -Name "POSH File System Operation 2" -SourcePath "C:\Temp" -ActionType "Create Directory"
$conf | New-WEMFileSystemOperation -Connection $db -Verbose -Name "POSH Test 1" -SourcePath "\\server\share\malware.exe" -TargetPath "C:\Windows\System32\explorer.exe" -RunOnce $false -ExecutionOrder 69
$conf | New-WEMFileSystemOperation -Connection $db -Verbose -Name "POSH Test 2" -SourcePath "\\server\share\malware.exe" -TargetPath "C:\Windows\System32\notepad.exe" -TargetOverwrite $false

# Get-WEMFileSystemOperation
$conf | Get-WEMAction -Connection $db -Verbose -Category "File System Operation" | Format-Table
$allFileSystemOps = $conf | Get-WEMFileSystemOperation -Connection $db -Verbose
$fileSystemOpsTest = $conf | Get-WEMFileSystemOp -Connection $db -Verbose -Name "*test 1"

$allFileSystemOps | Select-Object IdSite, IdAction, Name, Description

# Set-WEMFileSystemOperation
$allFileSystemOps | ForEach-Object { Set-WEMFileSystemOperation -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMFileSystemOperation" }
Set-WEMFileSystemOperation -Connection $db -Verbose -IdAction $fileSystemOpsTest.IdAction -Name "POSH Test 1 - Update" -TargetPath "C:\Windows\screensaver.exe"
Set-WEMFileSystemOperation -Connection $db -Verbose -IdAction $fileSystemOpsTest.IdAction -State "Disabled" -RunOnce $True -ExecutionOrder 666

# Remove-WEMAction (File System Operation)
Get-WEMFileSystemOperation -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $db -Verbose -Category "File System Operation"
Get-WEMFileSystemOperation -Connection $db -Verbose -IdSite $conf.IdSite -Name "*test 2" | Remove-WEMFileSystemOperation -Connection $db -Verbose

$allFileSystemOps = $conf | Get-WEMFileSystemOperation -Connection $db -Verbose

#endregion

#region WEMUserDSN
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMUserDSN
$conf | New-WEMUserDSN -Connection $db -Verbose -Name "POSH User DSN 1" -TargetName "POSH DSN 1" -TargetDriverName "SQL Server" -TargetServer "ITWSQL" -TargetDatabaseName "CitrixWEM" -RunOnce $false
$conf | New-WEMUserDSN -Connection $db -Verbose -Name "POSH User DSN 2" -TargetName "POSH DSN 2" -TargetDriverName "SQL Server" -TargetServer "ITWSQL" -TargetDatabaseName "ADFS" -RunOnce $true
$conf | New-WEMUserDSN -Connection $db -Verbose -Name "POSH Test 1" -TargetName "POSH Test" -TargetDriverName "SQL Server" -TargetServer "ITWTEMP" -TargetDatabaseName "TEMPDB" -RunOnce $true
$conf | New-WEMUserDSN -Connection $db -Verbose -Name "POSH Test 2" -TargetName "POSH Test 2" -TargetDriverName "SQL Server" -TargetServer "ITWTEMP" -TargetDatabaseName "TEMPDB" -RunOnce $true

# Get-WEMUserDSN
$conf | Get-WEMAction -Connection $db -Verbose -Category "User DSN" | Format-Table
$allUserDSNs = $conf | Get-WEMUserDSN -Connection $db -Verbose
$userDSNTest = $conf | Get-WEMUserDSN -Connection $db -Verbose -Name "*test 1"

$allUserDSNs | Select-Object IdSite, IdAction, Name, Description

# Set-WEMUserDSN
$allUserDSNs | ForEach-Object { Set-WEMUserDSN -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMUserDSN" }
Set-WEMUserDSN -Connection $db -Verbose -IdAction $userDSNTest.IdAction -Name "POSH Test 1 - Update" -TargetServer "ITWSQL" -TargetDatabaseName "TheDB" -RunOnce $false
Set-WEMUserDSN -Connection $db -Verbose -IdAction $userDSNTest.IdAction -State "Disabled"

# Remove-WEMAction (User DSN)
Get-WEMUserDSN -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $db -Verbose -Category "User DSN"
Get-WEMUserDSN -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test 2" | Remove-WEMUserDSN -Connection $db -Verbose

$allUserDSNs = $conf | Get-WEMUserDSN -Connection $db -Verbose

#endregion

#region WEMFileAssociation
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMFileAssociation
$conf | New-WEMFileAssociation -Connection $db -Verbose -Name "POSH File Association 1" -FileExtension "txt" -ProgramId "666" -Action "open" -IsDefault $true -TargetPath "c:\notepad++\notepad++.exe" -TargetCommand "%1"
$conf | New-WEMFileAssociation -Connection $db -Verbose -Name "POSH File Association 2" -FileExtension "log" -ProgramId "789" -Action "edit" -IsDefault $false -TargetPath "c:\notepad++\notepad++.exe" -TargetCommand "%1"
$conf | New-WEMFileAssociation -Connection $db -Verbose -Name "POSH Test 1" -FileExtension "nfo" -ProgramId "123" -Action "print" -TargetPath "c:\notepad++\notepad++.exe" -TargetCommand "%1"
$conf | New-WEMFileAssociation -Connection $db -Verbose -Name "POSH Test 2" -FileExtension "csv" -ProgramId "450" -Action "open" -TargetPath "c:\notepad++\notepad++.exe" -TargetCommand "%1"

# Get-WEMFileAssociation
$conf | Get-WEMAction -Connection $db -Verbose -Category "File Association" | Format-Table
$allFileAssocs = $conf | Get-WEMFileAssociation -Connection $db -Verbose
$fileAssocTest = $conf | Get-WEMFileAssoc -Connection $db -Verbose -Name "*test 1"

$allFileAssocs | Select-Object IdSite, IdAction, Name, Description

# Set-WEMFileAssociation
$allFileAssocs | ForEach-Object { Set-WEMFileAssociation -Connection $db -Verbose -IdAction $_.IdAction -Description "Set-WEMFileAssociation" }
Set-WEMFileAssociation -Connection $db -Verbose -IdAction $fileAssocTest.IdAction -Name "POSH Test 1 - Update" -Action "open" -IsDefault $true -TargetOverwrite $true -RunOnce $true 
Set-WEMFileAssoc -Connection $db -Verbose -IdAction $fileAssocTest.IdAction -State "Disabled"

# Remove-WEMAction (File Association)
Get-WEMFileAssociation -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test 1*" | Remove-WEMAction -Connection $db -Verbose -Category "File Association"
Get-WEMFileAssociation -Connection $db -Verbose -IdSite $conf.IdSite -Name "posh test 2" | Remove-WEMFileAssociation -Connection $db -Verbose

$allFileAssocs = $conf | Get-WEMFileAssociation -Connection $db -Verbose

#endregion

$allActions = $conf | Get-WEMAction -Connection $db -Verbose

#endregion

#region WEMADObject
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMADObject
# NOTE: This test requires the ActiveDirectory module to be present!
$conf | New-WEMADObject -Connection $db -Verbose -Name (Get-ADUser "amensc").SID
$conf | New-WEMADObject -Connection $db -Verbose -Name (Get-ADUser "adm_amensc").SID
$conf | New-WEMADObject -Connection $db -Verbose -Name (Get-ADGroup "Domain Users").SID
# Adding Domain Admins group as test for Remove-WEMADObject
$conf | New-WEMADObject -Connection $db -Verbose -Name (Get-ADGroup "Domain Admins").SID

# Get-WEMADObject
$conf | Get-WEMADObject -Connection $db -Verbose | Format-Table
$allADObjects = $conf | Get-WEMADObject -Connection $db -Verbose
$allADObjects | Select-Object IdSite, IdADObject, Name, Type

# Set-WEMADObject
$allADObjects | ForEach-Object { Set-WEMADObject -Connection $db -Verbose -IdADObject $_.IdADObject -Description "Set-WEMADObject" }
Set-WEMADObject -Connection $db -Verbose -IdADObject (Get-WEMADObject -Connection $db -Verbose -Name (Get-ADGroup "Domain Admins").SID).IdADObject -Name (Get-ADGroup "Enterprise Admins").SID -State "Disabled"

# Remove-WEMADObject
Remove-WEMADObject -Connection $db -Verbose -IdADObject (Get-WEMADObject -Connection $db -Verbose -Name (Get-ADGroup "Enterprise Admins").SID).IdADObject

$allADObjects = $conf | Get-WEMADObject -Connection $db -Verbose

#endregion

#region WEMCondition
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMCondition
$conf | New-WEMCondition -Connection $db -Verbose -Name "POSH Condition 1" -Type "Client OS" -TestResult "Windows 10"
$conf | New-WEMCondition -Connection $db -Verbose -Name "POSH Condition 2" -Type "Environment Variable Match" -TestValue "SystemRoot" -TestResult "C:\Windows"
$conf | New-WEMCondition -Connection $db -Verbose -Name "POSH Test 1" -Type "Active Directory Attribute Match" -TestValue "mail" -TestResult "arjan.mensch@it-worxx.nl"
$conf | New-WEMCondition -Connection $db -Verbose -Name "POSH Test 2" -Type "No Active Directory Group Match" -TestResult "Domain Admins"

# Get-WEMCondition
$conf | Get-WEMCondition -Connection $db -Verbose | Format-Table
$allConditions = $conf | Get-WEMCondition -Connection $db -Verbose
$allConditions | Select-Object IdSite, IdCondition, Name, Type, TestValue, TestResult | Format-Table

# Set-WEMCondition
$allConditions | Where-Object { $_.IdCondition -gt 1 } | ForEach-Object { Set-WEMCondition -Connection $db -Verbose -IdCondition $_.IdCondition -Description "Set-WEMCondition" }
Set-WEMCondition -Connection $db -Verbose -IdCondition (Get-WEMCondition -Connection $db -Verbose -Name "POSH Test 1").IdCondition -State "Disabled"

# Remove-WEMCondition
Remove-WEMCondition -Connection $db -Verbose -IdCondition (Get-WEMCondition -Connection $db -Verbose -Name "POSH Test 1" -IdSite $conf.IdSite).IdCondition
Get-WemCondition -Connection $db -Verbose -Name "*test 2" -IdSite $conf.IdSite | Remove-WEMCondition -Connection $db -Verbose

$allConditions = $conf | Get-WEMCondition -Connection $db -Verbose

#endregion

#region WEMRule
$conf = Get-WEMConfiguration -Connection $db -Verbose -Name "$($name)"

# New-WEMRule
$conf | New-WEMRule -Connection $db -Verbose -Name "POSH Rule 1" -Conditions (Get-WEMCondition -Connection $db -Verbose -Name "POSH Condition 1")
$conf | New-WEMRule -Connection $db -Verbose -Name "POSH Rule 2" -Conditions (Get-WEMCondition -Connection $db -Verbose -Name "POSH Condition 2")
$conf | New-WEMRule -Connection $db -Verbose -Name "POSH Rule 3" -Conditions (Get-WEMCondition -Connection $db -Verbose -Name "POSH Condition *")
$conf | New-WEMRule -Connection $db -Verbose -Name "POSH Test 1" -Conditions (Get-WEMCondition -Connection $db -Verbose -IdCondition 1)

$conf | New-WEMCondition -Connection $db -Verbose -Name "POSH Test 1" -Type "Active Directory Attribute Match" -TestValue "mail" -TestResult "arjan.mensch@it-worxx.nl"
$conf | New-WEMCondition -Connection $db -Verbose -Name "POSH Test 2" -Type "No Active Directory Group Match" -TestResult "Domain Admins"
$conf | New-WEMRule -Connection $db -Verbose -Name "POSH Test 2" -Conditions (Get-WEMCondition -Connection $db -Verbose -Name "POSH Test *")

# Get-WEMRule
$conf | Get-WEMRule -Connection $db -Verbose | Format-Table
$allRules = $conf | Get-WEMRule -Connection $db -Verbose
$testRule = $conf | Get-WEMRule -Connection $db -Verbose -Name "POSH Test 1"
$allRules | Select-Object IdSite, IdRule, Name, Conditions | Format-Table

# Set-WEMRule
$allRules | Where-Object { $_.IdRule -gt 1 } | ForEach-Object { Set-WEMRule -Connection $db -Verbose -IdRule $_.IdRule -Description "Set-WEMRule" }
$conditionArray = $testRule.Conditions
$conditionArray += Get-WEMCondition -Connection $db -IdSite $conf.IdSite -Name "POSH Condition *" 
Set-WEMRule -Connection $db -Verbose -IdRule $testRule.IdRule -State "Disabled" -Conditions $conditionArray
$conditionArray = $conditionArray | Where-Object { $_.Name -notlike "POSH Condition 1" }
Set-WEMRule -Connection $db -Verbose -IdRule $testRule.IdRule -Conditions $conditionArray

# Remove-WEMRule
Remove-WEMRule -Connection $db -Verbose -IdRule $testRule.IdRule
Remove-WEMCondition -Connection $db -Verbose -IdCondition (Get-WEMCondition -Connection $db -Name "POSH Test 1").IdCondition
Remove-WEMCondition -Connection $db -Verbose -IdCondition (Get-WEMCondition -Connection $db -Name "POSH Test 2").IdCondition

$allRules = $conf | Get-WEMRule -Connection $db -Verbose

#endregion

#region WEMActionGroup
$conf = Get-WEMConfiguration -Connection $db -Name "$($name)" -Verbose

# New-WEMActionGroup
$conf | New-WEMActionGroup -Connection $db -Verbose -Name "POSH Action Group 1"
$conf | New-WEMActionGroup -Connection $db -Verbose -Name "POSH Action Group 2"
$conf | New-WEMActionGroup -Connection $db -Verbose -Name "POSH Test 1"

# Get-WEMActionGroup
$conf | Get-WEMActionGroup -Connection $db -Verbose | Format-Table
$allActionGroups = $conf | Get-WEMActionGroup -Connection $db -Verbose
$testActionGroup = $conf | Get-WEMActionGroup -Connection $db -Verbose -Name "POSH Test 1"
$allActionGroups | Format-Table

# Set-WEMActionGroup
$allActionGroups | ForEach-Object { Set-WEMActionGroup -Connection $db -Verbose -IdActionGroup $_.IdActionGroup -Description "Set-WEMActionGroup" }

$actionGroupId = (Get-WEMActionGroup -Connection $db -IdSite $conf.IdSite -Name "POSH Action Group 1").IdActionGroup
$allApps | ForEach-Object { Set-WEMActionGroup -Connection $db -Verbose -IdActionGroup $actionGroupId -AddApplication $_ -AssignmentProperties "CreateStartMenuLink", "PinToStartMenu" }
$allPrinters | ForEach-Object { Set-WEMActionGroup -Connection $db -Verbose -IdActionGroup $actionGroupId -AddPrinter $_ }
Set-WEMActionGroup -Connection $db -Verbose -IdActionGroup $actionGroupId -AddNetworkDrive $allDrives[0] -DriveLetter H
Set-WEMActionGroup -Connection $db -Verbose -IdActionGroup $testActionGroup.IdActionGroup -AddNetworkDrive $allDrives[0] -DriveLetter H

# Remove-WEMActionGroup
Remove-WEMActionGroup -Connection $db -Verbose -IdActionGroup $testActionGroup.IdActionGroup

$allActionGroups = $conf | Get-WEMActionGroup -Connection $db -Verbose

#endregion

#region WEMAssignments

#region WEMApplicationAssignments
$conf = Get-WEMConfiguration -Connection $db -Name "$($name)" -Verbose

# New-WEMApplicationAssignment
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-1299").IdADObject
$rule = (Get-WEMRule -Connection $db -Name "POSH Rule 1").IdRule
$allApps[0] | New-WEMApplicationAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule
$allApps[1] | New-WEMApplicationAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule -AssignmentProperties "CreateDesktopLink","AutoStart","PinToStartMenu"
$allApps[2..3] | New-WEMApplicationAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule

# Get-WEMApplicationAssignment
$conf | Get-WEMApplicationAssignment -Connection $db -Verbose | Format-Table
$allAppAssignments = $conf | Get-WEMAssignment -Connection $db -Verbose -AssignmentType "Application"
$allAppAssignments | Format-Table

# Set-WEMApplicationAssignment
$rule = (Get-WEMRule -Connection $db -Name "Always True").IdRule
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-513").IdADObject
$allAppAssignments | Set-WEMApplicationAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule
$allAppAssignments | Set-WEMApplicationAssignment -Connection $db -Verbose -AssignmentProperties "CreateStartMenuLink", "PinToStartMenu"

# Remove-WEMApplicationAssignment
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-1299").IdADObject
$rule = (Get-WEMRule -Connection $db -Name "POSH Rule 1").IdRule
$testAssignment = $allApps[0] | New-WEMApplicationAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule
$testAssignment | Remove-WEMApplicationAssignment -Connection $db -Verbose

$allAppAssignments = $conf | Get-WEMAssignment -Connection $db -Verbose -AssignmentType "Application"

#endregion

#region WEMPrinterAssignments
$conf = Get-WEMConfiguration -Connection $db -Name "$($name)" -Verbose

# New-WEMPrinterAssignment
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-1299").IdADObject
$rule = (Get-WEMRule -Connection $db -Name "POSH Rule 1").IdRule
$allPrinters[0] | New-WEMPrinterAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule
$allPrinters[1] | New-WEMPrinterAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule -SetAsDefault $true

# Get-WEMPrinterAssignment
$conf | Get-WEMPrinterAssignment -Connection $db -Verbose | Format-Table
$allPrinterAssignments = $conf | Get-WEMAssignment -Connection $db -Verbose -AssignmentType "Printer"
$allPrinterAssignments | Format-Table

# Set-WEMPrinterAssignment
$rule = (Get-WEMRule -Connection $db -Name "Always True").IdRule
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-513").IdADObject
$allPrinterAssignments | Set-WEMPrinterAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule
$allPrinterAssignments | Set-WEMPrinterAssignment -Connection $db -Verbose -SetAsDefault $false

# Remove-WEMPrinterAssignment
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-1299").IdADObject
$rule = (Get-WEMRule -Connection $db -Name "POSH Rule 1").IdRule
$testAssignment = $allPrinters[0] | New-WEMPrinterAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule
$testAssignment | Remove-WEMPrinterAssignment -Connection $db -Verbose

$allPrinterAssignments = $conf | Get-WEMAssignment -Connection $db -Verbose -AssignmentType "Printer"

#endregion

#region WEMNetworkDrivesAssignments
$conf = Get-WEMConfiguration -Connection $db -Name "$($name)" -Verbose

# New-WEMNetworkDriveAssignment
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-1299").IdADObject
$rule = (Get-WEMRule -Connection $db -Name "POSH Rule 1").IdRule
$allDrives[0] | New-WEMNetworkDriveAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule -DriveLetter "E"
$allDrives[1] | New-WEMNetworkDriveAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule -DriveLetter "F"
$allDrives[2] | New-WEMNetworkDriveAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule -DriveLetter "H"

# Get-WEMNetworkDriveAssignment
$conf | Get-WEMNetworkDriveAssignment -Connection $db -Verbose | Format-Table
$allDriveAssignments = $conf | Get-WEMAssignment -Connection $db -Verbose -AssignmentType "Network Drive"
$allDriveAssignments | Format-Table

# Set-WEMNetworkDriveAssignment
$rule = (Get-WEMRule -Connection $db -Name "Always True").IdRule
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-513").IdADObject
$allDriveAssignments | Set-WEMNetworkDriveAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule
$allDriveAssignments[0] | Set-WEMNetworkDriveAssignment -Connection $db -Verbose -DriveLetter "G"
$allDriveAssignments[1] | Set-WEMNetworkDriveAssignment -Connection $db -Verbose -DriveLetter "J"

# Remove-WEMNetworkDriveAssignment
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-1299").IdADObject
$rule = (Get-WEMRule -Connection $db -Name "POSH Rule 1").IdRule
$testAssignment = $allDrives[0] | New-WEMNetworkDriveAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule -DriveLetter "G"
$testAssignment | Remove-WEMNetworkDriveAssignment -Connection $db -Verbose

$allDriveAssignments = $conf | Get-WEMAssignment -Connection $db -Verbose -AssignmentType "Network Drive"

#endregion

#region WEMVirtualDrivesAssignments
$conf = Get-WEMConfiguration -Connection $db -Name "$($name)" -Verbose

# New-WEMVirtualDriveAssignment
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-1299").IdADObject
$rule = (Get-WEMRule -Connection $db -Name "POSH Rule 1").IdRule
$allVDrives[0] | New-WEMVirtualDriveAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule -DriveLetter "E"
$allVDrives[1] | New-WEMVirtualDriveAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule -DriveLetter "F"
$allVDrives[2] | New-WEMvirtualDriveAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule -DriveLetter "K"

# Get-WEMVirtualDriveAssignment
$conf | Get-WEMNetworkDriveAssignment -Connection $db -Verbose | Format-Table
$allVDriveAssignments = $conf | Get-WEMAssignment -Connection $db -Verbose -AssignmentType "Virtual Drive"
$allVDriveAssignments | Format-Table

# Set-WEMVirtualDriveAssignment
$rule = (Get-WEMRule -Connection $db -Name "Always True").IdRule
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-513").IdADObject
$allVDriveAssignments | Set-WEMVirtualDriveAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule
$allVDriveAssignments[0] | Set-WEMVirtualDriveAssignment -Connection $db -Verbose -DriveLetter "L"
$allVDriveAssignments[1] | Set-WEMVirtualDriveAssignment -Connection $db -Verbose -DriveLetter "M"

# Remove-WEMVirtualDriveAssignment
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-1299").IdADObject
$rule = (Get-WEMRule -Connection $db -Name "POSH Rule 1").IdRule
$testAssignment = $allVDrives[0] | New-WEMVirtualDriveAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule -DriveLetter "E"
$testAssignment | Remove-WEMVirtualDriveAssignment -Connection $db -Verbose

$allVDriveAssignments = $conf | Get-WEMAssignment -Connection $db -Verbose -AssignmentType "Virtual Drive"

#endregion

#region WEMRegistryEntryAssignments
$conf = Get-WEMConfiguration -Connection $db -Name "$($name)" -Verbose

# New-WEMRegistryEntryAssignment
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-1299").IdADObject
$rule = (Get-WEMRule -Connection $db -Name "POSH Rule 1").IdRule
$allRegistryEntries | New-WEMRegistryEntryAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule

# Get-WEMRegistryEntryAssignment
$conf | Get-WEMRegistryEntryAssignment -Connection $db -Verbose | Format-Table
$allRegValueAssignments = $conf | Get-WEMAssignment -Connection $db -Verbose -AssignmentType "Registry Value"
$allRegValueAssignments | Format-Table

# Set-WEMRegistryEntryAssignment
$rule = (Get-WEMRule -Connection $db -Name "Always True").IdRule
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-513").IdADObject
$allRegValueAssignments | Set-WEMRegistryEntryAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule

# Remove-WEMRegistryEntryAssignment
$adobject = (Get-WEMADObject -Connection $db -Name "S-1-5-21-1644858761-3736240991-3467507639-1299").IdADObject
$rule = (Get-WEMRule -Connection $db -Name "POSH Rule 1").IdRule
$testAssignment = $allRegistryEntries[0] | New-WEMRegistryEntryAssignment -Connection $db -Verbose -IdADObject $adobject -IdRule $rule
$testAssignment | Remove-WEMRegistryEntryAssignment -Connection $db -Verbose

$allRegValueAssignments = $conf | Get-WEMAssignment -Connection $db -Verbose -AssignmentType "Virtual Drive"

#endregion

$allAssignments = $conf | Get-WEMAssignment -Connection $db -Verbose

#endregion

$allActions | Select-Object IdAction, IdSite, Category, Name, DisplayName, Description, State, Type, ActionType | Format-Table

$allADObjects | Where-Object { $_.Type -notlike "BUILTIN" } | Select-Object IdADObject, IdSite, Name, Description, State, Type, Priority | Format-Table

$allConditions | Select-Object IdSite, IdCondition, Name, Type, TestValue, TestResult | Format-Table

$allRules | Select-Object IdSite, IdRule, Name, Conditions | Format-Table

$allActionGroups | Format-Table

$allAssignments | Format-Table

# Cleanup
$db.Dispose()
