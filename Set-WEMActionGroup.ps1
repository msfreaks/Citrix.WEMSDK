<#
    .Synopsis
    Updates a WEM Action Group object in the WEM Database.

    .Description
    Updates a WEM Action Group object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdActionGroup
    ..

    .Parameter Name
    ..

    .Parameter Description
    ..

    .Parameter State
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMActionGroup {
    [CmdletBinding(DefaultParameterSetName="None")]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdActionGroup,

        [Parameter(Mandatory=$False)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State,
        [Parameter(Mandatory=$True,ParameterSetName="AddApplication")]
        [pscustomobject]$AddApplication,
        [Parameter(Mandatory=$True,ParameterSetName="AddPrinter")]
        [pscustomobject]$AddPrinter,
        [Parameter(Mandatory=$True,ParameterSetName="AddNetworkDrive")]
        [pscustomobject]$AddNetworkDrive,
        [Parameter(Mandatory=$True,ParameterSetName="AddVirtualDrive")]
        [pscustomobject]$AddVirtualDrive,
        [Parameter(Mandatory=$True,ParameterSetName="AddRegistryValue")]
        [pscustomobject]$AddRegistryValue,
        [Parameter(Mandatory=$True,ParameterSetName="AddEnvironmentVariable")]
        [pscustomobject]$AddEnvironmentVariable,
        [Parameter(Mandatory=$True,ParameterSetName="AddPort")]
        [pscustomobject]$AddPort,
        [Parameter(Mandatory=$True,ParameterSetName="AddIniFileOperation")]
        [pscustomobject]$AddIniFileOperation,
        [Parameter(Mandatory=$True,ParameterSetName="AddExternalTask")]
        [pscustomobject]$AddExternalTask,
        [Parameter(Mandatory=$True,ParameterSetName="AddFileSystemOperation")]
        [pscustomobject]$AddFileSystemOperation,
        [Parameter(Mandatory=$True,ParameterSetName="AddUserDSN")]
        [pscustomobject]$AddUserDSN,
        [Parameter(Mandatory=$True,ParameterSetName="AddFileAssociation")]
        [pscustomobject]$AddFileAssociation,
        [Parameter(Mandatory=$True,ParameterSetName="RemoveApplication")]
        [pscustomobject]$RemoveApplication,
        [Parameter(Mandatory=$True,ParameterSetName="RemovePrinter")]
        [pscustomobject]$RemovePrinter,
        [Parameter(Mandatory=$True,ParameterSetName="RemoveNetworkDrive")]
        [pscustomobject]$RemoveNetworkDrive,
        [Parameter(Mandatory=$True,ParameterSetName="RemoveVirtualDrive")]
        [pscustomobject]$RemoveVirtualDrive,
        [Parameter(Mandatory=$True,ParameterSetName="RemoveRegistryValue")]
        [pscustomobject]$RemoveRegistryValue,
        [Parameter(Mandatory=$True,ParameterSetName="RemoveEnvironmentVariable")]
        [pscustomobject]$RemoveEnvironmentVariable,
        [Parameter(Mandatory=$True,ParameterSetName="RemovePort")]
        [pscustomobject]$RemovePort,
        [Parameter(Mandatory=$True,ParameterSetName="RemoveIniFileOperation")]
        [pscustomobject]$RemoveIniFileOperation,
        [Parameter(Mandatory=$True,ParameterSetName="RemoveExternalTask")]
        [pscustomobject]$RemoveExternalTask,
        [Parameter(Mandatory=$True,ParameterSetName="RemoveFileSystemOperation")]
        [pscustomobject]$RemoveFileSystemOperation,
        [Parameter(Mandatory=$True,ParameterSetName="RemoveUserDSN")]
        [pscustomobject]$RemoveUserDSN,
        [Parameter(Mandatory=$True,ParameterSetName="RemoveFileAssociation")]
        [pscustomobject]$RemoveFileAssociation,
        [Parameter(Mandatory=$True,ParameterSetName="AddApplication")][ValidateSet("CreateDesktopLink","CreateQuickLaunchLink","CreateStartMenuLink","PinToTaskbar","PinToStartMenu","AutoStart")]
        [string[]]$AssignmentProperties,
        [Parameter(Mandatory=$False,ParameterSetName="AddPrinter")]
        [bool]$SetAsDefault = $false,
        [Parameter(Mandatory=$True,ParameterSetName="AddNetworkDrive")][ValidatePattern('^[a-zA-Z]+$')][ValidateLength(1,1)]
        [Parameter(Mandatory=$True,ParameterSetName="AddVirtualDrive")][ValidatePattern('^[a-zA-Z]+$')][ValidateLength(1,1)]
        [string]$DriveLetter,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origObject = Get-WEMActionGroup -Connection $Connection -IdActionGroup $IdActionGroup

        # only continue if the object was found
        if (-not $origObject) { 
            Write-Warning "No Action Group object found for Id $($IdActionGroup)"
            Break
        }
        
        # if a new name for the object is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name.Replace("'", "''") -notlike $origObject.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMActionsGroups WHERE Name LIKE '$($Name.Replace("'", "''"))' AND IdSite = $($origObject.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.ObjectCount) {
                # name must be unique
                Write-Error "There's already an Action Group object named '$($Name.Replace("'", "''"))' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"
        }

        # process customobjects if any were entered
        $parameterObject = $null
        $updateActions = $false

        switch ($PSCmdlet.ParameterSetName) {
            { $_ -like "*Application" } {
                if(($AddApplication -and $AddApplication.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.Application") -or ($RemoveApplication -and $RemoveApplication.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.Application")) {
                    Write-Error "Object passed is not a valid Application object"
                    break
                }

                Write-Verbose "Valid Application object found"
                if ($AddApplication) { $parameterObject = $AddApplication }
                if ($RemoveApplication) { $parameterObject = $RemoveApplication }

            }
            { $_ -like "*Printer" } {
                if(($AddPrinter -and $AddPrinter.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.Printer") -or ($RemovePrinter -and $RemovePrinter.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.Printer")) {
                    Write-Error "Object passed is not a valid Printer object"
                    break
                }

                Write-Verbose "Valid Printer object found"
                if ($AddPrinter) { $parameterObject = $AddPrinter }
                if ($RemovePrinter) { $parameterObject = $RemovePrinter }
            }
            { $_ -like "*NetworkDrive" } {
                if(($AddNetworkDrive -and $AddNetworkDrive.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.NetworkDrive") -or ($RemoveNetworkDrive -and $RemoveNetworkDrive.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.NetworkDrive")) {
                    Write-Error "Object passed is not a valid NetworkDrive object"
                    break
                }

                Write-Verbose "Valid NetworkDrive object found"
                if ($AddNetworkDrive) { $parameterObject = $AddNetworkDrive }
                if ($RemoveNetworkDrive) { $parameterObject = $RemoveNetworkDrive }
            }
            { $_ -like "*VirtualDrive" } {
                if(($AddVirtualDrive -and $AddVirtualDrive.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.VirtualDrive") -or ($RemoveVirtualDrive -and $RemoveVirtualDrive.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.VirtualDrive")) {
                    Write-Error "Object passed is not a valid VirtualDrive object"
                    break
                }

                Write-Verbose "Valid VirtualDrive object found"
                if ($AddVirtualDrive) { $parameterObject = $AddVirtualDrive }
                if ($RemoveVirtualDrive) { $parameterObject = $RemoveVirtualDrive }
            }
            { $_ -like "*RegistryValue" } {
                if(($AddRegistryValue -and $AddRegistryValue.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.RegistryValue") -or ($RemoveRegistryValue -and $RemoveRegistryValue.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.RegistryValue")) {
                    Write-Error "Object passed is not a valid RegistryValue object"
                    break
                }

                Write-Verbose "Valid RegistryValue object found"
                if ($AddRegistryValue) { $parameterObject = $AddRegistryValue }
                if ($RemoveRegistryValue) { $parameterObject = $RemoveRegistryValue }
            }
            { $_ -like "*EnvironmentVariable" } {
                if(($AddEnvironmentVariable -and $AddEnvironmentVariable.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.EnvironmentVariable") -or ($RemoveEnvironmentVariable -and $RemoveEnvironmentVariable.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.EnvironmentVariable")) {
                    Write-Error "Object passed is not a valid EnvironmentVariable object"
                    break
                }

                Write-Verbose "Valid EnvironmentVariable object found"
                if ($AddEnvironmentVariable) { $parameterObject = $AddEnvironmentVariable }
                if ($RemoveEnvironmentVariable) { $parameterObject = $RemoveEnvironmentVariable }
            }
            { $_ -like "*Port" } {
                if(($AddPort -and $AddPort.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.Port") -or ($RemovePort -and $RemovePort.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.Port")) {
                    Write-Error "Object passed is not a valid Port object"
                    break
                }

                Write-Verbose "Valid Port object found"
                if ($AddPort) { $parameterObject = $AddPort }
                if ($RemovePort) { $parameterObject = $RemovePort }
            }
            { $_ -like "*IniFileOperation" } {
                if(($AddIniFileOperation -and $AddIniFileOperation.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.IniFileOperation") -or ($RemoveIniFileOperation -and $RemoveIniFileOperation.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.IniFileOperation")) {
                    Write-Error "Object passed is not a valid IniFileOperation object"
                    break
                }

                Write-Verbose "Valid IniFileOperation object found"
                if ($AddIniFileOperation) { $parameterObject = $AddIniFileOperation }
                if ($RemoveIniFileOperation) { $parameterObject = $RemoveIniFileOperation }
            }
            { $_ -like "*ExternalTask" } {
                if(($AddExternalTask -and $AddExternalTask.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.ExternalTask") -or ($RemoveExternalTask -and $RemoveExternalTask.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.ExternalTask")) {
                    Write-Error "Object passed is not a valid ExternalTask object"
                    break
                }

                Write-Verbose "Valid ExternalTask object found"
                if ($AddExternalTask) { $parameterObject = $AddExternalTask }
                if ($RemoveExternalTask) { $parameterObject = $RemoveExternalTask }
            }
            { $_ -like "*FileSystemOperation" } {
                if(($AddFileSystemOperation -and $AddFileSystemOperation.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.FileSystemOperation") -or ($RemoveFileSystemOperation -and $RemoveFileSystemOperation.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.FileSystemOperation")) {
                    Write-Error "Object passed is not a valid FileSystemOperation object"
                    break
                }

                Write-Verbose "Valid FileSystemOperation object found"
                if ($AddFileSystemOperation) { $parameterObject = $AddFileSystemOperation }
                if ($RemoveFileSystemOperation) { $parameterObject = $RemoveFileSystemOperation }
            }
            { $_ -like "*UserDSN" } {
                if(($AddUserDSN -and $AddUserDSN.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.UserDSN") -or ($RemoveUserDSN -and $RemoveUserDSN.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.UserDSN")) {
                    Write-Error "Object passed is not a valid UserDSN object"
                    break
                }

                Write-Verbose "Valid UserDSN object found"
                if ($AddUserDSN) { $parameterObject = $AddUserDSN }
                if ($RemoveUserDSN) { $parameterObject = $RemoveUserDSN }
            }
            { $_ -like "*FileAssociation" } {
                if(($AddFileAssociation -and $AddFileAssociation.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.FileAssociation") -or ($RemoveFileAssociation -and $RemoveFileAssociation.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.FileAssociation")) {
                    Write-Error "Object passed is not a valid FileAssociation object"
                    break
                }

                Write-Verbose "Valid FileAssociation object found"
                if ($AddFileSystemOperation) { $parameterObject = $AddFileSystemOperation }
                if ($RemoveFileSystemOperation) { $parameterObject = $RemoveFileSystemOperation }
            }
            { $_ -like "Add*" } {
                Write-Verbose "Add Action detected"

                $properties = "0"
                if ($parameterObject.PSObject.TypeNames[0] -eq "Citrix.WEMSDK.Application") {
                    # calculate assignmentproperties
                    $bits = 0
                    $AssignmentProperties | ForEach-Object { $bits += $assignmentPropertiesEnum.Get_Item($_) }
                    $properties = [string]$bits
                }
                if ($parameterObject.PSObject.TypeNames[0] -eq "Citrix.WEMSDK.Printer") {
                    # assignmentproperties
                    $properties = [string][int]$SetAsDefault
                }
                if ($parameterObject.PSObject.TypeNames[0] -eq "Citrix.WEMSDK.NetworkDrive" -or $parameterObject.PSObject.TypeNames[0] -eq "Citrix.WEMSDK.VirtualDrive") {
                    # assignmentproperties
                    $properties = $DriveLetter.ToUpper()

                    # grab configuration properties
                    $SQLQuery = "SELECT Value AS Exclusions FROM VUEMParameters WHERE IdSite = $($origObject.IdSite) AND Name = 'excludedDriveletters'"
                    $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                    $excludedDriveletters = $result.Tables.Rows.Exclusions
                    Write-Verbose "Found excluded driveletters: $($excludedDriveletters)"

                    $SQLQuery = "SELECT Value AS AllowReuse FROM VUEMParameters WHERE IdSite = $($origObject.IdSite) AND Name = 'AllowDriveLetterReuse'"
                    $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                    $allowDriveletterReuse = [bool][int]$result.Tables.Rows.AllowReuse
                    Write-Verbose "Found Driveletter Re-use setting: $([string]$allowDriveletterReuse)"

                    # DriveLetter must not be excluded in the Configuration
                    if (($excludedDriveLetters -split ";") -contains $properties) {
                        # DriveLetter must not be Excluded
                        Write-Error "DriveLetter '$($properties)' is excluded in the Configuration (Exclusions: $($excludedDriveLetters.Replace(";",", ")))"
                        Break
                    }

                    # drivemapping detected, in Action Group, DriveLetter must be unique if re-use is $false
                    if (-not $allowDriveletterReuse) {
                        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMActionGroupsTemplates WHERE IdActionGroup = $($IdActionGroup) AND (ActionType = $($tableVUEMActionType["Network Drive"]) OR ActionType = $($tableVUEMActionType["Virtual Drive"])) AND Properties = '$($properties)' AND IdAction <> $($parameterObject.IdAction)"
                        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                        if ($result.Tables.Rows.ObjectCount) {
                            # DriveLetter must be unique
                            Write-Error "There's already a Drive object using DriveLetter '$($properties)' in the Action Group"
                            Break
                        }
                    }
                }

                # check if the Action already exists in the Action Group
                $queryAction = ""
                $SQLQuery = "SELECT * FROM VUEMActionGroupsTemplates WHERE IdActionGroup = $($IdActionGroup) AND ActionType = $($tableVUEMActionType[$parameterObject.Category]) AND IdAction = $($parameterObject.IdAction)"
                $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                if ($result.Tables.Rows -and $result.Tables.Rows.Id -and $result.Tables.Rows.Properties -ne $properties) {
                    # Action already in the Action Group, Properties are changed: Create Update Query
                    Write-Verbose "Action already in the Action Group, Properties are changed: Create Update Query"

                    $queryAction = "Update"
                    $SQLQuery = "UPDATE VUEMActionGroupsTemplates SET Properties = '$($properties)', RevisionId = $($result.Tables.Rows.RevisionId + 1) WHERE Id = $($result.Tables.Rows.Id)"
                } elseif (-not $result.Tables.Rows.Id) {
                    # Action is not in the Action Group: Create Insert Query
                    Write-Verbose "Action is not in the Action Group: Create Insert Query"

                    $queryAction = "Create"
                    $SQLQuery = "INSERT INTO VUEMActionGroupsTemplates (IdActionGroup,ActionType,IdAction,Properties,RevisionId,Reserved01) VALUES ($($IdActionGroup),$($tableVUEMActionType[$parameterObject.Category]),$($parameterObject.IdAction),'$($properties)',1,NULL)"
                } else {
                    # Action in the Action Group, and nothing was changed
                    Write-Verbose "Action is already in the Action Group, no changes requested: skip Query actions for this Action"
                }

                # execute the query if one was created
                if ($queryAction) {
                    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

                    # tell logic we changed the database
                    $updateActions = $true
                }
                
                continue
            }
            { $_ -like "Remove*" } {
                Write-Verbose "Remove Action detected"

                # check if this Action is in the Action Group
                $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMActionGroupsTemplates WHERE IdActionGroup = $($IdActionGroup) AND ActionType = $($tableVUEMActionType[$parameterObject.Category]) AND IdAction = $($parameterObject.IdAction)"
                $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                if (-not $result.Tables.Rows.ObjectCount) {
                    Write-Verbose "Action not found in this Action Group"
                } else {
                    # Action found in Action Group, Create and execute a Delete query
                    $SQLQuery = "DELETE FROM VUEMActionGroupsTemplates WHERE IdActionGroup = $($IdActionGroup) AND ActionType = $($tableVUEMActionType[$parameterObject.Category]) AND IdAction = $($parameterObject.IdAction)"
                    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

                    # tell logic we changed the database
                    $updateActions = $true
                }

                continue
            }
            Default {}
        }

        # build the query to update the object
        $updateFields = @()
        $SQLQuery = "UPDATE VUEMActionGroups SET "
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "idactiongroup" }
        foreach ($key in $keys) {
            switch ($key) {
                "Name" {
                    $updateFields += "Name = '$($Name.Replace("'", "''"))'"
                    continue
                }
                "Description" {
                    $updateFields += "Description = '$($Description.Replace("'", "''"))'"
                    continue
                }
                "State" {
                    $updateFields += "State = $($tableVUEMState["$State"])"
                    continue
                }
                Default {}
            }
        }

        # if anything needs to be updated, update the object
        if($updateFields -or $updateActions) {
            if ($updateFields) {
                $SQLQuery += "{0}, " -f ($updateFields -join ", ")
                $SQLQuery += "RevisionId = $($origObject.Version + 1) WHERE IdActionGroup = $($IdActionGroup)"
                $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
            }

            # Updating the ChangeLog
            $objectName = $origObject.Name
            if ($Name) { $objectName = $Name.Replace("'", "''") }
            
            New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdActionGroup -ChangeType "Update" -ObjectName $objectName -ObjectType "Actions\Action Groups" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}