
#region Module Global Functions
<#
    .Synopsis
    Executes an SQL statement.

    .Description
    Executes an SQL statement.

    .Link
    https://msfreaks.wordpress.com

    .Parameter Connection
    ..

    .Parameter Query
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Invoke-SQL {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$Query
    )
    Write-Verbose "Using SQLQuery: $($Query)"

    $QueryType = $Query.SubString(0,$Query.IndexOf(" "))
    Write-Verbose "Query type: $($QueryType)"
    
    $returnDataset = $false

    try {
        $Connection.Open()

        $Command = New-Object "System.Data.SqlClient.SqlCommand" $Query, $Connection
        $Adapter = New-Object "System.Data.SqlClient.SQLDataAdapter" $Command
        $Dataset = New-Object "System.Data.DataSet"

        switch ($QueryType) {
            Default { continue }
            "SELECT" {
                $null = $Adapter.Fill($Dataset)
                $returnDataset = $true

                Write-Verbose "Returning Dataset"
                continue
            }
            "DELETE" {
                $rowsAffected = $Command.ExecuteNonQuery()

                Write-Verbose "Deleted"
                continue
            }
            "INSERT" {
                $rowsAffected = $Command.ExecuteNonQuery()

                Write-Verbose "Inserted"
                continue
            }
            "UPDATE" {
                $rowsAffected = $Command.ExecuteNonQuery()

                Write-Verbose "Updated"
                continue
            }
        }

        $Command.Dispose()
        $Adapter.Dispose()

        $Connection.Close()
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        $ErrorMessage
        $FailedItem

        $Connection.Close()

        Break
    }

    if ($returnDataset) { return $Dataset }
}

<#
    Helper function to Escape strings before using them in a query
#>
function ConvertTo-StringEscaped {
    param (
        [string]$UnEscapedString
    )

    if ($UnEscapedString) { $UnEscapedString  = $UnEscapedString.Replace("'", "''") }

    return $UnEscapedString
}

<#
    Helper function for grabbing IconStream data
#>
function Get-IconStream {
    param (
        [string]$IconLocation
    )

    # pre-load System.Drawing namespace
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

    try {
        $stream = New-Object System.IO.MemoryStream
        $bmp = [System.Drawing.Icon]::ExtractAssociatedIcon("$($IconLocation)").ToBitmap()
        $bmp.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)

        return ([System.Convert]::ToBase64String($stream.ToArray()))
    }
    catch { 
        return $script:defaultIconStream
    }
}

<#
    .Synopsis
    Creates an entry in the VUEMChangesLog table.

    .Description
    Creates an entry in the VUEMChangesLog table.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdElement
    ..

    .Parameter UserId
    ..

    .Parameter ChangeType
    ..

    .Parameter ObjectName
    ..

    .Parameter ObjectType
    ..

    .Parameter NewValue
    ..

    .Parameter ChangeDescription
    ..

    .Parameter Reserved01
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-ChangesLogEntry {
    param(
        [int]$IdSite,
        [int]$IdElement,
        [string]$UserId,
        [string]$ChangeType,
        [string]$ObjectName,
        [string]$ObjectType,
        [string]$NewValue,
        [string]$ChangeDescription,
        [string]$Reserved01,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    if (-not $UserId) { $UserId = "[Citrix.WEMSDK] $($env:USERDOMAIN)\$($env:USERNAME)"}

    $SQLQuery = "INSERT INTO VUEMChangesLog (IdSite,IdElement,UserId,ChangeType,ObjectName,ObjectType,ChangeDate,NewValue,ChangeDescription,Reserved01) VALUES ($($IdSite),$($IdElement),'$($UserId)','$($ChangeType)','$($ObjectName)','$($ObjectType)','$(Get-Date)','$($NewValue)',"
    if ($ChangeDescription) { 
        $SQLQuery += "'$($ChangeDescription)',"
    } else { 
        $SQLQuery += "NULL,"
    }
    if ($Reserved01) { 
        $SQLQuery += "'$($Reserved01)')"
    } else { 
        $SQLQuery += "NULL)"
    }

    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
}

<#
    .Synopsis
    Converts SQL Data to a Site object

    .Description
    Converts SQL Data to a Site object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMSiteObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Site object '$($DataRow.Name)'"

    $vuemObject = [pscustomobject] @{
        'IdSite'      = [int]$DataRow.IdSite
        'Name'        = [string]$DataRow.Name
        'Description' = [string]$DataRow.Description
        'State'       = [string]$tableVUEMState[$DataRow.State]
        'Version'     = [int]$DataRow.RevisionId
    } 
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.Configuration")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to an Action Group object

    .Description
    Converts SQL Data to an Action Group object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMActionGroupObject() {
    param(
        [System.Data.DataRow]$DataRow,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    Write-Verbose "Found Action Group object '$($DataRow.Name)'"

    # grab Actions belonging to this Action Group
    $actionGroupActions = @()
    $SQLQuery = "SELECT * FROM VUEMActionGroupsTemplates WHERE IdActionGroup = $($DataRow.IdActionGroup)"
    $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

    foreach($row in $result.Tables.Rows) {
        Write-Verbose "Grabbing Action $($row.IdAction) in category '$($ActionCategories[$row.ActionType])'"
        $vuemAction = Get-WEMAction -Connection $Connection -IdAction $row.IdAction -Category $ActionCategories[$row.ActionType]

        switch ($row.ActionType) {
            0 {
                # Application
                Write-Verbose "Processing Application properties ($([int]$row.Properties))"
                $bits = [int]$row.Properties
                if ($bits) {
                    $vuemAction | Add-Member -NotePropertyName "AssignmentProperties" -NotePropertyValue ($assignmentPropertiesEnum.Keys | Where-Object { ($_).GetType().Name -like "Int32" -and $_ -band $bits } | ForEach-Object { $assignmentPropertiesEnum.Get_Item($_) })
                }

                continue
              }
            1 {
                # Printer
                Write-Verbose "Processing Printer properties"
                if ($row.Properties -eq "1") { 
                    Add-Member -InputObject $vuemAction -NotePropertyName "AssignmentProperties" -NotePropertyValue "SetAsDefault"
                }

                continue
            }
            2 {
                # NetDrive
                Write-Verbose "Processing Drive properties"
                Add-Member -InputObject $vuemAction -NotePropertyName "AssignmentProperties" -NotePropertyValue "DriveLetter: $($row.Properties)"

                continue
            }
            3 {
                # VirtualDrive
                Write-Verbose "Processing Drive properties"
                Add-Member -InputObject $vuemAction -NotePropertyName "AssignmentProperties" -NotePropertyValue "DriveLetter: $($row.Properties)"

                continue
            }
            Default {}
        }

        # add the resulting object to the array
        $actionGroupActions += $vuemAction
    }

    Write-Verbose "Actions processed: $($actionGroupActions.Count)"

    $vuemObject = [pscustomobject] @{
        'IdActionGroup' = [int]$DataRow.IdActionGroup
        'IdSite'        = [int]$DataRow.IdSite
        'Name'          = [string]$DataRow.Name
        'Description'   = [string]$DataRow.Description
        'State'         = [string]$tableVUEMState[$DataRow.State]
        'Actions'       = [pscustomobject]$actionGroupActions
        'Version'       = [int]$DataRow.RevisionId
    } 

    # override the default ToScript() method
    $vuemObject | Add-Member scriptmethod ToString { $this.Name } -force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.ActionGroup")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to an Application Action object

    .Description
    Converts SQL Data to an Application Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMApplicationObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Application action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemActionReserved = $DataRow.Reserved01
    [xml]$vuemActionXml = $vuemActionReserved.Substring($vuemActionReserved.ToLower().IndexOf("<array"))

    $vuemObject = [pscustomobject] @{
        'IdAction'                            = [int]$DataRow.IdApplication
        'IdSite'                              = [int]$DataRow.IdSite
        'Category'                            = [string]"Application"
        'Name'                                = [string]$DataRow.Name
        'DisplayName'                         = [string]$DataRow.DisplayName
        'Description'                         = [string]$DataRow.Description
        'State'                               = [string]$tableVUEMState[[int]$DataRow.State]
        'Type'                                = [string]$tableVUEMAppType[[int]$DataRow.AppType]
        'ActionType'                          = [string]$tableVUEMAppActionType[[int]$DataRow.ActionType]
        'StartMenuTarget'                     = [string]$DataRow.StartMenuTarget
        'TargetPath'                          = [string]$DataRow.TargetPath
        'Parameters'                          = [string]$DataRow.Parameters
        'WorkingDirectory'                    = [string]$DataRow.WorkingDirectory
        'WindowStyle'                         = [string]$DataRow.WindowStyle
        'HotKey'                              = [string]$DataRow.Hotkey
        'IconLocation'                        = [string]$DataRow.IconLocation
        'IconIndex'                           = [int]$DataRow.IconIndex
        'IconStream'                          = [string]$DataRow.IconStream
        'SelfHealingEnabled'                  = [bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SelfHealingEnabled"}).Value
        'EnforceIconLocation'                 = [bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforceIconLocation"}).Value
        'EnforceIconXValue'                   = [int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforceIconXValue"}).Value
        'EnforceIconYValue'                   = [int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforceIconYValue"}).Value
        'DoNotShowInSelfService'              = [bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "DoNotShowInSelfService"}).Value
        'CreateShortcutInUserFavoritesFolder' = [bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "CreateShortcutInUserFavoritesFolder"}).Value
        'Version'                             = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.Application")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to an Assignment object

    .Description
    Converts SQL Data to an Assignment object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Parameter AssignmentType
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMAssignmentObject() {
    param(
        [System.Data.DataRow]$DataRow,
        [string]$AssignmentType,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    Write-Verbose "Found Assignment object of Type '$($AssignmentType)' in IdSite $($DataRow.IdSite)"

    $assignedObject = $null
    if ($AssignmentType -like "Action Groups") {
        $assignedObject = Get-WEMActionGroup -Connection $Connection -IdActionGroup $row.IdAssignedObject
    } else {
        $assignedObject = Get-WEMAction -Connection $Connection -IdAction $row.IdAssignedObject -Category $AssignmentType
    }
    $vuemObject = [pscustomobject] @{
        'IdAssignment'                        = [int]$DataRow.IdAssignment
        'IdSite'                              = [int]$DataRow.IdSite
        'AssignmentType'                      = $AssignmentType
        'IdAssignedObject'                    = [int]$DataRow.IdAssignedObject
        'AssignedObject'                      = $assignedObject
        'ADObject'                            = Get-WEMADUserObject -Connection $Connection -IdSite $row.IdSite -IdADObject $row.Iditem
        'Rule'                                = Get-WEMRule -Connection $Connection -IdRule $row.IdFilterRule
        'Version'                             = [int]$DataRow.RevisionId
    }

    switch ($AssignmentType) {
        "Application" {
            # Application
            Write-Verbose "Processing Application properties"
            $bits = [int]$row.isDesktop + ([int]$row.isQuickLaunch * $assignmentPropertiesEnum["CreateQuickLaunchLink"]) + ([int]$row.isStartMenu * $assignmentPropertiesEnum["CreateStartMenuLink"]) + ([int]$row.isPinToTaskbar * $assignmentPropertiesEnum["PinToTaskbar"]) + ([int]$row.isPinToStartMenu * $assignmentPropertiesEnum["PinToStartMenu"]) + ([int]$row.isAutoStart * $assignmentPropertiesEnum["AutoStart"])
            if ($bits) {
                Add-Member -InputObject $vuemObject -NotePropertyName "AssignmentProperties" -NotePropertyValue ($assignmentPropertiesEnum.Keys | Where-Object { ($_).GetType().Name -like "Int32" -and $_ -band $bits } | ForEach-Object { $assignmentPropertiesEnum.Get_Item($_) })
            }

            continue
          }
        "Printer" {
            # Printer
            Write-Verbose "Processing Printer properties"
            if ([int]$row.isDefault -eq 1) { 
                Add-Member -InputObject $vuemObject -NotePropertyName "AssignmentProperties" -NotePropertyValue "SetAsDefault"
            }

            continue
        }
        "Network Drive" {
            # NetDrive
            Write-Verbose "Processing Drive properties"
            Add-Member -InputObject $vuemObject -NotePropertyName "AssignmentProperties" -NotePropertyValue "DriveLetter: $($row.DriveLetter)"

            continue
        }
        "Virtual Drive" {
            # VirtualDrive
            Write-Verbose "Processing Drive properties"
            Add-Member -InputObject $vuemObject -NotePropertyName "AssignmentProperties" -NotePropertyValue "DriveLetter: $($row.DriveLetter)"

            continue
        }
        Default {}
    }

    # override the default ToScript() method
    Add-Member -InputObject $vuemObject ScriptMethod ToString { "$($this.AssignedObject.Name) -> $($this.ADObject.Name)" } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.Assignment")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to a Printer Action object

    .Description
    Converts SQL Data to a Printer Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMPrinterObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Printer action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemActionReserved = [string]$DataRow.Reserved01

    # account for imported printers (Reserved01 = NULL in the database)
    if (-not $vuemActionReserved) { $vuemActionReserved = $defaultVUEMPrinterReserved }
    [xml]$vuemActionXml = $vuemActionReserved.Substring($vuemActionReserved.ToLower().IndexOf("<array"))

    $vuemObject = [pscustomobject] @{
        'IdAction'               = [int]$DataRow.IdPrinter
        'IdSite'                 = [int]$DataRow.IdSite
        'Category'               = [string]"Printer"
        'Name'                   = [string]$DataRow.Name
        'DisplayName'            = [string]$DataRow.DisplayName
        'Description'            = [string]$DataRow.Description
        'State'                  = [string]$tableVUEMState[[int]$DataRow.State]
        'ActionType'             = [string]$tableVUEMPrinterActionType[[int]$DataRow.ActionType]
        'TargetPath'             = [string]$DataRow.TargetPath
        'UseExternalCredentials' = [bool]$DataRow.UseExtCredentials
        'ExternalUsername'       = [string]$DataRow.ExtUsername
        'ExternalPassword'       = [string]$DataRow.ExtPassword
        'SelfHealingEnabled'     = [bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SelfHealingEnabled"}).Value
        'Version'                = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.Printer")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to a Network Drive Action object

    .Description
    Converts SQL Data to a Network Drive Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMNetDriveObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Network Drive action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemActionReserved = $DataRow.Reserved01
    [xml]$vuemActionXml = $vuemActionReserved.Substring($vuemActionReserved.ToLower().IndexOf("<array"))

    $vuemObject = [pscustomobject] @{
        'IdAction'               = [int]$DataRow.IdNetDrive
        'IdSite'                 = [int]$DataRow.IdSite
        'Category'               = [string]"Network Drive"
        'Name'                   = [string]$DataRow.Name
        'DisplayName'            = [string]$DataRow.DisplayName
        'Description'            = [string]$DataRow.Description
        'State'                  = [string]$tableVUEMState[[int]$DataRow.State]
        'ActionType'             = [string]$tableVUEMNetDriveActionType[[int]$DataRow.ActionType]
        'TargetPath'             = [string]$DataRow.TargetPath
        'UseExternalCredentials' = [bool]$DataRow.UseExtCredentials
        'ExternalUsername'       = [string]$DataRow.ExtUsername
        'ExternalPassword'       = [string]$DataRow.ExtPassword
        'SelfHealingEnabled'     = [bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SelfHealingEnabled"}).Value
        'SetAsHomeDriveEnabled'  = [bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SetAsHomeDriveEnabled"}).Value
        'Version'                = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.NetworkDrive")
    
    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to a Virtual Drive Action object

    .Description
    Converts SQL Data to a Virtual Drive Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMVirtualDriveObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Virtual Drive action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemActionReserved = $DataRow.Reserved01
    [xml]$vuemActionXml = $vuemActionReserved.Substring($vuemActionReserved.ToLower().IndexOf("<array"))

    $vuemObject = [pscustomobject] @{
        'IdAction'              = [int]$DataRow.IdVirtualDrive
        'IdSite'                = [int]$DataRow.IdSite
        'Category'              = [string]"Virtual Drive"
        'Name'                  = [string]$DataRow.Name
        'Description'           = [string]$DataRow.Description
        'State'                 = [string]$tableVUEMState[[int]$DataRow.State]
        'ActionType'            = [string]$tableVUEMVirtualDriveActionType[[int]$DataRow.ActionType]
        'TargetPath'            = [string]$DataRow.TargetPath
        'SetAsHomeDriveEnabled' = [bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SetAsHomeDriveEnabled"}).Value
        'Version'               = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.VirtualDrive")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to a Registry Value Action object

    .Description
    Converts SQL Data to a Registry Value Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMRegValueObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Registry Value action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemObject = [pscustomobject] @{
        'IdAction'    = [int]$DataRow.IdRegValue
        'IdSite'      = [int]$DataRow.IdSite
        'Category'    = [string]"Registry Value"
        'Name'        = [string]$DataRow.Name
        'Description' = [string]$DataRow.Description
        'State'       = [string]$tableVUEMState[[int]$DataRow.State]
        'ActionType'  = [string]$tableVUEMRegValueActionType[[int]$DataRow.ActionType]
        'TargetPath'  = [string]$DataRow.TargetPath
        'TargetName'  = [string]$DataRow.TargetName
        'TargetType'  = [string]$DataRow.TargetType
        'TargetValue' = [string]$DataRow.TargetValue
        'RunOnce'     = [bool]$DataRow.RunOnce
        'Version'     = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.RegistryValue")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to an Evironment Variable Action object

    .Description
    Converts SQL Data to an Environment Variable Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMEnvVariableObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Environment Variable action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemActionReserved = [string]$DataRow.Reserved01

    [xml]$vuemActionXml = $vuemActionReserved.Substring($vuemActionReserved.ToLower().IndexOf("<array"))

    $vuemObject = [pscustomobject] @{
        'IdAction'       = [int]$DataRow.IdEnvVariable
        'IdSite'         = [int]$DataRow.IdSite
        'Category'       = [string]"Environment Variable"
        'Name'           = [string]$DataRow.Name
        'Description'    = [string]$DataRow.Description
        'State'          = [string]$tableVUEMState[[int]$DataRow.State]
        'ActionType'     = [string]$tableVUEMEnvVariableActionType[[int]$DataRow.ActionType]
        'VariableName'   = [string]$DataRow.VariableName
        'VariableValue'  = [string]$DataRow.VariableValue
        'VariableType'   = [string]$DataRow.VariableType
        'ExecutionOrder' = [int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecOrder"}).Value
        'Version'        = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.EnvironmentVariable")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to a Port Action object

    .Description
    Converts SQL Data to a Port Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMPortObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Port action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemObject = [pscustomobject] @{
        'IdAction'    = [int]$DataRow.IdPort
        'IdSite'      = [int]$DataRow.IdSite
        'Category'    = [string]"Port"
        'Name'        = [string]$DataRow.Name
        'Description' = [string]$DataRow.Description
        'State'       = [string]$tableVUEMState[[int]$DataRow.State]
        'ActionType'  = [string]$tableVUEMPortActionType[[int]$DataRow.ActionType]
        'PortName'    = [string]$DataRow.PortName
        'TargetPath'  = [string]$DataRow.TargetPath
        'Version'     = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.Port")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to an Ini File Action object

    .Description
    Converts SQL Data to an Ini File Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMIniFileOpObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Ini File action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemObject = [pscustomobject] @{
        'IdAction'    = [int]$DataRow.IdIniFileOp
        'IdSite'      = [int]$DataRow.IdSite
        'Category'    = [string]"Ini File Operation"
        'Name'        = [string]$DataRow.Name
        'Description' = [string]$DataRow.Description
        'State'       = [string]$tableVUEMState[[int]$DataRow.State]
        'ActionType'  = [string]$tableVUEMIniFileOpActionType[[int]$DataRow.ActionType]
        'TargetPath'  = [string]$DataRow.TargetPath
        'TargetName'  = [string]$DataRow.TargetName
        'TargetValue' = [string]$DataRow.TargetValue
        'RunOnce'     = [bool]$DataRow.RunOnce
        'Version'     = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.IniFileOperation")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to an External Task Action object

    .Description
    Converts SQL Data to an External Task Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMExtTaskObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found External Task action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemActionReserved = $DataRow.Reserved01
    [xml]$vuemActionXml = $vuemActionReserved.Substring($vuemActionReserved.ToLower().IndexOf("<array"))

    $vuemObject = [pscustomobject] @{
        'IdAction'           = [int]$DataRow.IdExtTask
        'IdSite'             = [int]$DataRow.IdSite
        'Category'           = [string]"External Task"
        'Name'               = [string]$DataRow.Name
        'Description'        = [string]$DataRow.Description
        'State'              = [string]$tableVUEMState[[int]$DataRow.State]
        'ActionType'         = [string]$tableVUEMExtTaskActionType[[int]$DataRow.ActionType]
        'TargetPath'         = [string]$DataRow.TargetPath
        'TargetArguments'    = [string]$DataRow.TargetArgs
        'RunHidden'          = [bool]$DataRow.RunHidden
        'WaitForFinish'      = [bool]$DataRow.WaitForFinish
        'TimeOut'            = [int]$DataRow.TimeOut
        'ExecutionOrder'     = [int]$DataRow.ExecOrder
        'RunOnce'            = [bool]$DataRow.RunOnce
        'ExecuteOnlyAtLogon' = [bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteOnlyAtLogon"}).Value
        'Version'            = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.ExternalTask")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to an File System Operation Action object

    .Description
    Converts SQL Data to an File System Operation Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMFileSystemOpObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found File System Operations action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemActionReserved = [string]$DataRow.Reserved01

    [xml]$vuemActionXml = $vuemActionReserved.Substring($vuemActionReserved.ToLower().IndexOf("<array"))

    $vuemObject = [pscustomobject] @{
        'IdAction' = [int]$DataRow.IdFileSystemOp
        'IdSite' = [int]$DataRow.IdSite
        'Category' = [string]"File System Operation"
        'Name' = [string]$DataRow.Name
        'Description' = [string]$DataRow.Description
        'State' = [string]$tableVUEMState[[int]$DataRow.State]
        'ActionType' = [string]$tableVUEMFileSystemOpActionType[[int]$DataRow.ActionType]
        'SourcePath' = [string]$DataRow.SourcePath
        'TargetPath' = [string]$DataRow.TargetPath
        'TargetOverwrite' = [bool]$DataRow.TargetOverwrite
        'RunOnce' = [bool]$DataRow.RunOnce
        'ExecutionOrder' = [int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecOrder"}).Value
        'Version' = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.FileSystemOperation")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to a User DSN Action object

    .Description
    Converts SQL Data to a User DSN Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMUserDSNObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found User DSN action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemObject = [pscustomobject] @{
        'IdAction'                  = [int]$DataRow.IdUserDSN
        'IdSite'                    = [int]$DataRow.IdSite
        'Category'                  = [string]"User DSN"
        'Name'                      = [string]$DataRow.Name
        'Description'               = [string]$DataRow.Description
        'State'                     = [string]$tableVUEMState[[int]$DataRow.State]
        'ActionType'                = [string]$tableVUEMPortActionType[[int]$DataRow.ActionType]
        'TargetName'                = [string]$DataRow.TargetName
        'TargetDriverName'          = [string]$DataRow.TargetDriverName
        'TargetServerName'          = [string]$DataRow.TargetServerName
        'TargetDatabaseName'        = [string]$DataRow.TargetDatabaseName
        'UseExternalCredentials'    = [bool]$DataRow.UseExtCredentials
        'ExternalUsername'          = [string]$DataRow.ExtUsername
        'ExternalPassword'          = [string]$DataRow.ExtPassword
        'RunOnce'                   = [bool]$DataRow.RunOnce
        'Version'                   = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.UserDSN")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to a File Association Action object

    .Description
    Converts SQL Data to a File Association Action object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMFileAssocObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found File Association action object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemObject = [pscustomobject] @{
        'IdAction'          = [int]$DataRow.IdFileAssoc
        'IdSite'            = [int]$DataRow.IdSite
        'Category'          = [string]"File Association"
        'Name'              = [string]$DataRow.Name
        'Description'       = [string]$DataRow.Description
        'State'             = [string]$tableVUEMState[[int]$DataRow.State]
        'ActionType'        = [string]$tableVUEMFileAssocActionType[[int]$DataRow.ActionType]
        'FileExtension'     = [string]$DataRow.FileExt
        'ProgramId'         = [string]$DataRow.ProgId
        'Action'            = [string]$DataRow.Action
        'IsDefault'         = [bool]$DataRow.isDefault
        'TargetPath'        = [string]$DataRow.TargetPath
        'TargetCommand'     = [string]$DataRow.TargetCommand
        'TargetOverwrite'   = [bool]$DataRow.TargetOverwrite
        'RunOnce'           = [bool]$DataRow.RunOnce
        'Version'           = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.FileAssociation")

    return $vuemObject
}

<#
    Helper function to turn SID into an object with Name and Type
#>
function Get-ActiveDirectoryName {
    param(
        [string]$SID,
        [string]$GUID,
        [string]$Name,
        [int]$Type = -1
    )

    $account = $null
    try {
        if ($Type -eq -1 -or $Type -eq 4) { $account = [adsi]"LDAP://<SID=$($SID)>" }
        if ($Type -eq 8 -and $GUID)       { $account = [adsi]"LDAP://<Guid=$($GUID)>" }
        if ($Type -eq 4 -and $Name)       { $account = ([adsisearcher]"(&(objectCategory=Computer)(name=$($Name)))").FindOne() }
        if ($Type -eq 8 -and $Name)       { $account = [adsi]"LDAP://$($Name)" }

        $objectType = "Group"
        if ($account.objectClass -match "user")               { $objectType = "User" } 
        if ($account.objectClass -match "computer")           { $objectType = "Computer" }
        if ($account.objectClass -match "organizationalunit") { $objectType = "Organizational Unit"}

        $domain = ((($account.distinguishedName.ToLower().Split(",")) | Where-Object { $_ -match "dc="}).Replace("dc=","") -join ".")

        $ldapObject = [pscustomobject] @{
            'DistinguishedName' = $account.distinguishedName.ToString()
            'Type' = $objectType
        }
        # override the default ToScript() method
        if ($objectType -eq "Organizational Unit") {
            $ldapObject | Add-Member -NotePropertyName "Guid" -NotePropertyValue $GUID
        } else {
            $ldapObject | Add-Member -NotePropertyName "SID" -NotePropertyValue $SID
            $ldapObject | Add-Member -NotePropertyName "Account" -NotePropertyValue "$(([adsi]"LDAP://$domain").dc.ToUpper())\$($account.samAccountName)"
        }
        $ldapObject | Add-Member ScriptMethod ToString { $this.DistinguishedName } -Force

        return $ldapObject
    }
    catch {
        return $null
    }
}

<#
    .Synopsis
    Converts SQL Data to an Active Directory Agent or OU object

    .Description
    Converts SQL Data to an Active Directory Agent or OU object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMADAgentObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Active Directory Agent object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemObject = [pscustomobject] @{
        'IdADObject'        = [int]$DataRow.IdADObject
        'IdSite'            = [int]$DataRow.IdSite
        'Name'              = [string]$DataRow.Name
        'ADObjectId'        = [string]$DataRow.ADObjectId
        'Description'       = [string]$DataRow.Description
        'State'             = [string]$tableVUEMState[[int]$DataRow.State]
        'Type'              = [string]$tableVUEMADObjectType[$DataRow.Type]
        'Priority'          = [int]$DataRow.Priority
        'Version'           = [int]$DataRow.RevisionId
    }

    # try and get LDAP properties for the SID
    $ldapObject = Get-ActiveDirectoryName -SID $DataRow.ADObjectId -Type $DataRow.Type
    if ($ldapObject) { $vuemObject | Add-Member -NotePropertyName "LDAPObject" -NotePropertyValue $ldapObject -Force }

    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force

    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.ActiveDirectoryObject")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to an Active Directory User or Group object

    .Description
    Converts SQL Data to an Active Directory User or Group object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMADUserObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Active Directory User object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $Type = [int]$DataRow.Type
    if ($DataRow.Name -like "S-1-1-0" -or $DataRow.Name -like "S-1-5-32-544") { $Type = 3 }

    $vuemObject = [pscustomobject] @{
        'IdADObject'        = [int]$DataRow.IdItem
        'IdSite'            = [int]$DataRow.IdSite
        'Name'              = [string]$DataRow.Name
        'SID'               = [string]$DataRow.Name
        #'DistinguishedName' = [string]$DataRow.DistinguishedName
        'Description'       = [string]$DataRow.Description
        'State'             = [string]$tableVUEMState[[int]$DataRow.State]
        'Type'              = [string]$tableVUEMADObjectType[$Type]
        'Priority'          = [int]$DataRow.Priority
        'Version'           = [int]$DataRow.RevisionId
    }

    # try and get LDAP properties for the SID
    $ldapObject = Get-ActiveDirectoryName -SID $DataRow.Name
    if ($ldapObject) { 
        $vuemObject | Add-Member -NotePropertyName "Name" -NotePropertyValue $ldapObject.Account -Force
        $vuemObject | Add-Member -NotePropertyName "LDAPObject" -NotePropertyValue $ldapObject -Force
     }

    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force

    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.ActiveDirectoryObject")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to a Filter Condition object

    .Description
    Converts SQL Data to a Filter Condition object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMCondition() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Condition object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemObject = [pscustomobject] @{
        'IdCondition' = [int]$DataRow.IdFilterCondition
        'IdSite'      = [int]$DataRow.IdSite
        'Name'        = [string]$DataRow.Name
        'Description' = [string]$DataRow.Description
        'State'       = [string]$tableVUEMState[[int]$DataRow.State]
        'Type'        = [string]$tableVUEMFiltersConditionType[[int]$DataRow.Type].Name
        'TestValue'   = [string]$DataRow.TestValue
        'TestResult'  = [string]$DataRow.TestResult
        'Version'     = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    Add-Member -InputObject $vuemObject ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.Condition")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to a Filter Rule object

    .Description
    Converts SQL Data to a Filter Rule object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
Function New-VUEMRule() {
    param(
        [System.Data.DataRow]$DataRow,
        [System.Data.SqlClient.SqlConnection]$Connection

    )

    Write-Verbose "Found Rule object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemConditions = @()
    foreach ($idCondition in ($DataRow.Conditions.Split(";") | Sort-Object)) { $vuemConditions += Get-WEMCondition -Connection $Connection -IdCondition $idCondition }

    $vuemObject = [pscustomobject] @{
        'IdRule'      = [int]$DataRow.IdFilterRule
        'IdSite'      = [int]$DataRow.IdSite
        'Name'        = [string]$DataRow.Name
        'Description' = [string]$DataRow.Description
        'State'       = [string]$tableVUEMState[[int]$DataRow.State]
        'Conditions'  = $vuemConditions
        'Version'     = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.Rule")

    return $vuemObject
}

#endregion

#region Module Global variables
$configurationSettings = @{
    "4" = @{
        "ApplockerFields"                 = "IdSite, State, RevisionId, Value, Setting"
        "ApplockerValues"                 = @("({0}, 1, 1, 0, 'EnableProcessesAppLocker')", "({0}, 1, 1, 0, 'EnableDLLRuleCollection')", "({0}, 1, 1, 0, 'CollectionExeEnforcementState')", "({0}, 1, 1, 0, 'CollectionMsiEnforcementState')", "({0}, 1, 1, 0, 'CollectionScriptEnforcementState')", "({0}, 1, 1, 0, 'CollectionAppxEnforcementState')", "({0}, 1, 1, 0, 'CollectionDllEnforcementState')")
        "AgentSettingsFields"             = "IdSite,Name,Value,State,RevisionId"
        "AgentSettingsValues"             = @("({0},'OfflineModeEnabled','0',1,1)", "({0},'UseCacheEvenIfOnline','0',1,1)", "({0},'processVUEMApps','0',1,1)", "({0},'processVUEMPrinters','0',1,1)", "({0},'processVUEMNetDrives','0',1,1)", "({0},'processVUEMVirtualDrives','0',1,1)", "({0},'processVUEMRegValues','0',1,1)", "({0},'processVUEMEnvVariables','0',1,1)", "({0},'processVUEMPorts','0',1,1)", "({0},'processVUEMIniFilesOps','0',1,1)", "({0},'processVUEMExtTasks','0',1,1)", "({0},'processVUEMFileSystemOps','0',1,1)", "({0},'processVUEMUserDSNs','0',1,1)", "({0},'processVUEMFileAssocs','0',1,1)", "({0},'UIAgentSplashScreenBackGround','',1,1)", "({0},'UIAgentLoadingCircleColor','',1,1)", "({0},'UIAgentLbl1TextColor','',1,1)", "({0},'UIAgentHelpLink','',1,1)", "({0},'AgentServiceDebugMode','0',1,1)", "({0},'LaunchVUEMAgentOnLogon','0',1,1)", "({0},'ProcessVUEMAgentLaunchForAdmins','0',1,1)", "({0},'LaunchVUEMAgentOnReconnect','0',1,1)", "({0},'EnableVirtualDesktopCompatibility','0',1,1)", "({0},'VUEMAgentType','UI',1,1)", "({0},'VUEMAgentDesktopsExtraLaunchDelay','0',1,1)", "({0},'VUEMAgentCacheRefreshDelay','30',1,1)", "({0},'VUEMAgentSQLSettingsRefreshDelay','15',1,1)", "({0},'DeleteDesktopShortcuts','0',1,1)", "({0},'DeleteStartMenuShortcuts','0',1,1)", "({0},'DeleteQuickLaunchShortcuts','0',1,1)", "({0},'DeleteNetworkDrives','0',1,1)", "({0},'DeleteNetworkPrinters','0',1,1)", "({0},'PreserveAutocreatedPrinters','0',1,1)", "({0},'PreserveSpecificPrinters','0',1,1)", "({0},'SpecificPreservedPrinters','PDFCreator;PDFMail;Acrobat Distiller;Amyuni',1,1)", "({0},'EnableAgentLogging','1',1,1)", "({0},'AgentLogFile','%USERPROFILE%\Citrix WEM Agent.log',1,1)", "({0},'AgentDebugMode','0',1,1)", "({0},'RefreshEnvironmentSettings','0',1,1)", "({0},'RefreshSystemSettings','0',1,1)", "({0},'RefreshDesktop','0',1,1)", "({0},'RefreshAppearance','0',1,1)", "({0},'AgentExitForAdminsOnly','1',1,1)", "({0},'AgentAllowUsersToManagePrinters','0',1,1)", "({0},'DeleteTaskBarPinnedShortcuts','0',1,1)", "({0},'DeleteStartMenuPinnedShortcuts','0',1,1)", "({0},'InitialEnvironmentCleanUp','0',1,1)", "({0},'aSyncVUEMAppsProcessing','0',1,1)", "({0},'aSyncVUEMPrintersProcessing','0',1,1)", "({0},'aSyncVUEMNetDrivesProcessing','0',1,1)", "({0},'aSyncVUEMVirtualDrivesProcessing','0',1,1)", "({0},'aSyncVUEMRegValuesProcessing','0',1,1)", "({0},'aSyncVUEMEnvVariablesProcessing','0',1,1)", "({0},'aSyncVUEMPortsProcessing','0',1,1)", "({0},'aSyncVUEMIniFilesOpsProcessing','0',1,1)", "({0},'aSyncVUEMExtTasksProcessing','0',1,1)", "({0},'aSyncVUEMFileSystemOpsProcessing','0',1,1)", "({0},'aSyncVUEMUserDSNsProcessing','0',1,1)", "({0},'aSyncVUEMFileAssocsProcessing','0',1,1)", "({0},'byPassie4uinitCheck','0',1,1)", "({0},'UIAgentCustomLink','',1,1)", "({0},'enforceProcessVUEMApps','0',1,1)", "({0},'enforceProcessVUEMPrinters','0',1,1)", "({0},'enforceProcessVUEMNetDrives','0',1,1)", "({0},'enforceProcessVUEMVirtualDrives','0',1,1)", "({0},'enforceProcessVUEMRegValues','0',1,1)", "({0},'enforceProcessVUEMEnvVariables','0',1,1)", "({0},'enforceProcessVUEMPorts','0',1,1)", "({0},'enforceProcessVUEMIniFilesOps','0',1,1)", "({0},'enforceProcessVUEMExtTasks','0',1,1)", "({0},'enforceProcessVUEMFileSystemOps','0',1,1)", "({0},'enforceProcessVUEMUserDSNs','0',1,1)", "({0},'enforceProcessVUEMFileAssocs','0',1,1)", "({0},'revertUnassignedVUEMApps','0',1,1)", "({0},'revertUnassignedVUEMPrinters','0',1,1)", "({0},'revertUnassignedVUEMNetDrives','0',1,1)", "({0},'revertUnassignedVUEMVirtualDrives','0',1,1)", "({0},'revertUnassignedVUEMRegValues','0',1,1)", "({0},'revertUnassignedVUEMEnvVariables','0',1,1)", "({0},'revertUnassignedVUEMPorts','0',1,1)", "({0},'revertUnassignedVUEMIniFilesOps','0',1,1)", "({0},'revertUnassignedVUEMExtTasks','0',1,1)", "({0},'revertUnassignedVUEMFileSystemOps','0',1,1)", "({0},'revertUnassignedVUEMUserDSNs','0',1,1)", "({0},'revertUnassignedVUEMFileAssocs','0',1,1)", "({0},'AgentLaunchExcludeGroups','0',1,1)", "({0},'AgentLaunchExcludedGroups','',1,1)", "({0},'InitialDesktopUICleaning','0',1,1)", "({0},'EnableUIAgentAutomaticRefresh','0',1,1)", "({0},'UIAgentAutomaticRefreshDelay','30',1,1)", "({0},'AgentAllowUsersToManageApplications','0',1,1)", "({0},'HideUIAgentIconInPublishedApplications','0',1,1)", "({0},'ExecuteOnlyCmdAgentInPublishedApplications','0',1,1)", "({0},'enforceVUEMAppsFiltersProcessing','0',1,1)", "({0},'enforceVUEMPrintersFiltersProcessing','0',1,1)", "({0},'enforceVUEMNetDrivesFiltersProcessing','0',1,1)", "({0},'enforceVUEMVirtualDrivesFiltersProcessing','0',1,1)", "({0},'enforceVUEMRegValuesFiltersProcessing','0',1,1)", "({0},'enforceVUEMEnvVariablesFiltersProcessing','0',1,1)", "({0},'enforceVUEMPortsFiltersProcessing','0',1,1)", "({0},'enforceVUEMIniFilesOpsFiltersProcessing','0',1,1)", "({0},'enforceVUEMExtTasksFiltersProcessing','0',1,1)", "({0},'enforceVUEMFileSystemOpsFiltersProcessing','0',1,1)", "({0},'enforceVUEMUserDSNsFiltersProcessing','0',1,1)", "({0},'enforceVUEMFileAssocsFiltersProcessing','0',1,1)", "({0},'checkAppShortcutExistence','0',1,1)", "({0},'appShortcutExpandEnvironmentVariables','0',1,1)", "({0},'RefreshOnEnvironmentalSettingChange','1',1,1)", "({0},'HideUIAgentSplashScreen','0',1,1)", "({0},'processVUEMAppsOnReconnect','0',1,1)", "({0},'processVUEMPrintersOnReconnect','0',1,1)", "({0},'processVUEMNetDrivesOnReconnect','0',1,1)", "({0},'processVUEMVirtualDrivesOnReconnect','0',1,1)", "({0},'processVUEMRegValuesOnReconnect','0',1,1)", "({0},'processVUEMEnvVariablesOnReconnect','0',1,1)", "({0},'processVUEMPortsOnReconnect','0',1,1)", "({0},'processVUEMIniFilesOpsOnReconnect','0',1,1)", "({0},'processVUEMExtTasksOnReconnect','0',1,1)", "({0},'processVUEMFileSystemOpsOnReconnect','0',1,1)", "({0},'processVUEMUserDSNsOnReconnect','0',1,1)", "({0},'processVUEMFileAssocsOnReconnect','0',1,1)", "({0},'AgentAllowScreenCapture','0',1,1)", "({0},'AgentScreenCaptureEnableSendSupportEmail','0',1,1)", "({0},'AgentScreenCaptureSupportEmailAddress','',1,1)", "({0},'AgentScreenCaptureSupportEmailTemplate','',1,1)", "({0},'AgentEnableApplicationsShortcuts','0',1,1)", "({0},'UIAgentSkinName','Seven',1,1)", "({0},'HideUIAgentSplashScreenInPublishedApplications','0',1,1)", "({0},'MailCustomSubject',NULL,1,1)", "({0},'MailEnableUseSMTP','0',1,1)", "({0},'MailEnableSMTPSSL','0',1,1)", "({0},'MailSMTPPort','0',1,1)", "({0},'MailSMTPServer','',1,1)", "({0},'MailSMTPFromAddress','',1,1)", "({0},'MailSMTPToAddress','',1,1)", "({0},'MailEnableUseSMTPCredentials','0',1,1)", "({0},'MailSMTPUser','',1,1)", "({0},'MailSMTPPassword','',1,1)", "({0},'HideUIAgentSplashScreenOnReconnect','0',1,1)", "({0},'AgentDirectoryServiceTimeoutValue','15000',1,1)", "({0},'AgentBrokerServiceTimeoutValue','15000',1,1)", "({0},'AgentMaxDegreeOfParallelism','0',1,1)", "({0},'AgentPreventExitForAdmins','0',1,1)", "({0},'AgentNetworkResourceCheckTimeoutValue','500',1,1)", "({0},'AgentEnableCrossDomainsUserGroupsSearch','0',1,1)", "({0},'AgentShutdownAfterIdleEnabled','0',1,1)", "({0},'AgentShutdownAfterIdleTime','1800',1,1)", "({0},'AgentShutdownAfterEnabled','0',1,1)", "({0},'AgentShutdownAfter','02:00',1,1)", "({0},'AgentSuspendInsteadOfShutdown','0',1,1)", "({0},'AgentLaunchIncludeGroups','0',1,1)", "({0},'AgentLaunchIncludedGroups','',1,1)", "({0},'DisableAdministrativeRefreshFeedback','0',1,1)")
        "EnvironmentalFields"             = "IdSite,Name,Type,Value,State,RevisionId"
        "EnvironmentalValues"             = @("({0},'HideCommonPrograms',0,'0',1,1)", "({0},'HideControlPanel',0,'0',1,1)", "({0},'RemoveRunFromStartMenu',0,'0',1,1)", "({0},'HideNetworkIcon',0,'0',1,1)", "({0},'HideAdministrativeTools',0,'0',1,1)", "({0},'HideNetworkConnections',0,'0',1,1)", "({0},'HideHelp',0,'0',1,1)", "({0},'HideWindowsUpdate',0,'0',1,1)", "({0},'HideTurnOff',0,'0',1,1)", "({0},'ForceLogoff',0,'0',1,1)", "({0},'HideFind',0,'0',1,1)", "({0},'DisableRegistryEditing',0,'0',1,1)", "({0},'DisableCmd',0,'0',1,1)", "({0},'NoNetConnectDisconnect',0,'0',1,1)", "({0},'Turnoffnotificationareacleanup',1,'0',1,1)", "({0},'LockTaskbar',1,'0',1,1)", "({0},'TurnOffpersonalizedmenus',1,'0',1,1)", "({0},'ClearRecentprogramslist',1,'0',1,1)", "({0},'RemoveContextMenuManageItem',0,'0',1,1)", "({0},'HideSpecifiedDrivesFromExplorer',1,'0',1,1)", "({0},'ExplorerHiddenDrives',1,'',1,1)", "({0},'DisableDragFullWindows',1,'0',1,1)", "({0},'DisableSmoothScroll',1,'0',1,1)", "({0},'DisableCursorBlink',1,'0',1,1)", "({0},'DisableMinAnimate',1,'0',1,1)", "({0},'SetInteractiveDelay',1,'0',1,1)", "({0},'InteractiveDelayValue',1,'40',1,1)", "({0},'EnableAutoEndTasks',1,'0',1,1)", "({0},'WaitToKillAppTimeout',1,'20000',1,1)", "({0},'SetCursorBlinkRate',1,'0',1,1)", "({0},'CursorBlinkRateValue',1,'-1',1,1)", "({0},'SetMenuShowDelay',1,'0',1,1)", "({0},'MenuShowDelayValue',1,'10',1,1)", "({0},'SetVisualStyleFile',1,'0',1,1)", "({0},'VisualStyleFileValue',1,'%windir%\resources\Themes\Aero\aero.msstyles',1,1)", "({0},'SetWallpaper',1,'0',1,1)", "({0},'Wallpaper',1,'',1,1)", "({0},'WallpaperStyle',1,'0',1,1)", "({0},'processEnvironmentalSettings',2,'0',1,1)", "({0},'RestrictSpecifiedDrivesFromExplorer',1,'0',1,1)", "({0},'ExplorerRestrictedDrives',1,'',1,1)", "({0},'HideNetworkInExplorer',1,'0',1,1)", "({0},'HideLibrairiesInExplorer',1,'0',1,1)", "({0},'NoProgramsCPL',0,'0',1,1)", "({0},'NoPropertiesMyComputer',0,'0',1,1)", "({0},'SetSpecificThemeFile',1,'0',1,1)", "({0},'SpecificThemeFileValue',1,'%windir%\resources\Themes\aero.theme',1,1)", "({0},'DisableSpecifiedKnownFolders',1,'0',1,1)", "({0},'DisabledKnownFolders',1,'',1,1)", "({0},'DisableSilentRegedit',0,'0',1,1)", "({0},'DisableCmdScripts',0,'0',1,1)", "({0},'HideDevicesandPrinters',0,'0',1,1)", "({0},'processEnvironmentalSettingsForAdmins',2,'0',1,1)", "({0},'HideSystemClock',0,'0',1,1)", "({0},'SetDesktopBackGroundColor',0,'0',1,1)", "({0},'DesktopBackGroundColor',0,'',1,1)", "({0},'NoMyComputerIcon',1,'0',1,1)", "({0},'NoRecycleBinIcon',1,'0',1,1)", "({0},'NoPropertiesRecycleBin',0,'0',1,1)", "({0},'NoMyDocumentsIcon',1,'0',1,1)", "({0},'NoPropertiesMyDocuments',0,'0',1,1)", "({0},'NoNtSecurity',0,'0',1,1)", "({0},'DisableTaskMgr',0,'0',1,1)", "({0},'RestrictCpl',0,'0',1,1)", "({0},'RestrictCplList',0,'Display',1,1)", "({0},'DisallowCpl',0,'0',1,1)", "({0},'DisallowCplList',0,'',1,1)", "({0},'BootToDesktopInsteadOfStart',1,'0',1,1)", "({0},'DisableTLcorner',0,'0',1,1)", "({0},'DisableCharmsHint',0,'0',1,1)", "({0},'NoTrayContextMenu',0,'0',1,1)", "({0},'NoViewContextMenu',0,'0',1,1)")
        "ItemsFields"                     = "IdSite, Name, Description, State, Type, Priority, RevisionId"
        "ItemsValues"                     = @("({0}, 'S-1-1-0', 'A group that includes all users, even anonymous users and guests. Membership is controlled by the operating system.', 1, 1, 100, 1)", "({0}, 'S-1-5-32-544', 'A built-in group. After the initial installation of the operating system, the only member of the group is the Administrator account. When a computer joins a domain, the Domain Admins group is added to the Administrators group. When a server becomes a domain controller, the Enterprise Admins group also is added to the Administrators group.', 1, 1, 100, 1)")
        "KioskFields"                     = "IdSite,Name,Type,Value,State,RevisionId"
        "KioskValues"                     = @("({0},'PowerDontCheckBattery',0,'0',0,1)", "({0},'PowerShutdownAfterIdleTime',0,'1800',0,1)", "({0},'PowerShutdownAfterSpecifiedTime',0,'02:00',0,1)", "({0},'DesktopModeLogOffWebPortal',0,'0',0,1)", "({0},'EndSessionOption',0,'0',0,1)", "({0},'AutologonRegistryForce',0,'0',0,1)", "({0},'AutologonRegistryIgnoreShiftOverride',0,'0',0,1)", "({0},'AutologonPassword',0,'',0,1)", "({0},'AutologonDomain',0,'',0,1)", "({0},'AutologonUserName',0,'',0,1)", "({0},'AutologonEnable',0,'0',0,1)", "({0},'AdministrationHideDisplaySettings',0,'0',0,1)", "({0},'AdministrationHideKeyboardSettings',0,'0',0,1)", "({0},'AdministrationHideMouseSettings',0,'0',0,1)", "({0},'AdministrationHideClientDetails',0,'0',0,1)", "({0},'AdministrationDisableUnlock',0,'0',0,1)", "({0},'AdministrationHideWindowsVersion',0,'0',0,1)", "({0},'AdministrationDisableProgressBar',0,'0',0,1)", "({0},'AdministrationHidePrinterSettings',0,'0',0,1)", "({0},'AdministrationHideLogOffOption',0,'0',0,1)", "({0},'AdministrationHideRestartOption',0,'0',0,1)", "({0},'AdministrationHideShutdownOption',0,'0',0,1)", "({0},'AdministrationHideVolumeSettings',0,'0',0,1)", "({0},'AdministrationHideHomeButton',0,'0',0,1)", "({0},'AdministrationPreLaunchReceiver',0,'0',0,1)", "({0},'AdministrationIgnoreLastLanguage',0,'0',0,1)", "({0},'AdvancedHideTaskbar',0,'0',0,1)", "({0},'AdvancedLockCtrlAltDel',0,'0',0,1)", "({0},'AdvancedLockAltTab',0,'0',0,1)", "({0},'AdvancedFixBrowserRendering',0,'0',0,1)", "({0},'AdvancedLogOffScreenRedirection',0,'0',0,1)", "({0},'AdvancedSuppressScriptErrors',0,'0',0,1)", "({0},'AdvancedShowWifiSettings',0,'0',0,1)", "({0},'AdvancedHideKioskWhileCitrixSession',0,'0',0,1)", "({0},'AdvancedFixSslSites',0,'0',0,1)", "({0},'AdvancedAlwaysShowAdminMenu',0,'0',0,1)", "({0},'AdvancedFixZOrder',0,'0',0,1)", "({0},'ToolsAppsList',0,'',0,1)", "({0},'ToolsEnabled',0,'0',0,1)", "({0},'IsKioskEnabled',0,'0',0,1)", "({0},'SitesIsListEnabled',0,'0',0,1)", "({0},'SitesNamesAndLinks',0,'',0,1)", "({0},'GeneralStartUrl',0,'',0,1)", "({0},'GeneralTitle',0,'',0,1)", "({0},'GeneralShowNavigationButtons',0,'0',0,1)", "({0},'GeneralWindowMode',0,'0',0,1)", "({0},'GeneralClockEnabled',0,'0',0,1)", "({0},'GeneralClockUses12Hours',0,'0',0,1)", "({0},'GeneralUnlockPassword',0,'fLp34dnRI0DK26rJv8Tmqg==',0,1)", "({0},'GeneralEnableLanguageSelect',0,'0',0,1)", "({0},'GeneralAutoHideAppPanel',0,'0',0,1)", "({0},'GeneralEnableAppPanel',0,'0',0,1)", "({0},'ProcessLauncherEnabled',0,'0',0,1)", "({0},'ProcessLauncherApplication',0,'',0,1)", "({0},'ProcessLauncherArgs',0,'',0,1)", "({0},'ProcessLauncherClearLastUsernameVMWare',0,'0',0,1)", "({0},'ProcessLauncherEnableVMWareViewMode',0,'0',0,1)", "({0},'ProcessLauncherEnableMicrosoftRdsMode',0,'0',0,1)", "({0},'ProcessLauncherEnableCitrixMode',0,'0',0,1)", "({0},'SetCitrixReceiverFSOMode',0,'0',0,1)")
        "ParametersFields"                = "IdSite, Name, Value, State, RevisionId"
        "ParametersValues"                = @("({0},'excludedDriveletters','A;B;C;D',1,1)", "({0},'AllowDriveLetterReuse','0',1,1)")
        "PersonaFields"                   = "IdSite,Name,Value,State,RevisionId"
        "PersonaValues"                   = @("({0},'PersonaManagementEnabled','0',1,1)", "({0},'VPEnabled','0',1,1)", "({0},'UploadProfileInterval','10',1,1)", "({0},'SetCentralProfileStore','0',1,1)", "({0},'CentralProfileStore','',1,1)", "({0},'CentralProfileOverride','0',1,1)", "({0},'DeleteLocalProfile','0',1,1)", "({0},'DeleteLocalSettings','0',1,1)", "({0},'RoamLocalSettings','0',1,1)", "({0},'EnableBackgroundDownload','0',1,1)", "({0},'CleanupCLFSFiles','0',1,1)", "({0},'SetDynamicRoamingFiles','0',1,1)", "({0},'DynamicRoamingFiles','',1,1)", "({0},'SetDynamicRoamingFilesExceptions','0',1,1)", "({0},'DynamicRoamingFilesExceptions','',1,1)", "({0},'SetBasicRoamingFiles','0',1,1)", "({0},'BasicRoamingFiles','',1,1)", "({0},'SetBasicRoamingFilesExceptions','0',1,1)", "({0},'BasicRoamingFilesExceptions','',1,1)", "({0},'SetDontRoamFiles','0',1,1)", "({0},'DontRoamFiles','AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1)", "({0},'SetDontRoamFilesExceptions','0',1,1)", "({0},'DontRoamFilesExceptions','',1,1)", "({0},'SetBackgroundLoadFolders','0',1,1)", "({0},'BackgroundLoadFolders','',1,1)", "({0},'SetBackgroundLoadFoldersExceptions','0',1,1)", "({0},'BackgroundLoadFoldersExceptions','',1,1)", "({0},'SetExcludedProcesses','0',1,1)", "({0},'ExcludedProcesses','',1,1)", "({0},'HideOfflineIcon','0',1,1)", "({0},'HideFileCopyProgress','0',1,1)", "({0},'FileCopyMinSize','50',1,1)", "({0},'EnableTrayIconErrorAlerts','0',1,1)", "({0},'SetLogPath','0',1,1)", "({0},'LogPath','',1,1)", "({0},'SetLoggingDestination','0',1,1)", "({0},'LogToFile','0',1,1)", "({0},'LogToDebugPort','0',1,1)", "({0},'SetLoggingFlags','0',1,1)", "({0},'LogError','0',1,1)", "({0},'LogInformation','0',1,1)", "({0},'LogDebug','0',1,1)", "({0},'SetDebugFlags','0',1,1)", "({0},'DebugError','0',1,1)", "({0},'DebugInformation','0',1,1)", "({0},'DebugPorts','0',1,1)", "({0},'AddAdminGroupToRedirectedFolders','0',1,1)", "({0},'RedirectApplicationData','0',1,1)", "({0},'ApplicationDataRedirectedPath','',1,1)", "({0},'RedirectContacts','0',1,1)", "({0},'ContactsRedirectedPath','',1,1)", "({0},'RedirectCookies','0',1,1)", "({0},'CookiesRedirectedPath','',1,1)", "({0},'RedirectDesktop','0',1,1)", "({0},'DesktopRedirectedPath','',1,1)", "({0},'RedirectDownloads','0',1,1)", "({0},'DownloadsRedirectedPath','',1,1)", "({0},'RedirectFavorites','0',1,1)", "({0},'FavoritesRedirectedPath','',1,1)", "({0},'RedirectHistory','0',1,1)", "({0},'HistoryRedirectedPath','',1,1)", "({0},'RedirectLinks','0',1,1)", "({0},'LinksRedirectedPath','',1,1)", "({0},'RedirectMyDocuments','0',1,1)", "({0},'MyDocumentsRedirectedPath','',1,1)", "({0},'RedirectMyMusic','0',1,1)", "({0},'MyMusicRedirectedPath','',1,1)", "({0},'RedirectMyPictures','0',1,1)", "({0},'MyPicturesRedirectedPath','',1,1)", "({0},'RedirectMyVideos','0',1,1)", "({0},'MyVideosRedirectedPath','',1,1)", "({0},'RedirectNetworkNeighborhood','0',1,1)", "({0},'NetworkNeighborhoodRedirectedPath','',1,1)", "({0},'RedirectPrinterNeighborhood','0',1,1)", "({0},'PrinterNeighborhoodRedirectedPath','',1,1)", "({0},'RedirectRecentItems','0',1,1)", "({0},'RecentItemsRedirectedPath','',1,1)", "({0},'RedirectSavedGames','0',1,1)", "({0},'SavedGamesRedirectedPath','',1,1)", "({0},'RedirectSearches','0',1,1)", "({0},'SearchesRedirectedPath','',1,1)", "({0},'RedirectSendTo','0',1,1)", "({0},'SendToRedirectedPath','',1,1)", "({0},'RedirectStartMenu','0',1,1)", "({0},'StartMenuRedirectedPath','',1,1)", "({0},'RedirectStartupItems','0',1,1)", "({0},'StartupItemsRedirectedPath','',1,1)", "({0},'RedirectTemplates','0',1,1)", "({0},'TemplatesRedirectedPath','',1,1)", "({0},'RedirectTemporaryInternetFiles','0',1,1)", "({0},'TemporaryInternetFilesRedirectedPath','',1,1)", "({0},'SetFRExclusions','0',1,1)", "({0},'FRExclusions','',1,1)", "({0},'SetFRExclusionsExceptions','0',1,1)", "({0},'FRExclusionsExceptions','',1,1)")
        "SystemMonitoringFields"          = "IdSite,Name,Value,State,RevisionId"
        "SystemMonitoringValues"          = @("({0},'EnableSystemMonitoring','0',1,1)", "({0},'EnableGlobalSystemMonitoring','0',1,1)", "({0},'EnableProcessActivityMonitoring','0',1,1)", "({0},'EnableUserExperienceMonitoring','0',1,1)", "({0},'LocalDatabaseRetentionPeriod','3',1,1)", "({0},'LocalDataUploadFrequency','4',1,1)", "({0},'EnableApplicationReportsWindows2K3XPCompliance','0',1,1)", "({0},'ExcludeProcessesFromApplicationReports','1',1,1)", "({0},'ExcludedProcessesFromApplicationReports','dwm;taskhost;vmtoolsd;winlogon;csrss;wisptis;dllhost;consent;msiexec;userinit;LogonUI;mscorsvw;SearchProtocolHost;Rundll32;explorer;regsvr32;WmiPrvSE;services;smss;SearchFilterHost;lsass;svchost;lsm;msdtc;wininit;VGAuthService;SearchIndexer;spoolsv;vmtoolsd;vmacthlp;audiodg;VMwareResolutionSet;mobsync;wsqmcons;schtasks;Defrag;conhost;VSSVC;sdclt;MpCmdRun;WMIADAP;encsvc;wfshell;CpSvc;VDARedirector;CpSvc64;SemsService;ctxrdr;PicaSvc2;encsvc;GfxMgr;PicaSessionAgent;CtxGfx;PicaTwiHost;PicaUserAgent;VDARedirector;PicaShell;PicaEuemRelay;CtxMtHost;CtxSensLoader;ssonsvr;concentr;wfcrun32;pnamain;redirector;concentr;pnamain;pnagent;IMAAdvanceSrv;mfcom;ctxxmlss;Citrix.XenApp.Commands.Remoting.Service;HCAService;cmstart;startssonsvr;ctxhide;mmvdhost;runonce;rdpclip;TabTip;InputPersonalization;TabTip32;TSTheme;ngen;XTE;CtxSvcHost;OSPPSVC;TelemetryService;CtxAudioService;picatzrestore;CheckTermSrv;IMATest;RequestTicket;csc;cvtres;ssoncom;UpmUserMsg;CtxPvD;MultimediaRedirector;gpscript;shutdown;splwow64',1,1)", "({0},'EnableStrictPrivacy','0',1,1)", "({0},'BusinessDayStartHour','8',1,1)", "({0},'BusinessDayEndHour','19',1,1)", "({0},'ReportsBootTimeMinimum','5',1,1)", "({0},'ReportsLoginTimeMinimum','5',1,1)", "({0},'EnableWorkDaysFiltering','1',1,1)", "({0},'WorkDaysFilter','1;1;1;1;1;0;0',1,1)")
        "SystemUtilitiesFields"           = "IdSite,Name,Type,Value,State,RevisionId"
        "SystemUtilitiesValues"           = @("({0},'EnableFastLogoff',0,'0',1,1)", "({0},'ExcludeGroupsFromFastLogoff',0,'0',1,1)", "({0},'FastLogoffExcludedGroups',0,NULL,1,1)", "({0},'EnableCPUSpikesProtection',1,'0',1,1)", "({0},'SpikesProtectionCPUUsageLimitPercent',1,'70',1,1)", "({0},'SpikesProtectionCPUUsageLimitSampleTime',1,'30',1,1)", "({0},'SpikesProtectionIdlePriorityConstraintTime',1,'180',1,1)", "({0},'ExcludeProcessesFromCPUSpikesProtection',1,'0',1,1)", "({0},'CPUSpikesProtectionExcludedProcesses',1,NULL,1,1)", "({0},'EnableMemoryWorkingSetOptimization',2,'0',1,1)", "({0},'MemoryWorkingSetOptimizationIdleSampleTime',2,'120',1,1)", "({0},'ExcludeProcessesFromMemoryWorkingSetOptimization',2,'0',1,1)", "({0},'MemoryWorkingSetOptimizationExcludedProcesses',2,NULL,1,1)", "({0},'EnableProcessesBlackListing',3,'0',1,1)", "({0},'ProcessesManagementBlackListedProcesses',3,NULL,1,1)", "({0},'ProcessesManagementBlackListExcludeLocalAdministrators',3,'0',1,1)", "({0},'ProcessesManagementBlackListExcludeSpecifiedGroups',3,'0',1,1)", "({0},'ProcessesManagementBlackListExcludedSpecifiedGroupsList',3,'',1,1)", "({0},'EnableProcessesWhiteListing',3,'0',1,1)", "({0},'ProcessesManagementWhiteListedProcesses',3,NULL,1,1)", "({0},'ProcessesManagementWhiteListExcludeLocalAdministrators',3,'0',1,1)", "({0},'ProcessesManagementWhiteListExcludeSpecifiedGroups',3,'0',1,1)", "({0},'ProcessesManagementWhiteListExcludedSpecifiedGroupsList',3,'',1,1)", "({0},'EnableProcessesManagement',3,'0',1,1)", "({0},'EnableProcessesClamping',4,'0',1,1)", "({0},'ProcessesClampingList',4,NULL,1,1)", "({0},'EnableProcessesAffinity',5,'0',1,1)", "({0},'ProcessesAffinityList',5,NULL,1,1)", "({0},'EnableProcessesIoPriority',6,'0',1,1)", "({0},'ProcessesIoPriorityList',6,NULL,1,1)", "({0},'EnableProcessesCpuPriority',7,'0',1,1)", "({0},'ProcessesCpuPriorityList',7,NULL,1,1)", "({0},'MemoryWorkingSetOptimizationIdleStateLimitPercent',2,'1',1,1)", "({0},'EnableIntelligentCpuOptimization',1,'0',1,1)", "({0},'EnableIntelligentIoOptimization',1,'0',1,1)", "({0},'SpikesProtectionLimitCPUCoreNumber',1,'0',1,1)", "({0},'SpikesProtectionCPUCoreLimit',1,'1',1,1)", "({0},'AppLockerControllerManagement',1,'1',1,1)", "({0},'AppLockerControllerReplaceModeOn',1,'1',1,1)")
        "UPMFields"                       = "IdSite,Name,Value,State,RevisionId"
        "UPMValues"                       = @("({0},'UPMManagementEnabled','0',1,1)", "({0},'ServiceActive','0',1,1)", "({0},'SetProcessedGroups','0',1,1)", "({0},'ProcessedGroupsList','',1,1)", "({0},'ProcessAdmins','0',1,1)", "({0},'SetPathToUserStore','0',1,1)", "({0},'PathToUserStore','Windows',1,1)", "({0},'PSMidSessionWriteBack','0',1,1)", "({0},'OfflineSupport','0',1,1)", "({0},'DeleteCachedProfilesOnLogoff','0',1,1)", "({0},'SetMigrateWindowsProfilesToUserStore','0',1,1)", "({0},'MigrateWindowsProfilesToUserStore','1',1,1)", "({0},'SetLocalProfileConflictHandling','0',1,1)", "({0},'LocalProfileConflictHandling','1',1,1)", "({0},'SetTemplateProfilePath','0',1,1)", "({0},'TemplateProfilePath','',1,1)", "({0},'TemplateProfileOverridesLocalProfile','0',1,1)", "({0},'TemplateProfileOverridesRoamingProfile','0',1,1)", "({0},'SetLoadRetries','0',1,1)", "({0},'LoadRetries','5',1,1)", "({0},'SetUSNDBPath','0',1,1)", "({0},'USNDBPath','',1,1)", "({0},'XenAppOptimizationEnabled','0',1,1)", "({0},'XenAppOptimizationPath','',1,1)", "({0},'ProcessCookieFiles','0',1,1)", "({0},'DeleteRedirectedFolders','0',1,1)", "({0},'LoggingEnabled','0',1,1)", "({0},'SetLogLevels','0',1,1)", "({0},'LogLevels','0;0;0;0;0;0;0;0;0;0;0',1,1)", "({0},'SetMaxLogSize','0',1,1)", "({0},'MaxLogSize','1048576',1,1)", "({0},'SetPathToLogFile','0',1,1)", "({0},'PathToLogFile','',1,1)", "({0},'SetExclusionListRegistry','0',1,1)", "({0},'ExclusionListRegistry','',1,1)", "({0},'SetInclusionListRegistry','0',1,1)", "({0},'InclusionListRegistry','',1,1)", "({0},'SetSyncExclusionListFiles','0',1,1)", "({0},'SyncExclusionListFiles','AppData\Roaming\Microsoft\Windows\Start Menu\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Startup\Desktop.ini',1,1)", "({0},'SetSyncExclusionListDir','0',1,1)", "({0},'SyncExclusionListDir','`$Recycle.Bin;AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1)", "({0},'SetSyncDirList','0',1,1)", "({0},'SyncDirList','',1,1)", "({0},'SetSyncFileList','0',1,1)", "({0},'SyncFileList','',1,1)", "({0},'SetMirrorFoldersList','0',1,1)", "({0},'MirrorFoldersList','',1,1)", "({0},'SetLargeFileHandlingList','0',1,1)", "({0},'LargeFileHandlingList','',1,1)", "({0},'PSEnabled','0',1,1)", "({0},'PSAlwaysCache','0',1,1)", "({0},'PSAlwaysCacheSize','0',1,1)", "({0},'SetPSPendingLockTimeout','0',1,1)", "({0},'PSPendingLockTimeout','1',1,1)", "({0},'SetPSUserGroupsList','0',1,1)", "({0},'PSUserGroupsList','',1,1)", "({0},'CPEnabled','0',1,1)", "({0},'SetCPUserGroupList','0',1,1)", "({0},'CPUserGroupList','',1,1)", "({0},'SetCPSchemaPath','0',1,1)", "({0},'CPSchemaPath','',1,1)", "({0},'SetCPPath','0',1,1)", "({0},'CPPath','',1,1)", "({0},'CPMigrationFromBaseProfileToCPStore','0',1,1)", "({0},'SetExcludedGroups','0',1,1)", "({0},'ExcludedGroupsList','',1,1)", "({0},'DisableDynamicConfig','0',1,1)", "({0},'LogoffRatherThanTempProfile','0',1,1)", "({0},'SetProfileDeleteDelay','0',1,1)", "({0},'ProfileDeleteDelay','0',1,1)", "({0},'TemplateProfileIsMandatory','0',1,1)", "({0},'PSMidSessionWriteBackReg','0',1,1)", "({0},'CEIPEnabled','1',1,1)", "({0},'LastKnownGoodRegistry','0',1,1)", "({0},'EnableDefaultExclusionListRegistry','0',1,1)", "({0},'ExclusionDefaultRegistry01','1',1,1)", "({0},'ExclusionDefaultRegistry02','1',1,1)", "({0},'ExclusionDefaultRegistry03','1',1,1)", "({0},'EnableDefaultExclusionListDirectories','0',1,1)", "({0},'ExclusionDefaultDir01','1',1,1)", "({0},'ExclusionDefaultDir02','1',1,1)", "({0},'ExclusionDefaultDir03','1',1,1)", "({0},'ExclusionDefaultDir04','1',1,1)", "({0},'ExclusionDefaultDir05','1',1,1)", "({0},'ExclusionDefaultDir06','1',1,1)", "({0},'ExclusionDefaultDir07','1',1,1)", "({0},'ExclusionDefaultDir08','1',1,1)", "({0},'ExclusionDefaultDir09','1',1,1)", "({0},'ExclusionDefaultDir10','1',1,1)", "({0},'ExclusionDefaultDir11','1',1,1)", "({0},'ExclusionDefaultDir12','1',1,1)", "({0},'ExclusionDefaultDir13','1',1,1)", "({0},'ExclusionDefaultDir14','1',1,1)", "({0},'ExclusionDefaultDir15','1',1,1)", "({0},'ExclusionDefaultDir16','1',1,1)", "({0},'ExclusionDefaultDir17','1',1,1)", "({0},'ExclusionDefaultDir18','1',1,1)", "({0},'ExclusionDefaultDir19','1',1,1)", "({0},'ExclusionDefaultDir20','1',1,1)", "({0},'ExclusionDefaultDir21','1',1,1)", "({0},'ExclusionDefaultDir22','1',1,1)", "({0},'ExclusionDefaultDir23','1',1,1)", "({0},'ExclusionDefaultDir24','1',1,1)", "({0},'ExclusionDefaultDir25','1',1,1)", "({0},'ExclusionDefaultDir26','1',1,1)", "({0},'ExclusionDefaultDir27','1',1,1)", "({0},'ExclusionDefaultDir28','1',1,1)", "({0},'ExclusionDefaultDir29','1',1,1)", "({0},'ExclusionDefaultDir30','1',1,1)", "({0},'EnableStreamingExclusionList','0',1,1)", "({0},'StreamingExclusionList','',1,1)", "({0},'EnableLogonExclusionCheck','0',1,1)", "({0},'LogonExclusionCheck','0',1,1)", "({0},'OutlookSearchRoamingEnabled','0',1,1)")
        "USVFields"                       = "IdSite,Name,Type,Value,State,RevisionId"
        "USVValues"                       = @("({0},'processUSVConfiguration',0,'0',1,1)", "({0},'processUSVConfigurationForAdmins',0,'0',1,1)", "({0},'SetWindowsRoamingProfilesPath',1,'0',1,1)", "({0},'WindowsRoamingProfilesPath',1,'',1,1)", "({0},'SetRDSRoamingProfilesPath',1,'0',1,1)", "({0},'RDSRoamingProfilesPath',1,'',1,1)", "({0},'SetRDSHomeDrivePath',1,'0',1,1)", "({0},'RDSHomeDrivePath',1,'',1,1)", "({0},'RDSHomeDriveLetter',1,'Z:',1,1)", "({0},'SetRoamingProfilesFoldersExclusions',2,'0',1,1)", "({0},'RoamingProfilesFoldersExclusions',2,'AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp',1,1)", "({0},'DeleteRoamingCachedProfiles',1,'0',1,1)", "({0},'AddAdminGroupToRUP',1,'0',1,1)", "({0},'CompatibleRUPSecurity',1,'0',1,1)", "({0},'DisableSlowLinkDetect',1,'0',1,1)", "({0},'SlowLinkProfileDefault',1,'0',1,1)", "({0},'processFoldersRedirectionConfiguration',3,'0',1,1)", "({0},'DeleteLocalRedirectedFolders',3,'0',1,1)", "({0},'processDesktopRedirection',3,'0',1,1)", "({0},'DesktopRedirectedPath',3,'',1,1)", "({0},'processStartMenuRedirection',3,'0',1,1)", "({0},'StartMenuRedirectedPath',3,'',1,1)", "({0},'processPersonalRedirection',3,'0',1,1)", "({0},'PersonalRedirectedPath',3,'',1,1)", "({0},'processPicturesRedirection',3,'0',1,1)", "({0},'PicturesRedirectedPath',3,'',1,1)", "({0},'MyPicturesFollowsDocuments',3,'0',1,1)", "({0},'processMusicRedirection',3,'0',1,1)", "({0},'MusicRedirectedPath',3,'',1,1)", "({0},'MyMusicFollowsDocuments',3,'0',1,1)", "({0},'processVideoRedirection',3,'0',1,1)", "({0},'VideoRedirectedPath',3,'',1,1)", "({0},'MyVideoFollowsDocuments',3,'0',1,1)", "({0},'processFavoritesRedirection',3,'0',1,1)", "({0},'FavoritesRedirectedPath',3,'',1,1)", "({0},'processAppDataRedirection',3,'0',1,1)", "({0},'AppDataRedirectedPath',3,'',1,1)", "({0},'processContactsRedirection',3,'0',1,1)", "({0},'ContactsRedirectedPath',3,'',1,1)", "({0},'processDownloadsRedirection',3,'0',1,1)", "({0},'DownloadsRedirectedPath',3,'',1,1)", "({0},'processLinksRedirection',3,'0',1,1)", "({0},'LinksRedirectedPath',3,'',1,1)", "({0},'processSearchesRedirection',3,'0',1,1)", "({0},'SearchesRedirectedPath',3,'',1,1)")

        "CleanupTables"                   = @("VUEMApps","VUEMPrinters","VUEMNetDrives","VUEMVirtualDrives","VUEMRegValues","VUEMEnvVariables","VUEMPorts","VUEMIniFilesOps","VUEMExtTasks","VUEMFileSystemOps","VUEMUserDSNs","VUEMFileAssocs","VUEMActionsGroups","VUEMFiltersRules","VUEMFiltersConditions","VUEMItems","VUEMUserStatistics","VUEMAgentStatistics","VUEMSystemMonitoringData","VUEMActivityMonitoringData","VUEMUserExperienceMonitoringData","VUEMResourcesOptimizationData","VUEMParameters","VUEMAgentSettings","VUEMSystemUtilities","VUEMEnvironmentalSettings","VUEMUPMSettings","VUEMPersonaSettings","VUEMUSVSettings","VUEMKioskSettings","VUEMSystemMonitoringSettings","VUEMTasks","VUEMChangesLog","VUEMAgentsLog","VUEMADObjects","AppLockerSettings","VUEMSites")
    }
    "1903" = @{ 
        "ApplockerFields"                 = "IdSite, State, RevisionId, Value, Setting"
        "ApplockerFieldsValues"           = @("({0}, 1, 1, 0, 'EnableProcessesAppLocker')", "({0}, 1, 1, 0, 'EnableDLLRuleCollection')", "({0}, 1, 1, 0, 'CollectionExeEnforcementState')", "({0}, 1, 1, 0, 'CollectionMsiEnforcementState')", "({0}, 1, 1, 0, 'CollectionScriptEnforcementState')", "({0}, 1, 1, 0, 'CollectionAppxEnforcementState')", "({0}, 1, 1, 0, 'CollectionDllEnforcementState')")
        "GroupPolicyGlobalSettingsFields" = "IdSite, Name, Value"
        "GroupPolicyGlobalSettingsValues" = @("({0}, 'EnableGroupPolicyEnforcement', '0')")
        "AgentSettingsFields"             = "IdSite,Name,Value,State,RevisionId"
        "AgentSettingsValues"             = @("({0},'OfflineModeEnabled','0',1,1)", "({0},'UseCacheEvenIfOnline','0',1,1)", "({0},'processVUEMApps','0',1,1)", "({0},'processVUEMPrinters','0',1,1)", "({0},'processVUEMNetDrives','0',1,1)", "({0},'processVUEMVirtualDrives','0',1,1)", "({0},'processVUEMRegValues','0',1,1)", "({0},'processVUEMEnvVariables','0',1,1)", "({0},'processVUEMPorts','0',1,1)", "({0},'processVUEMIniFilesOps','0',1,1)", "({0},'processVUEMExtTasks','0',1,1)", "({0},'processVUEMFileSystemOps','0',1,1)", "({0},'processVUEMUserDSNs','0',1,1)", "({0},'processVUEMFileAssocs','0',1,1)", "({0},'UIAgentSplashScreenBackGround','',1,1)", "({0},'UIAgentLoadingCircleColor','',1,1)", "({0},'UIAgentLbl1TextColor','',1,1)", "({0},'UIAgentHelpLink','',1,1)", "({0},'AgentServiceDebugMode','0',1,1)", "({0},'LaunchVUEMAgentOnLogon','0',1,1)", "({0},'ProcessVUEMAgentLaunchForAdmins','0',1,1)", "({0},'LaunchVUEMAgentOnReconnect','0',1,1)", "({0},'EnableVirtualDesktopCompatibility','0',1,1)", "({0},'VUEMAgentType','UI',1,1)", "({0},'VUEMAgentDesktopsExtraLaunchDelay','0',1,1)", "({0},'VUEMAgentCacheRefreshDelay','30',1,1)", "({0},'VUEMAgentSQLSettingsRefreshDelay','15',1,1)", "({0},'DeleteDesktopShortcuts','0',1,1)", "({0},'DeleteStartMenuShortcuts','0',1,1)", "({0},'DeleteQuickLaunchShortcuts','0',1,1)", "({0},'DeleteNetworkDrives','0',1,1)", "({0},'DeleteNetworkPrinters','0',1,1)", "({0},'PreserveAutocreatedPrinters','0',1,1)", "({0},'PreserveSpecificPrinters','0',1,1)", "({0},'SpecificPreservedPrinters','PDFCreator;PDFMail;Acrobat Distiller;Amyuni',1,1)", "({0},'EnableAgentLogging','1',1,1)", "({0},'AgentLogFile','%USERPROFILE%\Citrix WEM Agent.log',1,1)", "({0},'AgentDebugMode','0',1,1)", "({0},'RefreshEnvironmentSettings','0',1,1)", "({0},'RefreshSystemSettings','0',1,1)", "({0},'RefreshDesktop','0',1,1)", "({0},'RefreshAppearance','0',1,1)", "({0},'AgentExitForAdminsOnly','1',1,1)", "({0},'AgentAllowUsersToManagePrinters','0',1,1)", "({0},'DeleteTaskBarPinnedShortcuts','0',1,1)", "({0},'DeleteStartMenuPinnedShortcuts','0',1,1)", "({0},'InitialEnvironmentCleanUp','0',1,1)", "({0},'aSyncVUEMAppsProcessing','0',1,1)", "({0},'aSyncVUEMPrintersProcessing','0',1,1)", "({0},'aSyncVUEMNetDrivesProcessing','0',1,1)", "({0},'aSyncVUEMVirtualDrivesProcessing','0',1,1)", "({0},'aSyncVUEMRegValuesProcessing','0',1,1)", "({0},'aSyncVUEMEnvVariablesProcessing','0',1,1)", "({0},'aSyncVUEMPortsProcessing','0',1,1)", "({0},'aSyncVUEMIniFilesOpsProcessing','0',1,1)", "({0},'aSyncVUEMExtTasksProcessing','0',1,1)", "({0},'aSyncVUEMFileSystemOpsProcessing','0',1,1)", "({0},'aSyncVUEMUserDSNsProcessing','0',1,1)", "({0},'aSyncVUEMFileAssocsProcessing','0',1,1)", "({0},'byPassie4uinitCheck','0',1,1)", "({0},'UIAgentCustomLink','',1,1)", "({0},'enforceProcessVUEMApps','0',1,1)", "({0},'enforceProcessVUEMPrinters','0',1,1)", "({0},'enforceProcessVUEMNetDrives','0',1,1)", "({0},'enforceProcessVUEMVirtualDrives','0',1,1)", "({0},'enforceProcessVUEMRegValues','0',1,1)", "({0},'enforceProcessVUEMEnvVariables','0',1,1)", "({0},'enforceProcessVUEMPorts','0',1,1)", "({0},'enforceProcessVUEMIniFilesOps','0',1,1)", "({0},'enforceProcessVUEMExtTasks','0',1,1)", "({0},'enforceProcessVUEMFileSystemOps','0',1,1)", "({0},'enforceProcessVUEMUserDSNs','0',1,1)", "({0},'enforceProcessVUEMFileAssocs','0',1,1)", "({0},'revertUnassignedVUEMApps','0',1,1)", "({0},'revertUnassignedVUEMPrinters','0',1,1)", "({0},'revertUnassignedVUEMNetDrives','0',1,1)", "({0},'revertUnassignedVUEMVirtualDrives','0',1,1)", "({0},'revertUnassignedVUEMRegValues','0',1,1)", "({0},'revertUnassignedVUEMEnvVariables','0',1,1)", "({0},'revertUnassignedVUEMPorts','0',1,1)", "({0},'revertUnassignedVUEMIniFilesOps','0',1,1)", "({0},'revertUnassignedVUEMExtTasks','0',1,1)", "({0},'revertUnassignedVUEMFileSystemOps','0',1,1)", "({0},'revertUnassignedVUEMUserDSNs','0',1,1)", "({0},'revertUnassignedVUEMFileAssocs','0',1,1)", "({0},'AgentLaunchExcludeGroups','0',1,1)", "({0},'AgentLaunchExcludedGroups','',1,1)", "({0},'InitialDesktopUICleaning','0',1,1)", "({0},'EnableUIAgentAutomaticRefresh','0',1,1)", "({0},'UIAgentAutomaticRefreshDelay','30',1,1)", "({0},'AgentAllowUsersToManageApplications','0',1,1)", "({0},'HideUIAgentIconInPublishedApplications','0',1,1)", "({0},'ExecuteOnlyCmdAgentInPublishedApplications','0',1,1)", "({0},'enforceVUEMAppsFiltersProcessing','0',1,1)", "({0},'enforceVUEMPrintersFiltersProcessing','0',1,1)", "({0},'enforceVUEMNetDrivesFiltersProcessing','0',1,1)", "({0},'enforceVUEMVirtualDrivesFiltersProcessing','0',1,1)", "({0},'enforceVUEMRegValuesFiltersProcessing','0',1,1)", "({0},'enforceVUEMEnvVariablesFiltersProcessing','0',1,1)", "({0},'enforceVUEMPortsFiltersProcessing','0',1,1)", "({0},'enforceVUEMIniFilesOpsFiltersProcessing','0',1,1)", "({0},'enforceVUEMExtTasksFiltersProcessing','0',1,1)", "({0},'enforceVUEMFileSystemOpsFiltersProcessing','0',1,1)", "({0},'enforceVUEMUserDSNsFiltersProcessing','0',1,1)", "({0},'enforceVUEMFileAssocsFiltersProcessing','0',1,1)", "({0},'checkAppShortcutExistence','0',1,1)", "({0},'appShortcutExpandEnvironmentVariables','0',1,1)", "({0},'RefreshOnEnvironmentalSettingChange','1',1,1)", "({0},'HideUIAgentSplashScreen','0',1,1)", "({0},'processVUEMAppsOnReconnect','0',1,1)", "({0},'processVUEMPrintersOnReconnect','0',1,1)", "({0},'processVUEMNetDrivesOnReconnect','0',1,1)", "({0},'processVUEMVirtualDrivesOnReconnect','0',1,1)", "({0},'processVUEMRegValuesOnReconnect','0',1,1)", "({0},'processVUEMEnvVariablesOnReconnect','0',1,1)", "({0},'processVUEMPortsOnReconnect','0',1,1)", "({0},'processVUEMIniFilesOpsOnReconnect','0',1,1)", "({0},'processVUEMExtTasksOnReconnect','0',1,1)", "({0},'processVUEMFileSystemOpsOnReconnect','0',1,1)", "({0},'processVUEMUserDSNsOnReconnect','0',1,1)", "({0},'processVUEMFileAssocsOnReconnect','0',1,1)", "({0},'AgentAllowScreenCapture','0',1,1)", "({0},'AgentScreenCaptureEnableSendSupportEmail','0',1,1)", "({0},'AgentScreenCaptureSupportEmailAddress','',1,1)", "({0},'AgentScreenCaptureSupportEmailTemplate','',1,1)", "({0},'AgentEnableApplicationsShortcuts','0',1,1)", "({0},'UIAgentSkinName','Seven',1,1)", "({0},'HideUIAgentSplashScreenInPublishedApplications','0',1,1)", "({0},'MailCustomSubject',NULL,1,1)", "({0},'MailEnableUseSMTP','0',1,1)", "({0},'MailEnableSMTPSSL','0',1,1)", "({0},'MailSMTPPort','0',1,1)", "({0},'MailSMTPServer','',1,1)", "({0},'MailSMTPFromAddress','',1,1)", "({0},'MailSMTPToAddress','',1,1)", "({0},'MailEnableUseSMTPCredentials','0',1,1)", "({0},'MailSMTPUser','',1,1)", "({0},'MailSMTPPassword','',1,1)", "({0},'HideUIAgentSplashScreenOnReconnect','0',1,1)", "({0},'AgentDirectoryServiceTimeoutValue','15000',1,1)", "({0},'AgentBrokerServiceTimeoutValue','15000',1,1)", "({0},'AgentMaxDegreeOfParallelism','0',1,1)", "({0},'AgentPreventExitForAdmins','0',1,1)", "({0},'AgentNetworkResourceCheckTimeoutValue','500',1,1)", "({0},'AgentEnableCrossDomainsUserGroupsSearch','0',1,1)", "({0},'AgentShutdownAfterIdleEnabled','0',1,1)", "({0},'AgentShutdownAfterIdleTime','1800',1,1)", "({0},'AgentShutdownAfterEnabled','0',1,1)", "({0},'AgentShutdownAfter','02:00',1,1)", "({0},'AgentSuspendInsteadOfShutdown','0',1,1)", "({0},'AgentLaunchIncludeGroups','0',1,1)", "({0},'AgentLaunchIncludedGroups','',1,1)", "({0},'DisableAdministrativeRefreshFeedback','0',1,1)")
        "EnvironmentalFields"             = "IdSite,Name,Type,Value,State,RevisionId"
        "EnvironmentalValues"             = @("({0},'HideCommonPrograms',0,'0',1,1)", "({0},'HideControlPanel',0,'0',1,1)", "({0},'RemoveRunFromStartMenu',0,'0',1,1)", "({0},'HideNetworkIcon',0,'0',1,1)", "({0},'HideAdministrativeTools',0,'0',1,1)", "({0},'HideNetworkConnections',0,'0',1,1)", "({0},'HideHelp',0,'0',1,1)", "({0},'HideWindowsUpdate',0,'0',1,1)", "({0},'HideTurnOff',0,'0',1,1)", "({0},'ForceLogoff',0,'0',1,1)", "({0},'HideFind',0,'0',1,1)", "({0},'DisableRegistryEditing',0,'0',1,1)", "({0},'DisableCmd',0,'0',1,1)", "({0},'NoNetConnectDisconnect',0,'0',1,1)", "({0},'Turnoffnotificationareacleanup',1,'0',1,1)", "({0},'LockTaskbar',1,'0',1,1)", "({0},'TurnOffpersonalizedmenus',1,'0',1,1)", "({0},'ClearRecentprogramslist',1,'0',1,1)", "({0},'RemoveContextMenuManageItem',0,'0',1,1)", "({0},'HideSpecifiedDrivesFromExplorer',1,'0',1,1)", "({0},'ExplorerHiddenDrives',1,'',1,1)", "({0},'DisableDragFullWindows',1,'0',1,1)", "({0},'DisableSmoothScroll',1,'0',1,1)", "({0},'DisableCursorBlink',1,'0',1,1)", "({0},'DisableMinAnimate',1,'0',1,1)", "({0},'SetInteractiveDelay',1,'0',1,1)", "({0},'InteractiveDelayValue',1,'40',1,1)", "({0},'EnableAutoEndTasks',1,'0',1,1)", "({0},'WaitToKillAppTimeout',1,'20000',1,1)", "({0},'SetCursorBlinkRate',1,'0',1,1)", "({0},'CursorBlinkRateValue',1,'-1',1,1)", "({0},'SetMenuShowDelay',1,'0',1,1)", "({0},'MenuShowDelayValue',1,'10',1,1)", "({0},'SetVisualStyleFile',1,'0',1,1)", "({0},'VisualStyleFileValue',1,'%windir%\resources\Themes\Aero\aero.msstyles',1,1)", "({0},'SetWallpaper',1,'0',1,1)", "({0},'Wallpaper',1,'',1,1)", "({0},'WallpaperStyle',1,'0',1,1)", "({0},'processEnvironmentalSettings',2,'0',1,1)", "({0},'RestrictSpecifiedDrivesFromExplorer',1,'0',1,1)", "({0},'ExplorerRestrictedDrives',1,'',1,1)", "({0},'HideNetworkInExplorer',1,'0',1,1)", "({0},'HideLibrairiesInExplorer',1,'0',1,1)", "({0},'NoProgramsCPL',0,'0',1,1)", "({0},'NoPropertiesMyComputer',0,'0',1,1)", "({0},'SetSpecificThemeFile',1,'0',1,1)", "({0},'SpecificThemeFileValue',1,'%windir%\resources\Themes\aero.theme',1,1)", "({0},'DisableSpecifiedKnownFolders',1,'0',1,1)", "({0},'DisabledKnownFolders',1,'',1,1)", "({0},'DisableSilentRegedit',0,'0',1,1)", "({0},'DisableCmdScripts',0,'0',1,1)", "({0},'HideDevicesandPrinters',0,'0',1,1)", "({0},'processEnvironmentalSettingsForAdmins',2,'0',1,1)", "({0},'HideSystemClock',0,'0',1,1)", "({0},'SetDesktopBackGroundColor',0,'0',1,1)", "({0},'DesktopBackGroundColor',0,'',1,1)", "({0},'NoMyComputerIcon',1,'0',1,1)", "({0},'NoRecycleBinIcon',1,'0',1,1)", "({0},'NoPropertiesRecycleBin',0,'0',1,1)", "({0},'NoMyDocumentsIcon',1,'0',1,1)", "({0},'NoPropertiesMyDocuments',0,'0',1,1)", "({0},'NoNtSecurity',0,'0',1,1)", "({0},'DisableTaskMgr',0,'0',1,1)", "({0},'RestrictCpl',0,'0',1,1)", "({0},'RestrictCplList',0,'Display',1,1)", "({0},'DisallowCpl',0,'0',1,1)", "({0},'DisallowCplList',0,'',1,1)", "({0},'BootToDesktopInsteadOfStart',1,'0',1,1)", "({0},'DisableTLcorner',0,'0',1,1)", "({0},'DisableCharmsHint',0,'0',1,1)", "({0},'NoTrayContextMenu',0,'0',1,1)", "({0},'NoViewContextMenu',0,'0',1,1)")
        "ItemsFields"                     = "IdSite, Name, DistinguishedName, Description, State, Type, Priority, RevisionId"
        "ItemsValues"                     = @("({0}, 'S-1-1-0', 'Everyone', 'A group that includes all users, even anonymous users and guests. Membership is controlled by the operating system.', 1, 1, 100, 1)", "({0}, 'S-1-5-32-544', 'BUILTIN\Administrators', 'A built-in group. After the initial installation of the operating system, the only member of the group is the Administrator account. When a computer joins a domain, the Domain Admins group is added to the Administrators group. When a server becomes a domain controller, the Enterprise Admins group also is added to the Administrators group.', 1, 1, 100, 1)")
        "KioskFields"                     = "IdSite,Name,Type,Value,State,RevisionId"
        "KioskValues"                     = @("({0},'PowerDontCheckBattery',0,'0',0,1)", "({0},'PowerShutdownAfterIdleTime',0,'1800',0,1)", "({0},'PowerShutdownAfterSpecifiedTime',0,'02:00',0,1)", "({0},'DesktopModeLogOffWebPortal',0,'0',0,1)", "({0},'EndSessionOption',0,'0',0,1)", "({0},'AutologonRegistryForce',0,'0',0,1)", "({0},'AutologonRegistryIgnoreShiftOverride',0,'0',0,1)", "({0},'AutologonPassword',0,'',0,1)", "({0},'AutologonDomain',0,'',0,1)", "({0},'AutologonUserName',0,'',0,1)", "({0},'AutologonEnable',0,'0',0,1)", "({0},'AdministrationHideDisplaySettings',0,'0',0,1)", "({0},'AdministrationHideKeyboardSettings',0,'0',0,1)", "({0},'AdministrationHideMouseSettings',0,'0',0,1)", "({0},'AdministrationHideClientDetails',0,'0',0,1)", "({0},'AdministrationDisableUnlock',0,'0',0,1)", "({0},'AdministrationHideWindowsVersion',0,'0',0,1)", "({0},'AdministrationDisableProgressBar',0,'0',0,1)", "({0},'AdministrationHidePrinterSettings',0,'0',0,1)", "({0},'AdministrationHideLogOffOption',0,'0',0,1)", "({0},'AdministrationHideRestartOption',0,'0',0,1)", "({0},'AdministrationHideShutdownOption',0,'0',0,1)", "({0},'AdministrationHideVolumeSettings',0,'0',0,1)", "({0},'AdministrationHideHomeButton',0,'0',0,1)", "({0},'AdministrationPreLaunchReceiver',0,'0',0,1)", "({0},'AdministrationIgnoreLastLanguage',0,'0',0,1)", "({0},'AdvancedHideTaskbar',0,'0',0,1)", "({0},'AdvancedLockCtrlAltDel',0,'0',0,1)", "({0},'AdvancedLockAltTab',0,'0',0,1)", "({0},'AdvancedFixBrowserRendering',0,'0',0,1)", "({0},'AdvancedLogOffScreenRedirection',0,'0',0,1)", "({0},'AdvancedSuppressScriptErrors',0,'0',0,1)", "({0},'AdvancedShowWifiSettings',0,'0',0,1)", "({0},'AdvancedHideKioskWhileCitrixSession',0,'0',0,1)", "({0},'AdvancedFixSslSites',0,'0',0,1)", "({0},'AdvancedAlwaysShowAdminMenu',0,'0',0,1)", "({0},'AdvancedFixZOrder',0,'0',0,1)", "({0},'ToolsAppsList',0,'',0,1)", "({0},'ToolsEnabled',0,'0',0,1)", "({0},'IsKioskEnabled',0,'0',0,1)", "({0},'SitesIsListEnabled',0,'0',0,1)", "({0},'SitesNamesAndLinks',0,'',0,1)", "({0},'GeneralStartUrl',0,'',0,1)", "({0},'GeneralTitle',0,'',0,1)", "({0},'GeneralShowNavigationButtons',0,'0',0,1)", "({0},'GeneralWindowMode',0,'0',0,1)", "({0},'GeneralClockEnabled',0,'0',0,1)", "({0},'GeneralClockUses12Hours',0,'0',0,1)", "({0},'GeneralUnlockPassword',0,'fLp34dnRI0DK26rJv8Tmqg==',0,1)", "({0},'GeneralEnableLanguageSelect',0,'0',0,1)", "({0},'GeneralAutoHideAppPanel',0,'0',0,1)", "({0},'GeneralEnableAppPanel',0,'0',0,1)", "({0},'ProcessLauncherEnabled',0,'0',0,1)", "({0},'ProcessLauncherApplication',0,'',0,1)", "({0},'ProcessLauncherArgs',0,'',0,1)", "({0},'ProcessLauncherClearLastUsernameVMWare',0,'0',0,1)", "({0},'ProcessLauncherEnableVMWareViewMode',0,'0',0,1)", "({0},'ProcessLauncherEnableMicrosoftRdsMode',0,'0',0,1)", "({0},'ProcessLauncherEnableCitrixMode',0,'0',0,1)", "({0},'SetCitrixReceiverFSOMode',0,'0',0,1)")
        "ParametersFields"                = "IdSite, Name, Value, State, RevisionId"
        "ParametersValues"                = @("({0},'excludedDriveletters','A;B;C;D',1,1)", "({0},'AllowDriveLetterReuse','0',1,1)")
        "PersonaFields"                   = "IdSite,Name,Value,State,RevisionId"
        "PersonaValues"                   = @("({0},'PersonaManagementEnabled','0',1,1)", "({0},'VPEnabled','0',1,1)", "({0},'UploadProfileInterval','10',1,1)", "({0},'SetCentralProfileStore','0',1,1)", "({0},'CentralProfileStore','',1,1)", "({0},'CentralProfileOverride','0',1,1)", "({0},'DeleteLocalProfile','0',1,1)", "({0},'DeleteLocalSettings','0',1,1)", "({0},'RoamLocalSettings','0',1,1)", "({0},'EnableBackgroundDownload','0',1,1)", "({0},'CleanupCLFSFiles','0',1,1)", "({0},'SetDynamicRoamingFiles','0',1,1)", "({0},'DynamicRoamingFiles','',1,1)", "({0},'SetDynamicRoamingFilesExceptions','0',1,1)", "({0},'DynamicRoamingFilesExceptions','',1,1)", "({0},'SetBasicRoamingFiles','0',1,1)", "({0},'BasicRoamingFiles','',1,1)", "({0},'SetBasicRoamingFilesExceptions','0',1,1)", "({0},'BasicRoamingFilesExceptions','',1,1)", "({0},'SetDontRoamFiles','0',1,1)", "({0},'DontRoamFiles','AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1)", "({0},'SetDontRoamFilesExceptions','0',1,1)", "({0},'DontRoamFilesExceptions','',1,1)", "({0},'SetBackgroundLoadFolders','0',1,1)", "({0},'BackgroundLoadFolders','',1,1)", "({0},'SetBackgroundLoadFoldersExceptions','0',1,1)", "({0},'BackgroundLoadFoldersExceptions','',1,1)", "({0},'SetExcludedProcesses','0',1,1)", "({0},'ExcludedProcesses','',1,1)", "({0},'HideOfflineIcon','0',1,1)", "({0},'HideFileCopyProgress','0',1,1)", "({0},'FileCopyMinSize','50',1,1)", "({0},'EnableTrayIconErrorAlerts','0',1,1)", "({0},'SetLogPath','0',1,1)", "({0},'LogPath','',1,1)", "({0},'SetLoggingDestination','0',1,1)", "({0},'LogToFile','0',1,1)", "({0},'LogToDebugPort','0',1,1)", "({0},'SetLoggingFlags','0',1,1)", "({0},'LogError','0',1,1)", "({0},'LogInformation','0',1,1)", "({0},'LogDebug','0',1,1)", "({0},'SetDebugFlags','0',1,1)", "({0},'DebugError','0',1,1)", "({0},'DebugInformation','0',1,1)", "({0},'DebugPorts','0',1,1)", "({0},'AddAdminGroupToRedirectedFolders','0',1,1)", "({0},'RedirectApplicationData','0',1,1)", "({0},'ApplicationDataRedirectedPath','',1,1)", "({0},'RedirectContacts','0',1,1)", "({0},'ContactsRedirectedPath','',1,1)", "({0},'RedirectCookies','0',1,1)", "({0},'CookiesRedirectedPath','',1,1)", "({0},'RedirectDesktop','0',1,1)", "({0},'DesktopRedirectedPath','',1,1)", "({0},'RedirectDownloads','0',1,1)", "({0},'DownloadsRedirectedPath','',1,1)", "({0},'RedirectFavorites','0',1,1)", "({0},'FavoritesRedirectedPath','',1,1)", "({0},'RedirectHistory','0',1,1)", "({0},'HistoryRedirectedPath','',1,1)", "({0},'RedirectLinks','0',1,1)", "({0},'LinksRedirectedPath','',1,1)", "({0},'RedirectMyDocuments','0',1,1)", "({0},'MyDocumentsRedirectedPath','',1,1)", "({0},'RedirectMyMusic','0',1,1)", "({0},'MyMusicRedirectedPath','',1,1)", "({0},'RedirectMyPictures','0',1,1)", "({0},'MyPicturesRedirectedPath','',1,1)", "({0},'RedirectMyVideos','0',1,1)", "({0},'MyVideosRedirectedPath','',1,1)", "({0},'RedirectNetworkNeighborhood','0',1,1)", "({0},'NetworkNeighborhoodRedirectedPath','',1,1)", "({0},'RedirectPrinterNeighborhood','0',1,1)", "({0},'PrinterNeighborhoodRedirectedPath','',1,1)", "({0},'RedirectRecentItems','0',1,1)", "({0},'RecentItemsRedirectedPath','',1,1)", "({0},'RedirectSavedGames','0',1,1)", "({0},'SavedGamesRedirectedPath','',1,1)", "({0},'RedirectSearches','0',1,1)", "({0},'SearchesRedirectedPath','',1,1)", "({0},'RedirectSendTo','0',1,1)", "({0},'SendToRedirectedPath','',1,1)", "({0},'RedirectStartMenu','0',1,1)", "({0},'StartMenuRedirectedPath','',1,1)", "({0},'RedirectStartupItems','0',1,1)", "({0},'StartupItemsRedirectedPath','',1,1)", "({0},'RedirectTemplates','0',1,1)", "({0},'TemplatesRedirectedPath','',1,1)", "({0},'RedirectTemporaryInternetFiles','0',1,1)", "({0},'TemporaryInternetFilesRedirectedPath','',1,1)", "({0},'SetFRExclusions','0',1,1)", "({0},'FRExclusions','',1,1)", "({0},'SetFRExclusionsExceptions','0',1,1)", "({0},'FRExclusionsExceptions','',1,1)")
        "SystemMonitoringFields"          = "IdSite,Name,Value,State,RevisionId"
        "SystemMonitoringValues"          = @("({0},'EnableSystemMonitoring','0',1,1)", "({0},'EnableGlobalSystemMonitoring','0',1,1)", "({0},'EnableProcessActivityMonitoring','0',1,1)", "({0},'EnableUserExperienceMonitoring','0',1,1)", "({0},'LocalDatabaseRetentionPeriod','3',1,1)", "({0},'LocalDataUploadFrequency','4',1,1)", "({0},'EnableApplicationReportsWindows2K3XPCompliance','0',1,1)", "({0},'ExcludeProcessesFromApplicationReports','1',1,1)", "({0},'ExcludedProcessesFromApplicationReports','dwm;taskhost;vmtoolsd;winlogon;csrss;wisptis;dllhost;consent;msiexec;userinit;LogonUI;mscorsvw;SearchProtocolHost;Rundll32;explorer;regsvr32;WmiPrvSE;services;smss;SearchFilterHost;lsass;svchost;lsm;msdtc;wininit;VGAuthService;SearchIndexer;spoolsv;vmtoolsd;vmacthlp;audiodg;VMwareResolutionSet;mobsync;wsqmcons;schtasks;Defrag;conhost;VSSVC;sdclt;MpCmdRun;WMIADAP;encsvc;wfshell;CpSvc;VDARedirector;CpSvc64;SemsService;ctxrdr;PicaSvc2;encsvc;GfxMgr;PicaSessionAgent;CtxGfx;PicaTwiHost;PicaUserAgent;VDARedirector;PicaShell;PicaEuemRelay;CtxMtHost;CtxSensLoader;ssonsvr;concentr;wfcrun32;pnamain;redirector;concentr;pnamain;pnagent;IMAAdvanceSrv;mfcom;ctxxmlss;Citrix.XenApp.Commands.Remoting.Service;HCAService;cmstart;startssonsvr;ctxhide;mmvdhost;runonce;rdpclip;TabTip;InputPersonalization;TabTip32;TSTheme;ngen;XTE;CtxSvcHost;OSPPSVC;TelemetryService;CtxAudioService;picatzrestore;CheckTermSrv;IMATest;RequestTicket;csc;cvtres;ssoncom;UpmUserMsg;CtxPvD;MultimediaRedirector;gpscript;shutdown;splwow64',1,1)", "({0},'EnableStrictPrivacy','0',1,1)", "({0},'BusinessDayStartHour','8',1,1)", "({0},'BusinessDayEndHour','19',1,1)", "({0},'ReportsBootTimeMinimum','5',1,1)", "({0},'ReportsLoginTimeMinimum','5',1,1)", "({0},'EnableWorkDaysFiltering','1',1,1)", "({0},'WorkDaysFilter','1;1;1;1;1;0;0',1,1)")
        "SystemUtilitiesFields"           = "IdSite,Name,Type,Value,State,RevisionId"
        "SystemUtilitiesValues"           = @("({0},'EnableFastLogoff',0,'0',1,1)", "({0},'ExcludeGroupsFromFastLogoff',0,'0',1,1)", "({0},'FastLogoffExcludedGroups',0,NULL,1,1)", "({0},'EnableCPUSpikesProtection',1,'0',1,1)", "({0},'SpikesProtectionCPUUsageLimitPercent',1,'70',1,1)", "({0},'SpikesProtectionCPUUsageLimitSampleTime',1,'30',1,1)", "({0},'SpikesProtectionIdlePriorityConstraintTime',1,'180',1,1)", "({0},'ExcludeProcessesFromCPUSpikesProtection',1,'0',1,1)", "({0},'CPUSpikesProtectionExcludedProcesses',1,NULL,1,1)", "({0},'EnableMemoryWorkingSetOptimization',2,'0',1,1)", "({0},'MemoryWorkingSetOptimizationIdleSampleTime',2,'120',1,1)", "({0},'ExcludeProcessesFromMemoryWorkingSetOptimization',2,'0',1,1)", "({0},'MemoryWorkingSetOptimizationExcludedProcesses',2,NULL,1,1)", "({0},'EnableProcessesBlackListing',3,'0',1,1)", "({0},'ProcessesManagementBlackListedProcesses',3,NULL,1,1)", "({0},'ProcessesManagementBlackListExcludeLocalAdministrators',3,'0',1,1)", "({0},'ProcessesManagementBlackListExcludeSpecifiedGroups',3,'0',1,1)", "({0},'ProcessesManagementBlackListExcludedSpecifiedGroupsList',3,'',1,1)", "({0},'EnableProcessesWhiteListing',3,'0',1,1)", "({0},'ProcessesManagementWhiteListedProcesses',3,NULL,1,1)", "({0},'ProcessesManagementWhiteListExcludeLocalAdministrators',3,'0',1,1)", "({0},'ProcessesManagementWhiteListExcludeSpecifiedGroups',3,'0',1,1)", "({0},'ProcessesManagementWhiteListExcludedSpecifiedGroupsList',3,'',1,1)", "({0},'EnableProcessesManagement',3,'0',1,1)", "({0},'EnableProcessesClamping',4,'0',1,1)", "({0},'ProcessesClampingList',4,NULL,1,1)", "({0},'EnableProcessesAffinity',5,'0',1,1)", "({0},'ProcessesAffinityList',5,NULL,1,1)", "({0},'EnableProcessesIoPriority',6,'0',1,1)", "({0},'ProcessesIoPriorityList',6,NULL,1,1)", "({0},'EnableProcessesCpuPriority',7,'0',1,1)", "({0},'ProcessesCpuPriorityList',7,NULL,1,1)", "({0},'MemoryWorkingSetOptimizationIdleStateLimitPercent',2,'1',1,1)", "({0},'EnableIntelligentCpuOptimization',1,'0',1,1)", "({0},'EnableIntelligentIoOptimization',1,'0',1,1)", "({0},'SpikesProtectionLimitCPUCoreNumber',1,'0',1,1)", "({0},'SpikesProtectionCPUCoreLimit',1,'1',1,1)", "({0},'AppLockerControllerManagement',1,'1',1,1)", "({0},'AppLockerControllerReplaceModeOn',1,'1',1,1)")
        "UPMFields"                       = "IdSite,Name,Value,State,RevisionId"
        "UPMValues"                       = @("({0},'UPMManagementEnabled','0',1,1)", "({0},'ServiceActive','0',1,1)", "({0},'SetProcessedGroups','0',1,1)", "({0},'ProcessedGroupsList','',1,1)", "({0},'ProcessAdmins','0',1,1)", "({0},'SetPathToUserStore','0',1,1)", "({0},'PathToUserStore','Windows',1,1)", "({0},'PSMidSessionWriteBack','0',1,1)", "({0},'OfflineSupport','0',1,1)", "({0},'DeleteCachedProfilesOnLogoff','0',1,1)", "({0},'SetMigrateWindowsProfilesToUserStore','0',1,1)", "({0},'MigrateWindowsProfilesToUserStore','1',1,1)", "({0},'SetLocalProfileConflictHandling','0',1,1)", "({0},'LocalProfileConflictHandling','1',1,1)", "({0},'SetTemplateProfilePath','0',1,1)", "({0},'TemplateProfilePath','',1,1)", "({0},'TemplateProfileOverridesLocalProfile','0',1,1)", "({0},'TemplateProfileOverridesRoamingProfile','0',1,1)", "({0},'SetLoadRetries','0',1,1)", "({0},'LoadRetries','5',1,1)", "({0},'SetUSNDBPath','0',1,1)", "({0},'USNDBPath','',1,1)", "({0},'XenAppOptimizationEnabled','0',1,1)", "({0},'XenAppOptimizationPath','',1,1)", "({0},'ProcessCookieFiles','0',1,1)", "({0},'DeleteRedirectedFolders','0',1,1)", "({0},'LoggingEnabled','0',1,1)", "({0},'SetLogLevels','0',1,1)", "({0},'LogLevels','0;0;0;0;0;0;0;0;0;0;0',1,1)", "({0},'SetMaxLogSize','0',1,1)", "({0},'MaxLogSize','1048576',1,1)", "({0},'SetPathToLogFile','0',1,1)", "({0},'PathToLogFile','',1,1)", "({0},'SetExclusionListRegistry','0',1,1)", "({0},'ExclusionListRegistry','',1,1)", "({0},'SetInclusionListRegistry','0',1,1)", "({0},'InclusionListRegistry','',1,1)", "({0},'SetSyncExclusionListFiles','0',1,1)", "({0},'SyncExclusionListFiles','AppData\Roaming\Microsoft\Windows\Start Menu\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Startup\Desktop.ini',1,1)", "({0},'SetSyncExclusionListDir','0',1,1)", "({0},'SyncExclusionListDir','`$Recycle.Bin;AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1)", "({0},'SetSyncDirList','0',1,1)", "({0},'SyncDirList','',1,1)", "({0},'SetSyncFileList','0',1,1)", "({0},'SyncFileList','',1,1)", "({0},'SetMirrorFoldersList','0',1,1)", "({0},'MirrorFoldersList','',1,1)", "({0},'SetLargeFileHandlingList','0',1,1)", "({0},'LargeFileHandlingList','',1,1)", "({0},'PSEnabled','0',1,1)", "({0},'PSAlwaysCache','0',1,1)", "({0},'PSAlwaysCacheSize','0',1,1)", "({0},'SetPSPendingLockTimeout','0',1,1)", "({0},'PSPendingLockTimeout','1',1,1)", "({0},'SetPSUserGroupsList','0',1,1)", "({0},'PSUserGroupsList','',1,1)", "({0},'CPEnabled','0',1,1)", "({0},'SetCPUserGroupList','0',1,1)", "({0},'CPUserGroupList','',1,1)", "({0},'SetCPSchemaPath','0',1,1)", "({0},'CPSchemaPath','',1,1)", "({0},'SetCPPath','0',1,1)", "({0},'CPPath','',1,1)", "({0},'CPMigrationFromBaseProfileToCPStore','0',1,1)", "({0},'SetExcludedGroups','0',1,1)", "({0},'ExcludedGroupsList','',1,1)", "({0},'DisableDynamicConfig','0',1,1)", "({0},'LogoffRatherThanTempProfile','0',1,1)", "({0},'SetProfileDeleteDelay','0',1,1)", "({0},'ProfileDeleteDelay','0',1,1)", "({0},'TemplateProfileIsMandatory','0',1,1)", "({0},'PSMidSessionWriteBackReg','0',1,1)", "({0},'CEIPEnabled','1',1,1)", "({0},'LastKnownGoodRegistry','0',1,1)", "({0},'EnableDefaultExclusionListRegistry','0',1,1)", "({0},'ExclusionDefaultRegistry01','1',1,1)", "({0},'ExclusionDefaultRegistry02','1',1,1)", "({0},'ExclusionDefaultRegistry03','1',1,1)", "({0},'EnableDefaultExclusionListDirectories','0',1,1)", "({0},'ExclusionDefaultDir01','1',1,1)", "({0},'ExclusionDefaultDir02','1',1,1)", "({0},'ExclusionDefaultDir03','1',1,1)", "({0},'ExclusionDefaultDir04','1',1,1)", "({0},'ExclusionDefaultDir05','1',1,1)", "({0},'ExclusionDefaultDir06','1',1,1)", "({0},'ExclusionDefaultDir07','1',1,1)", "({0},'ExclusionDefaultDir08','1',1,1)", "({0},'ExclusionDefaultDir09','1',1,1)", "({0},'ExclusionDefaultDir10','1',1,1)", "({0},'ExclusionDefaultDir11','1',1,1)", "({0},'ExclusionDefaultDir12','1',1,1)", "({0},'ExclusionDefaultDir13','1',1,1)", "({0},'ExclusionDefaultDir14','1',1,1)", "({0},'ExclusionDefaultDir15','1',1,1)", "({0},'ExclusionDefaultDir16','1',1,1)", "({0},'ExclusionDefaultDir17','1',1,1)", "({0},'ExclusionDefaultDir18','1',1,1)", "({0},'ExclusionDefaultDir19','1',1,1)", "({0},'ExclusionDefaultDir20','1',1,1)", "({0},'ExclusionDefaultDir21','1',1,1)", "({0},'ExclusionDefaultDir22','1',1,1)", "({0},'ExclusionDefaultDir23','1',1,1)", "({0},'ExclusionDefaultDir24','1',1,1)", "({0},'ExclusionDefaultDir25','1',1,1)", "({0},'ExclusionDefaultDir26','1',1,1)", "({0},'ExclusionDefaultDir27','1',1,1)", "({0},'ExclusionDefaultDir28','1',1,1)", "({0},'ExclusionDefaultDir29','1',1,1)", "({0},'ExclusionDefaultDir30','1',1,1)", "({0},'EnableStreamingExclusionList','0',1,1)", "({0},'StreamingExclusionList','',1,1)", "({0},'EnableLogonExclusionCheck','0',1,1)", "({0},'LogonExclusionCheck','0',1,1)", "({0},'OutlookSearchRoamingEnabled','0',1,1)")
        "USVFields"                       = "IdSite,Name,Type,Value,State,RevisionId"
        "USVValues"                       = @("({0},'processUSVConfiguration',0,'0',1,1)", "({0},'processUSVConfigurationForAdmins',0,'0',1,1)", "({0},'SetWindowsRoamingProfilesPath',1,'0',1,1)", "({0},'WindowsRoamingProfilesPath',1,'',1,1)", "({0},'SetRDSRoamingProfilesPath',1,'0',1,1)", "({0},'RDSRoamingProfilesPath',1,'',1,1)", "({0},'SetRDSHomeDrivePath',1,'0',1,1)", "({0},'RDSHomeDrivePath',1,'',1,1)", "({0},'RDSHomeDriveLetter',1,'Z:',1,1)", "({0},'SetRoamingProfilesFoldersExclusions',2,'0',1,1)", "({0},'RoamingProfilesFoldersExclusions',2,'AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp',1,1)", "({0},'DeleteRoamingCachedProfiles',1,'0',1,1)", "({0},'AddAdminGroupToRUP',1,'0',1,1)", "({0},'CompatibleRUPSecurity',1,'0',1,1)", "({0},'DisableSlowLinkDetect',1,'0',1,1)", "({0},'SlowLinkProfileDefault',1,'0',1,1)", "({0},'processFoldersRedirectionConfiguration',3,'0',1,1)", "({0},'DeleteLocalRedirectedFolders',3,'0',1,1)", "({0},'processDesktopRedirection',3,'0',1,1)", "({0},'DesktopRedirectedPath',3,'',1,1)", "({0},'processStartMenuRedirection',3,'0',1,1)", "({0},'StartMenuRedirectedPath',3,'',1,1)", "({0},'processPersonalRedirection',3,'0',1,1)", "({0},'PersonalRedirectedPath',3,'',1,1)", "({0},'processPicturesRedirection',3,'0',1,1)", "({0},'PicturesRedirectedPath',3,'',1,1)", "({0},'MyPicturesFollowsDocuments',3,'0',1,1)", "({0},'processMusicRedirection',3,'0',1,1)", "({0},'MusicRedirectedPath',3,'',1,1)", "({0},'MyMusicFollowsDocuments',3,'0',1,1)", "({0},'processVideoRedirection',3,'0',1,1)", "({0},'VideoRedirectedPath',3,'',1,1)", "({0},'MyVideoFollowsDocuments',3,'0',1,1)", "({0},'processFavoritesRedirection',3,'0',1,1)", "({0},'FavoritesRedirectedPath',3,'',1,1)", "({0},'processAppDataRedirection',3,'0',1,1)", "({0},'AppDataRedirectedPath',3,'',1,1)", "({0},'processContactsRedirection',3,'0',1,1)", "({0},'ContactsRedirectedPath',3,'',1,1)", "({0},'processDownloadsRedirection',3,'0',1,1)", "({0},'DownloadsRedirectedPath',3,'',1,1)", "({0},'processLinksRedirection',3,'0',1,1)", "({0},'LinksRedirectedPath',3,'',1,1)", "({0},'processSearchesRedirection',3,'0',1,1)", "({0},'SearchesRedirectedPath',3,'',1,1)")

        "CleanupTables"                   = @("VUEMApps","VUEMPrinters","VUEMNetDrives","VUEMVirtualDrives","VUEMRegValues","VUEMEnvVariables","VUEMPorts","VUEMIniFilesOps","VUEMExtTasks","VUEMFileSystemOps","VUEMUserDSNs","VUEMFileAssocs","VUEMActionsGroups","VUEMFiltersRules","VUEMFiltersConditions","VUEMItems","VUEMUserStatistics","VUEMAgentStatistics","VUEMSystemMonitoringData","VUEMActivityMonitoringData","VUEMUserExperienceMonitoringData","VUEMResourcesOptimizationData","VUEMParameters","VUEMAgentSettings","VUEMSystemUtilities","VUEMEnvironmentalSettings","VUEMUPMSettings","VUEMPersonaSettings","VUEMUSVSettings","VUEMKioskSettings","VUEMSystemMonitoringSettings","VUEMTasks","VUEMStorefrontSettings","VUEMChangesLog","VUEMAgentsLog","VUEMADObjects","AppLockerSettings","GroupPolicyObjects","GroupPolicyGlobalSettings","VUEMSites")
    }
    "1906" = @{ 
        "ApplockerFields"                 = "IdSite, State, RevisionId, Value, Setting"
        "ApplockerValues"                 = @("({0}, 1, 1, 0, 'EnableProcessesAppLocker')", "({0}, 1, 1, 0, 'EnableDLLRuleCollection')", "({0}, 1, 1, 0, 'CollectionExeEnforcementState')", "({0}, 1, 1, 0, 'CollectionMsiEnforcementState')", "({0}, 1, 1, 0, 'CollectionScriptEnforcementState')", "({0}, 1, 1, 0, 'CollectionAppxEnforcementState')", "({0}, 1, 1, 0, 'CollectionDllEnforcementState')")
        "GroupPolicyGlobalSettingsFields" = "IdSite, Name, Value"
        "GroupPolicyGlobalSettingsValues" = @("({0}, 'EnableGroupPolicyEnforcement', '0')")
        "AgentSettingsFields"             = "IdSite,Name,Value,State,RevisionId"
        "AgentSettingsValues"             = @("({0},'OfflineModeEnabled','0',1,1)", "({0},'UseCacheEvenIfOnline','0',1,1)", "({0},'processVUEMApps','0',1,1)", "({0},'processVUEMPrinters','0',1,1)", "({0},'processVUEMNetDrives','0',1,1)", "({0},'processVUEMVirtualDrives','0',1,1)", "({0},'processVUEMRegValues','0',1,1)", "({0},'processVUEMEnvVariables','0',1,1)", "({0},'processVUEMPorts','0',1,1)", "({0},'processVUEMIniFilesOps','0',1,1)", "({0},'processVUEMExtTasks','0',1,1)", "({0},'processVUEMFileSystemOps','0',1,1)", "({0},'processVUEMUserDSNs','0',1,1)", "({0},'processVUEMFileAssocs','0',1,1)", "({0},'UIAgentSplashScreenBackGround','',1,1)", "({0},'UIAgentLoadingCircleColor','',1,1)", "({0},'UIAgentLbl1TextColor','',1,1)", "({0},'UIAgentHelpLink','',1,1)", "({0},'AgentServiceDebugMode','0',1,1)", "({0},'LaunchVUEMAgentOnLogon','0',1,1)", "({0},'ProcessVUEMAgentLaunchForAdmins','0',1,1)", "({0},'LaunchVUEMAgentOnReconnect','0',1,1)", "({0},'EnableVirtualDesktopCompatibility','0',1,1)", "({0},'VUEMAgentType','UI',1,1)", "({0},'VUEMAgentDesktopsExtraLaunchDelay','0',1,1)", "({0},'VUEMAgentCacheRefreshDelay','30',1,1)", "({0},'VUEMAgentSQLSettingsRefreshDelay','15',1,1)", "({0},'DeleteDesktopShortcuts','0',1,1)", "({0},'DeleteStartMenuShortcuts','0',1,1)", "({0},'DeleteQuickLaunchShortcuts','0',1,1)", "({0},'DeleteNetworkDrives','0',1,1)", "({0},'DeleteNetworkPrinters','0',1,1)", "({0},'PreserveAutocreatedPrinters','0',1,1)", "({0},'PreserveSpecificPrinters','0',1,1)", "({0},'SpecificPreservedPrinters','PDFCreator;PDFMail;Acrobat Distiller;Amyuni',1,1)", "({0},'EnableAgentLogging','1',1,1)", "({0},'AgentLogFile','%USERPROFILE%\Citrix WEM Agent.log',1,1)", "({0},'AgentDebugMode','0',1,1)", "({0},'RefreshEnvironmentSettings','0',1,1)", "({0},'RefreshSystemSettings','0',1,1)", "({0},'RefreshDesktop','0',1,1)", "({0},'RefreshAppearance','0',1,1)", "({0},'AgentExitForAdminsOnly','1',1,1)", "({0},'AgentAllowUsersToManagePrinters','0',1,1)", "({0},'DeleteTaskBarPinnedShortcuts','0',1,1)", "({0},'DeleteStartMenuPinnedShortcuts','0',1,1)", "({0},'InitialEnvironmentCleanUp','0',1,1)", "({0},'aSyncVUEMAppsProcessing','0',1,1)", "({0},'aSyncVUEMPrintersProcessing','0',1,1)", "({0},'aSyncVUEMNetDrivesProcessing','0',1,1)", "({0},'aSyncVUEMVirtualDrivesProcessing','0',1,1)", "({0},'aSyncVUEMRegValuesProcessing','0',1,1)", "({0},'aSyncVUEMEnvVariablesProcessing','0',1,1)", "({0},'aSyncVUEMPortsProcessing','0',1,1)", "({0},'aSyncVUEMIniFilesOpsProcessing','0',1,1)", "({0},'aSyncVUEMExtTasksProcessing','0',1,1)", "({0},'aSyncVUEMFileSystemOpsProcessing','0',1,1)", "({0},'aSyncVUEMUserDSNsProcessing','0',1,1)", "({0},'aSyncVUEMFileAssocsProcessing','0',1,1)", "({0},'byPassie4uinitCheck','0',1,1)", "({0},'UIAgentCustomLink','',1,1)", "({0},'enforceProcessVUEMApps','0',1,1)", "({0},'enforceProcessVUEMPrinters','0',1,1)", "({0},'enforceProcessVUEMNetDrives','0',1,1)", "({0},'enforceProcessVUEMVirtualDrives','0',1,1)", "({0},'enforceProcessVUEMRegValues','0',1,1)", "({0},'enforceProcessVUEMEnvVariables','0',1,1)", "({0},'enforceProcessVUEMPorts','0',1,1)", "({0},'enforceProcessVUEMIniFilesOps','0',1,1)", "({0},'enforceProcessVUEMExtTasks','0',1,1)", "({0},'enforceProcessVUEMFileSystemOps','0',1,1)", "({0},'enforceProcessVUEMUserDSNs','0',1,1)", "({0},'enforceProcessVUEMFileAssocs','0',1,1)", "({0},'revertUnassignedVUEMApps','0',1,1)", "({0},'revertUnassignedVUEMPrinters','0',1,1)", "({0},'revertUnassignedVUEMNetDrives','0',1,1)", "({0},'revertUnassignedVUEMVirtualDrives','0',1,1)", "({0},'revertUnassignedVUEMRegValues','0',1,1)", "({0},'revertUnassignedVUEMEnvVariables','0',1,1)", "({0},'revertUnassignedVUEMPorts','0',1,1)", "({0},'revertUnassignedVUEMIniFilesOps','0',1,1)", "({0},'revertUnassignedVUEMExtTasks','0',1,1)", "({0},'revertUnassignedVUEMFileSystemOps','0',1,1)", "({0},'revertUnassignedVUEMUserDSNs','0',1,1)", "({0},'revertUnassignedVUEMFileAssocs','0',1,1)", "({0},'AgentLaunchExcludeGroups','0',1,1)", "({0},'AgentLaunchExcludedGroups','',1,1)", "({0},'InitialDesktopUICleaning','0',1,1)", "({0},'EnableUIAgentAutomaticRefresh','0',1,1)", "({0},'UIAgentAutomaticRefreshDelay','30',1,1)", "({0},'AgentAllowUsersToManageApplications','0',1,1)", "({0},'HideUIAgentIconInPublishedApplications','0',1,1)", "({0},'ExecuteOnlyCmdAgentInPublishedApplications','0',1,1)", "({0},'enforceVUEMAppsFiltersProcessing','0',1,1)", "({0},'enforceVUEMPrintersFiltersProcessing','0',1,1)", "({0},'enforceVUEMNetDrivesFiltersProcessing','0',1,1)", "({0},'enforceVUEMVirtualDrivesFiltersProcessing','0',1,1)", "({0},'enforceVUEMRegValuesFiltersProcessing','0',1,1)", "({0},'enforceVUEMEnvVariablesFiltersProcessing','0',1,1)", "({0},'enforceVUEMPortsFiltersProcessing','0',1,1)", "({0},'enforceVUEMIniFilesOpsFiltersProcessing','0',1,1)", "({0},'enforceVUEMExtTasksFiltersProcessing','0',1,1)", "({0},'enforceVUEMFileSystemOpsFiltersProcessing','0',1,1)", "({0},'enforceVUEMUserDSNsFiltersProcessing','0',1,1)", "({0},'enforceVUEMFileAssocsFiltersProcessing','0',1,1)", "({0},'checkAppShortcutExistence','0',1,1)", "({0},'appShortcutExpandEnvironmentVariables','0',1,1)", "({0},'RefreshOnEnvironmentalSettingChange','1',1,1)", "({0},'HideUIAgentSplashScreen','0',1,1)", "({0},'processVUEMAppsOnReconnect','0',1,1)", "({0},'processVUEMPrintersOnReconnect','0',1,1)", "({0},'processVUEMNetDrivesOnReconnect','0',1,1)", "({0},'processVUEMVirtualDrivesOnReconnect','0',1,1)", "({0},'processVUEMRegValuesOnReconnect','0',1,1)", "({0},'processVUEMEnvVariablesOnReconnect','0',1,1)", "({0},'processVUEMPortsOnReconnect','0',1,1)", "({0},'processVUEMIniFilesOpsOnReconnect','0',1,1)", "({0},'processVUEMExtTasksOnReconnect','0',1,1)", "({0},'processVUEMFileSystemOpsOnReconnect','0',1,1)", "({0},'processVUEMUserDSNsOnReconnect','0',1,1)", "({0},'processVUEMFileAssocsOnReconnect','0',1,1)", "({0},'AgentAllowScreenCapture','0',1,1)", "({0},'AgentScreenCaptureEnableSendSupportEmail','0',1,1)", "({0},'AgentScreenCaptureSupportEmailAddress','',1,1)", "({0},'AgentScreenCaptureSupportEmailTemplate','',1,1)", "({0},'AgentEnableApplicationsShortcuts','0',1,1)", "({0},'UIAgentSkinName','Seven',1,1)", "({0},'HideUIAgentSplashScreenInPublishedApplications','0',1,1)", "({0},'MailCustomSubject',NULL,1,1)", "({0},'MailEnableUseSMTP','0',1,1)", "({0},'MailEnableSMTPSSL','0',1,1)", "({0},'MailSMTPPort','0',1,1)", "({0},'MailSMTPServer','',1,1)", "({0},'MailSMTPFromAddress','',1,1)", "({0},'MailSMTPToAddress','',1,1)", "({0},'MailEnableUseSMTPCredentials','0',1,1)", "({0},'MailSMTPUser','',1,1)", "({0},'MailSMTPPassword','',1,1)", "({0},'HideUIAgentSplashScreenOnReconnect','0',1,1)", "({0},'AgentDirectoryServiceTimeoutValue','15000',1,1)", "({0},'AgentBrokerServiceTimeoutValue','15000',1,1)", "({0},'AgentMaxDegreeOfParallelism','0',1,1)", "({0},'ConnectionStateChangeNotificationEnabled','0',1,1)", "({0},'AgentPreventExitForAdmins','0',1,1)", "({0},'AgentNetworkResourceCheckTimeoutValue','500',1,1)", "({0},'AgentEnableCrossDomainsUserGroupsSearch','0',1,1)", "({0},'AgentShutdownAfterIdleEnabled','0',1,1)", "({0},'AgentShutdownAfterIdleTime','1800',1,1)", "({0},'AgentShutdownAfterEnabled','0',1,1)", "({0},'AgentShutdownAfter','02:00',1,1)", "({0},'AgentSuspendInsteadOfShutdown','0',1,1)", "({0},'AgentLaunchIncludeGroups','0',1,1)", "({0},'AgentLaunchIncludedGroups','',1,1)", "({0},'DisableAdministrativeRefreshFeedback','0',1,1)")
        "EnvironmentalFields"             = "IdSite,Name,Type,Value,State,RevisionId"
        "EnvironmentalValues"             = @("({0},'HideCommonPrograms',0,'0',1,1)", "({0},'HideControlPanel',0,'0',1,1)", "({0},'RemoveRunFromStartMenu',0,'0',1,1)", "({0},'HideNetworkIcon',0,'0',1,1)", "({0},'HideAdministrativeTools',0,'0',1,1)", "({0},'HideNetworkConnections',0,'0',1,1)", "({0},'HideHelp',0,'0',1,1)", "({0},'HideWindowsUpdate',0,'0',1,1)", "({0},'HideTurnOff',0,'0',1,1)", "({0},'ForceLogoff',0,'0',1,1)", "({0},'HideFind',0,'0',1,1)", "({0},'DisableRegistryEditing',0,'0',1,1)", "({0},'DisableCmd',0,'0',1,1)", "({0},'NoNetConnectDisconnect',0,'0',1,1)", "({0},'Turnoffnotificationareacleanup',1,'0',1,1)", "({0},'LockTaskbar',1,'0',1,1)", "({0},'TurnOffpersonalizedmenus',1,'0',1,1)", "({0},'ClearRecentprogramslist',1,'0',1,1)", "({0},'RemoveContextMenuManageItem',0,'0',1,1)", "({0},'HideSpecifiedDrivesFromExplorer',1,'0',1,1)", "({0},'ExplorerHiddenDrives',1,'',1,1)", "({0},'DisableDragFullWindows',1,'0',1,1)", "({0},'DisableSmoothScroll',1,'0',1,1)", "({0},'DisableCursorBlink',1,'0',1,1)", "({0},'DisableMinAnimate',1,'0',1,1)", "({0},'SetInteractiveDelay',1,'0',1,1)", "({0},'InteractiveDelayValue',1,'40',1,1)", "({0},'EnableAutoEndTasks',1,'0',1,1)", "({0},'WaitToKillAppTimeout',1,'20000',1,1)", "({0},'SetCursorBlinkRate',1,'0',1,1)", "({0},'CursorBlinkRateValue',1,'-1',1,1)", "({0},'SetMenuShowDelay',1,'0',1,1)", "({0},'MenuShowDelayValue',1,'10',1,1)", "({0},'SetVisualStyleFile',1,'0',1,1)", "({0},'VisualStyleFileValue',1,'%windir%\resources\Themes\Aero\aero.msstyles',1,1)", "({0},'SetWallpaper',1,'0',1,1)", "({0},'Wallpaper',1,'',1,1)", "({0},'WallpaperStyle',1,'0',1,1)", "({0},'processEnvironmentalSettings',2,'0',1,1)", "({0},'RestrictSpecifiedDrivesFromExplorer',1,'0',1,1)", "({0},'ExplorerRestrictedDrives',1,'',1,1)", "({0},'HideNetworkInExplorer',1,'0',1,1)", "({0},'HideLibrairiesInExplorer',1,'0',1,1)", "({0},'NoProgramsCPL',0,'0',1,1)", "({0},'NoPropertiesMyComputer',0,'0',1,1)", "({0},'SetSpecificThemeFile',1,'0',1,1)", "({0},'SpecificThemeFileValue',1,'%windir%\resources\Themes\aero.theme',1,1)", "({0},'DisableSpecifiedKnownFolders',1,'0',1,1)", "({0},'DisabledKnownFolders',1,'',1,1)", "({0},'DisableSilentRegedit',0,'0',1,1)", "({0},'DisableCmdScripts',0,'0',1,1)", "({0},'HideDevicesandPrinters',0,'0',1,1)", "({0},'processEnvironmentalSettingsForAdmins',2,'0',1,1)", "({0},'HideSystemClock',0,'0',1,1)", "({0},'SetDesktopBackGroundColor',0,'0',1,1)", "({0},'DesktopBackGroundColor',0,'',1,1)", "({0},'NoMyComputerIcon',1,'0',1,1)", "({0},'NoRecycleBinIcon',1,'0',1,1)", "({0},'NoPropertiesRecycleBin',0,'0',1,1)", "({0},'NoMyDocumentsIcon',1,'0',1,1)", "({0},'NoPropertiesMyDocuments',0,'0',1,1)", "({0},'NoNtSecurity',0,'0',1,1)", "({0},'DisableTaskMgr',0,'0',1,1)", "({0},'RestrictCpl',0,'0',1,1)", "({0},'RestrictCplList',0,'Display',1,1)", "({0},'DisallowCpl',0,'0',1,1)", "({0},'DisallowCplList',0,'',1,1)", "({0},'BootToDesktopInsteadOfStart',1,'0',1,1)", "({0},'DisableTLcorner',0,'0',1,1)", "({0},'DisableCharmsHint',0,'0',1,1)", "({0},'NoTrayContextMenu',0,'0',1,1)", "({0},'NoViewContextMenu',0,'0',1,1)")
        "ItemsFields"                     = "IdSite, Name, DistinguishedName, Description, State, Type, Priority, RevisionId"
        "ItemsValues"                     = @("({0}, 'S-1-1-0', 'Everyone', 'A group that includes all users, even anonymous users and guests. Membership is controlled by the operating system.', 1, 1, 100, 1)", "({0}, 'S-1-5-32-544', 'BUILTIN\Administrators', 'A built-in group. After the initial installation of the operating system, the only member of the group is the Administrator account. When a computer joins a domain, the Domain Admins group is added to the Administrators group. When a server becomes a domain controller, the Enterprise Admins group also is added to the Administrators group.', 1, 1, 100, 1)")
        "KioskFields"                     = "IdSite,Name,Type,Value,State,RevisionId"
        "KioskValues"                     = @("({0},'PowerDontCheckBattery',0,'0',0,1)", "({0},'PowerShutdownAfterIdleTime',0,'1800',0,1)", "({0},'PowerShutdownAfterSpecifiedTime',0,'02:00',0,1)", "({0},'DesktopModeLogOffWebPortal',0,'0',0,1)", "({0},'EndSessionOption',0,'0',0,1)", "({0},'AutologonRegistryForce',0,'0',0,1)", "({0},'AutologonRegistryIgnoreShiftOverride',0,'0',0,1)", "({0},'AutologonPassword',0,'',0,1)", "({0},'AutologonDomain',0,'',0,1)", "({0},'AutologonUserName',0,'',0,1)", "({0},'AutologonEnable',0,'0',0,1)", "({0},'AdministrationHideDisplaySettings',0,'0',0,1)", "({0},'AdministrationHideKeyboardSettings',0,'0',0,1)", "({0},'AdministrationHideMouseSettings',0,'0',0,1)", "({0},'AdministrationHideClientDetails',0,'0',0,1)", "({0},'AdministrationDisableUnlock',0,'0',0,1)", "({0},'AdministrationHideWindowsVersion',0,'0',0,1)", "({0},'AdministrationDisableProgressBar',0,'0',0,1)", "({0},'AdministrationHidePrinterSettings',0,'0',0,1)", "({0},'AdministrationHideLogOffOption',0,'0',0,1)", "({0},'AdministrationHideRestartOption',0,'0',0,1)", "({0},'AdministrationHideShutdownOption',0,'0',0,1)", "({0},'AdministrationHideVolumeSettings',0,'0',0,1)", "({0},'AdministrationHideHomeButton',0,'0',0,1)", "({0},'AdministrationPreLaunchReceiver',0,'0',0,1)", "({0},'AdministrationIgnoreLastLanguage',0,'0',0,1)", "({0},'AdvancedHideTaskbar',0,'0',0,1)", "({0},'AdvancedLockCtrlAltDel',0,'0',0,1)", "({0},'AdvancedLockAltTab',0,'0',0,1)", "({0},'AdvancedFixBrowserRendering',0,'0',0,1)", "({0},'AdvancedLogOffScreenRedirection',0,'0',0,1)", "({0},'AdvancedSuppressScriptErrors',0,'0',0,1)", "({0},'AdvancedShowWifiSettings',0,'0',0,1)", "({0},'AdvancedHideKioskWhileCitrixSession',0,'0',0,1)", "({0},'AdvancedFixSslSites',0,'0',0,1)", "({0},'AdvancedAlwaysShowAdminMenu',0,'0',0,1)", "({0},'AdvancedFixZOrder',0,'0',0,1)", "({0},'ToolsAppsList',0,'',0,1)", "({0},'ToolsEnabled',0,'0',0,1)", "({0},'IsKioskEnabled',0,'0',0,1)", "({0},'SitesIsListEnabled',0,'0',0,1)", "({0},'SitesNamesAndLinks',0,'',0,1)", "({0},'GeneralStartUrl',0,'',0,1)", "({0},'GeneralTitle',0,'',0,1)", "({0},'GeneralShowNavigationButtons',0,'0',0,1)", "({0},'GeneralWindowMode',0,'0',0,1)", "({0},'GeneralClockEnabled',0,'0',0,1)", "({0},'GeneralClockUses12Hours',0,'0',0,1)", "({0},'GeneralUnlockPassword',0,'fLp34dnRI0DK26rJv8Tmqg==',0,1)", "({0},'GeneralEnableLanguageSelect',0,'0',0,1)", "({0},'GeneralAutoHideAppPanel',0,'0',0,1)", "({0},'GeneralEnableAppPanel',0,'0',0,1)", "({0},'ProcessLauncherEnabled',0,'0',0,1)", "({0},'ProcessLauncherApplication',0,'',0,1)", "({0},'ProcessLauncherArgs',0,'',0,1)", "({0},'ProcessLauncherClearLastUsernameVMWare',0,'0',0,1)", "({0},'ProcessLauncherEnableVMWareViewMode',0,'0',0,1)", "({0},'ProcessLauncherEnableMicrosoftRdsMode',0,'0',0,1)", "({0},'ProcessLauncherEnableCitrixMode',0,'0',0,1)", "({0},'SetCitrixReceiverFSOMode',0,'0',0,1)")
        "ParametersFields"                = "IdSite, Name, Value, State, RevisionId"
        "ParametersValues"                = @("({0},'excludedDriveletters','A;B;C;D',1,1)", "({0},'AllowDriveLetterReuse','0',1,1)")
        "PersonaFields"                   = "IdSite,Name,Value,State,RevisionId"
        "PersonaValues"                   = @("({0},'PersonaManagementEnabled','0',1,1)", "({0},'VPEnabled','0',1,1)", "({0},'UploadProfileInterval','10',1,1)", "({0},'SetCentralProfileStore','0',1,1)", "({0},'CentralProfileStore','',1,1)", "({0},'CentralProfileOverride','0',1,1)", "({0},'DeleteLocalProfile','0',1,1)", "({0},'DeleteLocalSettings','0',1,1)", "({0},'RoamLocalSettings','0',1,1)", "({0},'EnableBackgroundDownload','0',1,1)", "({0},'CleanupCLFSFiles','0',1,1)", "({0},'SetDynamicRoamingFiles','0',1,1)", "({0},'DynamicRoamingFiles','',1,1)", "({0},'SetDynamicRoamingFilesExceptions','0',1,1)", "({0},'DynamicRoamingFilesExceptions','',1,1)", "({0},'SetBasicRoamingFiles','0',1,1)", "({0},'BasicRoamingFiles','',1,1)", "({0},'SetBasicRoamingFilesExceptions','0',1,1)", "({0},'BasicRoamingFilesExceptions','',1,1)", "({0},'SetDontRoamFiles','0',1,1)", "({0},'DontRoamFiles','AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1)", "({0},'SetDontRoamFilesExceptions','0',1,1)", "({0},'DontRoamFilesExceptions','',1,1)", "({0},'SetBackgroundLoadFolders','0',1,1)", "({0},'BackgroundLoadFolders','',1,1)", "({0},'SetBackgroundLoadFoldersExceptions','0',1,1)", "({0},'BackgroundLoadFoldersExceptions','',1,1)", "({0},'SetExcludedProcesses','0',1,1)", "({0},'ExcludedProcesses','',1,1)", "({0},'HideOfflineIcon','0',1,1)", "({0},'HideFileCopyProgress','0',1,1)", "({0},'FileCopyMinSize','50',1,1)", "({0},'EnableTrayIconErrorAlerts','0',1,1)", "({0},'SetLogPath','0',1,1)", "({0},'LogPath','',1,1)", "({0},'SetLoggingDestination','0',1,1)", "({0},'LogToFile','0',1,1)", "({0},'LogToDebugPort','0',1,1)", "({0},'SetLoggingFlags','0',1,1)", "({0},'LogError','0',1,1)", "({0},'LogInformation','0',1,1)", "({0},'LogDebug','0',1,1)", "({0},'SetDebugFlags','0',1,1)", "({0},'DebugError','0',1,1)", "({0},'DebugInformation','0',1,1)", "({0},'DebugPorts','0',1,1)", "({0},'AddAdminGroupToRedirectedFolders','0',1,1)", "({0},'RedirectApplicationData','0',1,1)", "({0},'ApplicationDataRedirectedPath','',1,1)", "({0},'RedirectContacts','0',1,1)", "({0},'ContactsRedirectedPath','',1,1)", "({0},'RedirectCookies','0',1,1)", "({0},'CookiesRedirectedPath','',1,1)", "({0},'RedirectDesktop','0',1,1)", "({0},'DesktopRedirectedPath','',1,1)", "({0},'RedirectDownloads','0',1,1)", "({0},'DownloadsRedirectedPath','',1,1)", "({0},'RedirectFavorites','0',1,1)", "({0},'FavoritesRedirectedPath','',1,1)", "({0},'RedirectHistory','0',1,1)", "({0},'HistoryRedirectedPath','',1,1)", "({0},'RedirectLinks','0',1,1)", "({0},'LinksRedirectedPath','',1,1)", "({0},'RedirectMyDocuments','0',1,1)", "({0},'MyDocumentsRedirectedPath','',1,1)", "({0},'RedirectMyMusic','0',1,1)", "({0},'MyMusicRedirectedPath','',1,1)", "({0},'RedirectMyPictures','0',1,1)", "({0},'MyPicturesRedirectedPath','',1,1)", "({0},'RedirectMyVideos','0',1,1)", "({0},'MyVideosRedirectedPath','',1,1)", "({0},'RedirectNetworkNeighborhood','0',1,1)", "({0},'NetworkNeighborhoodRedirectedPath','',1,1)", "({0},'RedirectPrinterNeighborhood','0',1,1)", "({0},'PrinterNeighborhoodRedirectedPath','',1,1)", "({0},'RedirectRecentItems','0',1,1)", "({0},'RecentItemsRedirectedPath','',1,1)", "({0},'RedirectSavedGames','0',1,1)", "({0},'SavedGamesRedirectedPath','',1,1)", "({0},'RedirectSearches','0',1,1)", "({0},'SearchesRedirectedPath','',1,1)", "({0},'RedirectSendTo','0',1,1)", "({0},'SendToRedirectedPath','',1,1)", "({0},'RedirectStartMenu','0',1,1)", "({0},'StartMenuRedirectedPath','',1,1)", "({0},'RedirectStartupItems','0',1,1)", "({0},'StartupItemsRedirectedPath','',1,1)", "({0},'RedirectTemplates','0',1,1)", "({0},'TemplatesRedirectedPath','',1,1)", "({0},'RedirectTemporaryInternetFiles','0',1,1)", "({0},'TemporaryInternetFilesRedirectedPath','',1,1)", "({0},'SetFRExclusions','0',1,1)", "({0},'FRExclusions','',1,1)", "({0},'SetFRExclusionsExceptions','0',1,1)", "({0},'FRExclusionsExceptions','',1,1)")
        "SystemMonitoringFields"          = "IdSite,Name,Value,State,RevisionId"
        "SystemMonitoringValues"          = @("({0},'EnableSystemMonitoring','0',1,1)", "({0},'EnableGlobalSystemMonitoring','0',1,1)", "({0},'EnableProcessActivityMonitoring','0',1,1)", "({0},'EnableUserExperienceMonitoring','0',1,1)", "({0},'LocalDatabaseRetentionPeriod','3',1,1)", "({0},'LocalDataUploadFrequency','4',1,1)", "({0},'EnableApplicationReportsWindows2K3XPCompliance','0',1,1)", "({0},'ExcludeProcessesFromApplicationReports','1',1,1)", "({0},'ExcludedProcessesFromApplicationReports','dwm;taskhost;vmtoolsd;winlogon;csrss;wisptis;dllhost;consent;msiexec;userinit;LogonUI;mscorsvw;SearchProtocolHost;Rundll32;explorer;regsvr32;WmiPrvSE;services;smss;SearchFilterHost;lsass;svchost;lsm;msdtc;wininit;VGAuthService;SearchIndexer;spoolsv;vmtoolsd;vmacthlp;audiodg;VMwareResolutionSet;mobsync;wsqmcons;schtasks;Defrag;conhost;VSSVC;sdclt;MpCmdRun;WMIADAP;encsvc;wfshell;CpSvc;VDARedirector;CpSvc64;SemsService;ctxrdr;PicaSvc2;encsvc;GfxMgr;PicaSessionAgent;CtxGfx;PicaTwiHost;PicaUserAgent;VDARedirector;PicaShell;PicaEuemRelay;CtxMtHost;CtxSensLoader;ssonsvr;concentr;wfcrun32;pnamain;redirector;concentr;pnamain;pnagent;IMAAdvanceSrv;mfcom;ctxxmlss;Citrix.XenApp.Commands.Remoting.Service;HCAService;cmstart;startssonsvr;ctxhide;mmvdhost;runonce;rdpclip;TabTip;InputPersonalization;TabTip32;TSTheme;ngen;XTE;CtxSvcHost;OSPPSVC;TelemetryService;CtxAudioService;picatzrestore;CheckTermSrv;IMATest;RequestTicket;csc;cvtres;ssoncom;UpmUserMsg;CtxPvD;MultimediaRedirector;gpscript;shutdown;splwow64',1,1)", "({0},'EnableStrictPrivacy','0',1,1)", "({0},'BusinessDayStartHour','8',1,1)", "({0},'BusinessDayEndHour','19',1,1)", "({0},'ReportsBootTimeMinimum','5',1,1)", "({0},'ReportsLoginTimeMinimum','5',1,1)", "({0},'EnableWorkDaysFiltering','1',1,1)", "({0},'WorkDaysFilter','1;1;1;1;1;0;0',1,1)")
        "SystemUtilitiesFields"           = "IdSite,Name,Type,Value,State,RevisionId"
        "SystemUtilitiesValues"           = @("({0},'EnableFastLogoff',0,'0',1,1)", "({0},'ExcludeGroupsFromFastLogoff',0,'0',1,1)", "({0},'FastLogoffExcludedGroups',0,NULL,1,1)", "({0},'EnableCPUSpikesProtection',1,'0',1,1)", "({0},'SpikesProtectionCPUUsageLimitPercent',1,'70',1,1)", "({0},'SpikesProtectionCPUUsageLimitSampleTime',1,'30',1,1)", "({0},'SpikesProtectionIdlePriorityConstraintTime',1,'180',1,1)", "({0},'ExcludeProcessesFromCPUSpikesProtection',1,'0',1,1)", "({0},'CPUSpikesProtectionExcludedProcesses',1,NULL,1,1)", "({0},'EnableMemoryWorkingSetOptimization',2,'0',1,1)", "({0},'MemoryWorkingSetOptimizationIdleSampleTime',2,'120',1,1)", "({0},'ExcludeProcessesFromMemoryWorkingSetOptimization',2,'0',1,1)", "({0},'MemoryWorkingSetOptimizationExcludedProcesses',2,NULL,1,1)", "({0},'EnableProcessesBlackListing',3,'0',1,1)", "({0},'ProcessesManagementBlackListedProcesses',3,NULL,1,1)", "({0},'ProcessesManagementBlackListExcludeLocalAdministrators',3,'0',1,1)", "({0},'ProcessesManagementBlackListExcludeSpecifiedGroups',3,'0',1,1)", "({0},'ProcessesManagementBlackListExcludedSpecifiedGroupsList',3,'',1,1)", "({0},'EnableProcessesWhiteListing',3,'0',1,1)", "({0},'ProcessesManagementWhiteListedProcesses',3,NULL,1,1)", "({0},'ProcessesManagementWhiteListExcludeLocalAdministrators',3,'0',1,1)", "({0},'ProcessesManagementWhiteListExcludeSpecifiedGroups',3,'0',1,1)", "({0},'ProcessesManagementWhiteListExcludedSpecifiedGroupsList',3,'',1,1)", "({0},'EnableProcessesManagement',3,'0',1,1)", "({0},'EnableProcessesClamping',4,'0',1,1)", "({0},'ProcessesClampingList',4,NULL,1,1)", "({0},'EnableProcessesAffinity',5,'0',1,1)", "({0},'ProcessesAffinityList',5,NULL,1,1)", "({0},'EnableProcessesIoPriority',6,'0',1,1)", "({0},'ProcessesIoPriorityList',6,NULL,1,1)", "({0},'EnableProcessesCpuPriority',7,'0',1,1)", "({0},'ProcessesCpuPriorityList',7,NULL,1,1)", "({0},'MemoryWorkingSetOptimizationIdleStateLimitPercent',2,'1',1,1)", "({0},'EnableIntelligentCpuOptimization',1,'0',1,1)", "({0},'EnableIntelligentIoOptimization',1,'0',1,1)", "({0},'SpikesProtectionLimitCPUCoreNumber',1,'0',1,1)", "({0},'SpikesProtectionCPUCoreLimit',1,'1',1,1)", "({0},'AppLockerControllerManagement',1,'1',1,1)", "({0},'AppLockerControllerReplaceModeOn',1,'1',1,1)")
        "UPMFields"                       = "IdSite,Name,Value,State,RevisionId"
        "UPMValues"                       = @("({0},'UPMManagementEnabled','0',1,1)", "({0},'ServiceActive','0',1,1)", "({0},'SetProcessedGroups','0',1,1)", "({0},'ProcessedGroupsList','',1,1)", "({0},'ProcessAdmins','0',1,1)", "({0},'SetPathToUserStore','0',1,1)", "({0},'PathToUserStore','Windows',1,1)", "({0},'PSMidSessionWriteBack','0',1,1)", "({0},'OfflineSupport','0',1,1)", "({0},'DeleteCachedProfilesOnLogoff','0',1,1)", "({0},'SetMigrateWindowsProfilesToUserStore','0',1,1)", "({0},'MigrateWindowsProfilesToUserStore','1',1,1)", "({0},'SetLocalProfileConflictHandling','0',1,1)", "({0},'LocalProfileConflictHandling','1',1,1)", "({0},'SetTemplateProfilePath','0',1,1)", "({0},'TemplateProfilePath','',1,1)", "({0},'TemplateProfileOverridesLocalProfile','0',1,1)", "({0},'TemplateProfileOverridesRoamingProfile','0',1,1)", "({0},'SetLoadRetries','0',1,1)", "({0},'LoadRetries','5',1,1)", "({0},'SetUSNDBPath','0',1,1)", "({0},'USNDBPath','',1,1)", "({0},'XenAppOptimizationEnabled','0',1,1)", "({0},'XenAppOptimizationPath','',1,1)", "({0},'ProcessCookieFiles','0',1,1)", "({0},'DeleteRedirectedFolders','0',1,1)", "({0},'LoggingEnabled','0',1,1)", "({0},'SetLogLevels','0',1,1)", "({0},'LogLevels','0;0;0;0;0;0;0;0;0;0;0',1,1)", "({0},'SetMaxLogSize','0',1,1)", "({0},'MaxLogSize','1048576',1,1)", "({0},'SetPathToLogFile','0',1,1)", "({0},'PathToLogFile','',1,1)", "({0},'SetExclusionListRegistry','0',1,1)", "({0},'ExclusionListRegistry','',1,1)", "({0},'SetInclusionListRegistry','0',1,1)", "({0},'InclusionListRegistry','',1,1)", "({0},'SetSyncExclusionListFiles','0',1,1)", "({0},'SyncExclusionListFiles','AppData\Roaming\Microsoft\Windows\Start Menu\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Startup\Desktop.ini',1,1)", "({0},'SetSyncExclusionListDir','0',1,1)", "({0},'SyncExclusionListDir','`$Recycle.Bin;AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1)", "({0},'SetSyncDirList','0',1,1)", "({0},'SyncDirList','',1,1)", "({0},'SetSyncFileList','0',1,1)", "({0},'SyncFileList','',1,1)", "({0},'SetMirrorFoldersList','0',1,1)", "({0},'MirrorFoldersList','',1,1)", "({0},'SetProfileContainerList','0',1,1)", "({0},'ProfileContainerList','',1,1)", "({0},'SetLargeFileHandlingList','0',1,1)", "({0},'LargeFileHandlingList','',1,1)", "({0},'PSEnabled','0',1,1)", "({0},'PSAlwaysCache','0',1,1)", "({0},'PSAlwaysCacheSize','0',1,1)", "({0},'SetPSPendingLockTimeout','0',1,1)", "({0},'PSPendingLockTimeout','1',1,1)", "({0},'SetPSUserGroupsList','0',1,1)", "({0},'PSUserGroupsList','',1,1)", "({0},'CPEnabled','0',1,1)", "({0},'SetCPUserGroupList','0',1,1)", "({0},'CPUserGroupList','',1,1)", "({0},'SetCPSchemaPath','0',1,1)", "({0},'CPSchemaPath','',1,1)", "({0},'SetCPPath','0',1,1)", "({0},'CPPath','',1,1)", "({0},'CPMigrationFromBaseProfileToCPStore','0',1,1)", "({0},'SetExcludedGroups','0',1,1)", "({0},'ExcludedGroupsList','',1,1)", "({0},'DisableDynamicConfig','0',1,1)", "({0},'LogoffRatherThanTempProfile','0',1,1)", "({0},'SetProfileDeleteDelay','0',1,1)", "({0},'ProfileDeleteDelay','0',1,1)", "({0},'TemplateProfileIsMandatory','0',1,1)", "({0},'PSMidSessionWriteBackReg','0',1,1)", "({0},'CEIPEnabled','1',1,1)", "({0},'LastKnownGoodRegistry','0',1,1)", "({0},'EnableDefaultExclusionListRegistry','0',1,1)", "({0},'ExclusionDefaultRegistry01','1',1,1)", "({0},'ExclusionDefaultRegistry02','1',1,1)", "({0},'ExclusionDefaultRegistry03','1',1,1)", "({0},'EnableDefaultExclusionListDirectories','0',1,1)", "({0},'ExclusionDefaultDir01','1',1,1)", "({0},'ExclusionDefaultDir02','1',1,1)", "({0},'ExclusionDefaultDir03','1',1,1)", "({0},'ExclusionDefaultDir04','1',1,1)", "({0},'ExclusionDefaultDir05','1',1,1)", "({0},'ExclusionDefaultDir06','1',1,1)", "({0},'ExclusionDefaultDir07','1',1,1)", "({0},'ExclusionDefaultDir08','1',1,1)", "({0},'ExclusionDefaultDir09','1',1,1)", "({0},'ExclusionDefaultDir10','1',1,1)", "({0},'ExclusionDefaultDir11','1',1,1)", "({0},'ExclusionDefaultDir12','1',1,1)", "({0},'ExclusionDefaultDir13','1',1,1)", "({0},'ExclusionDefaultDir14','1',1,1)", "({0},'ExclusionDefaultDir15','1',1,1)", "({0},'ExclusionDefaultDir16','1',1,1)", "({0},'ExclusionDefaultDir17','1',1,1)", "({0},'ExclusionDefaultDir18','1',1,1)", "({0},'ExclusionDefaultDir19','1',1,1)", "({0},'ExclusionDefaultDir20','1',1,1)", "({0},'ExclusionDefaultDir21','1',1,1)", "({0},'ExclusionDefaultDir22','1',1,1)", "({0},'ExclusionDefaultDir23','1',1,1)", "({0},'ExclusionDefaultDir24','1',1,1)", "({0},'ExclusionDefaultDir25','1',1,1)", "({0},'ExclusionDefaultDir26','1',1,1)", "({0},'ExclusionDefaultDir27','1',1,1)", "({0},'ExclusionDefaultDir28','1',1,1)", "({0},'ExclusionDefaultDir29','1',1,1)", "({0},'ExclusionDefaultDir30','1',1,1)", "({0},'EnableStreamingExclusionList','0',1,1)", "({0},'StreamingExclusionList','',1,1)", "({0},'EnableLogonExclusionCheck','0',1,1)", "({0},'LogonExclusionCheck','0',1,1)", "({0},'OutlookSearchRoamingEnabled','0',1,1)")
        "USVFields"                       = "IdSite,Name,Type,Value,State,RevisionId"
        "USVValues"                       = @("({0},'processUSVConfiguration',0,'0',1,1)", "({0},'processUSVConfigurationForAdmins',0,'0',1,1)", "({0},'SetWindowsRoamingProfilesPath',1,'0',1,1)", "({0},'WindowsRoamingProfilesPath',1,'',1,1)", "({0},'SetRDSRoamingProfilesPath',1,'0',1,1)", "({0},'RDSRoamingProfilesPath',1,'',1,1)", "({0},'SetRDSHomeDrivePath',1,'0',1,1)", "({0},'RDSHomeDrivePath',1,'',1,1)", "({0},'RDSHomeDriveLetter',1,'Z:',1,1)", "({0},'SetRoamingProfilesFoldersExclusions',2,'0',1,1)", "({0},'RoamingProfilesFoldersExclusions',2,'AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp',1,1)", "({0},'DeleteRoamingCachedProfiles',1,'0',1,1)", "({0},'AddAdminGroupToRUP',1,'0',1,1)", "({0},'CompatibleRUPSecurity',1,'0',1,1)", "({0},'DisableSlowLinkDetect',1,'0',1,1)", "({0},'SlowLinkProfileDefault',1,'0',1,1)", "({0},'processFoldersRedirectionConfiguration',3,'0',1,1)", "({0},'DeleteLocalRedirectedFolders',3,'0',1,1)", "({0},'processDesktopRedirection',3,'0',1,1)", "({0},'DesktopRedirectedPath',3,'',1,1)", "({0},'processStartMenuRedirection',3,'0',1,1)", "({0},'StartMenuRedirectedPath',3,'',1,1)", "({0},'processPersonalRedirection',3,'0',1,1)", "({0},'PersonalRedirectedPath',3,'',1,1)", "({0},'processPicturesRedirection',3,'0',1,1)", "({0},'PicturesRedirectedPath',3,'',1,1)", "({0},'MyPicturesFollowsDocuments',3,'0',1,1)", "({0},'processMusicRedirection',3,'0',1,1)", "({0},'MusicRedirectedPath',3,'',1,1)", "({0},'MyMusicFollowsDocuments',3,'0',1,1)", "({0},'processVideoRedirection',3,'0',1,1)", "({0},'VideoRedirectedPath',3,'',1,1)", "({0},'MyVideoFollowsDocuments',3,'0',1,1)", "({0},'processFavoritesRedirection',3,'0',1,1)", "({0},'FavoritesRedirectedPath',3,'',1,1)", "({0},'processAppDataRedirection',3,'0',1,1)", "({0},'AppDataRedirectedPath',3,'',1,1)", "({0},'processContactsRedirection',3,'0',1,1)", "({0},'ContactsRedirectedPath',3,'',1,1)", "({0},'processDownloadsRedirection',3,'0',1,1)", "({0},'DownloadsRedirectedPath',3,'',1,1)", "({0},'processLinksRedirection',3,'0',1,1)", "({0},'LinksRedirectedPath',3,'',1,1)", "({0},'processSearchesRedirection',3,'0',1,1)", "({0},'SearchesRedirectedPath',3,'',1,1)")

        "CleanupTables"                   = @("VUEMActionGroups","VUEMApps","VUEMPrinters","VUEMNetDrives","VUEMVirtualDrives","VUEMRegValues","VUEMEnvVariables","VUEMPorts","VUEMIniFilesOps","VUEMExtTasks","VUEMFileSystemOps","VUEMUserDSNs","VUEMFileAssocs","VUEMFiltersRules","VUEMFiltersConditions","VUEMItems","VUEMUserStatistics","VUEMAgentStatistics","VUEMSystemMonitoringData","VUEMActivityMonitoringData","VUEMUserExperienceMonitoringData","VUEMResourcesOptimizationData","VUEMParameters","VUEMAgentSettings","VUEMSystemUtilities","VUEMEnvironmentalSettings","VUEMUPMSettings","VUEMPersonaSettings","VUEMUSVSettings","VUEMKioskSettings","VUEMSystemMonitoringSettings","VUEMTasks","VUEMStorefrontSettings","VUEMChangesLog","VUEMAgentsLog","VUEMADObjects","AppLockerSettings","GroupPolicyObjects","GroupPolicyGlobalSettings","VUEMSites")
    }
}

$ActionCategories         = @("Application","Printer","Network Drive","Virtual Drive","Registry Value","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association")
$assignmentPropertiesEnum = @{1="CreateDesktopLink";2="CreateQuickLaunchLink";4="CreateStartMenuLink";8="PinToTaskbar";16="PinToStartMenu";32="AutoStart";"CreateDesktopLink"=1;"CreateQuickLaunchLink"=2;"CreateStartMenuLink"=4;"PinToTaskbar"=8;"PinToStartMenu"=16;"AutoStart"=32}

$XmlHeader                               = '<?xml version="1.0" encoding="utf-8"?><ArrayOfVUEMActionAdvancedOption xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
$XmlFooter                               = '</ArrayOfVUEMActionAdvancedOption>'
$defaultVUEMAppReserved                  = $XmlHeader + '<VUEMActionAdvancedOption><Name>SelfHealingEnabled</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>EnforceIconLocation</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>EnforcedIconXValue</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>EnforcedIconYValue</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>DoNotShowInSelfService</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>CreateShortcutInUserFavoritesFolder</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMPrinterReserved              = $XmlHeader + '<VUEMActionAdvancedOption><Name>SelfHealingEnabled</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMNetworkDriveReserved         = $XmlHeader + '<VUEMActionAdvancedOption><Name>SelfHealingEnabled</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>SetAsHomeDriveEnabled</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMVirtualDriveReserved         = $XmlHeader + '<VUEMActionAdvancedOption><Name>SetAsHomeDriveEnabled</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMEnvironmentVariableReserved  = $XmlHeader + '<VUEMActionAdvancedOption><Name>ExecOrder</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMExternalTaskReserved         = $XmlHeader + '<VUEMActionAdvancedOption><Name>ExecuteOnlyAtLogon</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMFileSystemOperationReserved  = $XmlHeader + '<VUEMActionAdvancedOption><Name>ExecOrder</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter

$defaultIconStream = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAEaSURBVFhH7ZTbCoJAEIaFCCKCCKJnLTpQVBdB14HQ00T0CqUP4AN41puJAVe92F3HRZegHfgQFvH7/1nQMmPmZ+Z8uYJOCm01vJe64PF8cZ+Ftho89DxPC8IAeZ73QpZlJWmattsAfsBavsk0yRsD3Ox7ST3A4uTC/OjC7ODCdO/AZOfAeOvAaPOB4foDg1UVwLZtIUmSqG2AIq9vgNcc5coBKHIWgNec0RhAdAUUOSJrjsRxrLYBihxBMa85QzkARY7ImjOkAURXQJEjKOY1Z0RRpLYBihyRNUe5cgCKHEEprzmjMYDoCqjImiNhGKptgApvA3V57wFkzbUGEMmDIGgfAKH84ShypQBdyn3fFwfQSaE1Y+bvx7K+efsbU5+Ow3MAAAAASUVORK5CYII="

$tableVUEMState = @{
    0 = "Disabled"
    1 = "Enabled"
    2 = "Maintenance Mode"
    "Disabled"         = 0
    "Enabled"          = 1
    "Maintenance Mode" = 2
}
$tableVUEMADObjectType = @{
    1 = "User"
    2 = "Group"
    3 = "BUILTIN"
    4 = "Computer"
    8 = "Organizational Unit"
    "User"                = 1
    "Group"               = 2
    "BUILTIN"             = 3
    "Computer"            = 4
    "Organizational Unit" = 8
}
$tableVUEMAppType = @{
    0 = "Installed application"
    4 = "URL"
    5 = "File / Folder"
    "Installed application" = 0
    "URL"                   = 4
    "File / Folder"         = 5
}
$tableVUEMAppActionType = @{
    0 = "Create Application Shortcut"
    "Create Application Shortcut" = 0
}
$tableVUEMPrinterActionType = @{
    0 = "Map Network Printer"
    1 = "Use Device Mapping Printers File"
    "Map Network Printer"              = 0
    "Use Device Mapping Printers File" = 1
}
$tableVUEMNetDriveActionType = @{
    0 = "Map Network Drive"
    "Map Network Drive" = 0
}
$tableVUEMVirtualDriveActionType = @{
    0 = "Map Virtual Drive"
    "Map Virtual Drive" = 0
}
$tableVUEMRegValueActionType = @{
    0 = "Create / Set Registry Value"
    1 = "Delete Registry Value"
    "Create / Set Registry Value" = 0
    "Delete Registry Value"       = 1
}
$tableVUEMEnvVariableActionType = @{
    0 = "Create / Set Environment Variable"
    "Create / Set Environment Variable" = 0
}
$tableVUEMPortActionType = @{
    0 = "Map Client Port"
    "Map Client Port" = 0
}
$tableVUEMIniFileOpActionType = @{
    0 = "Write Ini File Value"
    "Write Ini File Value" = 0
}
$tableVUEMExtTaskActionType = @{
    0 = "Execute External Task"
    "Execute External Task" = 0
}
$tableVUEMFileSystemOpActionType = @{
    0 = "Copy Files / Folders"
    1 = "Delete Files / Folders"
    2 = "Rename Files / Folders"
    3 = "Create Directory Symbolic Link"
    4 = "Create File Symbolic Link"
    5 = "Create Directory"
    6 = "Copy Directory Content"
    7 = "Delete Directory Content"
    8 = "Move Directory Content"
    "Copy Files / Folders"           = 0
    "Delete Files / Folders"         = 1
    "Rename Files / Folders"         = 2
    "Create Directory Symbolic Link" = 3
    "Create File Symbolic Link"      = 4
    "Create Directory"               = 5
    "Copy Directory Content"         = 6
    "Delete Directory Content"       = 7
    "Move Directory Content"         = 8
}
$tableVUEMUserDSNActionType = @{
    0 = "Create / Edit User DSN"
    "Create / Edit User DSN" = 0
}
$tableVUEMFileAssocActionType = @{
    0 = "Create / Set File Association"
    "Create / Set File Association" = 0
}
$tableVUEMFiltersConditionType = @{
    1 = @{ 'Name' = "Always True";'TestedValue' = "True";'TestedResult' = "True" }
    2 = @{ 'Name' = "ComputerName Match";'UseName' = $true }
    3 = @{ 'Name' = "ClientName Match";'UseName' = $true }
    4 = @{ 'Name' = "IP Address Match";'UseName' = $true }
    5 = @{ 'Name' = "Client IP Address Match";'UseName' = $true }
    6 = @{ 'Name' = "Active Directory Site Match";;'UseName' = $true }
    7 = @{ 'Name' = "Scheduling";'UseName' = $true }
    8 = @{ 'Name' = "Environment Variable Match" }
    9 = @{ 'Name' = "Registry Value Match" }
    10 = @{ 'Name' = "WMI Query result Match";'UseName' = $true }
    11 = @{ 'Name' = "User Country Match";'UseName' = $true }
    12 = @{ 'Name' = "User UI Language Match";'UseName' = $true }
    13 = @{ 'Name' = "User SBC Resource Type";'UseName' = $true;'TestedResult' = @("Desktop","Published Application") }
    14 = @{ 'Name' = "OS Platform Type";'UseName' = $true;'TestedResult' = @("x86","x64") }
    15 = @{ 'Name' = "Connection State";'UseName' = $true;'TestedResult' = @("Online","Offline") }
    16 = @{ 'Name' = "XenApp Version Match";'UseName' = $true }
    17 = @{ 'Name' = "XenApp Farm Name Match";'UseName' = $true }
    18 = @{ 'Name' = "XenApp Zone Name Match";'UseName' = $true }
    19 = @{ 'Name' = "XenDesktop Farm Name Match";'UseName' = $true }
    20 = @{ 'Name' = "XenDesktop Desktop Group Name Match";'UseName' = $true }
    21 = @{ 'Name' = "Provisioning Services Image Mode";'UseName' = $true;'TestedResult' = @("Shared","Private") }
    22 = @{ 'Name' = "Client OS";'UseName' = $true;'TestedResult' = @("Windows XP","Windows Vista","Windows 7","Windows 8","Windows 8.1","Windows 2003","Windows 2008","Windows 2008 R2","Windows 2012","Windows 2012 R2","Windows 10","Windows 2016") }
    23 = @{ 'Name' = "Active Directory Path Match";'UseName' = $true }
    24 = @{ 'Name' = "Active Directory Attribute Match" }
    25 = @{ 'Name' = "Name or Value is in List" }
    26 = @{ 'Name' = "No ComputerName Match";'UseName' = $true }
    27 = @{ 'Name' = "No ClientName Match";'UseName' = $true }
    28 = @{ 'Name' = "No IP Address Match";'UseName' = $true }
    29 = @{ 'Name' = "No Client IP Address Match";'UseName' = $true }
    30 = @{ 'Name' = "No Active Directory Site Match";'UseName' = $true }
    31 = @{ 'Name' = "No Environment Variable Match";'UseName' = $true }
    32 = @{ 'Name' = "No Registry Value Match";'UseName' = $true }
    33 = @{ 'Name' = "No WMI Query result Match";'UseName' = $true }
    34 = @{ 'Name' = "No User Country Match";'UseName' = $true }
    35 = @{ 'Name' = "No User UI Language Match";'UseName' = $true }
    36 = @{ 'Name' = "No XenApp Version Match";'UseName' = $true }
    37 = @{ 'Name' = "No XenApp Farm Name Match";'UseName' = $true }
    38 = @{ 'Name' = "No XenApp Zone Name Match";'UseName' = $true }
    39 = @{ 'Name' = "No XenDesktop Farm Name Match";'UseName' = $true }
    40 = @{ 'Name' = "No XenDesktop Desktop Group Name Match";'UseName' = $true }
    41 = @{ 'Name' = "No Active Directory Path Match";'UseName' = $true }
    42 = @{ 'Name' = "No Active Directory Attribute Match" }
    43 = @{ 'Name' = "Name or Value is not in List" }
    44 = @{ 'Name' = "Client Remote OS Match";'UseName' = $true;'TestedResult' = @("Unknown","Windows","Epoc","Os2","Dos32","Linux","Mac","Ios","Android","Blackberry","PlayBook","WindowsMobile","Html5","Java","WinCehp","WinCeWyse","ThinOsWyse") }
    45 = @{ 'Name' = "No Client Remote OS Match";'UseName' = $true;'TestedResult' = @("Unknown","Windows","Epoc","Os2","Dos32","Linux","Mac","Ios","Android","Blackberry","PlayBook","WindowsMobile","Html5","Java","WinCehp","WinCeWyse","ThinOsWyse") }
    46 = @{ 'Name' = "Dynamic Value Match" }
    47 = @{ 'Name' = "No Dynamic Value Match" }
    48 = @{ 'Name' = "Transformer Mode State";'UseName' = $true;'TestedResult' = @("Disabled","Enabled") }
    49 = @{ 'Name' = "No Client OS Match";'UseName' = $true;'TestedResult' = @("Windows XP","Windows Vista","Windows 7","Windows 8","Windows 8.1","Windows 2003","Windows 2008","Windows 2008 R2","Windows 2012","Windows 2012 R2","Windows 10","Windows 2016") }
    50 = @{ 'Name' = "Active Directory Group Match";'UseName' = $true }
    51 = @{ 'Name' = "No Active Directory Group Match";'UseName' = $true }
    52 = @{ 'Name' = "File Version Match" }
    53 = @{ 'Name' = "No File Version Match" }
    54 = @{ 'Name' = "Network Connection State";'UseName' = $true;'TestedResult' = @("Available","Not Available") }
    55 = @{ 'Name' = "Published Resource Name";'UseName' = $true }
    56 = @{ 'Name' = "Name is in List" }
    57 = @{ 'Name' = "Name is not in List" }
    58 = @{ 'Name' = "File/Folder exists";'UseName' = $true }
    59 = @{ 'Name' = "File/Folder does not exist";'UseName' = $true }
    60 = @{ 'Name' = "DateTime Match";'UseName' = $true }
    61 = @{ 'Name' = "No DateTime Match";'UseName' = $true }
    "Always True" 								= 1
    "ComputerName Match" 						= 2
    "ClientName Match" 							= 3
    "IP Address Match" 							= 4
    "Client IP Address Match" 					= 5
    "Active Directory Site Match" 				= 6
    "Scheduling" 								= 7
    "Environment Variable Match" 				= 8
    "Registry Value Match" 						= 9
    "WMI Query result Match" 					= 10
    "User Country Match" 						= 11
    "User UI Language Match" 					= 12
    "User SBC Resource Type" 					= 13
    "OS Platform Type" 							= 14
    "Connection State" 							= 15
    "XenApp Version Match" 						= 16
    "XenApp Farm Name Match" 					= 17
    "XenApp Zone Name Match" 					= 18
    "XenDesktop Farm Name Match" 				= 19
    "XenDesktop Desktop Group Name Match" 		= 20
    "Provisioning Services Image Mode" 			= 21
    "Client OS" 								= 22
    "Active Directory Path Match" 				= 23
    "Active Directory Attribute Match" 			= 24
    "Name or Value is in List" 					= 25
    "No ComputerName Match" 					= 26
    "No ClientName Match" 						= 27
    "No IP Address Match" 						= 28
    "No Client IP Address Match" 				= 29
    "No Active Directory Site Match" 			= 30
    "No Environment Variable Match" 			= 31
    "No Registry Value Match" 				 	= 32
    "No WMI Query result Match" 			  	= 33
    "No User Country Match" 				  	= 34
    "No User UI Language Match" 			  	= 35
    "No XenApp Version Match" 				  	= 36
    "No XenApp Farm Name Match" 			  	= 37
    "No XenApp Zone Name Match" 			  	= 38
    "No XenDesktop Farm Name Match" 		  	= 39
    "No XenDesktop Desktop Group Name Match" 	= 40
    "No Active Directory Path Match" 			= 41
    "No Active Directory Attribute Match" 		= 42
    "Name or Value is not in List" 				= 43
    "Client Remote OS Match" 					= 44
    "No Client Remote OS Match" 				= 45
    "Dynamic Value Match" 						= 46
    "No Dynamic Value Match" 					= 47
    "Transformer Mode State" 					= 48
    "No Client OS Match" 						= 49
    "Active Directory Group Match" 				= 50
    "No Active Directory Group Match" 			= 51
    "File Version Match" 						= 52
    "No File Version Match" 					= 53
    "Network Connection State" 					= 54
    "Published Resource Name" 					= 55
    "Name is in List" 							= 56
    "Name is not in List" 						= 57
    "File/Folder exists" 						= 58
    "File/Folder does not exist" 				= 59
    "DateTime Match" 							= 60
    "No DateTime Match"							= 61
}
$tableVUEMActionCategory = @{
    "Application"           = "Apps"
    "Printer"               = "Printers"
    "Network Drive"         = "NetDrives"
    "Virtual Drive"         = "VirtualDrives"
    "Registry Value"        = "RegValues"
    "Environment Variable"  = "EnvVariables"
    "Port"                  = "Ports"
    "Ini File Operation"    = "IniFilesOps"
    "External Task"         = "ExtTasks"
    "File System Operation" = "FileSystemOps"
    "User DSN"              = "UserDSNs"
    "File Association"      = "FileAssocs"
    "Action Groups"          = "ActionGroups"
}
$tableVUEMActionCategoryId = @{
    "Application"           = "IdApplication"
    "Printer"               = "IdPrinter"
    "Network Drive"         = "IdNetDrive"
    "Virtual Drive"         = "IdVirtualDrive"
    "Registry Value"        = "IdRegValue"
    "Environment Variable"  = "IdEnvVariable"
    "Port"                  = "IdPort"
    "Ini File Operation"    = "IdIniFileOp"
    "External Task"         = "IdExtTask"
    "File System Operation" = "IdFileSystemOp"
    "User DSN"              = "IdUserDSN"
    "File Association"      = "IdFileAssoc"
    "Action Groups"          = "IdActionGroup"
}
$tableVUEMActionType = @{
    0  = "Application"
    1  = "Printer"
    2  = "Network Drive"
    3  = "Virtual Drive"
    4  = "Registry Value"
    5  = "Environment Variable"
    6  = "Port"
    7  = "Ini File Operation"
    8  = "External Task"
    9  = "File System Operation"
    10 = "User DSN"
    11 = "File Association"
    "Application"           = 0
    "Printer"               = 1
    "Network Drive"         = 2
    "Virtual Drive"         = 3
    "Registry Value"        = 4
    "Environment Variable"  = 5
    "Port"                  = 6
    "Ini File Operation"    = 7
    "External Task"         = 8
    "File System Operation" = 9
    "User DSN"              = 10
    "File Association"      = 11
}

$databaseVersion = ""
$databaseSchema  = ""

#endregion