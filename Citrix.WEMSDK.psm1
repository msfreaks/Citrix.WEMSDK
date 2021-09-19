
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
    Author: Arjan Mensch
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
            "EXEC" {
                $rowsAffected = $Command.ExecuteNonQuery()

                Write-Verbose "Executed"
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

        $ldapObject.pstypenames.insert(0, "Citrix.WEMSDK.LDAPObject")
        $ldapObject | Add-Member ScriptMethod ToString { $this.DistinguishedName } -Force

        return $ldapObject
    }
    catch {
        return $null
    }
}

<#
    Helper function for grabbing Administrator Permissions
#>
function Get-AdministratorPermissions {
    param (
        [xml]$Permissions,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    $permissionsArray=@()
    foreach($permission in $Permissions.ArrayOfVUEMAdminPermission.VUEMAdminPermission) {

        if ($permission.idSite -ge 1) {
            $vuemObject = [pscustomobject] @{
                'IdSite'      = [int]$permission.idSite
                'Name'        = (Get-WEMConfiguration -Connection $Connection -IdSite $permission.idSite).Name
                'Permission'  = [string]$tableVUEMAdminPermissions[$permission.AuthorizationLevel]
            }
        } else {
            $vuemObject = [pscustomobject] @{
                'IdSite'      = 0
                'Name'        = "Global Admin"
                'Permission'  = [string]$tableVUEMAdminPermissions[$permission.AuthorizationLevel]
            }
        }

        # override the default ToScript() method
        $vuemObject | Add-Member ScriptMethod ToString { "$($this.Name) ($($this.Permission))" } -Force
        # set a custom type to the object
        $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.AdminPermission")
    
        $permissionsArray += $vuemObject
    }

    return $permissionsArray
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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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
    Converts SQL Data to an AppLocker Rule object

    .Description
    Converts SQL Data to an AppLocker Rule object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
Function New-VUEMAppLockerRule() {
    param(
        [System.Data.DataRow]$DataRow,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    Write-Verbose "Found AppLocker Rule object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemAppLockerRuleConditions = @()
    $vuemAppLockerRuleConditions = Get-WEMAppLockerRuleConditionObject -Connection $Connection -IdRule $DataRow.IdRule
    $vuemAppLockerRuleAssignments = @()
    $vuemAppLockerRuleAssignments = Get-WEMAppLockerRuleAssignment -Connection $Connection -IdRule $DataRow.IdRule

    $vuemObject = [pscustomobject] @{
        'IdRule'         = [int]$DataRow.IdRule
        'IdSite'         = [int]$DataRow.IdSite
        'Name'           = [string]$DataRow.Name
        'Description'    = [string]$DataRow.Description
        'CollectionType' = [string]$tableVUEMAppLockerCollectionType[[int]$DataRow.CollectionType]
        'RuleType'       = [string]$tableVUEMAppLockerRuleType[[int]$DataRow.RuleType]
        'Permission'     = [string]$tableVUEMAppLockerRulePermission[[int]$DataRow.State]
        'Condition'      = $vuemAppLockerRuleConditions | Where-Object {-not ($_.IsException)}
        'Exceptions'     = $vuemAppLockerRuleConditions | Where-Object { $_.IsException }
        'Assignments'    = $vuemAppLockerRuleAssignments
        'Version'        = [int]$DataRow.RevisionId
    }
    foreach($condition in $vuemObject.Condition) { $condition.PSObject.Properties.Remove('IsException') }
    foreach($condition in $vuemObject.Exceptions) { $condition.PSObject.Properties.Remove('IsException') }

    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.AppLockerRule")

    return $vuemObject
}

<#
    .Synopsis
    Converts SQL Data to a AppLocker Rule Condition object

    .Description
    Converts SQL Data to a AppLocker Rule Condition object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
Function New-VUEMAppLockerRuleCondition() {
    param(
        [string]$Type,
        [System.Data.DataRow]$DataRow,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    Write-Verbose "Found Condition object '$($DataRow.IdCondition)' for IdRule $($DataRow.IdRule)"

    $vuemObject = [pscustomobject] @{
        'IdCondition' = [int]$DataRow.IdCondition
        'Type'        = $Type
        'Version'     = [int]$DataRow.RevisionId
        'IsException' = [bool]$DataRow.IsException
    }

    switch ($Type) {
        "PathCondition" {
            $vuemObject | Add-Member -MemberType NoteProperty -Name "Path" -Value $DataRow.Path
        }
        "PublisherCondition" {
            $vuemObject | Add-Member -MemberType NoteProperty -Name "FilePath" -Value $DataRow.FilePath
            $vuemObject | Add-Member -MemberType NoteProperty -Name "FileName" -Value $DataRow.FileName
            $vuemObject | Add-Member -MemberType NoteProperty -Name "Publisher" -Value $DataRow.Publisher
            $vuemObject | Add-Member -MemberType NoteProperty -Name "Product" -Value $DataRow.Product
            $vuemObject | Add-Member -MemberType NoteProperty -Name "HighSection" -Value $DataRow.HighSection
            $vuemObject | Add-Member -MemberType NoteProperty -Name "LowSection" -Value $DataRow.LowSection
        }
        "HashCondition" {
            $vuemObject | Add-Member -MemberType NoteProperty -Name "Hashes" -Value @()

            # grab hashes associated with this condition
            $SQLQuery = "SELECT * FROM AppLockerRuleFileHashes WHERE IdCondition = $($DataRow.IdCondition)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            foreach ($row in $result.Tables.Rows) { 
                $hashObject = [pscustomobject]@{
                    HashAlgorithm = $row.HashAlgorithm
                    Hash          = "0x$(($row.Hash | ForEach-Object ToString X2) -join '')"
                    FileLength    = $row.FileLength
                    FileName      = $row.FileName
                    Extension     = ([System.IO.Path]::GetExtension($row.FileName)).ToLower()
                }
                $hashObject | Add-Member scriptmethod ToString { $this.FileName } -Force
                $hashObject.pstypenames.insert(0, "Citrix.WEMSDK.AppLockerRuleHashObject")

                $vuemObject.Hashes += $hashObject
            }
            $conditionPurpose = $null
            if ($vuemObject.Hashes -and @(".exe",".com") -contains $vuemObject.Hashes[0].Extension) { $conditionPublisherException = "Executable" }
            if ($vuemObject.Hashes -and @(".msi",".msp",".mst") -contains $vuemObject.Hashes[0].Extension) { $conditionPublisherException = "Windows Installer" }
            if ($vuemObject.Hashes -and @(".ps1",".bat",".cmd",".vbs",".js") -contains $vuemObject.Hashes[0].Extension) { $conditionPublisherException = "Scripts" }
            if ($vuemObject.Hashes -and @(".dll",".ocx") -contains $vuemObject.Hashes[0].Extension) { $conditionPublisherException = "DLL" }

            $vuemObject | Add-Member -MemberType NoteProperty -Name "Purpose" -Value $conditionPurpose
        }
        Default {}
    }

    # override the default ToScript() method
    $vuemObject | Add-Member scriptmethod ToString { $this.Type } -Force
    
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.AppLockerRule$($Type)")

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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
#>
Function New-VUEMGroupPolicySettingsAssignmentObject() {
    param(
        [System.Data.DataRow]$DataRow,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    Write-Verbose "Found Assignment object in IdSite $($DataRow.IdSite)"

    $assignedObject = $null
    $assignedObject = Get-WEMGroupPolicyObject -Connection $Connection -IdObject $row.IdObject

    $vuemObject = [pscustomobject] @{
        'IdAssignment'                        = [int]$DataRow.IdAssignment
        'IdSite'                              = [int]$DataRow.IdSite
        'AssignmentType'                      = "GroupPolicyObject"
        'IdAssignedObject'                    = [int]$DataRow.IdObject
        'AssignedObject'                      = $assignedObject
        'ADObject'                            = Get-WEMADUserObject -Connection $Connection -IdSite $row.IdSite -IdADObject $row.Iditem
        'Rule'                                = Get-WEMRule -Connection $Connection -IdRule $row.IdFilterRule
        'Priority'                            = [int]$DataRow.Priority
        'Version'                             = [int]$DataRow.RevisionId
    }

    # override the default ToScript() method
    Add-Member -InputObject $vuemObject ScriptMethod ToString { "$($this.AssignedObject.Name) -> $($this.ADObject.Name)" } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.Assignment")

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
    Author: Arjan Mensch
#>
Function New-VUEMGroupPolicySettingsObject() {
    param(
        [System.Data.DataRow]$DataRow,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    Write-Verbose "Found Group Policy Settings object '$($DataRow.Name)'"

    # grab RegOperations belonging to this GPO
    $gpoRegOperations = @()
    $SQLQuery = "SELECT * FROM GroupPolicyRegOperations WHERE IdObject = $($DataRow.IdObject)"
    $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

    foreach($row in $result.Tables.Rows) {
        Write-Verbose "Grabbing Registry Operation $($row.IdOperation)"
        $gpoRegType = $gpoRegData = $null
        if ($row.JData) {
            $gpoRegType = ($row.JData | ConvertFrom-Json).Type
            $gpoRegData = ($row.JData | ConvertFrom-Json).Data
        }

        $gpoRegOperation = [pscustomobject] @{
            'RegistryAction'  = [string]$tableVUEMRegAction[$row.RegAction]
            'RegistryScope'   = [string]$tableVUEMRegScope[$row.Scope]
            'RegistryKeyPath' = [string]$row.KeyPath
            'RegistryValue'   = [string]$row.Value
            'RegistryType'    = $gpoRegType
            'RegistryData'    = $gpoRegData
        }

        # override the default ToScript() method
        $gpoRegOperation | Add-Member scriptmethod ToString { "$($this.RegistryAction) '$($this.RegistryValue)'" } -force
        # set a custom type to the object
        $gpoRegOperation.pstypenames.insert(0, "Citrix.WEMSDK.GroupPolicyRegistryOperation")

        $gpoRegOperations += $gpoRegOperation
    }

    Write-Verbose "Registry Operations processed: $($gpoRegOperations.Count)"

    $vuemObject = [pscustomobject] @{
        'IdObject'            = [int]$DataRow.IdObject
        'IdSite'              = [int]$DataRow.IdSite
        'Guid'                = [string]$DataRow.Guid.ToString().ToUpper()
        'Name'                = [string]$DataRow.Name
        'Description'         = [string]$DataRow.Description
        'CreatedTime'         = [datetime]$DataRow.CreatedTime
        'ModifiedTime'        = [datetime]$DataRow.ModifiedTime
        'State'               = [string]$tableVUEMState[$DataRow.State]
        'Registry Operations' = [pscustomobject]$gpoRegOperations
        'Version'             = [int]$DataRow.RevisionId
    } 

    # override the default ToScript() method
    $vuemObject | Add-Member scriptmethod ToString { $this.Name } -force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.GroupPolicyObject")

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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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

    # set additional properties for 2003+
    if ($script:databaseSchema -ge 2003) {
        $vuemObject | Add-Member -NotePropertyName "ExecuteAtLogon" -NotePropertyValue ([bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteAtLogon"}).Value)
        $vuemObject | Add-Member -NotePropertyName "ExecuteAtLogoff" -NotePropertyValue ([bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteAtLogoff"}).Value)
        $vuemObject | Add-Member -NotePropertyName "ExecuteWhenRefresh" -NotePropertyValue ([bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteWhenRefresh"}).Value)
        $vuemObject | Add-Member -NotePropertyName "ExecuteWhenReconnect" -NotePropertyValue ([bool][int]($vuemActionXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteWhenReconnect"}).Value)
        $vuemObject.PSObject.Properties.Remove('ExecuteOnlyAtLogon')
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
    Author: Arjan Mensch
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
    Converts SQL Data to a Filter Condition object

    .Description
    Converts SQL Data to a Filter Condition object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
Function New-VUEMStorefrontSettingObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Storefront Setting object '$($DataRow.Url)' in IdSite $($DataRow.IdSite)"

    $vuemObject = [pscustomobject] @{
        'IdStorefrontSetting' = [int]$DataRow.IdItem
        'IdSite'              = [int]$DataRow.IdSite
        'StorefrontUrl'       = [string]$DataRow.Url
        'Description'         = [string]$DataRow.Description
        'State'               = [string]$tableVUEMState[[int]$DataRow.State]
        'Version'             = [int]$DataRow.RevisionId
    }
    # override the default ToScript() method
    Add-Member -InputObject $vuemObject ScriptMethod ToString { $this.StorefrontUrl } -Force
    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.StorefrontSetting")

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
    Author: Arjan Mensch
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
        'ActionType'                = [string]$tableVUEMUserDSNActionType[[int]$DataRow.ActionType]
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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.AgentObject")

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
    Author: Arjan Mensch
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
    Converts SQL Data to an Administrator object

    .Description
    Converts SQL Data to an Administrator object

    .Link
    https://msfreaks.wordpress.com

    .Parameter DataRow
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
Function New-VUEMAdminObject() {
    param(
        [System.Data.DataRow]$DataRow,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    Write-Verbose "Found Administrator object '$($DataRow.Name)'"

    $Type = [int]$DataRow.Type
    $vuemAdminReserved = $DataRow.Permissions
    [xml]$vuemAdminXml = $vuemAdminReserved.Substring($vuemAdminReserved.ToLower().IndexOf("<array"))

    $vuemObject = [pscustomobject] @{
        'IdAdministrator'   = [int]$DataRow.IdAdmin
        'Name'              = [string]$DataRow.Name
        'SID'               = [string]$DataRow.Name
        'Description'       = [string]$DataRow.Description
        'State'             = [string]$tableVUEMState[[int]$DataRow.State]
        'Type'              = [string]$tableVUEMADObjectType[$Type]
        'Permissions'       = Get-AdministratorPermissions -Connection $Connection -Permissions $vuemAdminXml
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
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.AdminObject")

    return $vuemObject
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
    Author: Arjan Mensch
#>
Function New-VUEMCitrixOptimizerConfigurationObject() {
    param(
        [System.Data.DataRow]$DataRow
    )

    Write-Verbose "Found Citrix Optimizer Configuration object '$($DataRow.Name)' in IdSite $($DataRow.IdSite)"

    $vuemObject = [pscustomobject] @{
        'IdTemplate'        = [int]$DataRow.IdTemplate
        'IdSite'            = [int]$DataRow.IdSite
        'Name'              = [string]$DataRow.Name
        'State'             = [string]$tableVUEMState[[int]$DataRow.State]
        'Targets'           = ConvertFrom-CitrixOptimizerTarget -Target ([int]$DataRow.Targets)
        'Groups'            = [string[]]$DataRow.SelectedGroups -split ";"
        'IsDefaultTemplate' = [bool]$DataRow.IsDefaultTemplate
        'Version'           = [int]$DataRow.RevisionId
    }

    $SQLQuery = "SELECT * FROM VUEMCitrixOptimizerTemplatesContent WHERE IdContent = $($DataRow.IdContent)"
    $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
    if ($result) {
        $vuemObject | Add-Member -NotePropertyName "TemplateXml" -NotePropertyValue ([xml]$result.Tables.Rows.TemplateContent)
    }

    # override the default ToScript() method
    $vuemObject | Add-Member ScriptMethod ToString { $this.Name } -Force

    # set a custom type to the object
    $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.CitrixOptimizerConfigurationObject")

    return $vuemObject
}

function ConvertFrom-CitrixOptimizerTarget {
    param (
        [int]$Target
    )

    $OSs = @()

    $optimizerTargets = $configurationSettings."$($script:databaseSchema)".VUEMCitrixOptimizerTargets 
    foreach ($bit in ($optimizerTargets.GetEnumerator() | Sort-Object -Property Name)){
        if (($Target -band $Bit.Name) -ne 0){ $OSs += $bit.Value }
    }

    return $OSs
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
    Author: Arjan Mensch
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
    Author: Arjan Mensch
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
$XmlHeader                               = '<?xml version="1.0" encoding="utf-8"?><ArrayOfVUEMActionAdvancedOption xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
$XmlFooter                               = '</ArrayOfVUEMActionAdvancedOption>'
$defaultVUEMAppReserved                  = $XmlHeader + '<VUEMActionAdvancedOption><Name>SelfHealingEnabled</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>EnforceIconLocation</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>EnforcedIconXValue</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>EnforcedIconYValue</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>DoNotShowInSelfService</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>CreateShortcutInUserFavoritesFolder</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMPrinterReserved              = $XmlHeader + '<VUEMActionAdvancedOption><Name>SelfHealingEnabled</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMNetworkDriveReserved         = $XmlHeader + '<VUEMActionAdvancedOption><Name>SelfHealingEnabled</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>SetAsHomeDriveEnabled</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMVirtualDriveReserved         = $XmlHeader + '<VUEMActionAdvancedOption><Name>SetAsHomeDriveEnabled</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMEnvironmentVariableReserved  = $XmlHeader + '<VUEMActionAdvancedOption><Name>ExecOrder</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMExternalTaskReserved         = $XmlHeader + '<VUEMActionAdvancedOption><Name>ExecuteOnlyAtLogon</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMFileSystemOperationReserved  = $XmlHeader + '<VUEMActionAdvancedOption><Name>ExecOrder</Name><Value>0</Value></VUEMActionAdvancedOption>' + $XmlFooter
$defaultVUEMAdministratorPermissions     = '<?xml version="1.0" encoding="utf-8"?><ArrayOfVUEMAdminPermission xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><VUEMAdminPermission><idSite>0</idSite><AuthorizationLevel>ReadOnly</AuthorizationLevel></VUEMAdminPermission></ArrayOfVUEMAdminPermission>'

$configurationSettings = @{
    "1903" = @{
        "AppLockerFields"                 = "IdSite, State, RevisionId, Value, Setting"
        "AppLockerFieldsValues"           = @("({0}, 1, 1, 0, 'EnableProcessesAppLocker')", "({0}, 1, 1, 0, 'EnableDLLRuleCollection')", "({0}, 1, 1, 0, 'CollectionExeEnforcementState')", "({0}, 1, 1, 0, 'CollectionMsiEnforcementState')", "({0}, 1, 1, 0, 'CollectionScriptEnforcementState')", "({0}, 1, 1, 0, 'CollectionAppxEnforcementState')", "({0}, 1, 1, 0, 'CollectionDllEnforcementState')")
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
        "SiteFields"                      = "Name, Description, State, JProperties, RevisionId, Reserved01"
        "SiteValues"                      = "'{0}','{1}',1,'',1,NULL"
        "AppLockerFields"                 = "IdSite, State, RevisionId, Value, Setting"
        "AppLockerValues"                 = @("({0}, 1, 1, 0, 'EnableProcessesAppLocker')", "({0}, 1, 1, 0, 'EnableDLLRuleCollection')", "({0}, 1, 1, 0, 'CollectionExeEnforcementState')", "({0}, 1, 1, 0, 'CollectionMsiEnforcementState')", "({0}, 1, 1, 0, 'CollectionScriptEnforcementState')", "({0}, 1, 1, 0, 'CollectionAppxEnforcementState')", "({0}, 1, 1, 0, 'CollectionDllEnforcementState')")
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
    "1909" = @{
        "SiteFields"                      = "Name,Description,State,JProperties,RevisionId,Reserved01"
        "SiteValues"                      = "'{0}','{1}',1,'',1,NULL"
        "AppLockerFields"                 = "IdSite,State,RevisionId,Reserved01,Value,Setting"
        "AppLockerValues"                 = @("({0},1,1,Null,0,'EnableProcessesAppLocker')", "({0},1,1,Null,0,'EnableDLLRuleCollection')", "({0},1,1,Null,0,'CollectionExeEnforcementState')", "({0},1,1,Null,0,'CollectionMsiEnforcementState')", "({0},1,1,Null,0,'CollectionScriptEnforcementState')", "({0},1,1,Null,0,'CollectionAppxEnforcementState')", "({0},1,1,Null,0,'CollectionDllEnforcementState')")
        "GroupPolicyGlobalSettingsFields" = "IdSite,Name,Value"
        "GroupPolicyGlobalSettingsValues" = @("({0},'EnableGroupPolicyEnforcement','0')")
        "AgentSettingsFields"             = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "AgentSettingsValues"             = @("({0},'OfflineModeEnabled','0',1,1,NULL)", "({0},'UseCacheEvenIfOnline','0',1,1,NULL)", "({0},'processVUEMApps','0',1,1,NULL)", "({0},'processVUEMPrinters','0',1,1,NULL)", "({0},'processVUEMNetDrives','0',1,1,NULL)", "({0},'processVUEMVirtualDrives','0',1,1,NULL)", "({0},'processVUEMRegValues','0',1,1,NULL)", "({0},'processVUEMEnvVariables','0',1,1,NULL)", "({0},'processVUEMPorts','0',1,1,NULL)", "({0},'processVUEMIniFilesOps','0',1,1,NULL)", "({0},'processVUEMExtTasks','0',1,1,NULL)", "({0},'processVUEMFileSystemOps','0',1,1,NULL)", "({0},'processVUEMUserDSNs','0',1,1,NULL)", "({0},'processVUEMFileAssocs','0',1,1,NULL)", "({0},'UIAgentSplashScreenBackGround','',1,1,NULL)", "({0},'UIAgentLoadingCircleColor','',1,1,NULL)", "({0},'UIAgentLbl1TextColor','',1,1,NULL)", "({0},'UIAgentHelpLink','',1,1,NULL)", "({0},'AgentServiceDebugMode','0',1,1,NULL)", "({0},'LaunchVUEMAgentOnLogon','0',1,1,NULL)", "({0},'ProcessVUEMAgentLaunchForAdmins','0',1,1,NULL)", "({0},'LaunchVUEMAgentOnReconnect','0',1,1,NULL)", "({0},'EnableVirtualDesktopCompatibility','0',1,1,NULL)", "({0},'VUEMAgentType','UI',1,1,NULL)", "({0},'VUEMAgentDesktopsExtraLaunchDelay','0',1,1,NULL)", "({0},'VUEMAgentCacheRefreshDelay','30',1,1,NULL)", "({0},'VUEMAgentSQLSettingsRefreshDelay','15',1,1,NULL)", "({0},'DeleteDesktopShortcuts','0',1,1,NULL)", "({0},'DeleteStartMenuShortcuts','0',1,1,NULL)", "({0},'DeleteQuickLaunchShortcuts','0',1,1,NULL)", "({0},'DeleteNetworkDrives','0',1,1,NULL)", "({0},'DeleteNetworkPrinters','0',1,1,NULL)", "({0},'PreserveAutocreatedPrinters','0',1,1,NULL)", "({0},'PreserveSpecificPrinters','0',1,1,NULL)", "({0},'SpecificPreservedPrinters','PDFCreator;PDFMail;Acrobat Distiller;Amyuni',1,1,NULL)", "({0},'EnableAgentLogging','1',1,1,NULL)", "({0},'AgentLogFile','%USERPROFILE%\Citrix WEM Agent.log',1,1,NULL)", "({0},'AgentDebugMode','0',1,1,NULL)", "({0},'RefreshEnvironmentSettings','0',1,1,NULL)", "({0},'RefreshSystemSettings','0',1,1,NULL)", "({0},'RefreshDesktop','0',1,1,NULL)", "({0},'RefreshAppearance','0',1,1,NULL)", "({0},'AgentExitForAdminsOnly','1',1,1,NULL)", "({0},'AgentAllowUsersToManagePrinters','0',1,1,NULL)", "({0},'DeleteTaskBarPinnedShortcuts','0',1,1,NULL)", "({0},'DeleteStartMenuPinnedShortcuts','0',1,1,NULL)", "({0},'InitialEnvironmentCleanUp','0',1,1,NULL)", "({0},'aSyncVUEMAppsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMPrintersProcessing','0',1,1,NULL)", "({0},'aSyncVUEMNetDrivesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMVirtualDrivesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMRegValuesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMEnvVariablesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMPortsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMIniFilesOpsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMExtTasksProcessing','0',1,1,NULL)", "({0},'aSyncVUEMFileSystemOpsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMUserDSNsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMFileAssocsProcessing','0',1,1,NULL)", "({0},'byPassie4uinitCheck','0',1,1,NULL)", "({0},'UIAgentCustomLink','',1,1,NULL)", "({0},'enforceProcessVUEMApps','0',1,1,NULL)", "({0},'enforceProcessVUEMPrinters','0',1,1,NULL)", "({0},'enforceProcessVUEMNetDrives','0',1,1,NULL)", "({0},'enforceProcessVUEMVirtualDrives','0',1,1,NULL)", "({0},'enforceProcessVUEMRegValues','0',1,1,NULL)", "({0},'enforceProcessVUEMEnvVariables','0',1,1,NULL)", "({0},'enforceProcessVUEMPorts','0',1,1,NULL)", "({0},'enforceProcessVUEMIniFilesOps','0',1,1,NULL)", "({0},'enforceProcessVUEMExtTasks','0',1,1,NULL)", "({0},'enforceProcessVUEMFileSystemOps','0',1,1,NULL)", "({0},'enforceProcessVUEMUserDSNs','0',1,1,NULL)", "({0},'enforceProcessVUEMFileAssocs','0',1,1,NULL)", "({0},'revertUnassignedVUEMApps','0',1,1,NULL)", "({0},'revertUnassignedVUEMPrinters','0',1,1,NULL)", "({0},'revertUnassignedVUEMNetDrives','0',1,1,NULL)", "({0},'revertUnassignedVUEMVirtualDrives','0',1,1,NULL)", "({0},'revertUnassignedVUEMRegValues','0',1,1,NULL)", "({0},'revertUnassignedVUEMEnvVariables','0',1,1,NULL)", "({0},'revertUnassignedVUEMPorts','0',1,1,NULL)", "({0},'revertUnassignedVUEMIniFilesOps','0',1,1,NULL)", "({0},'revertUnassignedVUEMExtTasks','0',1,1,NULL)", "({0},'revertUnassignedVUEMFileSystemOps','0',1,1,NULL)", "({0},'revertUnassignedVUEMUserDSNs','0',1,1,NULL)", "({0},'revertUnassignedVUEMFileAssocs','0',1,1,NULL)", "({0},'AgentLaunchExcludeGroups','0',1,1,NULL)", "({0},'AgentLaunchExcludedGroups','',1,1,NULL)", "({0},'InitialDesktopUICleaning','0',1,1,NULL)", "({0},'EnableUIAgentAutomaticRefresh','0',1,1,NULL)", "({0},'UIAgentAutomaticRefreshDelay','30',1,1,NULL)", "({0},'AgentAllowUsersToManageApplications','0',1,1,NULL)", "({0},'HideUIAgentIconInPublishedApplications','0',1,1,NULL)", "({0},'ExecuteOnlyCmdAgentInPublishedApplications','0',1,1,NULL)", "({0},'enforceVUEMAppsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMPrintersFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMNetDrivesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMVirtualDrivesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMRegValuesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMEnvVariablesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMPortsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMIniFilesOpsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMExtTasksFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMFileSystemOpsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMUserDSNsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMFileAssocsFiltersProcessing','0',1,1,NULL)", "({0},'checkAppShortcutExistence','0',1,1,NULL)", "({0},'appShortcutExpandEnvironmentVariables','0',1,1,NULL)", "({0},'RefreshOnEnvironmentalSettingChange','1',1,1,NULL)", "({0},'HideUIAgentSplashScreen','0',1,1,NULL)", "({0},'processVUEMAppsOnReconnect','0',1,1,NULL)", "({0},'processVUEMPrintersOnReconnect','0',1,1,NULL)", "({0},'processVUEMNetDrivesOnReconnect','0',1,1,NULL)", "({0},'processVUEMVirtualDrivesOnReconnect','0',1,1,NULL)", "({0},'processVUEMRegValuesOnReconnect','0',1,1,NULL)", "({0},'processVUEMEnvVariablesOnReconnect','0',1,1,NULL)", "({0},'processVUEMPortsOnReconnect','0',1,1,NULL)", "({0},'processVUEMIniFilesOpsOnReconnect','0',1,1,NULL)", "({0},'processVUEMExtTasksOnReconnect','0',1,1,NULL)", "({0},'processVUEMFileSystemOpsOnReconnect','0',1,1,NULL)", "({0},'processVUEMUserDSNsOnReconnect','0',1,1,NULL)", "({0},'processVUEMFileAssocsOnReconnect','0',1,1,NULL)", "({0},'AgentAllowScreenCapture','0',1,1,NULL)", "({0},'AgentScreenCaptureEnableSendSupportEmail','0',1,1,NULL)", "({0},'AgentScreenCaptureSupportEmailAddress','',1,1,NULL)", "({0},'AgentScreenCaptureSupportEmailTemplate','',1,1,NULL)", "({0},'AgentEnableApplicationsShortcuts','0',1,1,NULL)", "({0},'UIAgentSkinName','Seven',1,1,NULL)", "({0},'HideUIAgentSplashScreenInPublishedApplications','0',1,1,NULL)", "({0},'MailCustomSubject',NULL,1,1,NULL)", "({0},'MailEnableUseSMTP','0',1,1,NULL)", "({0},'MailEnableSMTPSSL','0',1,1,NULL)", "({0},'MailSMTPPort','0',1,1,NULL)", "({0},'MailSMTPServer','',1,1,NULL)", "({0},'MailSMTPFromAddress','',1,1,NULL)", "({0},'MailSMTPToAddress','',1,1,NULL)", "({0},'MailEnableUseSMTPCredentials','0',1,1,NULL)", "({0},'MailSMTPUser','',1,1,NULL)", "({0},'MailSMTPPassword','',1,1,NULL)", "({0},'HideUIAgentSplashScreenOnReconnect','0',1,1,NULL)", "({0},'AgentDirectoryServiceTimeoutValue','15000',1,1,NULL)", "({0},'AgentBrokerServiceTimeoutValue','15000',1,1,NULL)", "({0},'AgentMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'ConnectionStateChangeNotificationEnabled','0',1,1,NULL)", "({0},'AgentPreventExitForAdmins','0',1,1,NULL)", "({0},'AgentNetworkResourceCheckTimeoutValue','500',1,1,NULL)", "({0},'AgentEnableCrossDomainsUserGroupsSearch','0',1,1,NULL)", "({0},'AgentShutdownAfterIdleEnabled','0',1,1,NULL)", "({0},'AgentShutdownAfterIdleTime','1800',1,1,NULL)", "({0},'AgentShutdownAfterEnabled','0',1,1,NULL)", "({0},'AgentShutdownAfter','02:00',1,1,NULL)", "({0},'AgentSuspendInsteadOfShutdown','0',1,1,NULL)", "({0},'AgentLaunchIncludeGroups','0',1,1,NULL)", "({0},'AgentLaunchIncludedGroups','',1,1,NULL)", "({0},'DisableAdministrativeRefreshFeedback','0',1,1,NULL)", "({0},'SwitchtoServiceAgent','0',1,1,NULL)", "({0},'UseGPO','0',1,1,NULL)", "({0},'CloudConnectors','',1,1,NULL)", "({0},'AgentSwitchFeatureToggle','1',1,1,NULL)", "({0},'AgentAllowUsersToResetCachedActions','0',1,1,NULL)")
        "EnvironmentalFields"             = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "EnvironmentalValues"             = @("({0},'HideCommonPrograms',0,'0',1,1,NULL)", "({0},'HideControlPanel',0,'0',1,1,NULL)", "({0},'RemoveRunFromStartMenu',0,'0',1,1,NULL)", "({0},'HideNetworkIcon',0,'0',1,1,NULL)", "({0},'HideAdministrativeTools',0,'0',1,1,NULL)", "({0},'HideNetworkConnections',0,'0',1,1,NULL)", "({0},'HideHelp',0,'0',1,1,NULL)", "({0},'HideWindowsUpdate',0,'0',1,1,NULL)", "({0},'HideTurnOff',0,'0',1,1,NULL)", "({0},'ForceLogoff',0,'0',1,1,NULL)", "({0},'HideFind',0,'0',1,1,NULL)", "({0},'DisableRegistryEditing',0,'0',1,1,NULL)", "({0},'DisableCmd',0,'0',1,1,NULL)", "({0},'NoNetConnectDisconnect',0,'0',1,1,NULL)", "({0},'Turnoffnotificationareacleanup',1,'0',1,1,NULL)", "({0},'LockTaskbar',1,'0',1,1,NULL)", "({0},'TurnOffpersonalizedmenus',1,'0',1,1,NULL)", "({0},'ClearRecentprogramslist',1,'0',1,1,NULL)", "({0},'RemoveContextMenuManageItem',0,'0',1,1,NULL)", "({0},'HideSpecifiedDrivesFromExplorer',1,'0',1,1,NULL)", "({0},'ExplorerHiddenDrives',1,'',1,1,NULL)", "({0},'DisableDragFullWindows',1,'0',1,1,NULL)", "({0},'DisableSmoothScroll',1,'0',1,1,NULL)", "({0},'DisableCursorBlink',1,'0',1,1,NULL)", "({0},'DisableMinAnimate',1,'0',1,1,NULL)", "({0},'SetInteractiveDelay',1,'0',1,1,NULL)", "({0},'InteractiveDelayValue',1,'40',1,1,NULL)", "({0},'EnableAutoEndTasks',1,'0',1,1,NULL)", "({0},'WaitToKillAppTimeout',1,'20000',1,1,NULL)", "({0},'SetCursorBlinkRate',1,'0',1,1,NULL)", "({0},'CursorBlinkRateValue',1,'-1',1,1,NULL)", "({0},'SetMenuShowDelay',1,'0',1,1,NULL)", "({0},'MenuShowDelayValue',1,'10',1,1,NULL)", "({0},'SetVisualStyleFile',1,'0',1,1,NULL)", "({0},'VisualStyleFileValue',1,'%windir%\resources\Themes\Aero\aero.msstyles',1,1,NULL)", "({0},'SetWallpaper',1,'0',1,1,NULL)", "({0},'Wallpaper',1,'',1,1,NULL)", "({0},'WallpaperStyle',1,'0',1,1,NULL)", "({0},'processEnvironmentalSettings',2,'0',1,1,NULL)", "({0},'RestrictSpecifiedDrivesFromExplorer',1,'0',1,1,NULL)", "({0},'ExplorerRestrictedDrives',1,'',1,1,NULL)", "({0},'HideNetworkInExplorer',1,'0',1,1,NULL)", "({0},'HideLibrairiesInExplorer',1,'0',1,1,NULL)", "({0},'NoProgramsCPL',0,'0',1,1,NULL)", "({0},'NoPropertiesMyComputer',0,'0',1,1,NULL)", "({0},'SetSpecificThemeFile',1,'0',1,1,NULL)", "({0},'SpecificThemeFileValue',1,'%windir%\resources\Themes\aero.theme',1,1,NULL)", "({0},'DisableSpecifiedKnownFolders',1,'0',1,1,NULL)", "({0},'DisabledKnownFolders',1,'',1,1,NULL)", "({0},'DisableSilentRegedit',0,'0',1,1,NULL)", "({0},'DisableCmdScripts',0,'0',1,1,NULL)", "({0},'HideDevicesandPrinters',0,'0',1,1,NULL)", "({0},'processEnvironmentalSettingsForAdmins',2,'0',1,1,NULL)", "({0},'HideSystemClock',0,'0',1,1,NULL)", "({0},'SetDesktopBackGroundColor',0,'0',1,1,NULL)", "({0},'DesktopBackGroundColor',0,'',1,1,NULL)", "({0},'NoMyComputerIcon',1,'0',1,1,NULL)", "({0},'NoRecycleBinIcon',1,'0',1,1,NULL)", "({0},'NoPropertiesRecycleBin',0,'0',1,1,NULL)", "({0},'NoMyDocumentsIcon',1,'0',1,1,NULL)", "({0},'NoPropertiesMyDocuments',0,'0',1,1,NULL)", "({0},'NoNtSecurity',0,'0',1,1,NULL)", "({0},'DisableTaskMgr',0,'0',1,1,NULL)", "({0},'RestrictCpl',0,'0',1,1,NULL)", "({0},'RestrictCplList',0,'Display',1,1,NULL)", "({0},'DisallowCpl',0,'0',1,1,NULL)", "({0},'DisallowCplList',0,'',1,1,NULL)", "({0},'BootToDesktopInsteadOfStart',1,'0',1,1,NULL)", "({0},'DisableTLcorner',0,'0',1,1,NULL)", "({0},'DisableCharmsHint',0,'0',1,1,NULL)", "({0},'NoTrayContextMenu',0,'0',1,1,NULL)", "({0},'NoViewContextMenu',0,'0',1,1,NULL)")
        "ItemsFields"                     = "IdSite,Name,DistinguishedName,Description,State,Type,Priority,RevisionId,Reserved01"
        "ItemsValues"                     = @("({0},'S-1-1-0','Everyone','A group that includes all users, even anonymous users and guests. Membership is controlled by the operating system.',1,1,100,1,NULL)", "({0},'S-1-5-32-544','BUILTIN\Administrators','A built-in group. After the initial installation of the operating system, the only member of the group is the Administrator account. When a computer joins a domain, the Domain Admins group is added to the Administrators group. When a server becomes a domain controller, the Enterprise Admins group also is added to the Administrators group.',1,1,100,1,NULL)")
        "KioskFields"                     = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "KioskValues"                     = @("({0},'PowerDontCheckBattery',0,'0',0,1,NULL)", "({0},'PowerShutdownAfterIdleTime',0,'1800',0,1,NULL)", "({0},'PowerShutdownAfterSpecifiedTime',0,'02:00',0,1,NULL)", "({0},'DesktopModeLogOffWebPortal',0,'0',0,1,NULL)", "({0},'EndSessionOption',0,'0',0,1,NULL)", "({0},'AutologonRegistryForce',0,'0',0,1,NULL)", "({0},'AutologonRegistryIgnoreShiftOverride',0,'0',0,1,NULL)", "({0},'AutologonPassword',0,'',0,1,NULL)", "({0},'AutologonDomain',0,'',0,1,NULL)", "({0},'AutologonUserName',0,'',0,1,NULL)", "({0},'AutologonEnable',0,'0',0,1,NULL)", "({0},'AdministrationHideDisplaySettings',0,'0',0,1,NULL)", "({0},'AdministrationHideKeyboardSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideMouseSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideClientDetails',0,'0',0,1,NULL)", "({0},'AdministrationDisableUnlock',0,'0',0,1,NULL)", "({0},'AdministrationHideWindowsVersion',0,'0',0,1,NULL)", "({0},'AdministrationDisableProgressBar',0,'0',0,1,NULL)", "({0},'AdministrationHidePrinterSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideLogOffOption',0,'0',0,1,NULL)", "({0},'AdministrationHideRestartOption',0,'0',0,1,NULL)", "({0},'AdministrationHideShutdownOption',0,'0',0,1,NULL)", "({0},'AdministrationHideVolumeSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideHomeButton',0,'0',0,1,NULL)", "({0},'AdministrationPreLaunchReceiver',0,'0',0,1,NULL)", "({0},'AdministrationIgnoreLastLanguage',0,'0',0,1,NULL)", "({0},'AdvancedHideTaskbar',0,'0',0,1,NULL)", "({0},'AdvancedLockCtrlAltDel',0,'0',0,1,NULL)", "({0},'AdvancedLockAltTab',0,'0',0,1,NULL)", "({0},'AdvancedFixBrowserRendering',0,'0',0,1,NULL)", "({0},'AdvancedLogOffScreenRedirection',0,'0',0,1,NULL)", "({0},'AdvancedSuppressScriptErrors',0,'0',0,1,NULL)", "({0},'AdvancedShowWifiSettings',0,'0',0,1,NULL)", "({0},'AdvancedHideKioskWhileCitrixSession',0,'0',0,1,NULL)", "({0},'AdvancedFixSslSites',0,'0',0,1,NULL)", "({0},'AdvancedAlwaysShowAdminMenu',0,'0',0,1,NULL)", "({0},'AdvancedFixZOrder',0,'0',0,1,NULL)", "({0},'ToolsAppsList',0,'',0,1,NULL)", "({0},'ToolsEnabled',0,'0',0,1,NULL)", "({0},'IsKioskEnabled',0,'0',0,1,NULL)", "({0},'SitesIsListEnabled',0,'0',0,1,NULL)", "({0},'SitesNamesAndLinks',0,'',0,1,'')", "({0},'GeneralStartUrl',0,'',0,1,NULL)", "({0},'GeneralTitle',0,'',0,1,NULL)", "({0},'GeneralShowNavigationButtons',0,'0',0,1,NULL)", "({0},'GeneralWindowMode',0,'0',0,1,NULL)", "({0},'GeneralClockEnabled',0,'0',0,1,NULL)", "({0},'GeneralClockUses12Hours',0,'0',0,1,NULL)", "({0},'GeneralUnlockPassword',0,'fLp34dnRI0DK26rJv8Tmqg==',0,1,NULL)", "({0},'GeneralEnableLanguageSelect',0,'0',0,1,NULL)", "({0},'GeneralAutoHideAppPanel',0,'0',0,1,NULL)", "({0},'GeneralEnableAppPanel',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnabled',0,'0',0,1,NULL)", "({0},'ProcessLauncherApplication',0,'',0,1,NULL)", "({0},'ProcessLauncherArgs',0,'',0,1,NULL)", "({0},'ProcessLauncherClearLastUsernameVMWare',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableVMWareViewMode',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableMicrosoftRdsMode',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableCitrixMode',0,'0',0,1,NULL)", "({0},'SetCitrixReceiverFSOMode',0,'0',0,1,NULL)")
        "ParametersFields"                = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "ParametersValues"                = @("({0},'excludedDriveletters','A;B;C;D',1,1,NULL)", "({0},'AllowDriveLetterReuse','0',1,1,NULL)")
        "PersonaFields"                   = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "PersonaValues"                   = @("({0},''PersonaManagementEnabled'',''0'',1,1,NULL)", "({0},''VPEnabled'',''0'',1,1,NULL)", "({0},''UploadProfileInterval'',''10'',1,1,NULL)", "({0},''SetCentralProfileStore'',''0'',1,1,NULL)", "({0},''CentralProfileStore'','''',1,1,NULL)", "({0},''CentralProfileOverride'',''0'',1,1,NULL)", "({0},''DeleteLocalProfile'',''0'',1,1,NULL)", "({0},''DeleteLocalSettings'',''0'',1,1,NULL)", "({0},''RoamLocalSettings'',''0'',1,1,NULL)", "({0},''EnableBackgroundDownload'',''0'',1,1,NULL)", "({0},''CleanupCLFSFiles'',''0'',1,1,NULL)", "({0},''SetDynamicRoamingFiles'',''0'',1,1,NULL)", "({0},''DynamicRoamingFiles'','''',1,1,NULL)", "({0},''SetDynamicRoamingFilesExceptions'',''0'',1,1,NULL)", "({0},''DynamicRoamingFilesExceptions'','''',1,1,NULL)", "({0},''SetBasicRoamingFiles'',''0'',1,1,NULL)", "({0},''BasicRoamingFiles'','''',1,1,NULL)", "({0},''SetBasicRoamingFilesExceptions'',''0'',1,1,NULL)", "({0},''BasicRoamingFilesExceptions'','''',1,1,NULL)", "({0},''SetDontRoamFiles'',''0'',1,1,NULL)", "({0},''DontRoamFiles'',''AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla'',1,1,NULL)", "({0},''SetDontRoamFilesExceptions'',''0'',1,1,NULL)", "({0},''DontRoamFilesExceptions'','''',1,1,NULL)", "({0},''SetBackgroundLoadFolders'',''0'',1,1,NULL)", "({0},''BackgroundLoadFolders'','''',1,1,NULL)", "({0},''SetBackgroundLoadFoldersExceptions'',''0'',1,1,NULL)", "({0},''BackgroundLoadFoldersExceptions'','''',1,1,NULL)", "({0},''SetExcludedProcesses'',''0'',1,1,NULL)", "({0},''ExcludedProcesses'','''',1,1,NULL)", "({0},''HideOfflineIcon'',''0'',1,1,NULL)", "({0},''HideFileCopyProgress'',''0'',1,1,NULL)", "({0},''FileCopyMinSize'',''50'',1,1,NULL)", "({0},''EnableTrayIconErrorAlerts'',''0'',1,1,NULL)", "({0},''SetLogPath'',''0'',1,1,NULL)", "({0},''LogPath'','''',1,1,NULL)", "({0},''SetLoggingDestination'',''0'',1,1,NULL)", "({0},''LogToFile'',''0'',1,1,NULL)", "({0},''LogToDebugPort'',''0'',1,1,NULL)", "({0},''SetLoggingFlags'',''0'',1,1,NULL)", "({0},''LogError'',''0'',1,1,NULL)", "({0},''LogInformation'',''0'',1,1,NULL)", "({0},''LogDebug'',''0'',1,1,NULL)", "({0},''SetDebugFlags'',''0'',1,1,NULL)", "({0},''DebugError'',''0'',1,1,NULL)", "({0},''DebugInformation'',''0'',1,1,NULL)", "({0},''DebugPorts'',''0'',1,1,NULL)", "({0},''AddAdminGroupToRedirectedFolders'',''0'',1,1,NULL)", "({0},''RedirectApplicationData'',''0'',1,1,NULL)", "({0},''ApplicationDataRedirectedPath'','''',1,1,NULL)", "({0},''RedirectContacts'',''0'',1,1,NULL)", "({0},''ContactsRedirectedPath'','''',1,1,NULL)", "({0},''RedirectCookies'',''0'',1,1,NULL)", "({0},''CookiesRedirectedPath'','''',1,1,NULL)", "({0},''RedirectDesktop'',''0'',1,1,NULL)", "({0},''DesktopRedirectedPath'','''',1,1,NULL)", "({0},''RedirectDownloads'',''0'',1,1,NULL)", "({0},''DownloadsRedirectedPath'','''',1,1,NULL)", "({0},''RedirectFavorites'',''0'',1,1,NULL)", "({0},''FavoritesRedirectedPath'','''',1,1,NULL)", "({0},''RedirectHistory'',''0'',1,1,NULL)", "({0},''HistoryRedirectedPath'','''',1,1,NULL)", "({0},''RedirectLinks'',''0'',1,1,NULL)", "({0},''LinksRedirectedPath'','''',1,1,NULL)", "({0},''RedirectMyDocuments'',''0'',1,1,NULL)", "({0},''MyDocumentsRedirectedPath'','''',1,1,NULL)", "({0},''RedirectMyMusic'',''0'',1,1,NULL)", "({0},''MyMusicRedirectedPath'','''',1,1,NULL)", "({0},''RedirectMyPictures'',''0'',1,1,NULL)", "({0},''MyPicturesRedirectedPath'','''',1,1,NULL)", "({0},''RedirectMyVideos'',''0'',1,1,NULL)", "({0},''MyVideosRedirectedPath'','''',1,1,NULL)", "({0},''RedirectNetworkNeighborhood'',''0'',1,1,NULL)", "({0},''NetworkNeighborhoodRedirectedPath'','''',1,1,NULL)", "({0},''RedirectPrinterNeighborhood'',''0'',1,1,NULL)", "({0},''PrinterNeighborhoodRedirectedPath'','''',1,1,NULL)", "({0},''RedirectRecentItems'',''0'',1,1,NULL)", "({0},''RecentItemsRedirectedPath'','''',1,1,NULL)", "({0},''RedirectSavedGames'',''0'',1,1,NULL)", "({0},''SavedGamesRedirectedPath'','''',1,1,NULL)", "({0},''RedirectSearches'',''0'',1,1,NULL)", "({0},''SearchesRedirectedPath'','''',1,1,NULL)", "({0},''RedirectSendTo'',''0'',1,1,NULL)", "({0},''SendToRedirectedPath'','''',1,1,NULL)", "({0},''RedirectStartMenu'',''0'',1,1,NULL)", "({0},''StartMenuRedirectedPath'','''',1,1,NULL)", "({0},''RedirectStartupItems'',''0'',1,1,NULL)", "({0},''StartupItemsRedirectedPath'','''',1,1,NULL)", "({0},''RedirectTemplates'',''0'',1,1,NULL)", "({0},''TemplatesRedirectedPath'','''',1,1,NULL)", "({0},''RedirectTemporaryInternetFiles'',''0'',1,1,NULL)", "({0},''TemporaryInternetFilesRedirectedPath'','''',1,1,NULL)", "({0},''SetFRExclusions'',''0'',1,1,NULL)", "({0},''FRExclusions'','''',1,1,NULL)", "({0},''SetFRExclusionsExceptions'',''0'',1,1,NULL)", "({0},''FRExclusionsExceptions'','''',1,1,NULL)")
        "SystemMonitoringFields"          = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "SystemMonitoringValues"          = @("({0},'EnableSystemMonitoring','0',1,1,NULL)", "({0},'EnableGlobalSystemMonitoring','0',1,1,NULL)", "({0},'EnableProcessActivityMonitoring','0',1,1,NULL)", "({0},'EnableUserExperienceMonitoring','0',1,1,NULL)", "({0},'LocalDatabaseRetentionPeriod','3',1,1,NULL)", "({0},'LocalDataUploadFrequency','4',1,1,NULL)", "({0},'EnableApplicationReportsWindows2K3XPCompliance','0',1,1,NULL)",  "({0},'ExcludeProcessesFromApplicationReports','1',1,1,NULL)", "({0},'ExcludedProcessesFromApplicationReports','dwm;taskhost;vmtoolsd;winlogon;csrss;wisptis;dllhost;consent;msiexec;userinit;LogonUI;mscorsvw;SearchProtocolHost;Rundll32;explorer;regsvr32;WmiPrvSE;services;smss;SearchFilterHost;lsass;svchost;lsm;msdtc;wininit;VGAuthService;SearchIndexer;spoolsv;vmtoolsd;vmacthlp;audiodg;VMwareResolutionSet;mobsync;wsqmcons;schtasks;Defrag;conhost;VSSVC;sdclt;MpCmdRun;WMIADAP;encsvc;wfshell;CpSvc;VDARedirector;CpSvc64;SemsService;ctxrdr;PicaSvc2;encsvc;GfxMgr;PicaSessionAgent;CtxGfx;PicaTwiHost;PicaUserAgent;VDARedirector;PicaShell;PicaEuemRelay;CtxMtHost;CtxSensLoader;ssonsvr;concentr;wfcrun32;pnamain;redirector;concentr;pnamain;pnagent;IMAAdvanceSrv;mfcom;ctxxmlss;Citrix.XenApp.Commands.Remoting.Service;HCAService;cmstart;startssonsvr;ctxhide;mmvdhost;runonce;rdpclip;TabTip;InputPersonalization;TabTip32;TSTheme;ngen;XTE;CtxSvcHost;OSPPSVC;TelemetryService;CtxAudioService;picatzrestore;CheckTermSrv;IMATest;RequestTicket;csc;cvtres;ssoncom;UpmUserMsg;CtxPvD;MultimediaRedirector;gpscript;shutdown;splwow64',1,1,NULL)", "({0},'EnableStrictPrivacy','0',1,1,NULL)", "({0},'BusinessDayStartHour','8',1,1,NULL)", "({0},'BusinessDayEndHour','19',1,1,NULL)", "({0},'ReportsBootTimeMinimum','5',1,1,NULL)", "({0},'ReportsLoginTimeMinimum','5',1,1,NULL)", "({0},'EnableWorkDaysFiltering','1',1,1,NULL)", "({0},'WorkDaysFilter','1;1;1;1;1;0;0',1,1,NULL)")
        "SystemUtilitiesFields"           = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "SystemUtilitiesValues"           = @("({0},'EnableFastLogoff',0,'0',1,1,NULL)", "({0},'ExcludeGroupsFromFastLogoff',0,'0',1,1,NULL)", "({0},'FastLogoffExcludedGroups',0,NULL,1,1,NULL)", "({0},'EnableCPUSpikesProtection',1,'0',1,1,NULL)", "({0},'SpikesProtectionCPUUsageLimitPercent',1,'70',1,1,NULL)", "({0},'SpikesProtectionCPUUsageLimitSampleTime',1,'30',1,1,NULL)", "({0},'SpikesProtectionIdlePriorityConstraintTime',1,'180',1,1,NULL)", "({0},'ExcludeProcessesFromCPUSpikesProtection',1,'0',1,1,NULL)", "({0},'CPUSpikesProtectionExcludedProcesses',1,NULL,1,1,NULL)", "({0},'EnableMemoryWorkingSetOptimization',2,'0',1,1,NULL)", "({0},'MemoryWorkingSetOptimizationIdleSampleTime',2,'120',1,1,NULL)", "({0},'ExcludeProcessesFromMemoryWorkingSetOptimization',2,'0',1,1,NULL)", "({0},'MemoryWorkingSetOptimizationExcludedProcesses',2,NULL,1,1,NULL)", "({0},'EnableProcessesBlackListing',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListedProcesses',3,NULL,1,1,NULL)", "({0},'ProcessesManagementBlackListExcludeLocalAdministrators',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListExcludeSpecifiedGroups',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListExcludedSpecifiedGroupsList',3,'',1,1,NULL)", "({0},'EnableProcessesWhiteListing',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListedProcesses',3,NULL,1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludeLocalAdministrators',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludeSpecifiedGroups',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludedSpecifiedGroupsList',3,'',1,1,NULL)", "({0},'EnableProcessesManagement',3,'0',1,1,NULL)", "({0},'EnableProcessesClamping',4,'0',1,1,NULL)", "({0},'ProcessesClampingList',4,NULL,1,1,NULL)", "({0},'EnableProcessesAffinity',5,'0',1,1,NULL)", "({0},'ProcessesAffinityList',5,NULL,1,1,NULL)", "({0},'EnableProcessesIoPriority',6,'0',1,1,NULL)", "({0},'ProcessesIoPriorityList',6,NULL,1,1,NULL)", "({0},'EnableProcessesCpuPriority',7,'0',1,1,NULL)", "({0},'ProcessesCpuPriorityList',7,NULL,1,1,NULL)", "({0},'MemoryWorkingSetOptimizationIdleStateLimitPercent',2,'1',1,1,NULL)", "({0},'EnableIntelligentCpuOptimization',1,'0',1,1,NULL)", "({0},'EnableIntelligentIoOptimization',1,'0',1,1,NULL)", "({0},'SpikesProtectionLimitCPUCoreNumber',1,'0',1,1,NULL)", "({0},'SpikesProtectionCPUCoreLimit',1,'1',1,1,NULL)",  "({0},'AppLockerControllerManagement',1,'1',1,1,NULL)", "({0},'AppLockerControllerReplaceModeOn',1,'1',1,1,NULL)", "({0},'AutoCPUSpikeProtectionSelected',1,'1',1,1,NULL)")
        "UPMFields"                       = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "UPMValues"                       = @("({0},'UPMManagementEnabled','0',1,1,NULL)", "({0},'ServiceActive','0',1,1,NULL)", "({0},'SetProcessedGroups','0',1,1,NULL)", "({0},'ProcessedGroupsList','',1,1,NULL)", "({0},'ProcessAdmins','0',1,1,NULL)", "({0},'SetPathToUserStore','0',1,1,NULL)", "({0},'MigrateUserStore','0',1,1,NULL)", "({0},'PathToUserStore','Windows',1,1,NULL)", "({0},'MigrateUserStorePath','',1,1,NULL)", "({0},'PSMidSessionWriteBack','0',1,1,NULL)", "({0},'OfflineSupport','0',1,1,NULL)", "({0},'DeleteCachedProfilesOnLogoff','0',1,1,NULL)", "({0},'SetMigrateWindowsProfilesToUserStore','0',1,1,NULL)", "({0},'MigrateWindowsProfilesToUserStore','1',1,1,NULL)", "({0},'AutomaticMigrationEnabled','0',1,1,NULL)", "({0},'SetLocalProfileConflictHandling','0',1,1,NULL)", "({0},'LocalProfileConflictHandling','1',1,1,NULL)", "({0},'SetTemplateProfilePath','0',1,1,NULL)", "({0},'TemplateProfilePath','',1,1,NULL)", "({0},'TemplateProfileOverridesLocalProfile','0',1,1,NULL)", "({0},'TemplateProfileOverridesRoamingProfile','0',1,1,NULL)", "({0},'SetLoadRetries','0',1,1,NULL)", "({0},'LoadRetries','5',1,1,NULL)", "({0},'SetUSNDBPath','0',1,1,NULL)", "({0},'USNDBPath','',1,1,NULL)", "({0},'XenAppOptimizationEnabled','0',1,1,NULL)", "({0},'XenAppOptimizationPath','',1,1,NULL)", "({0},'ProcessCookieFiles','0',1,1,NULL)", "({0},'DeleteRedirectedFolders','0',1,1,NULL)", "({0},'LoggingEnabled','0',1,1,NULL)", "({0},'SetLogLevels','0',1,1,NULL)", "({0},'LogLevels','0;0;0;0;0;0;0;0;0;0;0',1,1,NULL)", "({0},'SetMaxLogSize','0',1,1,NULL)", "({0},'MaxLogSize','1048576',1,1,NULL)", "({0},'SetPathToLogFile','0',1,1,NULL)", "({0},'PathToLogFile','',1,1,NULL)", "({0},'SetExclusionListRegistry','0',1,1,NULL)", "({0},'ExclusionListRegistry','',1,1,NULL)", "({0},'SetInclusionListRegistry','0',1,1,NULL)", "({0},'InclusionListRegistry','',1,1,NULL)", "({0},'SetSyncExclusionListFiles','0',1,1,NULL)", "({0},'SyncExclusionListFiles','AppData\Roaming\Microsoft\Windows\Start Menu\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Startup\Desktop.ini',1,1,NULL)", "({0},'SetSyncExclusionListDir','0',1,1,NULL)", "({0},'SyncExclusionListDir','`$Recycle.Bin;AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1,NULL)", "({0},'SetSyncDirList','0',1,1,NULL)", "({0},'SyncDirList','',1,1,NULL)", "({0},'SetSyncFileList','0',1,1,NULL)", "({0},'SyncFileList','',1,1,NULL)", "({0},'SetMirrorFoldersList','0',1,1,NULL)", "({0},'MirrorFoldersList','',1,1,NULL)", "({0},'SetProfileContainerList','0',1,1,NULL)", "({0},'ProfileContainerList','',1,1,NULL)", "({0},'SetLargeFileHandlingList','0',1,1,NULL)", "({0},'LargeFileHandlingList','',1,1,NULL)", "({0},'PSEnabled','0',1,1,NULL)", "({0},'PSAlwaysCache','0',1,1,NULL)", "({0},'PSAlwaysCacheSize','0',1,1,NULL)", "({0},'SetPSPendingLockTimeout','0',1,1,NULL)", "({0},'PSPendingLockTimeout','1',1,1,NULL)", "({0},'SetPSUserGroupsList','0',1,1,NULL)", "({0},'PSUserGroupsList','',1,1,NULL)", "({0},'CPEnabled','0',1,1,NULL)", "({0},'SetCPUserGroupList','0',1,1,NULL)", "({0},'CPUserGroupList','',1,1,NULL)", "({0},'SetCPSchemaPath','0',1,1,NULL)", "({0},'CPSchemaPath','',1,1,NULL)", "({0},'SetCPPath','0',1,1,NULL)", "({0},'CPPath','',1,1,NULL)", "({0},'CPMigrationFromBaseProfileToCPStore','0',1,1,NULL)", "({0},'SetExcludedGroups','0',1,1,NULL)", "({0},'ExcludedGroupsList','',1,1,NULL)", "({0},'DisableDynamicConfig','0',1,1,NULL)", "({0},'LogoffRatherThanTempProfile','0',1,1,NULL)", "({0},'SetProfileDeleteDelay','0',1,1,NULL)", "({0},'ProfileDeleteDelay','0',1,1,NULL)", "({0},'TemplateProfileIsMandatory','0',1,1,NULL)", "({0},'PSMidSessionWriteBackReg','0',1,1,NULL)", "({0},'CEIPEnabled','1',1,1,NULL)", "({0},'LastKnownGoodRegistry','0',1,1,NULL)", "({0},'EnableDefaultExclusionListRegistry','0',1,1,NULL)", "({0},'ExclusionDefaultRegistry01','1',1,1,NULL)", "({0},'ExclusionDefaultRegistry02','1',1,1,NULL)", "({0},'ExclusionDefaultRegistry03','1',1,1,NULL)", "({0},'EnableDefaultExclusionListDirectories','0',1,1,NULL)", "({0},'ExclusionDefaultDir01','1',1,1,NULL)", "({0},'ExclusionDefaultDir02','1',1,1,NULL)", "({0},'ExclusionDefaultDir03','1',1,1,NULL)", "({0},'ExclusionDefaultDir04','1',1,1,NULL)", "({0},'ExclusionDefaultDir05','1',1,1,NULL)", "({0},'ExclusionDefaultDir06','1',1,1,NULL)", "({0},'ExclusionDefaultDir07','1',1,1,NULL)", "({0},'ExclusionDefaultDir08','1',1,1,NULL)", "({0},'ExclusionDefaultDir09','1',1,1,NULL)", "({0},'ExclusionDefaultDir10','1',1,1,NULL)", "({0},'ExclusionDefaultDir11','1',1,1,NULL)", "({0},'ExclusionDefaultDir12','1',1,1,NULL)", "({0},'ExclusionDefaultDir13','1',1,1,NULL)", "({0},'ExclusionDefaultDir14','1',1,1,NULL)", "({0},'ExclusionDefaultDir15','1',1,1,NULL)", "({0},'ExclusionDefaultDir16','1',1,1,NULL)", "({0},'ExclusionDefaultDir17','1',1,1,NULL)", "({0},'ExclusionDefaultDir18','1',1,1,NULL)", "({0},'ExclusionDefaultDir19','1',1,1,NULL)", "({0},'ExclusionDefaultDir20','1',1,1,NULL)", "({0},'ExclusionDefaultDir21','1',1,1,NULL)", "({0},'ExclusionDefaultDir22','1',1,1,NULL)", "({0},'ExclusionDefaultDir23','1',1,1,NULL)", "({0},'ExclusionDefaultDir24','1',1,1,NULL)", "({0},'ExclusionDefaultDir25','1',1,1,NULL)", "({0},'ExclusionDefaultDir26','1',1,1,NULL)", "({0},'ExclusionDefaultDir27','1',1,1,NULL)", "({0},'ExclusionDefaultDir28','1',1,1,NULL)", "({0},'ExclusionDefaultDir29','1',1,1,NULL)", "({0},'ExclusionDefaultDir30','1',1,1,NULL)", "({0},'EnableStreamingExclusionList','0',1,1,NULL)", "({0},'StreamingExclusionList','',1,1,NULL)", "({0},'EnableLogonExclusionCheck','0',1,1,NULL)", "({0},'LogonExclusionCheck','0',1,1,NULL)", "({0},'OutlookSearchRoamingEnabled','0',1,1,NULL)", "({0},'SearchBackupRestoreEnabled','0',1,1,NULL)")
        "USVFields"                       = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "USVValues"                       = @("({0},'processUSVConfiguration',0,'0',1,1,NULL)", "({0},'processUSVConfigurationForAdmins',0,'0',1,1,NULL)", "({0},'SetWindowsRoamingProfilesPath',1,'0',1,1,NULL)", "({0},'WindowsRoamingProfilesPath',1,'',1,1,NULL)", "({0},'SetRDSRoamingProfilesPath',1,'0',1,1,NULL)", "({0},'RDSRoamingProfilesPath',1,'',1,1,NULL)", "({0},'SetRDSHomeDrivePath',1,'0',1,1,NULL)", "({0},'RDSHomeDrivePath',1,'',1,1,NULL)", "({0},'RDSHomeDriveLetter',1,'Z:',1,1,NULL)", "({0},'SetRoamingProfilesFoldersExclusions',2,'0',1,1,NULL)", "({0},'RoamingProfilesFoldersExclusions',2,'AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp',1,1,NULL)", "({0},'DeleteRoamingCachedProfiles',1,'0',1,1,NULL)", "({0},'AddAdminGroupToRUP',1,'0',1,1,NULL)", "({0},'CompatibleRUPSecurity',1,'0',1,1,NULL)", "({0},'DisableSlowLinkDetect',1,'0',1,1,NULL)", "({0},'SlowLinkProfileDefault',1,'0',1,1,NULL)", "({0},'processFoldersRedirectionConfiguration',3,'0',1,1,NULL)", "({0},'DeleteLocalRedirectedFolders',3,'0',1,1,NULL)", "({0},'processDesktopRedirection',3,'0',1,1,NULL)", "({0},'DesktopRedirectedPath',3,'',1,1,NULL)", "({0},'processStartMenuRedirection',3,'0',1,1,NULL)", "({0},'StartMenuRedirectedPath',3,'',1,1,NULL)", "({0},'processPersonalRedirection',3,'0',1,1,NULL)", "({0},'PersonalRedirectedPath',3,'',1,1,NULL)", "({0},'processPicturesRedirection',3,'0',1,1,NULL)", "({0},'PicturesRedirectedPath',3,'',1,1,NULL)", "({0},'MyPicturesFollowsDocuments',3,'0',1,1,NULL)", "({0},'processMusicRedirection',3,'0',1,1,NULL)", "({0},'MusicRedirectedPath',3,'',1,1,NULL)", "({0},'MyMusicFollowsDocuments',3,'0',1,1,NULL)", "({0},'processVideoRedirection',3,'0',1,1,NULL)", "({0},'VideoRedirectedPath',3,'',1,1,NULL)", "({0},'MyVideoFollowsDocuments',3,'0',1,1,NULL)", "({0},'processFavoritesRedirection',3,'0',1,1,NULL)", "({0},'FavoritesRedirectedPath',3,'',1,1,NULL)", "({0},'processAppDataRedirection',3,'0',1,1,NULL)", "({0},'AppDataRedirectedPath',3,'',1,1,NULL)", "({0},'processContactsRedirection',3,'0',1,1,NULL)", "({0},'ContactsRedirectedPath',3,'',1,1,NULL)", "({0},'processDownloadsRedirection',3,'0',1,1,NULL)", "({0},'DownloadsRedirectedPath',3,'',1,1,NULL)", "({0},'processLinksRedirection',3,'0',1,1,NULL)", "({0},'LinksRedirectedPath',3,'',1,1,NULL)", "({0},'processSearchesRedirection',3,'0',1,1,NULL)", "({0},'SearchesRedirectedPath',3,'',1,1,NULL)")

        "CleanupTables"                   = @("VUEMActionGroups","VUEMApps","VUEMPrinters","VUEMNetDrives","VUEMVirtualDrives","VUEMRegValues","VUEMEnvVariables","VUEMPorts","VUEMIniFilesOps","VUEMExtTasks","VUEMFileSystemOps","VUEMUserDSNs","VUEMFileAssocs","VUEMFiltersRules","VUEMFiltersConditions","VUEMItems","VUEMUserStatistics","VUEMAgentStatistics","VUEMSystemMonitoringData","VUEMActivityMonitoringData","VUEMUserExperienceMonitoringData","VUEMResourcesOptimizationData","VUEMParameters","VUEMAgentSettings","VUEMSystemUtilities","VUEMEnvironmentalSettings","VUEMUPMSettings","VUEMPersonaSettings","VUEMUSVSettings","VUEMKioskSettings","VUEMSystemMonitoringSettings","VUEMTasks","VUEMStorefrontSettings","VUEMChangesLog","VUEMAgentsLog","VUEMADObjects","AppLockerSettings","GroupPolicyObjects","GroupPolicyGlobalSettings","VUEMSites")
    }
    "1912" = @{
        "SiteFields"                      = "Name,Description,State,JProperties,RevisionId,Reserved01"
        "SiteValues"                      = "'{0}','{1}',1,'',1,NULL"
        "AppLockerFields"                 = "IdSite,State,RevisionId,Reserved01,Value,Setting"
        "AppLockerValues"                 = @("({0},1,1,Null,0,'EnableProcessesAppLocker')", "({0},1,1,Null,0,'EnableDLLRuleCollection')", "({0},1,1,Null,0,'CollectionExeEnforcementState')", "({0},1,1,Null,0,'CollectionMsiEnforcementState')", "({0},1,1,Null,0,'CollectionScriptEnforcementState')", "({0},1,1,Null,0,'CollectionAppxEnforcementState')", "({0},1,1,Null,0,'CollectionDllEnforcementState')")
        "GroupPolicyGlobalSettingsFields" = "IdSite,Name,Value"
        "GroupPolicyGlobalSettingsValues" = @("({0},'EnableGroupPolicyEnforcement','0')")
        "AgentSettingsFields"             = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "AgentSettingsValues"             = @("({0},'OfflineModeEnabled','0',1,1,NULL)", "({0},'UseCacheEvenIfOnline','0',1,1,NULL)", "({0},'processVUEMApps','0',1,1,NULL)", "({0},'processVUEMPrinters','0',1,1,NULL)", "({0},'processVUEMNetDrives','0',1,1,NULL)", "({0},'processVUEMVirtualDrives','0',1,1,NULL)", "({0},'processVUEMRegValues','0',1,1,NULL)", "({0},'processVUEMEnvVariables','0',1,1,NULL)", "({0},'processVUEMPorts','0',1,1,NULL)", "({0},'processVUEMIniFilesOps','0',1,1,NULL)", "({0},'processVUEMExtTasks','0',1,1,NULL)", "({0},'processVUEMFileSystemOps','0',1,1,NULL)", "({0},'processVUEMUserDSNs','0',1,1,NULL)", "({0},'processVUEMFileAssocs','0',1,1,NULL)", "({0},'UIAgentSplashScreenBackGround','',1,1,NULL)", "({0},'UIAgentLoadingCircleColor','',1,1,NULL)", "({0},'UIAgentLbl1TextColor','',1,1,NULL)", "({0},'UIAgentHelpLink','',1,1,NULL)", "({0},'AgentServiceDebugMode','0',1,1,NULL)", "({0},'LaunchVUEMAgentOnLogon','0',1,1,NULL)", "({0},'ProcessVUEMAgentLaunchForAdmins','0',1,1,NULL)", "({0},'LaunchVUEMAgentOnReconnect','0',1,1,NULL)", "({0},'EnableVirtualDesktopCompatibility','0',1,1,NULL)", "({0},'VUEMAgentType','UI',1,1,NULL)", "({0},'VUEMAgentDesktopsExtraLaunchDelay','0',1,1,NULL)", "({0},'VUEMAgentCacheRefreshDelay','30',1,1,NULL)", "({0},'VUEMAgentSQLSettingsRefreshDelay','15',1,1,NULL)", "({0},'DeleteDesktopShortcuts','0',1,1,NULL)", "({0},'DeleteStartMenuShortcuts','0',1,1,NULL)", "({0},'DeleteQuickLaunchShortcuts','0',1,1,NULL)", "({0},'DeleteNetworkDrives','0',1,1,NULL)", "({0},'DeleteNetworkPrinters','0',1,1,NULL)", "({0},'PreserveAutocreatedPrinters','0',1,1,NULL)", "({0},'PreserveSpecificPrinters','0',1,1,NULL)", "({0},'SpecificPreservedPrinters','PDFCreator;PDFMail;Acrobat Distiller;Amyuni',1,1,NULL)", "({0},'EnableAgentLogging','1',1,1,NULL)", "({0},'AgentLogFile','%USERPROFILE%\Citrix WEM Agent.log',1,1,NULL)", "({0},'AgentDebugMode','0',1,1,NULL)", "({0},'RefreshEnvironmentSettings','0',1,1,NULL)", "({0},'RefreshSystemSettings','0',1,1,NULL)", "({0},'RefreshDesktop','0',1,1,NULL)", "({0},'RefreshAppearance','0',1,1,NULL)", "({0},'AgentExitForAdminsOnly','1',1,1,NULL)", "({0},'AgentAllowUsersToManagePrinters','0',1,1,NULL)", "({0},'DeleteTaskBarPinnedShortcuts','0',1,1,NULL)", "({0},'DeleteStartMenuPinnedShortcuts','0',1,1,NULL)", "({0},'InitialEnvironmentCleanUp','0',1,1,NULL)", "({0},'aSyncVUEMAppsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMPrintersProcessing','0',1,1,NULL)", "({0},'aSyncVUEMNetDrivesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMVirtualDrivesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMRegValuesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMEnvVariablesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMPortsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMIniFilesOpsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMExtTasksProcessing','0',1,1,NULL)", "({0},'aSyncVUEMFileSystemOpsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMUserDSNsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMFileAssocsProcessing','0',1,1,NULL)", "({0},'byPassie4uinitCheck','0',1,1,NULL)", "({0},'UIAgentCustomLink','',1,1,NULL)", "({0},'enforceProcessVUEMApps','0',1,1,NULL)", "({0},'enforceProcessVUEMPrinters','0',1,1,NULL)", "({0},'enforceProcessVUEMNetDrives','0',1,1,NULL)", "({0},'enforceProcessVUEMVirtualDrives','0',1,1,NULL)", "({0},'enforceProcessVUEMRegValues','0',1,1,NULL)", "({0},'enforceProcessVUEMEnvVariables','0',1,1,NULL)", "({0},'enforceProcessVUEMPorts','0',1,1,NULL)", "({0},'enforceProcessVUEMIniFilesOps','0',1,1,NULL)", "({0},'enforceProcessVUEMExtTasks','0',1,1,NULL)", "({0},'enforceProcessVUEMFileSystemOps','0',1,1,NULL)", "({0},'enforceProcessVUEMUserDSNs','0',1,1,NULL)", "({0},'enforceProcessVUEMFileAssocs','0',1,1,NULL)", "({0},'revertUnassignedVUEMApps','0',1,1,NULL)", "({0},'revertUnassignedVUEMPrinters','0',1,1,NULL)", "({0},'revertUnassignedVUEMNetDrives','0',1,1,NULL)", "({0},'revertUnassignedVUEMVirtualDrives','0',1,1,NULL)", "({0},'revertUnassignedVUEMRegValues','0',1,1,NULL)", "({0},'revertUnassignedVUEMEnvVariables','0',1,1,NULL)", "({0},'revertUnassignedVUEMPorts','0',1,1,NULL)", "({0},'revertUnassignedVUEMIniFilesOps','0',1,1,NULL)", "({0},'revertUnassignedVUEMExtTasks','0',1,1,NULL)", "({0},'revertUnassignedVUEMFileSystemOps','0',1,1,NULL)", "({0},'revertUnassignedVUEMUserDSNs','0',1,1,NULL)", "({0},'revertUnassignedVUEMFileAssocs','0',1,1,NULL)", "({0},'AgentLaunchExcludeGroups','0',1,1,NULL)", "({0},'AgentLaunchExcludedGroups','',1,1,NULL)", "({0},'InitialDesktopUICleaning','0',1,1,NULL)", "({0},'EnableUIAgentAutomaticRefresh','0',1,1,NULL)", "({0},'UIAgentAutomaticRefreshDelay','30',1,1,NULL)", "({0},'AgentAllowUsersToManageApplications','0',1,1,NULL)", "({0},'HideUIAgentIconInPublishedApplications','0',1,1,NULL)", "({0},'ExecuteOnlyCmdAgentInPublishedApplications','0',1,1,NULL)", "({0},'enforceVUEMAppsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMPrintersFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMNetDrivesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMVirtualDrivesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMRegValuesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMEnvVariablesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMPortsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMIniFilesOpsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMExtTasksFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMFileSystemOpsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMUserDSNsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMFileAssocsFiltersProcessing','0',1,1,NULL)", "({0},'checkAppShortcutExistence','0',1,1,NULL)", "({0},'appShortcutExpandEnvironmentVariables','0',1,1,NULL)", "({0},'RefreshOnEnvironmentalSettingChange','1',1,1,NULL)", "({0},'HideUIAgentSplashScreen','0',1,1,NULL)", "({0},'processVUEMAppsOnReconnect','0',1,1,NULL)", "({0},'processVUEMPrintersOnReconnect','0',1,1,NULL)", "({0},'processVUEMNetDrivesOnReconnect','0',1,1,NULL)", "({0},'processVUEMVirtualDrivesOnReconnect','0',1,1,NULL)", "({0},'processVUEMRegValuesOnReconnect','0',1,1,NULL)", "({0},'processVUEMEnvVariablesOnReconnect','0',1,1,NULL)", "({0},'processVUEMPortsOnReconnect','0',1,1,NULL)", "({0},'processVUEMIniFilesOpsOnReconnect','0',1,1,NULL)", "({0},'processVUEMExtTasksOnReconnect','0',1,1,NULL)", "({0},'processVUEMFileSystemOpsOnReconnect','0',1,1,NULL)", "({0},'processVUEMUserDSNsOnReconnect','0',1,1,NULL)", "({0},'processVUEMFileAssocsOnReconnect','0',1,1,NULL)", "({0},'AgentAllowScreenCapture','0',1,1,NULL)", "({0},'AgentScreenCaptureEnableSendSupportEmail','0',1,1,NULL)", "({0},'AgentScreenCaptureSupportEmailAddress','',1,1,NULL)", "({0},'AgentScreenCaptureSupportEmailTemplate','',1,1,NULL)", "({0},'AgentEnableApplicationsShortcuts','0',1,1,NULL)", "({0},'UIAgentSkinName','Seven',1,1,NULL)", "({0},'HideUIAgentSplashScreenInPublishedApplications','0',1,1,NULL)", "({0},'MailCustomSubject',NULL,1,1,NULL)", "({0},'MailEnableUseSMTP','0',1,1,NULL)", "({0},'MailEnableSMTPSSL','0',1,1,NULL)", "({0},'MailSMTPPort','0',1,1,NULL)", "({0},'MailSMTPServer','',1,1,NULL)", "({0},'MailSMTPFromAddress','',1,1,NULL)", "({0},'MailSMTPToAddress','',1,1,NULL)", "({0},'MailEnableUseSMTPCredentials','0',1,1,NULL)", "({0},'MailSMTPUser','',1,1,NULL)", "({0},'MailSMTPPassword','',1,1,NULL)", "({0},'HideUIAgentSplashScreenOnReconnect','0',1,1,NULL)", "({0},'AgentDirectoryServiceTimeoutValue','15000',1,1,NULL)", "({0},'AgentBrokerServiceTimeoutValue','15000',1,1,NULL)", "({0},'AgentMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'ConnectionStateChangeNotificationEnabled','0',1,1,NULL)", "({0},'AgentPreventExitForAdmins','0',1,1,NULL)", "({0},'AgentNetworkResourceCheckTimeoutValue','500',1,1,NULL)", "({0},'AgentEnableCrossDomainsUserGroupsSearch','0',1,1,NULL)", "({0},'AgentShutdownAfterIdleEnabled','0',1,1,NULL)", "({0},'AgentShutdownAfterIdleTime','1800',1,1,NULL)", "({0},'AgentShutdownAfterEnabled','0',1,1,NULL)", "({0},'AgentShutdownAfter','02:00',1,1,NULL)", "({0},'AgentSuspendInsteadOfShutdown','0',1,1,NULL)", "({0},'AgentLaunchIncludeGroups','0',1,1,NULL)", "({0},'AgentLaunchIncludedGroups','',1,1,NULL)", "({0},'DisableAdministrativeRefreshFeedback','0',1,1,NULL)", "({0},'SwitchtoServiceAgent','0',1,1,NULL)", "({0},'UseGPO','0',1,1,NULL)", "({0},'CloudConnectors','',1,1,NULL)", "({0},'AgentSwitchFeatureToggle','1',1,1,NULL)")
        "EnvironmentalFields"             = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "EnvironmentalValues"             = @("({0},'HideCommonPrograms',0,'0',1,1,NULL)", "({0},'HideControlPanel',0,'0',1,1,NULL)", "({0},'RemoveRunFromStartMenu',0,'0',1,1,NULL)", "({0},'HideNetworkIcon',0,'0',1,1,NULL)", "({0},'HideAdministrativeTools',0,'0',1,1,NULL)", "({0},'HideNetworkConnections',0,'0',1,1,NULL)", "({0},'HideHelp',0,'0',1,1,NULL)", "({0},'HideWindowsUpdate',0,'0',1,1,NULL)", "({0},'HideTurnOff',0,'0',1,1,NULL)", "({0},'ForceLogoff',0,'0',1,1,NULL)", "({0},'HideFind',0,'0',1,1,NULL)", "({0},'DisableRegistryEditing',0,'0',1,1,NULL)", "({0},'DisableCmd',0,'0',1,1,NULL)", "({0},'NoNetConnectDisconnect',0,'0',1,1,NULL)", "({0},'Turnoffnotificationareacleanup',1,'0',1,1,NULL)", "({0},'LockTaskbar',1,'0',1,1,NULL)", "({0},'TurnOffpersonalizedmenus',1,'0',1,1,NULL)", "({0},'ClearRecentprogramslist',1,'0',1,1,NULL)", "({0},'RemoveContextMenuManageItem',0,'0',1,1,NULL)", "({0},'HideSpecifiedDrivesFromExplorer',1,'0',1,1,NULL)", "({0},'ExplorerHiddenDrives',1,'',1,1,NULL)", "({0},'DisableDragFullWindows',1,'0',1,1,NULL)", "({0},'DisableSmoothScroll',1,'0',1,1,NULL)", "({0},'DisableCursorBlink',1,'0',1,1,NULL)", "({0},'DisableMinAnimate',1,'0',1,1,NULL)", "({0},'SetInteractiveDelay',1,'0',1,1,NULL)", "({0},'InteractiveDelayValue',1,'40',1,1,NULL)", "({0},'EnableAutoEndTasks',1,'0',1,1,NULL)", "({0},'WaitToKillAppTimeout',1,'20000',1,1,NULL)", "({0},'SetCursorBlinkRate',1,'0',1,1,NULL)", "({0},'CursorBlinkRateValue',1,'-1',1,1,NULL)", "({0},'SetMenuShowDelay',1,'0',1,1,NULL)", "({0},'MenuShowDelayValue',1,'10',1,1,NULL)", "({0},'SetVisualStyleFile',1,'0',1,1,NULL)", "({0},'VisualStyleFileValue',1,'%windir%\resources\Themes\Aero\aero.msstyles',1,1,NULL)", "({0},'SetWallpaper',1,'0',1,1,NULL)", "({0},'Wallpaper',1,'',1,1,NULL)", "({0},'WallpaperStyle',1,'0',1,1,NULL)", "({0},'processEnvironmentalSettings',2,'0',1,1,NULL)", "({0},'RestrictSpecifiedDrivesFromExplorer',1,'0',1,1,NULL)", "({0},'ExplorerRestrictedDrives',1,'',1,1,NULL)", "({0},'HideNetworkInExplorer',1,'0',1,1,NULL)", "({0},'HideLibrairiesInExplorer',1,'0',1,1,NULL)", "({0},'NoProgramsCPL',0,'0',1,1,NULL)", "({0},'NoPropertiesMyComputer',0,'0',1,1,NULL)", "({0},'SetSpecificThemeFile',1,'0',1,1,NULL)", "({0},'SpecificThemeFileValue',1,'%windir%\resources\Themes\aero.theme',1,1,NULL)", "({0},'DisableSpecifiedKnownFolders',1,'0',1,1,NULL)", "({0},'DisabledKnownFolders',1,'',1,1,NULL)", "({0},'DisableSilentRegedit',0,'0',1,1,NULL)", "({0},'DisableCmdScripts',0,'0',1,1,NULL)", "({0},'HideDevicesandPrinters',0,'0',1,1,NULL)", "({0},'processEnvironmentalSettingsForAdmins',2,'0',1,1,NULL)", "({0},'HideSystemClock',0,'0',1,1,NULL)", "({0},'SetDesktopBackGroundColor',0,'0',1,1,NULL)", "({0},'DesktopBackGroundColor',0,'',1,1,NULL)", "({0},'NoMyComputerIcon',1,'0',1,1,NULL)", "({0},'NoRecycleBinIcon',1,'0',1,1,NULL)", "({0},'NoPropertiesRecycleBin',0,'0',1,1,NULL)", "({0},'NoMyDocumentsIcon',1,'0',1,1,NULL)", "({0},'NoPropertiesMyDocuments',0,'0',1,1,NULL)", "({0},'NoNtSecurity',0,'0',1,1,NULL)", "({0},'DisableTaskMgr',0,'0',1,1,NULL)", "({0},'RestrictCpl',0,'0',1,1,NULL)", "({0},'RestrictCplList',0,'Display',1,1,NULL)", "({0},'DisallowCpl',0,'0',1,1,NULL)", "({0},'DisallowCplList',0,'',1,1,NULL)", "({0},'BootToDesktopInsteadOfStart',1,'0',1,1,NULL)", "({0},'DisableTLcorner',0,'0',1,1,NULL)", "({0},'DisableCharmsHint',0,'0',1,1,NULL)", "({0},'NoTrayContextMenu',0,'0',1,1,NULL)", "({0},'NoViewContextMenu',0,'0',1,1,NULL)")
        "ItemsFields"                     = "IdSite,Name,DistinguishedName,Description,State,Type,Priority,RevisionId,Reserved01"
        "ItemsValues"                     = @("({0},'S-1-1-0','Everyone','A group that includes all users, even anonymous users and guests. Membership is controlled by the operating system.',1,1,100,1,NULL)", "({0},'S-1-5-32-544','BUILTIN\Administrators','A built-in group. After the initial installation of the operating system, the only member of the group is the Administrator account. When a computer joins a domain, the Domain Admins group is added to the Administrators group. When a server becomes a domain controller, the Enterprise Admins group also is added to the Administrators group.',1,1,100,1,NULL)")
        "KioskFields"                     = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "KioskValues"                     = @("({0},'PowerDontCheckBattery',0,'0',0,1,NULL)", "({0},'PowerShutdownAfterIdleTime',0,'1800',0,1,NULL)", "({0},'PowerShutdownAfterSpecifiedTime',0,'02:00',0,1,NULL)", "({0},'DesktopModeLogOffWebPortal',0,'0',0,1,NULL)", "({0},'EndSessionOption',0,'0',0,1,NULL)", "({0},'AutologonRegistryForce',0,'0',0,1,NULL)", "({0},'AutologonRegistryIgnoreShiftOverride',0,'0',0,1,NULL)", "({0},'AutologonPassword',0,'',0,1,NULL)", "({0},'AutologonDomain',0,'',0,1,NULL)", "({0},'AutologonUserName',0,'',0,1,NULL)", "({0},'AutologonEnable',0,'0',0,1,NULL)", "({0},'AdministrationHideDisplaySettings',0,'0',0,1,NULL)", "({0},'AdministrationHideKeyboardSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideMouseSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideClientDetails',0,'0',0,1,NULL)", "({0},'AdministrationDisableUnlock',0,'0',0,1,NULL)", "({0},'AdministrationHideWindowsVersion',0,'0',0,1,NULL)", "({0},'AdministrationDisableProgressBar',0,'0',0,1,NULL)", "({0},'AdministrationHidePrinterSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideLogOffOption',0,'0',0,1,NULL)", "({0},'AdministrationHideRestartOption',0,'0',0,1,NULL)", "({0},'AdministrationHideShutdownOption',0,'0',0,1,NULL)", "({0},'AdministrationHideVolumeSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideHomeButton',0,'0',0,1,NULL)", "({0},'AdministrationPreLaunchReceiver',0,'0',0,1,NULL)", "({0},'AdministrationIgnoreLastLanguage',0,'0',0,1,NULL)", "({0},'AdvancedHideTaskbar',0,'0',0,1,NULL)", "({0},'AdvancedLockCtrlAltDel',0,'0',0,1,NULL)", "({0},'AdvancedLockAltTab',0,'0',0,1,NULL)", "({0},'AdvancedFixBrowserRendering',0,'0',0,1,NULL)", "({0},'AdvancedLogOffScreenRedirection',0,'0',0,1,NULL)", "({0},'AdvancedSuppressScriptErrors',0,'0',0,1,NULL)", "({0},'AdvancedShowWifiSettings',0,'0',0,1,NULL)", "({0},'AdvancedHideKioskWhileCitrixSession',0,'0',0,1,NULL)", "({0},'AdvancedFixSslSites',0,'0',0,1,NULL)", "({0},'AdvancedAlwaysShowAdminMenu',0,'0',0,1,NULL)", "({0},'AdvancedFixZOrder',0,'0',0,1,NULL)", "({0},'ToolsAppsList',0,'',0,1,NULL)", "({0},'ToolsEnabled',0,'0',0,1,NULL)", "({0},'IsKioskEnabled',0,'0',0,1,NULL)", "({0},'SitesIsListEnabled',0,'0',0,1,NULL)", "({0},'SitesNamesAndLinks',0,'',0,1,'')", "({0},'GeneralStartUrl',0,'',0,1,NULL)", "({0},'GeneralTitle',0,'',0,1,NULL)", "({0},'GeneralShowNavigationButtons',0,'0',0,1,NULL)", "({0},'GeneralWindowMode',0,'0',0,1,NULL)", "({0},'GeneralClockEnabled',0,'0',0,1,NULL)", "({0},'GeneralClockUses12Hours',0,'0',0,1,NULL)", "({0},'GeneralUnlockPassword',0,'fLp34dnRI0DK26rJv8Tmqg==',0,1,NULL)", "({0},'GeneralEnableLanguageSelect',0,'0',0,1,NULL)", "({0},'GeneralAutoHideAppPanel',0,'0',0,1,NULL)", "({0},'GeneralEnableAppPanel',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnabled',0,'0',0,1,NULL)", "({0},'ProcessLauncherApplication',0,'',0,1,NULL)", "({0},'ProcessLauncherArgs',0,'',0,1,NULL)", "({0},'ProcessLauncherClearLastUsernameVMWare',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableVMWareViewMode',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableMicrosoftRdsMode',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableCitrixMode',0,'0',0,1,NULL)", "({0},'SetCitrixReceiverFSOMode',0,'0',0,1,NULL)")
        "ParametersFields"                = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "ParametersValues"                = @("({0},'excludedDriveletters','A;B;C;D',1,1,NULL)", "({0},'AllowDriveLetterReuse','0',1,1,NULL)")
        "PersonaFields"                   = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "PersonaValues"                   = @("({0},'PersonaManagementEnabled','0',1,1,NULL)", "({0},'VPEnabled','0',1,1,NULL)", "({0},'UploadProfileInterval','10',1,1,NULL)", "({0},'SetCentralProfileStore','0',1,1,NULL)", "({0},'CentralProfileStore','',1,1,NULL)", "({0},'CentralProfileOverride','0',1,1,NULL)", "({0},'DeleteLocalProfile','0',1,1,NULL)", "({0},'DeleteLocalSettings','0',1,1,NULL)", "({0},'RoamLocalSettings','0',1,1,NULL)", "({0},'EnableBackgroundDownload','0',1,1,NULL)", "({0},'CleanupCLFSFiles','0',1,1,NULL)", "({0},'SetDynamicRoamingFiles','0',1,1,NULL)", "({0},'DynamicRoamingFiles','',1,1,NULL)", "({0},'SetDynamicRoamingFilesExceptions','0',1,1,NULL)", "({0},'DynamicRoamingFilesExceptions','',1,1,NULL)", "({0},'SetBasicRoamingFiles','0',1,1,NULL)", "({0},'BasicRoamingFiles','',1,1,NULL)", "({0},'SetBasicRoamingFilesExceptions','0',1,1,NULL)", "({0},'BasicRoamingFilesExceptions','',1,1,NULL)", "({0},'SetDontRoamFiles','0',1,1,NULL)", "({0},'DontRoamFiles','AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1,NULL)", "({0},'SetDontRoamFilesExceptions','0',1,1,NULL)", "({0},'DontRoamFilesExceptions','',1,1,NULL)", "({0},'SetBackgroundLoadFolders','0',1,1,NULL)", "({0},'BackgroundLoadFolders','',1,1,NULL)", "({0},'SetBackgroundLoadFoldersExceptions','0',1,1,NULL)", "({0},'BackgroundLoadFoldersExceptions','',1,1,NULL)", "({0},'SetExcludedProcesses','0',1,1,NULL)", "({0},'ExcludedProcesses','',1,1,NULL)", "({0},'HideOfflineIcon','0',1,1,NULL)", "({0},'HideFileCopyProgress','0',1,1,NULL)", "({0},'FileCopyMinSize','50',1,1,NULL)", "({0},'EnableTrayIconErrorAlerts','0',1,1,NULL)", "({0},'SetLogPath','0',1,1,NULL)", "({0},'LogPath','',1,1,NULL)", "({0},'SetLoggingDestination','0',1,1,NULL)", "({0},'LogToFile','0',1,1,NULL)", "({0},'LogToDebugPort','0',1,1,NULL)", "({0},'SetLoggingFlags','0',1,1,NULL)", "({0},'LogError','0',1,1,NULL)", "({0},'LogInformation','0',1,1,NULL)", "({0},'LogDebug','0',1,1,NULL)", "({0},'SetDebugFlags','0',1,1,NULL)", "({0},'DebugError','0',1,1,NULL)", "({0},'DebugInformation','0',1,1,NULL)", "({0},'DebugPorts','0',1,1,NULL)", "({0},'AddAdminGroupToRedirectedFolders','0',1,1,NULL)", "({0},'RedirectApplicationData','0',1,1,NULL)", "({0},'ApplicationDataRedirectedPath','',1,1,NULL)", "({0},'RedirectContacts','0',1,1,NULL)", "({0},'ContactsRedirectedPath','',1,1,NULL)", "({0},'RedirectCookies','0',1,1,NULL)", "({0},'CookiesRedirectedPath','',1,1,NULL)", "({0},'RedirectDesktop','0',1,1,NULL)", "({0},'DesktopRedirectedPath','',1,1,NULL)", "({0},'RedirectDownloads','0',1,1,NULL)", "({0},'DownloadsRedirectedPath','',1,1,NULL)", "({0},'RedirectFavorites','0',1,1,NULL)", "({0},'FavoritesRedirectedPath','',1,1,NULL)", "({0},'RedirectHistory','0',1,1,NULL)", "({0},'HistoryRedirectedPath','',1,1,NULL)", "({0},'RedirectLinks','0',1,1,NULL)", "({0},'LinksRedirectedPath','',1,1,NULL)", "({0},'RedirectMyDocuments','0',1,1,NULL)", "({0},'MyDocumentsRedirectedPath','',1,1,NULL)", "({0},'RedirectMyMusic','0',1,1,NULL)", "({0},'MyMusicRedirectedPath','',1,1,NULL)", "({0},'RedirectMyPictures','0',1,1,NULL)", "({0},'MyPicturesRedirectedPath','',1,1,NULL)", "({0},'RedirectMyVideos','0',1,1,NULL)", "({0},'MyVideosRedirectedPath','',1,1,NULL)", "({0},'RedirectNetworkNeighborhood','0',1,1,NULL)", "({0},'NetworkNeighborhoodRedirectedPath','',1,1,NULL)", "({0},'RedirectPrinterNeighborhood','0',1,1,NULL)", "({0},'PrinterNeighborhoodRedirectedPath','',1,1,NULL)", "({0},'RedirectRecentItems','0',1,1,NULL)", "({0},'RecentItemsRedirectedPath','',1,1,NULL)", "({0},'RedirectSavedGames','0',1,1,NULL)", "({0},'SavedGamesRedirectedPath','',1,1,NULL)", "({0},'RedirectSearches','0',1,1,NULL)", "({0},'SearchesRedirectedPath','',1,1,NULL)", "({0},'RedirectSendTo','0',1,1,NULL)", "({0},'SendToRedirectedPath','',1,1,NULL)", "({0},'RedirectStartMenu','0',1,1,NULL)", "({0},'StartMenuRedirectedPath','',1,1,NULL)", "({0},'RedirectStartupItems','0',1,1,NULL)", "({0},'StartupItemsRedirectedPath','',1,1,NULL)", "({0},'RedirectTemplates','0',1,1,NULL)", "({0},'TemplatesRedirectedPath','',1,1,NULL)", "({0},'RedirectTemporaryInternetFiles','0',1,1,NULL)", "({0},'TemporaryInternetFilesRedirectedPath','',1,1,NULL)", "({0},'SetFRExclusions','0',1,1,NULL)", "({0},'FRExclusions','',1,1,NULL)", "({0},'SetFRExclusionsExceptions','0',1,1,NULL)", "({0},'FRExclusionsExceptions','',1,1,NULL)")
        "SystemMonitoringFields"          = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "SystemMonitoringValues"          = @("({0},'EnableSystemMonitoring','0',1,1,NULL)", "({0},'EnableGlobalSystemMonitoring','0',1,1,NULL)", "({0},'EnableProcessActivityMonitoring','0',1,1,NULL)", "({0},'EnableUserExperienceMonitoring','0',1,1,NULL)", "({0},'LocalDatabaseRetentionPeriod','3',1,1,NULL)", "({0},'LocalDataUploadFrequency','4',1,1,NULL)", "({0},'EnableApplicationReportsWindows2K3XPCompliance','0',1,1,NULL)",  "({0},'ExcludeProcessesFromApplicationReports','1',1,1,NULL)", "({0},'ExcludedProcessesFromApplicationReports','dwm;taskhost;vmtoolsd;winlogon;csrss;wisptis;dllhost;consent;msiexec;userinit;LogonUI;mscorsvw;SearchProtocolHost;Rundll32;explorer;regsvr32;WmiPrvSE;services;smss;SearchFilterHost;lsass;svchost;lsm;msdtc;wininit;VGAuthService;SearchIndexer;spoolsv;vmtoolsd;vmacthlp;audiodg;VMwareResolutionSet;mobsync;wsqmcons;schtasks;Defrag;conhost;VSSVC;sdclt;MpCmdRun;WMIADAP;encsvc;wfshell;CpSvc;VDARedirector;CpSvc64;SemsService;ctxrdr;PicaSvc2;encsvc;GfxMgr;PicaSessionAgent;CtxGfx;PicaTwiHost;PicaUserAgent;VDARedirector;PicaShell;PicaEuemRelay;CtxMtHost;CtxSensLoader;ssonsvr;concentr;wfcrun32;pnamain;redirector;concentr;pnamain;pnagent;IMAAdvanceSrv;mfcom;ctxxmlss;Citrix.XenApp.Commands.Remoting.Service;HCAService;cmstart;startssonsvr;ctxhide;mmvdhost;runonce;rdpclip;TabTip;InputPersonalization;TabTip32;TSTheme;ngen;XTE;CtxSvcHost;OSPPSVC;TelemetryService;CtxAudioService;picatzrestore;CheckTermSrv;IMATest;RequestTicket;csc;cvtres;ssoncom;UpmUserMsg;CtxPvD;MultimediaRedirector;gpscript;shutdown;splwow64',1,1,NULL)", "({0},'EnableStrictPrivacy','0',1,1,NULL)", "({0},'BusinessDayStartHour','8',1,1,NULL)", "({0},'BusinessDayEndHour','19',1,1,NULL)", "({0},'ReportsBootTimeMinimum','5',1,1,NULL)", "({0},'ReportsLoginTimeMinimum','5',1,1,NULL)", "({0},'EnableWorkDaysFiltering','1',1,1,NULL)", "({0},'WorkDaysFilter','1;1;1;1;1;0;0',1,1,NULL)")
        "SystemUtilitiesFields"           = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "SystemUtilitiesValues"           = @("({0},'EnableFastLogoff',0,'0',1,1,NULL)", "({0},'ExcludeGroupsFromFastLogoff',0,'0',1,1,NULL)", "({0},'FastLogoffExcludedGroups',0,NULL,1,1,NULL)", "({0},'EnableCPUSpikesProtection',1,'0',1,1,NULL)", "({0},'SpikesProtectionCPUUsageLimitPercent',1,'70',1,1,NULL)", "({0},'SpikesProtectionCPUUsageLimitSampleTime',1,'30',1,1,NULL)", "({0},'SpikesProtectionIdlePriorityConstraintTime',1,'180',1,1,NULL)", "({0},'ExcludeProcessesFromCPUSpikesProtection',1,'0',1,1,NULL)", "({0},'CPUSpikesProtectionExcludedProcesses',1,NULL,1,1,NULL)", "({0},'EnableMemoryWorkingSetOptimization',2,'0',1,1,NULL)", "({0},'MemoryWorkingSetOptimizationIdleSampleTime',2,'120',1,1,NULL)", "({0},'ExcludeProcessesFromMemoryWorkingSetOptimization',2,'0',1,1,NULL)", "({0},'MemoryWorkingSetOptimizationExcludedProcesses',2,NULL,1,1,NULL)", "({0},'EnableProcessesBlackListing',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListedProcesses',3,NULL,1,1,NULL)", "({0},'ProcessesManagementBlackListExcludeLocalAdministrators',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListExcludeSpecifiedGroups',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListExcludedSpecifiedGroupsList',3,'',1,1,NULL)", "({0},'EnableProcessesWhiteListing',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListedProcesses',3,NULL,1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludeLocalAdministrators',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludeSpecifiedGroups',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludedSpecifiedGroupsList',3,'',1,1,NULL)", "({0},'EnableProcessesManagement',3,'0',1,1,NULL)", "({0},'EnableProcessesClamping',4,'0',1,1,NULL)", "({0},'ProcessesClampingList',4,NULL,1,1,NULL)", "({0},'EnableProcessesAffinity',5,'0',1,1,NULL)", "({0},'ProcessesAffinityList',5,NULL,1,1,NULL)", "({0},'EnableProcessesIoPriority',6,'0',1,1,NULL)", "({0},'ProcessesIoPriorityList',6,NULL,1,1,NULL)", "({0},'EnableProcessesCpuPriority',7,'0',1,1,NULL)", "({0},'ProcessesCpuPriorityList',7,NULL,1,1,NULL)", "({0},'MemoryWorkingSetOptimizationIdleStateLimitPercent',2,'1',1,1,NULL)", "({0},'EnableIntelligentCpuOptimization',1,'0',1,1,NULL)", "({0},'EnableIntelligentIoOptimization',1,'0',1,1,NULL)", "({0},'SpikesProtectionLimitCPUCoreNumber',1,'0',1,1,NULL)", "({0},'SpikesProtectionCPUCoreLimit',1,'1',1,1,NULL)", "({0},'AppLockerControllerManagement',1,'1',1,1,NULL)", "({0},'AppLockerControllerReplaceModeOn',1,'1',1,1,NULL)", "({0},'AutoCPUSpikeProtectionSelected',1,'1',1,1,NULL)")
        "UPMFields"                       = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "UPMValues"                       = @("({0},'UPMManagementEnabled','0',1,1,NULL)", "({0},'ServiceActive','0',1,1,NULL)", "({0},'SetProcessedGroups','0',1,1,NULL)", "({0},'ProcessedGroupsList','',1,1,NULL)", "({0},'ProcessAdmins','0',1,1,NULL)", "({0},'SetPathToUserStore','0',1,1,NULL)", "({0},'MigrateUserStore','0',1,1,NULL)", "({0},'PathToUserStore','Windows',1,1,NULL)", "({0},'MigrateUserStorePath','',1,1,NULL)", "({0},'PSMidSessionWriteBack','0',1,1,NULL)", "({0},'OfflineSupport','0',1,1,NULL)", "({0},'DeleteCachedProfilesOnLogoff','0',1,1,NULL)", "({0},'SetMigrateWindowsProfilesToUserStore','0',1,1,NULL)", "({0},'MigrateWindowsProfilesToUserStore','1',1,1,NULL)", "({0},'AutomaticMigrationEnabled','0',1,1,NULL)", "({0},'SetLocalProfileConflictHandling','0',1,1,NULL)", "({0},'LocalProfileConflictHandling','1',1,1,NULL)", "({0},'SetTemplateProfilePath','0',1,1,NULL)", "({0},'TemplateProfilePath','',1,1,NULL)", "({0},'TemplateProfileOverridesLocalProfile','0',1,1,NULL)", "({0},'TemplateProfileOverridesRoamingProfile','0',1,1,NULL)", "({0},'SetLoadRetries','0',1,1,NULL)", "({0},'LoadRetries','5',1,1,NULL)", "({0},'SetUSNDBPath','0',1,1,NULL)", "({0},'USNDBPath','',1,1,NULL)", "({0},'XenAppOptimizationEnabled','0',1,1,NULL)", "({0},'XenAppOptimizationPath','',1,1,NULL)", "({0},'ProcessCookieFiles','0',1,1,NULL)", "({0},'DeleteRedirectedFolders','0',1,1,NULL)", "({0},'LoggingEnabled','0',1,1,NULL)", "({0},'SetLogLevels','0',1,1,NULL)", "({0},'LogLevels','0;0;0;0;0;0;0;0;0;0;0',1,1,NULL)", "({0},'SetMaxLogSize','0',1,1,NULL)", "({0},'MaxLogSize','1048576',1,1,NULL)", "({0},'SetPathToLogFile','0',1,1,NULL)", "({0},'PathToLogFile','',1,1,NULL)", "({0},'SetExclusionListRegistry','0',1,1,NULL)", "({0},'ExclusionListRegistry','',1,1,NULL)", "({0},'SetInclusionListRegistry','0',1,1,NULL)", "({0},'InclusionListRegistry','',1,1,NULL)", "({0},'SetSyncExclusionListFiles','0',1,1,NULL)", "({0},'SyncExclusionListFiles','AppData\Roaming\Microsoft\Windows\Start Menu\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Startup\Desktop.ini',1,1,NULL)", "({0},'SetSyncExclusionListDir','0',1,1,NULL)", "({0},'SyncExclusionListDir','`$Recycle.Bin;AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1,NULL)", "({0},'SetSyncDirList','0',1,1,NULL)", "({0},'SyncDirList','',1,1,NULL)", "({0},'SetSyncFileList','0',1,1,NULL)", "({0},'SyncFileList','',1,1,NULL)", "({0},'SetMirrorFoldersList','0',1,1,NULL)", "({0},'MirrorFoldersList','',1,1,NULL)", "({0},'SetProfileContainerList','0',1,1,NULL)", "({0},'ProfileContainerList','',1,1,NULL)", "({0},'SetLargeFileHandlingList','0',1,1,NULL)", "({0},'LargeFileHandlingList','',1,1,NULL)", "({0},'PSEnabled','0',1,1,NULL)", "({0},'PSAlwaysCache','0',1,1,NULL)", "({0},'PSAlwaysCacheSize','0',1,1,NULL)", "({0},'SetPSPendingLockTimeout','0',1,1,NULL)", "({0},'PSPendingLockTimeout','1',1,1,NULL)", "({0},'SetPSUserGroupsList','0',1,1,NULL)", "({0},'PSUserGroupsList','',1,1,NULL)", "({0},'CPEnabled','0',1,1,NULL)", "({0},'SetCPUserGroupList','0',1,1,NULL)", "({0},'CPUserGroupList','',1,1,NULL)", "({0},'SetCPSchemaPath','0',1,1,NULL)", "({0},'CPSchemaPath','',1,1,NULL)", "({0},'SetCPPath','0',1,1,NULL)", "({0},'CPPath','',1,1,NULL)", "({0},'CPMigrationFromBaseProfileToCPStore','0',1,1,NULL)", "({0},'SetExcludedGroups','0',1,1,NULL)", "({0},'ExcludedGroupsList','',1,1,NULL)", "({0},'DisableDynamicConfig','0',1,1,NULL)", "({0},'LogoffRatherThanTempProfile','0',1,1,NULL)", "({0},'SetProfileDeleteDelay','0',1,1,NULL)", "({0},'ProfileDeleteDelay','0',1,1,NULL)", "({0},'TemplateProfileIsMandatory','0',1,1,NULL)", "({0},'PSMidSessionWriteBackReg','0',1,1,NULL)", "({0},'CEIPEnabled','1',1,1,NULL)", "({0},'LastKnownGoodRegistry','0',1,1,NULL)", "({0},'EnableDefaultExclusionListRegistry','0',1,1,NULL)", "({0},'ExclusionDefaultRegistry01','1',1,1,NULL)", "({0},'ExclusionDefaultRegistry02','1',1,1,NULL)", "({0},'ExclusionDefaultRegistry03','1',1,1,NULL)", "({0},'EnableDefaultExclusionListDirectories','0',1,1,NULL)", "({0},'ExclusionDefaultDir01','1',1,1,NULL)", "({0},'ExclusionDefaultDir02','1',1,1,NULL)", "({0},'ExclusionDefaultDir03','1',1,1,NULL)", "({0},'ExclusionDefaultDir04','1',1,1,NULL)", "({0},'ExclusionDefaultDir05','1',1,1,NULL)", "({0},'ExclusionDefaultDir06','1',1,1,NULL)", "({0},'ExclusionDefaultDir07','1',1,1,NULL)", "({0},'ExclusionDefaultDir08','1',1,1,NULL)", "({0},'ExclusionDefaultDir09','1',1,1,NULL)", "({0},'ExclusionDefaultDir10','1',1,1,NULL)", "({0},'ExclusionDefaultDir11','1',1,1,NULL)", "({0},'ExclusionDefaultDir12','1',1,1,NULL)", "({0},'ExclusionDefaultDir13','1',1,1,NULL)", "({0},'ExclusionDefaultDir14','1',1,1,NULL)", "({0},'ExclusionDefaultDir15','1',1,1,NULL)", "({0},'ExclusionDefaultDir16','1',1,1,NULL)", "({0},'ExclusionDefaultDir17','1',1,1,NULL)", "({0},'ExclusionDefaultDir18','1',1,1,NULL)", "({0},'ExclusionDefaultDir19','1',1,1,NULL)", "({0},'ExclusionDefaultDir20','1',1,1,NULL)", "({0},'ExclusionDefaultDir21','1',1,1,NULL)", "({0},'ExclusionDefaultDir22','1',1,1,NULL)", "({0},'ExclusionDefaultDir23','1',1,1,NULL)", "({0},'ExclusionDefaultDir24','1',1,1,NULL)", "({0},'ExclusionDefaultDir25','1',1,1,NULL)", "({0},'ExclusionDefaultDir26','1',1,1,NULL)", "({0},'ExclusionDefaultDir27','1',1,1,NULL)", "({0},'ExclusionDefaultDir28','1',1,1,NULL)", "({0},'ExclusionDefaultDir29','1',1,1,NULL)", "({0},'ExclusionDefaultDir30','1',1,1,NULL)", "({0},'EnableStreamingExclusionList','0',1,1,NULL)", "({0},'StreamingExclusionList','',1,1,NULL)", "({0},'EnableLogonExclusionCheck','0',1,1,NULL)", "({0},'LogonExclusionCheck','0',1,1,NULL)", "({0},'OutlookSearchRoamingEnabled','0',1,1,NULL)", "({0},'SearchBackupRestoreEnabled','0',1,1,NULL)")
        "USVFields"                       = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "USVValues"                       = @("({0},'processUSVConfiguration',0,'0',1,1,NULL)", "({0},'processUSVConfigurationForAdmins',0,'0',1,1,NULL)", "({0},'SetWindowsRoamingProfilesPath',1,'0',1,1,NULL)", "({0},'WindowsRoamingProfilesPath',1,'',1,1,NULL)", "({0},'SetRDSRoamingProfilesPath',1,'0',1,1,NULL)", "({0},'RDSRoamingProfilesPath',1,'',1,1,NULL)", "({0},'SetRDSHomeDrivePath',1,'0',1,1,NULL)", "({0},'RDSHomeDrivePath',1,'',1,1,NULL)", "({0},'RDSHomeDriveLetter',1,'Z:',1,1,NULL)", "({0},'SetRoamingProfilesFoldersExclusions',2,'0',1,1,NULL)", "({0},'RoamingProfilesFoldersExclusions',2,'AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp',1,1,NULL)", "({0},'DeleteRoamingCachedProfiles',1,'0',1,1,NULL)", "({0},'AddAdminGroupToRUP',1,'0',1,1,NULL)", "({0},'CompatibleRUPSecurity',1,'0',1,1,NULL)", "({0},'DisableSlowLinkDetect',1,'0',1,1,NULL)", "({0},'SlowLinkProfileDefault',1,'0',1,1,NULL)", "({0},'processFoldersRedirectionConfiguration',3,'0',1,1,NULL)", "({0},'DeleteLocalRedirectedFolders',3,'0',1,1,NULL)", "({0},'processDesktopRedirection',3,'0',1,1,NULL)", "({0},'DesktopRedirectedPath',3,'',1,1,NULL)", "({0},'processStartMenuRedirection',3,'0',1,1,NULL)", "({0},'StartMenuRedirectedPath',3,'',1,1,NULL)", "({0},'processPersonalRedirection',3,'0',1,1,NULL)", "({0},'PersonalRedirectedPath',3,'',1,1,NULL)", "({0},'processPicturesRedirection',3,'0',1,1,NULL)", "({0},'PicturesRedirectedPath',3,'',1,1,NULL)", "({0},'MyPicturesFollowsDocuments',3,'0',1,1,NULL)", "({0},'processMusicRedirection',3,'0',1,1,NULL)", "({0},'MusicRedirectedPath',3,'',1,1,NULL)", "({0},'MyMusicFollowsDocuments',3,'0',1,1,NULL)", "({0},'processVideoRedirection',3,'0',1,1,NULL)", "({0},'VideoRedirectedPath',3,'',1,1,NULL)", "({0},'MyVideoFollowsDocuments',3,'0',1,1,NULL)", "({0},'processFavoritesRedirection',3,'0',1,1,NULL)", "({0},'FavoritesRedirectedPath',3,'',1,1,NULL)", "({0},'processAppDataRedirection',3,'0',1,1,NULL)", "({0},'AppDataRedirectedPath',3,'',1,1,NULL)", "({0},'processContactsRedirection',3,'0',1,1,NULL)", "({0},'ContactsRedirectedPath',3,'',1,1,NULL)", "({0},'processDownloadsRedirection',3,'0',1,1,NULL)", "({0},'DownloadsRedirectedPath',3,'',1,1,NULL)", "({0},'processLinksRedirection',3,'0',1,1,NULL)", "({0},'LinksRedirectedPath',3,'',1,1,NULL)", "({0},'processSearchesRedirection',3,'0',1,1,NULL)", "({0},'SearchesRedirectedPath',3,'',1,1,NULL)")

        "CleanupTables"                   = @("VUEMActionGroups","VUEMApps","VUEMPrinters","VUEMNetDrives","VUEMVirtualDrives","VUEMRegValues","VUEMEnvVariables","VUEMPorts","VUEMIniFilesOps","VUEMExtTasks","VUEMFileSystemOps","VUEMUserDSNs","VUEMFileAssocs","VUEMFiltersRules","VUEMFiltersConditions","VUEMItems","VUEMUserStatistics","VUEMAgentStatistics","VUEMSystemMonitoringData","VUEMActivityMonitoringData","VUEMUserExperienceMonitoringData","VUEMResourcesOptimizationData","VUEMParameters","VUEMAgentSettings","VUEMSystemUtilities","VUEMEnvironmentalSettings","VUEMUPMSettings","VUEMPersonaSettings","VUEMUSVSettings","VUEMKioskSettings","VUEMSystemMonitoringSettings","VUEMTasks","VUEMStorefrontSettings","VUEMChangesLog","VUEMAgentsLog","VUEMADObjects","AppLockerSettings","GroupPolicyObjects","GroupPolicyGlobalSettings","VUEMSites")
    }
    "2003" = @{
        "SiteFields"                          = "Name,Description,State,JProperties,RevisionId,Reserved01"
        "SiteValues"                          = "'{0}','{1}',1,'',1,NULL"
        "AppLockerFields"                     = "IdSite,State,RevisionId,Reserved01,Value,Setting"
        "AppLockerValues"                     = @("({0},1,1,Null,0,'EnableProcessesAppLocker')", "({0},1,1,Null,0,'EnableDLLRuleCollection')", "({0},1,1,Null,0,'CollectionExeEnforcementState')", "({0},1,1,Null,0,'CollectionMsiEnforcementState')", "({0},1,1,Null,0,'CollectionScriptEnforcementState')", "({0},1,1,Null,0,'CollectionAppxEnforcementState')", "({0},1,1,Null,0,'CollectionDllEnforcementState')")
        "GroupPolicyGlobalSettingsFields"     = "IdSite,Name,Value"
        "GroupPolicyGlobalSettingsValues"     = @("({0},'EnableGroupPolicyEnforcement','0')")
        "AgentSettingsFields"                 = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "AgentSettingsValues"                 = @("({0},'OfflineModeEnabled','0',1,1,NULL)", "({0},'UseCacheEvenIfOnline','0',1,1,NULL)", "({0},'UseCacheForActionsProcessing','1',1,1,NULL)", "({0},'processVUEMApps','0',1,1,NULL)", "({0},'processVUEMPrinters','0',1,1,NULL)", "({0},'processVUEMNetDrives','0',1,1,NULL)", "({0},'processVUEMVirtualDrives','0',1,1,NULL)", "({0},'processVUEMRegValues','0',1,1,NULL)", "({0},'processVUEMEnvVariables','0',1,1,NULL)", "({0},'processVUEMPorts','0',1,1,NULL)", "({0},'processVUEMIniFilesOps','0',1,1,NULL)", "({0},'processVUEMExtTasks','0',1,1,NULL)", "({0},'processVUEMFileSystemOps','0',1,1,NULL)", "({0},'processVUEMUserDSNs','0',1,1,NULL)", "({0},'processVUEMFileAssocs','0',1,1,NULL)", "({0},'UIAgentSplashScreenBackGround','',1,1,NULL)", "({0},'UIAgentLoadingCircleColor','',1,1,NULL)", "({0},'UIAgentLbl1TextColor','',1,1,NULL)", "({0},'UIAgentHelpLink','',1,1,NULL)", "({0},'AgentServiceDebugMode','0',1,1,NULL)", "({0},'LaunchVUEMAgentOnLogon','0',1,1,NULL)", "({0},'ProcessVUEMAgentLaunchForAdmins','0',1,1,NULL)", "({0},'LaunchVUEMAgentOnReconnect','0',1,1,NULL)", "({0},'EnableVirtualDesktopCompatibility','0',1,1,NULL)", "({0},'VUEMAgentType','UI',1,1,NULL)", "({0},'VUEMAgentDesktopsExtraLaunchDelay','0',1,1,NULL)", "({0},'VUEMAgentCacheRefreshDelay','30',1,1,NULL)", "({0},'VUEMAgentSQLSettingsRefreshDelay','15',1,1,NULL)", "({0},'DeleteDesktopShortcuts','0',1,1,NULL)", "({0},'DeleteStartMenuShortcuts','0',1,1,NULL)", "({0},'DeleteQuickLaunchShortcuts','0',1,1,NULL)", "({0},'DeleteNetworkDrives','0',1,1,NULL)", "({0},'DeleteNetworkPrinters','0',1,1,NULL)", "({0},'PreserveAutocreatedPrinters','0',1,1,NULL)", "({0},'PreserveSpecificPrinters','0',1,1,NULL)", "({0},'SpecificPreservedPrinters','PDFCreator;PDFMail;Acrobat Distiller;Amyuni',1,1,NULL)", "({0},'EnableAgentLogging','1',1,1,NULL)", "({0},'AgentLogFile','%USERPROFILE%\Citrix WEM Agent.log',1,1,NULL)", "({0},'AgentDebugMode','0',1,1,NULL)", "({0},'RefreshEnvironmentSettings','0',1,1,NULL)", "({0},'RefreshSystemSettings','0',1,1,NULL)", "({0},'RefreshDesktop','0',1,1,NULL)", "({0},'RefreshAppearance','0',1,1,NULL)", "({0},'AgentExitForAdminsOnly','1',1,1,NULL)", "({0},'AgentAllowUsersToManagePrinters','0',1,1,NULL)", "({0},'DeleteTaskBarPinnedShortcuts','0',1,1,NULL)", "({0},'DeleteStartMenuPinnedShortcuts','0',1,1,NULL)", "({0},'InitialEnvironmentCleanUp','0',1,1,NULL)", "({0},'aSyncVUEMAppsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMPrintersProcessing','0',1,1,NULL)", "({0},'aSyncVUEMNetDrivesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMVirtualDrivesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMRegValuesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMEnvVariablesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMPortsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMIniFilesOpsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMExtTasksProcessing','0',1,1,NULL)", "({0},'aSyncVUEMFileSystemOpsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMUserDSNsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMFileAssocsProcessing','0',1,1,NULL)", "({0},'byPassie4uinitCheck','0',1,1,NULL)", "({0},'UIAgentCustomLink','',1,1,NULL)", "({0},'enforceProcessVUEMApps','0',1,1,NULL)", "({0},'enforceProcessVUEMPrinters','0',1,1,NULL)", "({0},'enforceProcessVUEMNetDrives','0',1,1,NULL)", "({0},'enforceProcessVUEMVirtualDrives','0',1,1,NULL)", "({0},'enforceProcessVUEMRegValues','0',1,1,NULL)", "({0},'enforceProcessVUEMEnvVariables','0',1,1,NULL)", "({0},'enforceProcessVUEMPorts','0',1,1,NULL)", "({0},'enforceProcessVUEMIniFilesOps','0',1,1,NULL)", "({0},'enforceProcessVUEMExtTasks','0',1,1,NULL)", "({0},'enforceProcessVUEMFileSystemOps','0',1,1,NULL)", "({0},'enforceProcessVUEMUserDSNs','0',1,1,NULL)", "({0},'enforceProcessVUEMFileAssocs','0',1,1,NULL)", "({0},'revertUnassignedVUEMApps','0',1,1,NULL)", "({0},'revertUnassignedVUEMPrinters','0',1,1,NULL)", "({0},'revertUnassignedVUEMNetDrives','0',1,1,NULL)", "({0},'revertUnassignedVUEMVirtualDrives','0',1,1,NULL)", "({0},'revertUnassignedVUEMRegValues','0',1,1,NULL)", "({0},'revertUnassignedVUEMEnvVariables','0',1,1,NULL)", "({0},'revertUnassignedVUEMPorts','0',1,1,NULL)", "({0},'revertUnassignedVUEMIniFilesOps','0',1,1,NULL)", "({0},'revertUnassignedVUEMExtTasks','0',1,1,NULL)", "({0},'revertUnassignedVUEMFileSystemOps','0',1,1,NULL)", "({0},'revertUnassignedVUEMUserDSNs','0',1,1,NULL)", "({0},'revertUnassignedVUEMFileAssocs','0',1,1,NULL)", "({0},'AgentLaunchExcludeGroups','0',1,1,NULL)", "({0},'AgentLaunchExcludedGroups','',1,1,NULL)", "({0},'InitialDesktopUICleaning','0',1,1,NULL)", "({0},'EnableUIAgentAutomaticRefresh','0',1,1,NULL)", "({0},'UIAgentAutomaticRefreshDelay','30',1,1,NULL)", "({0},'AgentAllowUsersToManageApplications','0',1,1,NULL)", "({0},'HideUIAgentIconInPublishedApplications','0',1,1,NULL)", "({0},'ExecuteOnlyCmdAgentInPublishedApplications','0',1,1,NULL)", "({0},'enforceVUEMAppsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMPrintersFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMNetDrivesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMVirtualDrivesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMRegValuesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMEnvVariablesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMPortsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMIniFilesOpsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMExtTasksFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMFileSystemOpsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMUserDSNsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMFileAssocsFiltersProcessing','0',1,1,NULL)", "({0},'checkAppShortcutExistence','0',1,1,NULL)", "({0},'appShortcutExpandEnvironmentVariables','0',1,1,NULL)", "({0},'RefreshOnEnvironmentalSettingChange','1',1,1,NULL)", "({0},'HideUIAgentSplashScreen','0',1,1,NULL)", "({0},'processVUEMAppsOnReconnect','0',1,1,NULL)", "({0},'processVUEMPrintersOnReconnect','0',1,1,NULL)", "({0},'processVUEMNetDrivesOnReconnect','0',1,1,NULL)", "({0},'processVUEMVirtualDrivesOnReconnect','0',1,1,NULL)", "({0},'processVUEMRegValuesOnReconnect','0',1,1,NULL)", "({0},'processVUEMEnvVariablesOnReconnect','0',1,1,NULL)", "({0},'processVUEMPortsOnReconnect','0',1,1,NULL)", "({0},'processVUEMIniFilesOpsOnReconnect','0',1,1,NULL)", "({0},'processVUEMExtTasksOnReconnect','0',1,1,NULL)", "({0},'processVUEMFileSystemOpsOnReconnect','0',1,1,NULL)", "({0},'processVUEMUserDSNsOnReconnect','0',1,1,NULL)", "({0},'processVUEMFileAssocsOnReconnect','0',1,1,NULL)", "({0},'AgentAllowScreenCapture','0',1,1,NULL)", "({0},'AgentScreenCaptureEnableSendSupportEmail','0',1,1,NULL)", "({0},'AgentScreenCaptureSupportEmailAddress','',1,1,NULL)", "({0},'AgentScreenCaptureSupportEmailTemplate','',1,1,NULL)", "({0},'AgentEnableApplicationsShortcuts','0',1,1,NULL)", "({0},'UIAgentSkinName','Seven',1,1,NULL)", "({0},'HideUIAgentSplashScreenInPublishedApplications','0',1,1,NULL)", "({0},'MailCustomSubject',NULL,1,1,NULL)", "({0},'MailEnableUseSMTP','0',1,1,NULL)", "({0},'MailEnableSMTPSSL','0',1,1,NULL)", "({0},'MailSMTPPort','0',1,1,NULL)", "({0},'MailSMTPServer','',1,1,NULL)", "({0},'MailSMTPFromAddress','',1,1,NULL)", "({0},'MailSMTPToAddress','',1,1,NULL)", "({0},'MailEnableUseSMTPCredentials','0',1,1,NULL)", "({0},'MailSMTPUser','',1,1,NULL)", "({0},'MailSMTPPassword','',1,1,NULL)", "({0},'HideUIAgentSplashScreenOnReconnect','0',1,1,NULL)", "({0},'AgentDirectoryServiceTimeoutValue','15000',1,1,NULL)", "({0},'AgentBrokerServiceTimeoutValue','15000',1,1,NULL)", "({0},'AgentMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'ConnectionStateChangeNotificationEnabled','0',1,1,NULL)", "({0},'AgentPreventExitForAdmins','0',1,1,NULL)", "({0},'AgentNetworkResourceCheckTimeoutValue','500',1,1,NULL)", "({0},'AgentEnableCrossDomainsUserGroupsSearch','0',1,1,NULL)", "({0},'AgentShutdownAfterIdleEnabled','0',1,1,NULL)", "({0},'AgentShutdownAfterIdleTime','1800',1,1,NULL)", "({0},'AgentShutdownAfterEnabled','0',1,1,NULL)", "({0},'AgentShutdownAfter','8,33333333333333E-02',1,1,NULL)", "({0},'AgentSuspendInsteadOfShutdown','0',1,1,NULL)", "({0},'AgentLaunchIncludeGroups','0',1,1,NULL)", "({0},'AgentLaunchIncludedGroups','',1,1,NULL)", "({0},'DisableAdministrativeRefreshFeedback','0',1,1,NULL)", "({0},'SwitchtoServiceAgent','0',1,1,NULL)", "({0},'UseGPO','0',1,1,NULL)", "({0},'CloudConnectors','',1,1,NULL)", "({0},'AgentSwitchFeatureToggle','1',1,1,NULL)", "({0},'EnableAutoUpgrade','0',1,1,NULL)", "({0},'EnableManualUpgrade','0',1,1,NULL)", "({0},'EnableSpecifiedUpgrade','0',1,1,NULL)", "({0},'UpgradeToVersion','',1,1,NULL)", "({0},'AgentUpgradeExecutionStartTime','4,16666666666667E-02',1,1,NULL)", "({0},'AgentUpgradeExecutionEndTime','0,25',1,1,NULL)", "({0},'AgentAllowUsersToResetCachedActions','0',1,1,NULL)", "({0},'AppsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'PrintersMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'NetDrivesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'VirtualDrivesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'RegValuesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'PortsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'EnvVariablesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'ExtTasksMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'FileAssocsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'FileSystemOpsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'IniFileOpsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'UserDSNsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'AppsRetryTimes','0',1,1,NULL)", "({0},'PrintersRetryTimes','3',1,1,NULL)", "({0},'NetDrivesRetryTimes','0',1,1,NULL)", "({0},'VirtualDrivesRetryTimes','0',1,1,NULL)", "({0},'RegValuesRetryTimes','0',1,1,NULL)", "({0},'PortsRetryTimes','0',1,1,NULL)", "({0},'EnvVariablesRetryTimes','0',1,1,NULL)", "({0},'ExtTasksRetryTimes','0',1,1,NULL)", "({0},'FileAssocsRetryTimes','0',1,1,NULL)", "({0},'FileSystemOpsRetryTimes','0',1,1,NULL)", "({0},'IniFileOpsRetryTimes','0',1,1,NULL)", "({0},'UserDSNsRetryTimes','0',1,1,NULL)")
        "CitrixOptimizerConfigurationsFields" = "IdSite,Name,State,Targets,SelectedGroups,UnselectedGroups,IsDefaultTemplate,IdContent,RevisionId,Reserved01"
        "CitrixOptimizerConfigurationsValues" = @("({0},'Citrix_Windows_7.xml',1,1,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,1,1,NULL)", "({0},'Citrix_Windows_10_1607.xml',1,2,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,2,1,NULL)", "({0},'Citrix_Windows_10_1703.xml',1,4,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,3,1,NULL)", "({0},'Citrix_Windows_10_1709.xml',1,8,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,4,1,NULL)", "({0},'Citrix_Windows_10_1803.xml',1,16,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,5,1,NULL)", "({0},'Citrix_Windows_10_1809.xml',1,32,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,6,1,NULL)", "({0},'Citrix_Windows_8.xml',1,64,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,7,1,NULL)", "({0},'Citrix_Windows_Server_2008R2.xml',1,128,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,8,1,NULL)", "({0},'Citrix_Windows_Server_2012R2.xml',1,256,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,9,1,NULL)", "({0},'Citrix_Windows_Server_2016_1607.xml',1,512,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,10,1,NULL)", "({0},'Citrix_Windows_Server_2019_1809.xml',1,1024,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,11,1,NULL)", "({0},'Citrix_Windows_10_1903.xml',1,2048,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,12,1,NULL)")
        "EnvironmentalFields"                 = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "EnvironmentalValues"                 = @("({0},'HideCommonPrograms',0,'0',1,1,NULL)", "({0},'HideControlPanel',0,'0',1,1,NULL)", "({0},'RemoveRunFromStartMenu',0,'0',1,1,NULL)", "({0},'HideNetworkIcon',0,'0',1,1,NULL)", "({0},'HideAdministrativeTools',0,'0',1,1,NULL)", "({0},'HideNetworkConnections',0,'0',1,1,NULL)", "({0},'HideHelp',0,'0',1,1,NULL)", "({0},'HideWindowsUpdate',0,'0',1,1,NULL)", "({0},'HideTurnOff',0,'0',1,1,NULL)", "({0},'ForceLogoff',0,'0',1,1,NULL)", "({0},'HideFind',0,'0',1,1,NULL)", "({0},'DisableRegistryEditing',0,'0',1,1,NULL)", "({0},'DisableCmd',0,'0',1,1,NULL)", "({0},'NoNetConnectDisconnect',0,'0',1,1,NULL)", "({0},'Turnoffnotificationareacleanup',1,'0',1,1,NULL)", "({0},'LockTaskbar',1,'0',1,1,NULL)", "({0},'TurnOffpersonalizedmenus',1,'0',1,1,NULL)", "({0},'ClearRecentprogramslist',1,'0',1,1,NULL)", "({0},'RemoveContextMenuManageItem',0,'0',1,1,NULL)", "({0},'HideSpecifiedDrivesFromExplorer',1,'0',1,1,NULL)", "({0},'ExplorerHiddenDrives',1,'',1,1,NULL)", "({0},'DisableDragFullWindows',1,'0',1,1,NULL)", "({0},'DisableSmoothScroll',1,'0',1,1,NULL)", "({0},'DisableCursorBlink',1,'0',1,1,NULL)", "({0},'DisableMinAnimate',1,'0',1,1,NULL)", "({0},'SetInteractiveDelay',1,'0',1,1,NULL)", "({0},'InteractiveDelayValue',1,'40',1,1,NULL)", "({0},'EnableAutoEndTasks',1,'0',1,1,NULL)", "({0},'WaitToKillAppTimeout',1,'20000',1,1,NULL)", "({0},'SetCursorBlinkRate',1,'0',1,1,NULL)", "({0},'CursorBlinkRateValue',1,'-1',1,1,NULL)", "({0},'SetMenuShowDelay',1,'0',1,1,NULL)", "({0},'MenuShowDelayValue',1,'10',1,1,NULL)", "({0},'SetVisualStyleFile',1,'0',1,1,NULL)", "({0},'VisualStyleFileValue',1,'%windir%\resources\Themes\Aero\aero.msstyles',1,1,NULL)", "({0},'SetWallpaper',1,'0',1,1,NULL)", "({0},'Wallpaper',1,'',1,1,NULL)", "({0},'WallpaperStyle',1,'0',1,1,NULL)", "({0},'processEnvironmentalSettings',2,'0',1,1,NULL)", "({0},'RestrictSpecifiedDrivesFromExplorer',1,'0',1,1,NULL)", "({0},'ExplorerRestrictedDrives',1,'',1,1,NULL)", "({0},'HideNetworkInExplorer',1,'0',1,1,NULL)", "({0},'HideLibrairiesInExplorer',1,'0',1,1,NULL)", "({0},'NoProgramsCPL',0,'0',1,1,NULL)", "({0},'NoPropertiesMyComputer',0,'0',1,1,NULL)", "({0},'SetSpecificThemeFile',1,'0',1,1,NULL)", "({0},'SpecificThemeFileValue',1,'%windir%\resources\Themes\aero.theme',1,1,NULL)", "({0},'DisableSpecifiedKnownFolders',1,'0',1,1,NULL)", "({0},'DisabledKnownFolders',1,'',1,1,NULL)", "({0},'DisableSilentRegedit',0,'0',1,1,NULL)", "({0},'DisableCmdScripts',0,'0',1,1,NULL)", "({0},'HideDevicesandPrinters',0,'0',1,1,NULL)", "({0},'processEnvironmentalSettingsForAdmins',2,'0',1,1,NULL)", "({0},'HideSystemClock',0,'0',1,1,NULL)", "({0},'SetDesktopBackGroundColor',0,'0',1,1,NULL)", "({0},'DesktopBackGroundColor',0,'',1,1,NULL)", "({0},'NoMyComputerIcon',1,'0',1,1,NULL)", "({0},'NoRecycleBinIcon',1,'0',1,1,NULL)", "({0},'NoPropertiesRecycleBin',0,'0',1,1,NULL)", "({0},'NoMyDocumentsIcon',1,'0',1,1,NULL)", "({0},'NoPropertiesMyDocuments',0,'0',1,1,NULL)", "({0},'NoNtSecurity',0,'0',1,1,NULL)", "({0},'DisableTaskMgr',0,'0',1,1,NULL)", "({0},'RestrictCpl',0,'0',1,1,NULL)", "({0},'RestrictCplList',0,'Display',1,1,NULL)", "({0},'DisallowCpl',0,'0',1,1,NULL)", "({0},'DisallowCplList',0,'',1,1,NULL)", "({0},'BootToDesktopInsteadOfStart',1,'0',1,1,NULL)", "({0},'DisableTLcorner',0,'0',1,1,NULL)", "({0},'DisableCharmsHint',0,'0',1,1,NULL)", "({0},'NoTrayContextMenu',0,'0',1,1,NULL)", "({0},'NoViewContextMenu',0,'0',1,1,NULL)")
        "ItemsFields"                         = "IdSite,Name,DistinguishedName,Description,State,Type,Priority,RevisionId,Reserved01"
        "ItemsValues"                         = @("({0},'S-1-1-0','Everyone','A group that includes all users, even anonymous users and guests. Membership is controlled by the operating system.',1,1,100,1,NULL)", "({0},'S-1-5-32-544','BUILTIN\Administrators','A built-in group. After the initial installation of the operating system, the only member of the group is the Administrator account. When a computer joins a domain, the Domain Admins group is added to the Administrators group. When a server becomes a domain controller, the Enterprise Admins group also is added to the Administrators group.',1,1,100,1,NULL)")
        "KioskFields"                         = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "KioskValues"                         = @("({0},'PowerDontCheckBattery',0,'0',0,1,NULL)", "({0},'PowerShutdownAfterIdleTime',0,'1800',0,1,NULL)", "({0},'PowerShutdownAfterSpecifiedTime',0,'02:00',0,1,NULL)", "({0},'DesktopModeLogOffWebPortal',0,'0',0,1,NULL)", "({0},'EndSessionOption',0,'0',0,1,NULL)", "({0},'AutologonRegistryForce',0,'0',0,1,NULL)", "({0},'AutologonRegistryIgnoreShiftOverride',0,'0',0,1,NULL)", "({0},'AutologonPassword',0,'',0,1,NULL)", "({0},'AutologonDomain',0,'',0,1,NULL)", "({0},'AutologonUserName',0,'',0,1,NULL)", "({0},'AutologonEnable',0,'0',0,1,NULL)", "({0},'AdministrationHideDisplaySettings',0,'0',0,1,NULL)", "({0},'AdministrationHideKeyboardSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideMouseSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideClientDetails',0,'0',0,1,NULL)", "({0},'AdministrationDisableUnlock',0,'0',0,1,NULL)", "({0},'AdministrationHideWindowsVersion',0,'0',0,1,NULL)", "({0},'AdministrationDisableProgressBar',0,'0',0,1,NULL)", "({0},'AdministrationHidePrinterSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideLogOffOption',0,'0',0,1,NULL)", "({0},'AdministrationHideRestartOption',0,'0',0,1,NULL)", "({0},'AdministrationHideShutdownOption',0,'0',0,1,NULL)", "({0},'AdministrationHideVolumeSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideHomeButton',0,'0',0,1,NULL)", "({0},'AdministrationPreLaunchReceiver',0,'0',0,1,NULL)", "({0},'AdministrationIgnoreLastLanguage',0,'0',0,1,NULL)", "({0},'AdvancedHideTaskbar',0,'0',0,1,NULL)", "({0},'AdvancedLockCtrlAltDel',0,'0',0,1,NULL)", "({0},'AdvancedLockAltTab',0,'0',0,1,NULL)", "({0},'AdvancedFixBrowserRendering',0,'0',0,1,NULL)", "({0},'AdvancedLogOffScreenRedirection',0,'0',0,1,NULL)", "({0},'AdvancedSuppressScriptErrors',0,'0',0,1,NULL)", "({0},'AdvancedShowWifiSettings',0,'0',0,1,NULL)", "({0},'AdvancedHideKioskWhileCitrixSession',0,'0',0,1,NULL)", "({0},'AdvancedFixSslSites',0,'0',0,1,NULL)", "({0},'AdvancedAlwaysShowAdminMenu',0,'0',0,1,NULL)", "({0},'AdvancedFixZOrder',0,'0',0,1,NULL)", "({0},'ToolsAppsList',0,'',0,1,NULL)", "({0},'ToolsEnabled',0,'0',0,1,NULL)", "({0},'IsKioskEnabled',0,'0',0,1,NULL)", "({0},'SitesIsListEnabled',0,'0',0,1,NULL)", "({0},'SitesNamesAndLinks',0,'',0,1,'')", "({0},'GeneralStartUrl',0,'',0,1,NULL)", "({0},'GeneralTitle',0,'',0,1,NULL)", "({0},'GeneralShowNavigationButtons',0,'0',0,1,NULL)", "({0},'GeneralWindowMode',0,'0',0,1,NULL)", "({0},'GeneralClockEnabled',0,'0',0,1,NULL)", "({0},'GeneralClockUses12Hours',0,'0',0,1,NULL)", "({0},'GeneralUnlockPassword',0,'fLp34dnRI0DK26rJv8Tmqg==',0,1,NULL)", "({0},'GeneralEnableLanguageSelect',0,'0',0,1,NULL)", "({0},'GeneralAutoHideAppPanel',0,'0',0,1,NULL)", "({0},'GeneralEnableAppPanel',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnabled',0,'0',0,1,NULL)", "({0},'ProcessLauncherApplication',0,'',0,1,NULL)", "({0},'ProcessLauncherArgs',0,'',0,1,NULL)", "({0},'ProcessLauncherClearLastUsernameVMWare',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableVMWareViewMode',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableMicrosoftRdsMode',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableCitrixMode',0,'0',0,1,NULL)", "({0},'SetCitrixReceiverFSOMode',0,'0',0,1,NULL)")
        "ParametersFields"                    = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "ParametersValues"                    = @("({0},'excludedDriveletters','A;B;C;D',1,1,NULL)", "({0},'AllowDriveLetterReuse','0',1,1,NULL)")
        "PersonaFields"                       = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "PersonaValues"                       = @("({0},'PersonaManagementEnabled','0',1,1,NULL)", "({0},'VPEnabled','0',1,1,NULL)", "({0},'UploadProfileInterval','10',1,1,NULL)", "({0},'SetCentralProfileStore','0',1,1,NULL)", "({0},'CentralProfileStore','',1,1,NULL)", "({0},'CentralProfileOverride','0',1,1,NULL)", "({0},'DeleteLocalProfile','0',1,1,NULL)", "({0},'DeleteLocalSettings','0',1,1,NULL)", "({0},'RoamLocalSettings','0',1,1,NULL)", "({0},'EnableBackgroundDownload','0',1,1,NULL)", "({0},'CleanupCLFSFiles','0',1,1,NULL)", "({0},'SetDynamicRoamingFiles','0',1,1,NULL)", "({0},'DynamicRoamingFiles','',1,1,NULL)", "({0},'SetDynamicRoamingFilesExceptions','0',1,1,NULL)", "({0},'DynamicRoamingFilesExceptions','',1,1,NULL)", "({0},'SetBasicRoamingFiles','0',1,1,NULL)", "({0},'BasicRoamingFiles','',1,1,NULL)", "({0},'SetBasicRoamingFilesExceptions','0',1,1,NULL)", "({0},'BasicRoamingFilesExceptions','',1,1,NULL)", "({0},'SetDontRoamFiles','0',1,1,NULL)", "({0},'DontRoamFiles','AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1,NULL)", "({0},'SetDontRoamFilesExceptions','0',1,1,NULL)", "({0},'DontRoamFilesExceptions','',1,1,NULL)", "({0},'SetBackgroundLoadFolders','0',1,1,NULL)", "({0},'BackgroundLoadFolders','',1,1,NULL)", "({0},'SetBackgroundLoadFoldersExceptions','0',1,1,NULL)", "({0},'BackgroundLoadFoldersExceptions','',1,1,NULL)", "({0},'SetExcludedProcesses','0',1,1,NULL)", "({0},'ExcludedProcesses','',1,1,NULL)", "({0},'HideOfflineIcon','0',1,1,NULL)", "({0},'HideFileCopyProgress','0',1,1,NULL)", "({0},'FileCopyMinSize','50',1,1,NULL)", "({0},'EnableTrayIconErrorAlerts','0',1,1,NULL)", "({0},'SetLogPath','0',1,1,NULL)", "({0},'LogPath','',1,1,NULL)", "({0},'SetLoggingDestination','0',1,1,NULL)", "({0},'LogToFile','0',1,1,NULL)", "({0},'LogToDebugPort','0',1,1,NULL)", "({0},'SetLoggingFlags','0',1,1,NULL)", "({0},'LogError','0',1,1,NULL)", "({0},'LogInformation','0',1,1,NULL)", "({0},'LogDebug','0',1,1,NULL)", "({0},'SetDebugFlags','0',1,1,NULL)", "({0},'DebugError','0',1,1,NULL)", "({0},'DebugInformation','0',1,1,NULL)", "({0},'DebugPorts','0',1,1,NULL)", "({0},'AddAdminGroupToRedirectedFolders','0',1,1,NULL)", "({0},'RedirectApplicationData','0',1,1,NULL)", "({0},'ApplicationDataRedirectedPath','',1,1,NULL)", "({0},'RedirectContacts','0',1,1,NULL)", "({0},'ContactsRedirectedPath','',1,1,NULL)", "({0},'RedirectCookies','0',1,1,NULL)", "({0},'CookiesRedirectedPath','',1,1,NULL)", "({0},'RedirectDesktop','0',1,1,NULL)", "({0},'DesktopRedirectedPath','',1,1,NULL)", "({0},'RedirectDownloads','0',1,1,NULL)", "({0},'DownloadsRedirectedPath','',1,1,NULL)", "({0},'RedirectFavorites','0',1,1,NULL)", "({0},'FavoritesRedirectedPath','',1,1,NULL)", "({0},'RedirectHistory','0',1,1,NULL)", "({0},'HistoryRedirectedPath','',1,1,NULL)", "({0},'RedirectLinks','0',1,1,NULL)", "({0},'LinksRedirectedPath','',1,1,NULL)", "({0},'RedirectMyDocuments','0',1,1,NULL)", "({0},'MyDocumentsRedirectedPath','',1,1,NULL)", "({0},'RedirectMyMusic','0',1,1,NULL)", "({0},'MyMusicRedirectedPath','',1,1,NULL)", "({0},'RedirectMyPictures','0',1,1,NULL)", "({0},'MyPicturesRedirectedPath','',1,1,NULL)", "({0},'RedirectMyVideos','0',1,1,NULL)", "({0},'MyVideosRedirectedPath','',1,1,NULL)", "({0},'RedirectNetworkNeighborhood','0',1,1,NULL)", "({0},'NetworkNeighborhoodRedirectedPath','',1,1,NULL)", "({0},'RedirectPrinterNeighborhood','0',1,1,NULL)", "({0},'PrinterNeighborhoodRedirectedPath','',1,1,NULL)", "({0},'RedirectRecentItems','0',1,1,NULL)", "({0},'RecentItemsRedirectedPath','',1,1,NULL)", "({0},'RedirectSavedGames','0',1,1,NULL)", "({0},'SavedGamesRedirectedPath','',1,1,NULL)", "({0},'RedirectSearches','0',1,1,NULL)", "({0},'SearchesRedirectedPath','',1,1,NULL)", "({0},'RedirectSendTo','0',1,1,NULL)", "({0},'SendToRedirectedPath','',1,1,NULL)", "({0},'RedirectStartMenu','0',1,1,NULL)", "({0},'StartMenuRedirectedPath','',1,1,NULL)", "({0},'RedirectStartupItems','0',1,1,NULL)", "({0},'StartupItemsRedirectedPath','',1,1,NULL)", "({0},'RedirectTemplates','0',1,1,NULL)", "({0},'TemplatesRedirectedPath','',1,1,NULL)", "({0},'RedirectTemporaryInternetFiles','0',1,1,NULL)", "({0},'TemporaryInternetFilesRedirectedPath','',1,1,NULL)", "({0},'SetFRExclusions','0',1,1,NULL)", "({0},'FRExclusions','',1,1,NULL)", "({0},'SetFRExclusionsExceptions','0',1,1,NULL)", "({0},'FRExclusionsExceptions','',1,1,NULL)")
        "SystemMonitoringFields"              = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "SystemMonitoringValues"              = @("({0},'EnableSystemMonitoring','0',1,1,NULL)", "({0},'EnableGlobalSystemMonitoring','0',1,1,NULL)", "({0},'EnableProcessActivityMonitoring','0',1,1,NULL)", "({0},'EnableUserExperienceMonitoring','0',1,1,NULL)", "({0},'LocalDatabaseRetentionPeriod','3',1,1,NULL)", "({0},'LocalDataUploadFrequency','4',1,1,NULL)", "({0},'EnableApplicationReportsWindows2K3XPCompliance','0',1,1,NULL)",  "({0},'ExcludeProcessesFromApplicationReports','1',1,1,NULL)", "({0},'ExcludedProcessesFromApplicationReports','dwm;taskhost;vmtoolsd;winlogon;csrss;wisptis;dllhost;consent;msiexec;userinit;LogonUI;mscorsvw;SearchProtocolHost;Rundll32;explorer;regsvr32;WmiPrvSE;services;smss;SearchFilterHost;lsass;svchost;lsm;msdtc;wininit;VGAuthService;SearchIndexer;spoolsv;vmtoolsd;vmacthlp;audiodg;VMwareResolutionSet;mobsync;wsqmcons;schtasks;Defrag;conhost;VSSVC;sdclt;MpCmdRun;WMIADAP;encsvc;wfshell;CpSvc;VDARedirector;CpSvc64;SemsService;ctxrdr;PicaSvc2;encsvc;GfxMgr;PicaSessionAgent;CtxGfx;PicaTwiHost;PicaUserAgent;VDARedirector;PicaShell;PicaEuemRelay;CtxMtHost;CtxSensLoader;ssonsvr;concentr;wfcrun32;pnamain;redirector;concentr;pnamain;pnagent;IMAAdvanceSrv;mfcom;ctxxmlss;Citrix.XenApp.Commands.Remoting.Service;HCAService;cmstart;startssonsvr;ctxhide;mmvdhost;runonce;rdpclip;TabTip;InputPersonalization;TabTip32;TSTheme;ngen;XTE;CtxSvcHost;OSPPSVC;TelemetryService;CtxAudioService;picatzrestore;CheckTermSrv;IMATest;RequestTicket;csc;cvtres;ssoncom;UpmUserMsg;CtxPvD;MultimediaRedirector;gpscript;shutdown;splwow64',1,1,NULL)", "({0},'EnableStrictPrivacy','0',1,1,NULL)", "({0},'BusinessDayStartHour','8',1,1,NULL)", "({0},'BusinessDayEndHour','19',1,1,NULL)", "({0},'ReportsBootTimeMinimum','5',1,1,NULL)", "({0},'ReportsLoginTimeMinimum','5',1,1,NULL)", "({0},'EnableWorkDaysFiltering','1',1,1,NULL)", "({0},'WorkDaysFilter','1;1;1;1;1;0;0',1,1,NULL)")
        "SystemUtilitiesFields"               = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "SystemUtilitiesValues"               = @("({0},'EnableFastLogoff',0,'0',1,1,NULL)", "({0},'ExcludeGroupsFromFastLogoff',0,'0',1,1,NULL)", "({0},'FastLogoffExcludedGroups',0,NULL,1,1,NULL)", "({0},'EnableCPUSpikesProtection',1,'0',1,1,NULL)", "({0},'SpikesProtectionCPUUsageLimitPercent',1,'70',1,1,NULL)", "({0},'SpikesProtectionCPUUsageLimitSampleTime',1,'30',1,1,NULL)", "({0},'SpikesProtectionIdlePriorityConstraintTime',1,'180',1,1,NULL)", "({0},'ExcludeProcessesFromCPUSpikesProtection',1,'0',1,1,NULL)", "({0},'CPUSpikesProtectionExcludedProcesses',1,NULL,1,1,NULL)", "({0},'EnableMemoryWorkingSetOptimization',2,'0',1,1,NULL)", "({0},'MemoryWorkingSetOptimizationIdleSampleTime',2,'120',1,1,NULL)", "({0},'ExcludeProcessesFromMemoryWorkingSetOptimization',2,'0',1,1,NULL)", "({0},'MemoryWorkingSetOptimizationExcludedProcesses',2,NULL,1,1,NULL)", "({0},'EnableProcessesBlackListing',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListedProcesses',3,NULL,1,1,NULL)", "({0},'ProcessesManagementBlackListExcludeLocalAdministrators',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListExcludeSpecifiedGroups',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListExcludedSpecifiedGroupsList',3,'',1,1,NULL)", "({0},'EnableProcessesWhiteListing',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListedProcesses',3,NULL,1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludeLocalAdministrators',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludeSpecifiedGroups',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludedSpecifiedGroupsList',3,'',1,1,NULL)", "({0},'EnableProcessesManagement',3,'0',1,1,NULL)", "({0},'EnableProcessesClamping',4,'0',1,1,NULL)", "({0},'ProcessesClampingList',4,NULL,1,1,NULL)", "({0},'EnableProcessesAffinity',5,'0',1,1,NULL)", "({0},'ProcessesAffinityList',5,NULL,1,1,NULL)", "({0},'EnableProcessesIoPriority',6,'0',1,1,NULL)", "({0},'ProcessesIoPriorityList',6,NULL,1,1,NULL)", "({0},'EnableProcessesCpuPriority',7,'0',1,1,NULL)", "({0},'ProcessesCpuPriorityList',7,NULL,1,1,NULL)", "({0},'MemoryWorkingSetOptimizationIdleStateLimitPercent',2,'1',1,1,NULL)", "({0},'EnableIntelligentCpuOptimization',1,'0',1,1,NULL)", "({0},'EnableIntelligentIoOptimization',1,'0',1,1,NULL)", "({0},'SpikesProtectionLimitCPUCoreNumber',1,'0',1,1,NULL)", "({0},'SpikesProtectionCPUCoreLimit',1,'1',1,1,NULL)", "({0},'AppLockerControllerManagement',1,'1',1,1,NULL)", "({0},'AppLockerControllerReplaceModeOn',1,'1',1,1,NULL)", "({0},'AutoCPUSpikeProtectionSelected',1,'1',1,1,NULL)", "({0},'EnableCitrixOptimizer',8,'0',1,1,NULL)", "({0},'CitrixOptimizerRunWeekly',8,'0',1,1,NULL)")
        "UPMFields"                           = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "UPMValues"                           = @("({0},'UPMManagementEnabled','0',1,1,NULL)", "({0},'ServiceActive','0',1,1,NULL)", "({0},'SetProcessedGroups','0',1,1,NULL)", "({0},'ProcessedGroupsList','',1,1,NULL)", "({0},'ProcessAdmins','0',1,1,NULL)", "({0},'SetPathToUserStore','0',1,1,NULL)", "({0},'MigrateUserStore','0',1,1,NULL)", "({0},'PathToUserStore','Windows',1,1,NULL)", "({0},'MigrateUserStorePath','',1,1,NULL)", "({0},'PSMidSessionWriteBack','0',1,1,NULL)", "({0},'OfflineSupport','0',1,1,NULL)", "({0},'DeleteCachedProfilesOnLogoff','0',1,1,NULL)", "({0},'SetMigrateWindowsProfilesToUserStore','0',1,1,NULL)", "({0},'MigrateWindowsProfilesToUserStore','1',1,1,NULL)", "({0},'AutomaticMigrationEnabled','0',1,1,NULL)", "({0},'SetLocalProfileConflictHandling','0',1,1,NULL)", "({0},'LocalProfileConflictHandling','1',1,1,NULL)", "({0},'SetTemplateProfilePath','0',1,1,NULL)", "({0},'TemplateProfilePath','',1,1,NULL)", "({0},'TemplateProfileOverridesLocalProfile','0',1,1,NULL)", "({0},'TemplateProfileOverridesRoamingProfile','0',1,1,NULL)", "({0},'SetLoadRetries','0',1,1,NULL)", "({0},'LoadRetries','5',1,1,NULL)", "({0},'SetUSNDBPath','0',1,1,NULL)", "({0},'USNDBPath','',1,1,NULL)", "({0},'XenAppOptimizationEnabled','0',1,1,NULL)", "({0},'XenAppOptimizationPath','',1,1,NULL)", "({0},'ProcessCookieFiles','0',1,1,NULL)", "({0},'DeleteRedirectedFolders','0',1,1,NULL)", "({0},'LoggingEnabled','0',1,1,NULL)", "({0},'SetLogLevels','0',1,1,NULL)", "({0},'LogLevels','0;0;0;0;0;0;0;0;0;0;0',1,1,NULL)", "({0},'SetMaxLogSize','0',1,1,NULL)", "({0},'MaxLogSize','1048576',1,1,NULL)", "({0},'SetPathToLogFile','0',1,1,NULL)", "({0},'PathToLogFile','',1,1,NULL)", "({0},'SetExclusionListRegistry','0',1,1,NULL)", "({0},'ExclusionListRegistry','',1,1,NULL)", "({0},'SetInclusionListRegistry','0',1,1,NULL)", "({0},'InclusionListRegistry','',1,1,NULL)", "({0},'SetSyncExclusionListFiles','0',1,1,NULL)", "({0},'SyncExclusionListFiles','AppData\Roaming\Microsoft\Windows\Start Menu\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Startup\Desktop.ini',1,1,NULL)", "({0},'SetSyncExclusionListDir','0',1,1,NULL)", "({0},'SyncExclusionListDir','`$Recycle.Bin;AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1,NULL)", "({0},'SetSyncDirList','0',1,1,NULL)", "({0},'SyncDirList','',1,1,NULL)", "({0},'SetSyncFileList','0',1,1,NULL)", "({0},'SyncFileList','',1,1,NULL)", "({0},'SetMirrorFoldersList','0',1,1,NULL)", "({0},'MirrorFoldersList','',1,1,NULL)", "({0},'SetProfileContainerList','0',1,1,NULL)", "({0},'ProfileContainerList','',1,1,NULL)", "({0},'SetLargeFileHandlingList','0',1,1,NULL)", "({0},'LargeFileHandlingList','',1,1,NULL)", "({0},'PSEnabled','0',1,1,NULL)", "({0},'PSAlwaysCache','0',1,1,NULL)", "({0},'PSAlwaysCacheSize','0',1,1,NULL)", "({0},'SetPSPendingLockTimeout','0',1,1,NULL)", "({0},'PSPendingLockTimeout','1',1,1,NULL)", "({0},'SetPSUserGroupsList','0',1,1,NULL)", "({0},'PSUserGroupsList','',1,1,NULL)", "({0},'CPEnabled','0',1,1,NULL)", "({0},'SetCPUserGroupList','0',1,1,NULL)", "({0},'CPUserGroupList','',1,1,NULL)", "({0},'SetCPSchemaPath','0',1,1,NULL)", "({0},'CPSchemaPath','',1,1,NULL)", "({0},'SetCPPath','0',1,1,NULL)", "({0},'CPPath','',1,1,NULL)", "({0},'CPMigrationFromBaseProfileToCPStore','0',1,1,NULL)", "({0},'SetExcludedGroups','0',1,1,NULL)", "({0},'ExcludedGroupsList','',1,1,NULL)", "({0},'DisableDynamicConfig','0',1,1,NULL)", "({0},'LogoffRatherThanTempProfile','0',1,1,NULL)", "({0},'SetProfileDeleteDelay','0',1,1,NULL)", "({0},'ProfileDeleteDelay','0',1,1,NULL)", "({0},'TemplateProfileIsMandatory','0',1,1,NULL)", "({0},'PSMidSessionWriteBackReg','0',1,1,NULL)", "({0},'CEIPEnabled','1',1,1,NULL)", "({0},'LastKnownGoodRegistry','0',1,1,NULL)", "({0},'EnableDefaultExclusionListRegistry','0',1,1,NULL)", "({0},'ExclusionDefaultRegistry01','1',1,1,NULL)", "({0},'ExclusionDefaultRegistry02','1',1,1,NULL)", "({0},'ExclusionDefaultRegistry03','1',1,1,NULL)", "({0},'EnableDefaultExclusionListDirectories','0',1,1,NULL)", "({0},'ExclusionDefaultDir01','1',1,1,NULL)", "({0},'ExclusionDefaultDir02','1',1,1,NULL)", "({0},'ExclusionDefaultDir03','1',1,1,NULL)", "({0},'ExclusionDefaultDir04','1',1,1,NULL)", "({0},'ExclusionDefaultDir05','1',1,1,NULL)", "({0},'ExclusionDefaultDir06','1',1,1,NULL)", "({0},'ExclusionDefaultDir07','1',1,1,NULL)", "({0},'ExclusionDefaultDir08','1',1,1,NULL)", "({0},'ExclusionDefaultDir09','1',1,1,NULL)", "({0},'ExclusionDefaultDir10','1',1,1,NULL)", "({0},'ExclusionDefaultDir11','1',1,1,NULL)", "({0},'ExclusionDefaultDir12','1',1,1,NULL)", "({0},'ExclusionDefaultDir13','1',1,1,NULL)", "({0},'ExclusionDefaultDir14','1',1,1,NULL)", "({0},'ExclusionDefaultDir15','1',1,1,NULL)", "({0},'ExclusionDefaultDir16','1',1,1,NULL)", "({0},'ExclusionDefaultDir17','1',1,1,NULL)", "({0},'ExclusionDefaultDir18','1',1,1,NULL)", "({0},'ExclusionDefaultDir19','1',1,1,NULL)", "({0},'ExclusionDefaultDir20','1',1,1,NULL)", "({0},'ExclusionDefaultDir21','1',1,1,NULL)", "({0},'ExclusionDefaultDir22','1',1,1,NULL)", "({0},'ExclusionDefaultDir23','1',1,1,NULL)", "({0},'ExclusionDefaultDir24','1',1,1,NULL)", "({0},'ExclusionDefaultDir25','1',1,1,NULL)", "({0},'ExclusionDefaultDir26','1',1,1,NULL)", "({0},'ExclusionDefaultDir27','1',1,1,NULL)", "({0},'ExclusionDefaultDir28','1',1,1,NULL)", "({0},'ExclusionDefaultDir29','1',1,1,NULL)", "({0},'ExclusionDefaultDir30','1',1,1,NULL)", "({0},'EnableStreamingExclusionList','0',1,1,NULL)", "({0},'StreamingExclusionList','',1,1,NULL)", "({0},'EnableLogonExclusionCheck','0',1,1,NULL)", "({0},'LogonExclusionCheck','0',1,1,NULL)", "({0},'OutlookSearchRoamingEnabled','0',1,1,NULL)", "({0},'SearchBackupRestoreEnabled','0',1,1,NULL)", "({0},'FSLogixSupport','0',1,1,NULL)")
        "USVFields"                           = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "USVValues"                           = @("({0},'processUSVConfiguration',0,'0',1,1,NULL)", "({0},'processUSVConfigurationForAdmins',0,'0',1,1,NULL)", "({0},'SetWindowsRoamingProfilesPath',1,'0',1,1,NULL)", "({0},'WindowsRoamingProfilesPath',1,'',1,1,NULL)", "({0},'SetRDSRoamingProfilesPath',1,'0',1,1,NULL)", "({0},'RDSRoamingProfilesPath',1,'',1,1,NULL)", "({0},'SetRDSHomeDrivePath',1,'0',1,1,NULL)", "({0},'RDSHomeDrivePath',1,'',1,1,NULL)", "({0},'RDSHomeDriveLetter',1,'Z:',1,1,NULL)", "({0},'SetRoamingProfilesFoldersExclusions',2,'0',1,1,NULL)", "({0},'RoamingProfilesFoldersExclusions',2,'AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp',1,1,NULL)", "({0},'DeleteRoamingCachedProfiles',1,'0',1,1,NULL)", "({0},'AddAdminGroupToRUP',1,'0',1,1,NULL)", "({0},'CompatibleRUPSecurity',1,'0',1,1,NULL)", "({0},'DisableSlowLinkDetect',1,'0',1,1,NULL)", "({0},'SlowLinkProfileDefault',1,'0',1,1,NULL)", "({0},'processFoldersRedirectionConfiguration',3,'0',1,1,NULL)", "({0},'DeleteLocalRedirectedFolders',3,'0',1,1,NULL)", "({0},'processDesktopRedirection',3,'0',1,1,NULL)", "({0},'DesktopRedirectedPath',3,'',1,1,NULL)", "({0},'processStartMenuRedirection',3,'0',1,1,NULL)", "({0},'StartMenuRedirectedPath',3,'',1,1,NULL)", "({0},'processPersonalRedirection',3,'0',1,1,NULL)", "({0},'PersonalRedirectedPath',3,'',1,1,NULL)", "({0},'processPicturesRedirection',3,'0',1,1,NULL)", "({0},'PicturesRedirectedPath',3,'',1,1,NULL)", "({0},'MyPicturesFollowsDocuments',3,'0',1,1,NULL)", "({0},'processMusicRedirection',3,'0',1,1,NULL)", "({0},'MusicRedirectedPath',3,'',1,1,NULL)", "({0},'MyMusicFollowsDocuments',3,'0',1,1,NULL)", "({0},'processVideoRedirection',3,'0',1,1,NULL)", "({0},'VideoRedirectedPath',3,'',1,1,NULL)", "({0},'MyVideoFollowsDocuments',3,'0',1,1,NULL)", "({0},'processFavoritesRedirection',3,'0',1,1,NULL)", "({0},'FavoritesRedirectedPath',3,'',1,1,NULL)", "({0},'processAppDataRedirection',3,'0',1,1,NULL)", "({0},'AppDataRedirectedPath',3,'',1,1,NULL)", "({0},'processContactsRedirection',3,'0',1,1,NULL)", "({0},'ContactsRedirectedPath',3,'',1,1,NULL)", "({0},'processDownloadsRedirection',3,'0',1,1,NULL)", "({0},'DownloadsRedirectedPath',3,'',1,1,NULL)", "({0},'processLinksRedirection',3,'0',1,1,NULL)", "({0},'LinksRedirectedPath',3,'',1,1,NULL)", "({0},'processSearchesRedirection',3,'0',1,1,NULL)", "({0},'SearchesRedirectedPath',3,'',1,1,NULL)")

        "CleanupTables"                       = @("VUEMActionGroups","VUEMApps","VUEMPrinters","VUEMNetDrives","VUEMVirtualDrives","VUEMRegValues","VUEMEnvVariables","VUEMPorts","VUEMIniFilesOps","VUEMExtTasks","VUEMFileSystemOps","VUEMUserDSNs","VUEMFileAssocs","VUEMFiltersRules","VUEMFiltersConditions","VUEMItems","VUEMUserStatistics","VUEMAgentStatistics","VUEMSystemMonitoringData","VUEMActivityMonitoringData","VUEMUserExperienceMonitoringData","VUEMResourcesOptimizationData","VUEMParameters","VUEMAgentSettings","VUEMSystemUtilities","VUEMEnvironmentalSettings","VUEMUPMSettings","VUEMPersonaSettings","VUEMUSVSettings","VUEMKioskSettings","VUEMSystemMonitoringSettings","VUEMTasks","VUEMStorefrontSettings","VUEMChangesLog","VUEMAgentsLog","VUEMADObjects","AppLockerSettings","GroupPolicyObjects","GroupPolicyGlobalSettings","VUEMCitrixOptimizerConfigurations","VUEMSites")

        "VUEMExternalTaskReserved"            = $XmlHeader + '<VUEMActionAdvancedOption><Name>ExecuteOnlyAtLogon</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteAtLogon</Name><Value>1</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteAtLogoff</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteWhenRefresh</Name><Value>1</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteWhenReconnect</Name><Value>1</Value></VUEMActionAdvancedOption>' + $XmlFooter

        "VUEMCitrixOptimizerTargets"          = @{
            1    = "Windows 7 SP1"
            2    = "Windows 10 Version 1607"
            4    = "Windows 10 Version 1703"
            8    = "Windows 10 Version 1709"
            16   = "Windows 10 Version 1803"
            32   = "Windows 10 Version 1809"
            64   = "Windows 8"
            128  = "Windows Server 2008 R2"
            256  = "Windows Server 2012 R2"
            512  = "Windows Server 2016 Version 1607"
            1024 = "Windows Server 2019 Version 1809"
            2048 = "Windows 10 Version 1903"
            4096 = "Windows Server 2016 Version 1709"
            8192 = "Windows Server 2016 Version 1803"
        }
    }
    "2005" = @{
        "AgentSettingsFields"                 = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "AgentSettingsValues"                 = @("({0},'OfflineModeEnabled','0',1,1,NULL)", "({0},'UseCacheEvenIfOnline','0',1,1,NULL)", "({0},'UseCacheForActionsProcessing','1',1,1,NULL)", "({0},'processVUEMApps','0',1,1,NULL)", "({0},'processVUEMPrinters','0',1,1,NULL)", "({0},'processVUEMNetDrives','0',1,1,NULL)", "({0},'processVUEMVirtualDrives','0',1,1,NULL)", "({0},'processVUEMRegValues','0',1,1,NULL)", "({0},'processVUEMEnvVariables','0',1,1,NULL)", "({0},'processVUEMPorts','0',1,1,NULL)", "({0},'processVUEMIniFilesOps','0',1,1,NULL)", "({0},'processVUEMExtTasks','0',1,1,NULL)", "({0},'processVUEMFileSystemOps','0',1,1,NULL)", "({0},'processVUEMUserDSNs','0',1,1,NULL)", "({0},'processVUEMFileAssocs','0',1,1,NULL)", "({0},'UIAgentSplashScreenBackGround','',1,1,NULL)", "({0},'UIAgentLoadingCircleColor','',1,1,NULL)", "({0},'UIAgentLbl1TextColor','',1,1,NULL)", "({0},'UIAgentHelpLink','',1,1,NULL)", "({0},'AgentServiceDebugMode','0',1,1,NULL)", "({0},'LaunchVUEMAgentOnLogon','0',1,1,NULL)", "({0},'ProcessVUEMAgentLaunchForAdmins','0',1,1,NULL)", "({0},'LaunchVUEMAgentOnReconnect','0',1,1,NULL)", "({0},'EnableVirtualDesktopCompatibility','0',1,1,NULL)", "({0},'VUEMAgentType','UI',1,1,NULL)", "({0},'VUEMAgentDesktopsExtraLaunchDelay','0',1,1,NULL)", "({0},'VUEMAgentCacheRefreshDelay','30',1,1,NULL)", "({0},'VUEMAgentSQLSettingsRefreshDelay','15',1,1,NULL)", "({0},'DeleteDesktopShortcuts','0',1,1,NULL)", "({0},'DeleteStartMenuShortcuts','0',1,1,NULL)", "({0},'DeleteQuickLaunchShortcuts','0',1,1,NULL)", "({0},'DeleteNetworkDrives','0',1,1,NULL)", "({0},'DeleteNetworkPrinters','0',1,1,NULL)", "({0},'PreserveAutocreatedPrinters','0',1,1,NULL)", "({0},'PreserveSpecificPrinters','0',1,1,NULL)", "({0},'SpecificPreservedPrinters','PDFCreator;PDFMail;Acrobat Distiller;Amyuni',1,1,NULL)", "({0},'EnableAgentLogging','1',1,1,NULL)", "({0},'AgentLogFile','%USERPROFILE%\Citrix WEM Agent.log',1,1,NULL)", "({0},'AgentDebugMode','0',1,1,NULL)", "({0},'RefreshEnvironmentSettings','0',1,1,NULL)", "({0},'RefreshSystemSettings','0',1,1,NULL)", "({0},'RefreshDesktop','0',1,1,NULL)", "({0},'RefreshAppearance','0',1,1,NULL)", "({0},'AgentExitForAdminsOnly','1',1,1,NULL)", "({0},'AgentAllowUsersToManagePrinters','0',1,1,NULL)", "({0},'DeleteTaskBarPinnedShortcuts','0',1,1,NULL)", "({0},'DeleteStartMenuPinnedShortcuts','0',1,1,NULL)", "({0},'InitialEnvironmentCleanUp','0',1,1,NULL)", "({0},'aSyncVUEMAppsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMPrintersProcessing','0',1,1,NULL)", "({0},'aSyncVUEMNetDrivesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMVirtualDrivesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMRegValuesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMEnvVariablesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMPortsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMIniFilesOpsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMExtTasksProcessing','0',1,1,NULL)", "({0},'aSyncVUEMFileSystemOpsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMUserDSNsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMFileAssocsProcessing','0',1,1,NULL)", "({0},'byPassie4uinitCheck','0',1,1,NULL)", "({0},'UIAgentCustomLink','',1,1,NULL)", "({0},'enforceProcessVUEMApps','0',1,1,NULL)", "({0},'enforceProcessVUEMPrinters','0',1,1,NULL)", "({0},'enforceProcessVUEMNetDrives','0',1,1,NULL)", "({0},'enforceProcessVUEMVirtualDrives','0',1,1,NULL)", "({0},'enforceProcessVUEMRegValues','0',1,1,NULL)", "({0},'enforceProcessVUEMEnvVariables','0',1,1,NULL)", "({0},'enforceProcessVUEMPorts','0',1,1,NULL)", "({0},'enforceProcessVUEMIniFilesOps','0',1,1,NULL)", "({0},'enforceProcessVUEMExtTasks','0',1,1,NULL)", "({0},'enforceProcessVUEMFileSystemOps','0',1,1,NULL)", "({0},'enforceProcessVUEMUserDSNs','0',1,1,NULL)", "({0},'enforceProcessVUEMFileAssocs','0',1,1,NULL)", "({0},'revertUnassignedVUEMApps','0',1,1,NULL)", "({0},'revertUnassignedVUEMPrinters','0',1,1,NULL)", "({0},'revertUnassignedVUEMNetDrives','0',1,1,NULL)", "({0},'revertUnassignedVUEMVirtualDrives','0',1,1,NULL)", "({0},'revertUnassignedVUEMRegValues','0',1,1,NULL)", "({0},'revertUnassignedVUEMEnvVariables','0',1,1,NULL)", "({0},'revertUnassignedVUEMPorts','0',1,1,NULL)", "({0},'revertUnassignedVUEMIniFilesOps','0',1,1,NULL)", "({0},'revertUnassignedVUEMExtTasks','0',1,1,NULL)", "({0},'revertUnassignedVUEMFileSystemOps','0',1,1,NULL)", "({0},'revertUnassignedVUEMUserDSNs','0',1,1,NULL)", "({0},'revertUnassignedVUEMFileAssocs','0',1,1,NULL)", "({0},'AgentLaunchExcludeGroups','0',1,1,NULL)", "({0},'AgentLaunchExcludedGroups','',1,1,NULL)", "({0},'InitialDesktopUICleaning','0',1,1,NULL)", "({0},'EnableUIAgentAutomaticRefresh','0',1,1,NULL)", "({0},'UIAgentAutomaticRefreshDelay','30',1,1,NULL)", "({0},'AgentAllowUsersToManageApplications','0',1,1,NULL)", "({0},'HideUIAgentIconInPublishedApplications','0',1,1,NULL)", "({0},'ExecuteOnlyCmdAgentInPublishedApplications','0',1,1,NULL)", "({0},'enforceVUEMAppsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMPrintersFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMNetDrivesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMVirtualDrivesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMRegValuesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMEnvVariablesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMPortsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMIniFilesOpsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMExtTasksFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMFileSystemOpsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMUserDSNsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMFileAssocsFiltersProcessing','0',1,1,NULL)", "({0},'checkAppShortcutExistence','0',1,1,NULL)", "({0},'appShortcutExpandEnvironmentVariables','0',1,1,NULL)", "({0},'RefreshOnEnvironmentalSettingChange','1',1,1,NULL)", "({0},'HideUIAgentSplashScreen','0',1,1,NULL)", "({0},'processVUEMAppsOnReconnect','0',1,1,NULL)", "({0},'processVUEMPrintersOnReconnect','0',1,1,NULL)", "({0},'processVUEMNetDrivesOnReconnect','0',1,1,NULL)", "({0},'processVUEMVirtualDrivesOnReconnect','0',1,1,NULL)", "({0},'processVUEMRegValuesOnReconnect','0',1,1,NULL)", "({0},'processVUEMEnvVariablesOnReconnect','0',1,1,NULL)", "({0},'processVUEMPortsOnReconnect','0',1,1,NULL)", "({0},'processVUEMIniFilesOpsOnReconnect','0',1,1,NULL)", "({0},'processVUEMExtTasksOnReconnect','0',1,1,NULL)", "({0},'processVUEMFileSystemOpsOnReconnect','0',1,1,NULL)", "({0},'processVUEMUserDSNsOnReconnect','0',1,1,NULL)", "({0},'processVUEMFileAssocsOnReconnect','0',1,1,NULL)", "({0},'AgentAllowScreenCapture','0',1,1,NULL)", "({0},'AgentScreenCaptureEnableSendSupportEmail','0',1,1,NULL)", "({0},'AgentScreenCaptureSupportEmailAddress','',1,1,NULL)", "({0},'AgentScreenCaptureSupportEmailTemplate','',1,1,NULL)", "({0},'AgentEnableApplicationsShortcuts','0',1,1,NULL)", "({0},'UIAgentSkinName','Seven',1,1,NULL)", "({0},'HideUIAgentSplashScreenInPublishedApplications','0',1,1,NULL)", "({0},'MailCustomSubject',NULL,1,1,NULL)", "({0},'MailEnableUseSMTP','0',1,1,NULL)", "({0},'MailEnableSMTPSSL','0',1,1,NULL)", "({0},'MailSMTPPort','0',1,1,NULL)", "({0},'MailSMTPServer','',1,1,NULL)", "({0},'MailSMTPFromAddress','',1,1,NULL)", "({0},'MailSMTPToAddress','',1,1,NULL)", "({0},'MailEnableUseSMTPCredentials','0',1,1,NULL)", "({0},'MailSMTPUser','',1,1,NULL)", "({0},'MailSMTPPassword','',1,1,NULL)", "({0},'HideUIAgentSplashScreenOnReconnect','0',1,1,NULL)", "({0},'AgentDirectoryServiceTimeoutValue','15000',1,1,NULL)", "({0},'AgentBrokerServiceTimeoutValue','15000',1,1,NULL)", "({0},'AgentMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'ConnectionStateChangeNotificationEnabled','0',1,1,NULL)", "({0},'AgentPreventExitForAdmins','0',1,1,NULL)", "({0},'AgentNetworkResourceCheckTimeoutValue','500',1,1,NULL)", "({0},'AgentEnableCrossDomainsUserGroupsSearch','0',1,1,NULL)", "({0},'AgentShutdownAfterIdleEnabled','0',1,1,NULL)", "({0},'AgentShutdownAfterIdleTime','1800',1,1,NULL)", "({0},'AgentShutdownAfterEnabled','0',1,1,NULL)", "({0},'AgentShutdownAfter','8,33333333333333E-02',1,1,NULL)", "({0},'AgentSuspendInsteadOfShutdown','0',1,1,NULL)", "({0},'AgentLaunchIncludeGroups','0',1,1,NULL)", "({0},'AgentLaunchIncludedGroups','',1,1,NULL)", "({0},'DisableAdministrativeRefreshFeedback','0',1,1,NULL)", "({0},'SwitchtoServiceAgent','0',1,1,NULL)", "({0},'UseGPO','0',1,1,NULL)", "({0},'CloudConnectors','',1,1,NULL)", "({0},'AgentSwitchFeatureToggle','1',1,1,NULL)", "({0},'EnableAutoUpgrade','0',1,1,NULL)", "({0},'EnableManualUpgrade','0',1,1,NULL)", "({0},'EnableSpecifiedUpgrade','0',1,1,NULL)", "({0},'UpgradeToVersion','',1,1,NULL)", "({0},'AgentUpgradeExecutionStartTime','4,16666666666667E-02',1,1,NULL)", "({0},'AgentUpgradeExecutionEndTime','0,25',1,1,NULL)", "({0},'AgentAllowUsersToResetCachedActions','0',1,1,NULL)", "({0},'AppsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'PrintersMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'NetDrivesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'VirtualDrivesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'RegValuesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'PortsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'EnvVariablesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'ExtTasksMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'FileAssocsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'FileSystemOpsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'IniFileOpsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'UserDSNsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'AppsRetryTimes','0',1,1,NULL)", "({0},'PrintersRetryTimes','3',1,1,NULL)", "({0},'NetDrivesRetryTimes','0',1,1,NULL)", "({0},'VirtualDrivesRetryTimes','0',1,1,NULL)", "({0},'RegValuesRetryTimes','0',1,1,NULL)", "({0},'PortsRetryTimes','0',1,1,NULL)", "({0},'EnvVariablesRetryTimes','0',1,1,NULL)", "({0},'ExtTasksRetryTimes','0',1,1,NULL)", "({0},'FileAssocsRetryTimes','0',1,1,NULL)", "({0},'FileSystemOpsRetryTimes','0',1,1,NULL)", "({0},'IniFileOpsRetryTimes','0',1,1,NULL)", "({0},'UserDSNsRetryTimes','0',1,1,NULL)")
        "AppLockerFields"                     = "IdSite,State,RevisionId,Reserved01,Value,Setting"
        "AppLockerValues"                     = @("({0},1,1,Null,0,'EnableProcessesAppLocker')", "({0},1,1,Null,0,'EnableDLLRuleCollection')", "({0},1,1,Null,0,'CollectionExeEnforcementState')", "({0},1,1,Null,0,'CollectionMsiEnforcementState')", "({0},1,1,Null,0,'CollectionScriptEnforcementState')", "({0},1,1,Null,0,'CollectionAppxEnforcementState')", "({0},1,1,Null,0,'CollectionDllEnforcementState')")
        "CitrixOptimizerConfigurationsFields" = "IdSite,Name,State,Targets,SelectedGroups,UnselectedGroups,IsDefaultTemplate,IdContent,RevisionId,Reserved01"
        "CitrixOptimizerConfigurationsValues" = @("({0},'Citrix_Windows_7.xml',1,1,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,1,1,NULL)", "({0},'Citrix_Windows_10_1607.xml',1,2,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,2,1,NULL)", "({0},'Citrix_Windows_10_1703.xml',1,4,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,3,1,NULL)", "({0},'Citrix_Windows_10_1709.xml',1,8,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,4,1,NULL)", "({0},'Citrix_Windows_10_1803.xml',1,16,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,5,1,NULL)", "({0},'Citrix_Windows_10_1809.xml',1,32,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,6,1,NULL)", "({0},'Citrix_Windows_8.xml',1,64,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,7,1,NULL)", "({0},'Citrix_Windows_Server_2008R2.xml',1,128,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,8,1,NULL)", "({0},'Citrix_Windows_Server_2012R2.xml',1,256,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,9,1,NULL)", "({0},'Citrix_Windows_Server_2016_1607.xml',1,512,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,10,1,NULL)", "({0},'Citrix_Windows_Server_2019_1809.xml',1,1024,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,11,1,NULL)", "({0},'Citrix_Windows_10_1903.xml',1,2048,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,12,1,NULL)")
        "EnvironmentalFields"                 = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "EnvironmentalValues"                 = @("({0},'HideCommonPrograms',0,'0',1,1,NULL)", "({0},'HideControlPanel',0,'0',1,1,NULL)", "({0},'RemoveRunFromStartMenu',0,'0',1,1,NULL)", "({0},'HideNetworkIcon',0,'0',1,1,NULL)", "({0},'HideAdministrativeTools',0,'0',1,1,NULL)", "({0},'HideNetworkConnections',0,'0',1,1,NULL)", "({0},'HideHelp',0,'0',1,1,NULL)", "({0},'HideWindowsUpdate',0,'0',1,1,NULL)", "({0},'HideTurnOff',0,'0',1,1,NULL)", "({0},'ForceLogoff',0,'0',1,1,NULL)", "({0},'HideFind',0,'0',1,1,NULL)", "({0},'DisableRegistryEditing',0,'0',1,1,NULL)", "({0},'DisableCmd',0,'0',1,1,NULL)", "({0},'NoNetConnectDisconnect',0,'0',1,1,NULL)", "({0},'Turnoffnotificationareacleanup',1,'0',1,1,NULL)", "({0},'LockTaskbar',1,'0',1,1,NULL)", "({0},'TurnOffpersonalizedmenus',1,'0',1,1,NULL)", "({0},'ClearRecentprogramslist',1,'0',1,1,NULL)", "({0},'RemoveContextMenuManageItem',0,'0',1,1,NULL)", "({0},'HideSpecifiedDrivesFromExplorer',1,'0',1,1,NULL)", "({0},'ExplorerHiddenDrives',1,'',1,1,NULL)", "({0},'DisableDragFullWindows',1,'0',1,1,NULL)", "({0},'DisableSmoothScroll',1,'0',1,1,NULL)", "({0},'DisableCursorBlink',1,'0',1,1,NULL)", "({0},'DisableMinAnimate',1,'0',1,1,NULL)", "({0},'SetInteractiveDelay',1,'0',1,1,NULL)", "({0},'InteractiveDelayValue',1,'40',1,1,NULL)", "({0},'EnableAutoEndTasks',1,'0',1,1,NULL)", "({0},'WaitToKillAppTimeout',1,'20000',1,1,NULL)", "({0},'SetCursorBlinkRate',1,'0',1,1,NULL)", "({0},'CursorBlinkRateValue',1,'-1',1,1,NULL)", "({0},'SetMenuShowDelay',1,'0',1,1,NULL)", "({0},'MenuShowDelayValue',1,'10',1,1,NULL)", "({0},'SetVisualStyleFile',1,'0',1,1,NULL)", "({0},'VisualStyleFileValue',1,'%windir%\resources\Themes\Aero\aero.msstyles',1,1,NULL)", "({0},'SetWallpaper',1,'0',1,1,NULL)", "({0},'Wallpaper',1,'',1,1,NULL)", "({0},'WallpaperStyle',1,'0',1,1,NULL)", "({0},'processEnvironmentalSettings',2,'0',1,1,NULL)", "({0},'RestrictSpecifiedDrivesFromExplorer',1,'0',1,1,NULL)", "({0},'ExplorerRestrictedDrives',1,'',1,1,NULL)", "({0},'HideNetworkInExplorer',1,'0',1,1,NULL)", "({0},'HideLibrairiesInExplorer',1,'0',1,1,NULL)", "({0},'NoProgramsCPL',0,'0',1,1,NULL)", "({0},'NoPropertiesMyComputer',0,'0',1,1,NULL)", "({0},'SetSpecificThemeFile',1,'0',1,1,NULL)", "({0},'SpecificThemeFileValue',1,'%windir%\resources\Themes\aero.theme',1,1,NULL)", "({0},'DisableSpecifiedKnownFolders',1,'0',1,1,NULL)", "({0},'DisabledKnownFolders',1,'',1,1,NULL)", "({0},'DisableSilentRegedit',0,'0',1,1,NULL)", "({0},'DisableCmdScripts',0,'0',1,1,NULL)", "({0},'HideDevicesandPrinters',0,'0',1,1,NULL)", "({0},'processEnvironmentalSettingsForAdmins',2,'0',1,1,NULL)", "({0},'HideSystemClock',0,'0',1,1,NULL)", "({0},'SetDesktopBackGroundColor',0,'0',1,1,NULL)", "({0},'DesktopBackGroundColor',0,'',1,1,NULL)", "({0},'NoMyComputerIcon',1,'0',1,1,NULL)", "({0},'NoRecycleBinIcon',1,'0',1,1,NULL)", "({0},'NoPropertiesRecycleBin',0,'0',1,1,NULL)", "({0},'NoMyDocumentsIcon',1,'0',1,1,NULL)", "({0},'NoPropertiesMyDocuments',0,'0',1,1,NULL)", "({0},'NoNtSecurity',0,'0',1,1,NULL)", "({0},'DisableTaskMgr',0,'0',1,1,NULL)", "({0},'RestrictCpl',0,'0',1,1,NULL)", "({0},'RestrictCplList',0,'Display',1,1,NULL)", "({0},'DisallowCpl',0,'0',1,1,NULL)", "({0},'DisallowCplList',0,'',1,1,NULL)", "({0},'BootToDesktopInsteadOfStart',1,'0',1,1,NULL)", "({0},'DisableTLcorner',0,'0',1,1,NULL)", "({0},'DisableCharmsHint',0,'0',1,1,NULL)", "({0},'NoTrayContextMenu',0,'0',1,1,NULL)", "({0},'NoViewContextMenu',0,'0',1,1,NULL)")
        "GroupPolicyGlobalSettingsFields"     = "IdSite,Name,Value"
        "GroupPolicyGlobalSettingsValues"     = @("({0},'EnableGroupPolicyEnforcement','0')")
        "ItemsFields"                         = "IdSite,Name,DistinguishedName,Description,State,Type,Priority,RevisionId,Reserved01"
        "ItemsValues"                         = @("({0},'S-1-1-0','Everyone','A group that includes all users, even anonymous users and guests. Membership is controlled by the operating system.',1,1,100,1,NULL)", "({0},'S-1-5-32-544','BUILTIN\Administrators','A built-in group. After the initial installation of the operating system, the only member of the group is the Administrator account. When a computer joins a domain, the Domain Admins group is added to the Administrators group. When a server becomes a domain controller, the Enterprise Admins group also is added to the Administrators group.',1,1,100,1,NULL)")
        "KioskFields"                         = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "KioskValues"                         = @("({0},'PowerDontCheckBattery',0,'0',0,1,NULL)", "({0},'PowerShutdownAfterIdleTime',0,'1800',0,1,NULL)", "({0},'PowerShutdownAfterSpecifiedTime',0,'02:00',0,1,NULL)", "({0},'DesktopModeLogOffWebPortal',0,'0',0,1,NULL)", "({0},'EndSessionOption',0,'0',0,1,NULL)", "({0},'AutologonRegistryForce',0,'0',0,1,NULL)", "({0},'AutologonRegistryIgnoreShiftOverride',0,'0',0,1,NULL)", "({0},'AutologonPassword',0,'',0,1,NULL)", "({0},'AutologonDomain',0,'',0,1,NULL)", "({0},'AutologonUserName',0,'',0,1,NULL)", "({0},'AutologonEnable',0,'0',0,1,NULL)", "({0},'AdministrationHideDisplaySettings',0,'0',0,1,NULL)", "({0},'AdministrationHideKeyboardSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideMouseSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideClientDetails',0,'0',0,1,NULL)", "({0},'AdministrationDisableUnlock',0,'0',0,1,NULL)", "({0},'AdministrationHideWindowsVersion',0,'0',0,1,NULL)", "({0},'AdministrationDisableProgressBar',0,'0',0,1,NULL)", "({0},'AdministrationHidePrinterSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideLogOffOption',0,'0',0,1,NULL)", "({0},'AdministrationHideRestartOption',0,'0',0,1,NULL)", "({0},'AdministrationHideShutdownOption',0,'0',0,1,NULL)", "({0},'AdministrationHideVolumeSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideHomeButton',0,'0',0,1,NULL)", "({0},'AdministrationPreLaunchReceiver',0,'0',0,1,NULL)", "({0},'AdministrationIgnoreLastLanguage',0,'0',0,1,NULL)", "({0},'AdvancedHideTaskbar',0,'0',0,1,NULL)", "({0},'AdvancedLockCtrlAltDel',0,'0',0,1,NULL)", "({0},'AdvancedLockAltTab',0,'0',0,1,NULL)", "({0},'AdvancedFixBrowserRendering',0,'0',0,1,NULL)", "({0},'AdvancedLogOffScreenRedirection',0,'0',0,1,NULL)", "({0},'AdvancedSuppressScriptErrors',0,'0',0,1,NULL)", "({0},'AdvancedShowWifiSettings',0,'0',0,1,NULL)", "({0},'AdvancedHideKioskWhileCitrixSession',0,'0',0,1,NULL)", "({0},'AdvancedFixSslSites',0,'0',0,1,NULL)", "({0},'AdvancedAlwaysShowAdminMenu',0,'0',0,1,NULL)", "({0},'AdvancedFixZOrder',0,'0',0,1,NULL)", "({0},'ToolsAppsList',0,'',0,1,NULL)", "({0},'ToolsEnabled',0,'0',0,1,NULL)", "({0},'IsKioskEnabled',0,'0',0,1,NULL)", "({0},'SitesIsListEnabled',0,'0',0,1,NULL)", "({0},'SitesNamesAndLinks',0,'',0,1,'')", "({0},'GeneralStartUrl',0,'',0,1,NULL)", "({0},'GeneralTitle',0,'',0,1,NULL)", "({0},'GeneralShowNavigationButtons',0,'0',0,1,NULL)", "({0},'GeneralWindowMode',0,'0',0,1,NULL)", "({0},'GeneralClockEnabled',0,'0',0,1,NULL)", "({0},'GeneralClockUses12Hours',0,'0',0,1,NULL)", "({0},'GeneralUnlockPassword',0,'fLp34dnRI0DK26rJv8Tmqg==',0,1,NULL)", "({0},'GeneralEnableLanguageSelect',0,'0',0,1,NULL)", "({0},'GeneralAutoHideAppPanel',0,'0',0,1,NULL)", "({0},'GeneralEnableAppPanel',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnabled',0,'0',0,1,NULL)", "({0},'ProcessLauncherApplication',0,'',0,1,NULL)", "({0},'ProcessLauncherArgs',0,'',0,1,NULL)", "({0},'ProcessLauncherClearLastUsernameVMWare',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableVMWareViewMode',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableMicrosoftRdsMode',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableCitrixMode',0,'0',0,1,NULL)", "({0},'SetCitrixReceiverFSOMode',0,'0',0,1,NULL)")
        "ParametersFields"                    = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "ParametersValues"                    = @("({0},'excludedDriveletters','A;B;C;D',1,1,NULL)", "({0},'AllowDriveLetterReuse','0',1,1,NULL)")
        "PersonaFields"                       = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "PersonaValues"                       = @("({0},'PersonaManagementEnabled','0',1,1,NULL)", "({0},'VPEnabled','0',1,1,NULL)", "({0},'UploadProfileInterval','10',1,1,NULL)", "({0},'SetCentralProfileStore','0',1,1,NULL)", "({0},'CentralProfileStore','',1,1,NULL)", "({0},'CentralProfileOverride','0',1,1,NULL)", "({0},'DeleteLocalProfile','0',1,1,NULL)", "({0},'DeleteLocalSettings','0',1,1,NULL)", "({0},'RoamLocalSettings','0',1,1,NULL)", "({0},'EnableBackgroundDownload','0',1,1,NULL)", "({0},'CleanupCLFSFiles','0',1,1,NULL)", "({0},'SetDynamicRoamingFiles','0',1,1,NULL)", "({0},'DynamicRoamingFiles','',1,1,NULL)", "({0},'SetDynamicRoamingFilesExceptions','0',1,1,NULL)", "({0},'DynamicRoamingFilesExceptions','',1,1,NULL)", "({0},'SetBasicRoamingFiles','0',1,1,NULL)", "({0},'BasicRoamingFiles','',1,1,NULL)", "({0},'SetBasicRoamingFilesExceptions','0',1,1,NULL)", "({0},'BasicRoamingFilesExceptions','',1,1,NULL)", "({0},'SetDontRoamFiles','0',1,1,NULL)", "({0},'DontRoamFiles','AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1,NULL)", "({0},'SetDontRoamFilesExceptions','0',1,1,NULL)", "({0},'DontRoamFilesExceptions','',1,1,NULL)", "({0},'SetBackgroundLoadFolders','0',1,1,NULL)", "({0},'BackgroundLoadFolders','',1,1,NULL)", "({0},'SetBackgroundLoadFoldersExceptions','0',1,1,NULL)", "({0},'BackgroundLoadFoldersExceptions','',1,1,NULL)", "({0},'SetExcludedProcesses','0',1,1,NULL)", "({0},'ExcludedProcesses','',1,1,NULL)", "({0},'HideOfflineIcon','0',1,1,NULL)", "({0},'HideFileCopyProgress','0',1,1,NULL)", "({0},'FileCopyMinSize','50',1,1,NULL)", "({0},'EnableTrayIconErrorAlerts','0',1,1,NULL)", "({0},'SetLogPath','0',1,1,NULL)", "({0},'LogPath','',1,1,NULL)", "({0},'SetLoggingDestination','0',1,1,NULL)", "({0},'LogToFile','0',1,1,NULL)", "({0},'LogToDebugPort','0',1,1,NULL)", "({0},'SetLoggingFlags','0',1,1,NULL)", "({0},'LogError','0',1,1,NULL)", "({0},'LogInformation','0',1,1,NULL)", "({0},'LogDebug','0',1,1,NULL)", "({0},'SetDebugFlags','0',1,1,NULL)", "({0},'DebugError','0',1,1,NULL)", "({0},'DebugInformation','0',1,1,NULL)", "({0},'DebugPorts','0',1,1,NULL)", "({0},'AddAdminGroupToRedirectedFolders','0',1,1,NULL)", "({0},'RedirectApplicationData','0',1,1,NULL)", "({0},'ApplicationDataRedirectedPath','',1,1,NULL)", "({0},'RedirectContacts','0',1,1,NULL)", "({0},'ContactsRedirectedPath','',1,1,NULL)", "({0},'RedirectCookies','0',1,1,NULL)", "({0},'CookiesRedirectedPath','',1,1,NULL)", "({0},'RedirectDesktop','0',1,1,NULL)", "({0},'DesktopRedirectedPath','',1,1,NULL)", "({0},'RedirectDownloads','0',1,1,NULL)", "({0},'DownloadsRedirectedPath','',1,1,NULL)", "({0},'RedirectFavorites','0',1,1,NULL)", "({0},'FavoritesRedirectedPath','',1,1,NULL)", "({0},'RedirectHistory','0',1,1,NULL)", "({0},'HistoryRedirectedPath','',1,1,NULL)", "({0},'RedirectLinks','0',1,1,NULL)", "({0},'LinksRedirectedPath','',1,1,NULL)", "({0},'RedirectMyDocuments','0',1,1,NULL)", "({0},'MyDocumentsRedirectedPath','',1,1,NULL)", "({0},'RedirectMyMusic','0',1,1,NULL)", "({0},'MyMusicRedirectedPath','',1,1,NULL)", "({0},'RedirectMyPictures','0',1,1,NULL)", "({0},'MyPicturesRedirectedPath','',1,1,NULL)", "({0},'RedirectMyVideos','0',1,1,NULL)", "({0},'MyVideosRedirectedPath','',1,1,NULL)", "({0},'RedirectNetworkNeighborhood','0',1,1,NULL)", "({0},'NetworkNeighborhoodRedirectedPath','',1,1,NULL)", "({0},'RedirectPrinterNeighborhood','0',1,1,NULL)", "({0},'PrinterNeighborhoodRedirectedPath','',1,1,NULL)", "({0},'RedirectRecentItems','0',1,1,NULL)", "({0},'RecentItemsRedirectedPath','',1,1,NULL)", "({0},'RedirectSavedGames','0',1,1,NULL)", "({0},'SavedGamesRedirectedPath','',1,1,NULL)", "({0},'RedirectSearches','0',1,1,NULL)", "({0},'SearchesRedirectedPath','',1,1,NULL)", "({0},'RedirectSendTo','0',1,1,NULL)", "({0},'SendToRedirectedPath','',1,1,NULL)", "({0},'RedirectStartMenu','0',1,1,NULL)", "({0},'StartMenuRedirectedPath','',1,1,NULL)", "({0},'RedirectStartupItems','0',1,1,NULL)", "({0},'StartupItemsRedirectedPath','',1,1,NULL)", "({0},'RedirectTemplates','0',1,1,NULL)", "({0},'TemplatesRedirectedPath','',1,1,NULL)", "({0},'RedirectTemporaryInternetFiles','0',1,1,NULL)", "({0},'TemporaryInternetFilesRedirectedPath','',1,1,NULL)", "({0},'SetFRExclusions','0',1,1,NULL)", "({0},'FRExclusions','',1,1,NULL)", "({0},'SetFRExclusionsExceptions','0',1,1,NULL)", "({0},'FRExclusionsExceptions','',1,1,NULL)")
        "PrivElevationSettingsFields"         = "IdSite,Setting,Value,RevisionId,Reserved01"
        "PrivElevationSettingsValues"         = @("({0},'EnablePrivilegeElevation',0,1,NULL)", "({0},'EnforceRunAsInvoker',1,1,NULL)", "({0},'EnableApplytoMultiSessionOS',0,1,NULL)")
        "SiteFields"                          = "Name,Description,State,JProperties,RevisionId,Reserved01"
        "SiteValues"                          = "'{0}','{1}',1,'',1,NULL"
        "SystemMonitoringFields"              = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "SystemMonitoringValues"              = @("({0},'EnableSystemMonitoring','0',1,1,NULL)", "({0},'EnableGlobalSystemMonitoring','0',1,1,NULL)", "({0},'EnableProcessActivityMonitoring','0',1,1,NULL)", "({0},'EnableUserExperienceMonitoring','0',1,1,NULL)", "({0},'LocalDatabaseRetentionPeriod','3',1,1,NULL)", "({0},'LocalDataUploadFrequency','4',1,1,NULL)", "({0},'EnableApplicationReportsWindows2K3XPCompliance','0',1,1,NULL)", "({0},'ExcludeProcessesFromApplicationReports','1',1,1,NULL)", "({0},'ExcludedProcessesFromApplicationReports','dwm;taskhost;vmtoolsd;winlogon;csrss;wisptis;dllhost;consent;msiexec;userinit;LogonUI;mscorsvw;SearchProtocolHost;Rundll32;explorer;regsvr32;WmiPrvSE;services;smss;SearchFilterHost;lsass;svchost;lsm;msdtc;wininit;VGAuthService;SearchIndexer;spoolsv;vmtoolsd;vmacthlp;audiodg;VMwareResolutionSet;mobsync;wsqmcons;schtasks;Defrag;conhost;VSSVC;sdclt;MpCmdRun;WMIADAP;encsvc;wfshell;CpSvc;VDARedirector;CpSvc64;SemsService;ctxrdr;PicaSvc2;encsvc;GfxMgr;PicaSessionAgent;CtxGfx;PicaTwiHost;PicaUserAgent;VDARedirector;PicaShell;PicaEuemRelay;CtxMtHost;CtxSensLoader;ssonsvr;concentr;wfcrun32;pnamain;redirector;concentr;pnamain;pnagent;IMAAdvanceSrv;mfcom;ctxxmlss;Citrix.XenApp.Commands.Remoting.Service;HCAService;cmstart;startssonsvr;ctxhide;mmvdhost;runonce;rdpclip;TabTip;InputPersonalization;TabTip32;TSTheme;ngen;XTE;CtxSvcHost;OSPPSVC;TelemetryService;CtxAudioService;picatzrestore;CheckTermSrv;IMATest;RequestTicket;csc;cvtres;ssoncom;UpmUserMsg;CtxPvD;MultimediaRedirector;gpscript;shutdown;splwow64',1,1,NULL)", "({0},'EnableStrictPrivacy','0',1,1,NULL)", "({0},'BusinessDayStartHour','8',1,1,NULL)", "({0},'BusinessDayEndHour','19',1,1,NULL)", "({0},'ReportsBootTimeMinimum','5',1,1,NULL)", "({0},'ReportsLoginTimeMinimum','5',1,1,NULL)", "({0},'EnableWorkDaysFiltering','1',1,1,NULL)", "({0},'WorkDaysFilter','1;1;1;1;1;0;0',1,1,NULL)")
        "SystemUtilitiesFields"               = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "SystemUtilitiesValues"               = @("({0},'EnableFastLogoff',0,'0',1,1,NULL)", "({0},'ExcludeGroupsFromFastLogoff',0,'0',1,1,NULL)", "({0},'FastLogoffExcludedGroups',0,NULL,1,1,NULL)", "({0},'EnableCPUSpikesProtection',1,'0',1,1,NULL)", "({0},'SpikesProtectionCPUUsageLimitPercent',1,'70',1,1,NULL)", "({0},'SpikesProtectionCPUUsageLimitSampleTime',1,'30',1,1,NULL)", "({0},'SpikesProtectionIdlePriorityConstraintTime',1,'180',1,1,NULL)", "({0},'ExcludeProcessesFromCPUSpikesProtection',1,'0',1,1,NULL)", "({0},'CPUSpikesProtectionExcludedProcesses',1,NULL,1,1,NULL)", "({0},'EnableMemoryWorkingSetOptimization',2,'0',1,1,NULL)", "({0},'MemoryWorkingSetOptimizationIdleSampleTime',2,'120',1,1,NULL)", "({0},'ExcludeProcessesFromMemoryWorkingSetOptimization',2,'0',1,1,NULL)", "({0},'MemoryWorkingSetOptimizationExcludedProcesses',2,NULL,1,1,NULL)", "({0},'EnableProcessesBlackListing',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListedProcesses',3,NULL,1,1,NULL)", "({0},'ProcessesManagementBlackListExcludeLocalAdministrators',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListExcludeSpecifiedGroups',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListExcludedSpecifiedGroupsList',3,'',1,1,NULL)", "({0},'EnableProcessesWhiteListing',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListedProcesses',3,NULL,1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludeLocalAdministrators',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludeSpecifiedGroups',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludedSpecifiedGroupsList',3,'',1,1,NULL)", "({0},'EnableProcessesManagement',3,'0',1,1,NULL)", "({0},'EnableProcessesClamping',4,'0',1,1,NULL)", "({0},'ProcessesClampingList',4,NULL,1,1,NULL)", "({0},'EnableProcessesAffinity',5,'0',1,1,NULL)", "({0},'ProcessesAffinityList',5,NULL,1,1,NULL)", "({0},'EnableProcessesIoPriority',6,'0',1,1,NULL)", "({0},'ProcessesIoPriorityList',6,NULL,1,1,NULL)", "({0},'EnableProcessesCpuPriority',7,'0',1,1,NULL)", "({0},'ProcessesCpuPriorityList',7,NULL,1,1,NULL)", "({0},'MemoryWorkingSetOptimizationIdleStateLimitPercent',2,'1',1,1,NULL)", "({0},'EnableIntelligentCpuOptimization',1,'0',1,1,NULL)", "({0},'EnableIntelligentIoOptimization',1,'0',1,1,NULL)", "({0},'SpikesProtectionLimitCPUCoreNumber',1,'0',1,1,NULL)", "({0},'SpikesProtectionCPUCoreLimit',1,'1',1,1,NULL)", "({0},'AppLockerControllerManagement',1,'1',1,1,NULL)", "({0},'PrivilegeMgmtControllerManagement',1,'1',1,1,NULL)", "({0},'AppLockerControllerReplaceModeOn',1,'1',1,1,NULL)", "({0},'AutoCPUSpikeProtectionSelected',1,'1',1,1,NULL)", "({0},'EnableCitrixOptimizer',8,'0',1,1,NULL)", "({0},'CitrixOptimizerRunWeekly',8,'0',1,1,NULL)")
        "UPMFields"                           = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "UPMValues"                           = @("({0},'UPMManagementEnabled','0',1,1,NULL)", "({0},'ServiceActive','0',1,1,NULL)", "({0},'SetProcessedGroups','0',1,1,NULL)", "({0},'ProcessedGroupsList','',1,1,NULL)", "({0},'ProcessAdmins','0',1,1,NULL)", "({0},'SetPathToUserStore','0',1,1,NULL)", "({0},'MigrateUserStore','0',1,1,NULL)", "({0},'PathToUserStore','Windows',1,1,NULL)", "({0},'MigrateUserStorePath','',1,1,NULL)", "({0},'PSMidSessionWriteBack','0',1,1,NULL)", "({0},'OfflineSupport','0',1,1,NULL)", "({0},'DeleteCachedProfilesOnLogoff','0',1,1,NULL)", "({0},'SetMigrateWindowsProfilesToUserStore','0',1,1,NULL)", "({0},'MigrateWindowsProfilesToUserStore','1',1,1,NULL)", "({0},'AutomaticMigrationEnabled','0',1,1,NULL)", "({0},'SetLocalProfileConflictHandling','0',1,1,NULL)", "({0},'LocalProfileConflictHandling','1',1,1,NULL)", "({0},'SetTemplateProfilePath','0',1,1,NULL)", "({0},'TemplateProfilePath','',1,1,NULL)", "({0},'TemplateProfileOverridesLocalProfile','0',1,1,NULL)", "({0},'TemplateProfileOverridesRoamingProfile','0',1,1,NULL)", "({0},'SetLoadRetries','0',1,1,NULL)", "({0},'LoadRetries','5',1,1,NULL)", "({0},'SetUSNDBPath','0',1,1,NULL)", "({0},'USNDBPath','',1,1,NULL)", "({0},'XenAppOptimizationEnabled','0',1,1,NULL)", "({0},'XenAppOptimizationPath','',1,1,NULL)", "({0},'ProcessCookieFiles','0',1,1,NULL)", "({0},'DeleteRedirectedFolders','0',1,1,NULL)", "({0},'LoggingEnabled','0',1,1,NULL)", "({0},'SetLogLevels','0',1,1,NULL)", "({0},'LogLevels','0;0;0;0;0;0;0;0;0;0;0',1,1,NULL)", "({0},'SetMaxLogSize','0',1,1,NULL)", "({0},'MaxLogSize','1048576',1,1,NULL)", "({0},'SetPathToLogFile','0',1,1,NULL)", "({0},'PathToLogFile','',1,1,NULL)", "({0},'SetExclusionListRegistry','0',1,1,NULL)", "({0},'ExclusionListRegistry','',1,1,NULL)", "({0},'SetInclusionListRegistry','0',1,1,NULL)", "({0},'InclusionListRegistry','',1,1,NULL)", "({0},'SetSyncExclusionListFiles','0',1,1,NULL)", "({0},'SyncExclusionListFiles','AppData\Roaming\Microsoft\Windows\Start Menu\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Startup\Desktop.ini',1,1,NULL)", "({0},'SetSyncExclusionListDir','0',1,1,NULL)", "({0},'SyncExclusionListDir','`$Recycle.Bin;AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1,NULL)", "({0},'SetSyncDirList','0',1,1,NULL)", "({0},'SyncDirList','',1,1,NULL)", "({0},'SetSyncFileList','0',1,1,NULL)", "({0},'SyncFileList','',1,1,NULL)", "({0},'SetMirrorFoldersList','0',1,1,NULL)", "({0},'MirrorFoldersList','',1,1,NULL)", "({0},'SetProfileContainerList','0',1,1,NULL)", "({0},'ProfileContainerList','',1,1,NULL)", "({0},'SetLargeFileHandlingList','0',1,1,NULL)", "({0},'LargeFileHandlingList','',1,1,NULL)", "({0},'PSEnabled','0',1,1,NULL)", "({0},'PSAlwaysCache','0',1,1,NULL)", "({0},'PSAlwaysCacheSize','0',1,1,NULL)", "({0},'SetPSPendingLockTimeout','0',1,1,NULL)", "({0},'PSPendingLockTimeout','1',1,1,NULL)", "({0},'SetPSUserGroupsList','0',1,1,NULL)", "({0},'PSUserGroupsList','',1,1,NULL)", "({0},'CPEnabled','0',1,1,NULL)", "({0},'SetCPUserGroupList','0',1,1,NULL)", "({0},'CPUserGroupList','',1,1,NULL)", "({0},'SetCPSchemaPath','0',1,1,NULL)", "({0},'CPSchemaPath','',1,1,NULL)", "({0},'SetCPPath','0',1,1,NULL)", "({0},'CPPath','',1,1,NULL)", "({0},'CPMigrationFromBaseProfileToCPStore','0',1,1,NULL)", "({0},'SetExcludedGroups','0',1,1,NULL)", "({0},'ExcludedGroupsList','',1,1,NULL)", "({0},'DisableDynamicConfig','0',1,1,NULL)", "({0},'LogoffRatherThanTempProfile','0',1,1,NULL)", "({0},'SetProfileDeleteDelay','0',1,1,NULL)", "({0},'ProfileDeleteDelay','0',1,1,NULL)", "({0},'TemplateProfileIsMandatory','0',1,1,NULL)", "({0},'PSMidSessionWriteBackReg','0',1,1,NULL)", "({0},'CEIPEnabled','1',1,1,NULL)", "({0},'LastKnownGoodRegistry','0',1,1,NULL)", "({0},'EnableDefaultExclusionListRegistry','0',1,1,NULL)", "({0},'ExclusionDefaultRegistry01','1',1,1,NULL)", "({0},'ExclusionDefaultRegistry02','1',1,1,NULL)", "({0},'ExclusionDefaultRegistry03','1',1,1,NULL)", "({0},'EnableDefaultExclusionListDirectories','0',1,1,NULL)", "({0},'ExclusionDefaultDir01','1',1,1,NULL)", "({0},'ExclusionDefaultDir02','1',1,1,NULL)", "({0},'ExclusionDefaultDir03','1',1,1,NULL)", "({0},'ExclusionDefaultDir04','1',1,1,NULL)", "({0},'ExclusionDefaultDir05','1',1,1,NULL)", "({0},'ExclusionDefaultDir06','1',1,1,NULL)", "({0},'ExclusionDefaultDir07','1',1,1,NULL)", "({0},'ExclusionDefaultDir08','1',1,1,NULL)", "({0},'ExclusionDefaultDir09','1',1,1,NULL)", "({0},'ExclusionDefaultDir10','1',1,1,NULL)", "({0},'ExclusionDefaultDir11','1',1,1,NULL)", "({0},'ExclusionDefaultDir12','1',1,1,NULL)", "({0},'ExclusionDefaultDir13','1',1,1,NULL)", "({0},'ExclusionDefaultDir14','1',1,1,NULL)", "({0},'ExclusionDefaultDir15','1',1,1,NULL)", "({0},'ExclusionDefaultDir16','1',1,1,NULL)", "({0},'ExclusionDefaultDir17','1',1,1,NULL)", "({0},'ExclusionDefaultDir18','1',1,1,NULL)", "({0},'ExclusionDefaultDir19','1',1,1,NULL)", "({0},'ExclusionDefaultDir20','1',1,1,NULL)", "({0},'ExclusionDefaultDir21','1',1,1,NULL)", "({0},'ExclusionDefaultDir22','1',1,1,NULL)", "({0},'ExclusionDefaultDir23','1',1,1,NULL)", "({0},'ExclusionDefaultDir24','1',1,1,NULL)", "({0},'ExclusionDefaultDir25','1',1,1,NULL)", "({0},'ExclusionDefaultDir26','1',1,1,NULL)", "({0},'ExclusionDefaultDir27','1',1,1,NULL)", "({0},'ExclusionDefaultDir28','1',1,1,NULL)", "({0},'ExclusionDefaultDir29','1',1,1,NULL)", "({0},'ExclusionDefaultDir30','1',1,1,NULL)", "({0},'EnableStreamingExclusionList','0',1,1,NULL)", "({0},'StreamingExclusionList','',1,1,NULL)", "({0},'EnableLogonExclusionCheck','0',1,1,NULL)", "({0},'LogonExclusionCheck','0',1,1,NULL)", "({0},'OutlookSearchRoamingEnabled','0',1,1,NULL)", "({0},'SearchBackupRestoreEnabled','0',1,1,NULL)", "({0},'FSLogixSupport','0',1,1,NULL)")
        "USVFields"                           = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "USVValues"                           = @("({0},'processUSVConfiguration',0,'0',1,1,NULL)", "({0},'processUSVConfigurationForAdmins',0,'0',1,1,NULL)", "({0},'SetWindowsRoamingProfilesPath',1,'0',1,1,NULL)", "({0},'WindowsRoamingProfilesPath',1,'',1,1,NULL)", "({0},'SetRDSRoamingProfilesPath',1,'0',1,1,NULL)", "({0},'RDSRoamingProfilesPath',1,'',1,1,NULL)", "({0},'SetRDSHomeDrivePath',1,'0',1,1,NULL)", "({0},'RDSHomeDrivePath',1,'',1,1,NULL)", "({0},'RDSHomeDriveLetter',1,'Z:',1,1,NULL)", "({0},'SetRoamingProfilesFoldersExclusions',2,'0',1,1,NULL)", "({0},'RoamingProfilesFoldersExclusions',2,'AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp',1,1,NULL)", "({0},'DeleteRoamingCachedProfiles',1,'0',1,1,NULL)", "({0},'AddAdminGroupToRUP',1,'0',1,1,NULL)", "({0},'CompatibleRUPSecurity',1,'0',1,1,NULL)", "({0},'DisableSlowLinkDetect',1,'0',1,1,NULL)", "({0},'SlowLinkProfileDefault',1,'0',1,1,NULL)", "({0},'processFoldersRedirectionConfiguration',3,'0',1,1,NULL)", "({0},'DeleteLocalRedirectedFolders',3,'0',1,1,NULL)", "({0},'processDesktopRedirection',3,'0',1,1,NULL)", "({0},'DesktopRedirectedPath',3,'',1,1,NULL)", "({0},'processStartMenuRedirection',3,'0',1,1,NULL)", "({0},'StartMenuRedirectedPath',3,'',1,1,NULL)", "({0},'processPersonalRedirection',3,'0',1,1,NULL)", "({0},'PersonalRedirectedPath',3,'',1,1,NULL)", "({0},'processPicturesRedirection',3,'0',1,1,NULL)", "({0},'PicturesRedirectedPath',3,'',1,1,NULL)", "({0},'MyPicturesFollowsDocuments',3,'0',1,1,NULL)", "({0},'processMusicRedirection',3,'0',1,1,NULL)", "({0},'MusicRedirectedPath',3,'',1,1,NULL)", "({0},'MyMusicFollowsDocuments',3,'0',1,1,NULL)", "({0},'processVideoRedirection',3,'0',1,1,NULL)", "({0},'VideoRedirectedPath',3,'',1,1,NULL)", "({0},'MyVideoFollowsDocuments',3,'0',1,1,NULL)", "({0},'processFavoritesRedirection',3,'0',1,1,NULL)", "({0},'FavoritesRedirectedPath',3,'',1,1,NULL)", "({0},'processAppDataRedirection',3,'0',1,1,NULL)", "({0},'AppDataRedirectedPath',3,'',1,1,NULL)", "({0},'processContactsRedirection',3,'0',1,1,NULL)", "({0},'ContactsRedirectedPath',3,'',1,1,NULL)", "({0},'processDownloadsRedirection',3,'0',1,1,NULL)", "({0},'DownloadsRedirectedPath',3,'',1,1,NULL)", "({0},'processLinksRedirection',3,'0',1,1,NULL)", "({0},'LinksRedirectedPath',3,'',1,1,NULL)", "({0},'processSearchesRedirection',3,'0',1,1,NULL)", "({0},'SearchesRedirectedPath',3,'',1,1,NULL)")

        "CleanupTables"                       = @("VUEMActionGroups","VUEMApps","VUEMPrinters","VUEMNetDrives","VUEMVirtualDrives","VUEMRegValues","VUEMEnvVariables","VUEMPorts","VUEMIniFilesOps","VUEMExtTasks","VUEMFileSystemOps","VUEMUserDSNs","VUEMFileAssocs","VUEMFiltersRules","VUEMFiltersConditions","VUEMItems","VUEMUserStatistics","VUEMAgentStatistics","VUEMSystemMonitoringData","VUEMActivityMonitoringData","VUEMUserExperienceMonitoringData","VUEMResourcesOptimizationData","VUEMParameters","VUEMAgentSettings","VUEMSystemUtilities","VUEMCitrixOptimizerConfigurations","VUEMEnvironmentalSettings","VUEMUPMSettings","VUEMPersonaSettings","VUEMUSVSettings","VUEMKioskSettings","VUEMSystemMonitoringSettings","VUEMTasks","VUEMStorefrontSettings","VUEMChangesLog","VUEMAgentsLog","VUEMADObjects","AppLockerSettings","PrivElevationSettings","GroupPolicyObjects","GroupPolicyGlobalSettings","EncryptedData","VUEMSites")

        "VUEMExternalTaskReserved"            = $XmlHeader + '<VUEMActionAdvancedOption><Name>ExecuteOnlyAtLogon</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteAtLogon</Name><Value>1</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteAtLogoff</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteWhenRefresh</Name><Value>1</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteWhenReconnect</Name><Value>1</Value></VUEMActionAdvancedOption>' + $XmlFooter

        "VUEMCitrixOptimizerTargets"          = @{
            1    = "Windows 7 SP1"
            2    = "Windows 10 Version 1607"
            4    = "Windows 10 Version 1703"
            8    = "Windows 10 Version 1709"
            16   = "Windows 10 Version 1803"
            32   = "Windows 10 Version 1809"
            64   = "Windows 8"
            128  = "Windows Server 2008 R2"
            256  = "Windows Server 2012 R2"
            512  = "Windows Server 2016 Version 1607"
            1024 = "Windows Server 2019 Version 1809"
            2048 = "Windows 10 Version 1903"
            4096 = "Windows Server 2016 Version 1709"
            8192 = "Windows Server 2016 Version 1803"
        }
    }
    "2009" = @{
        "AgentSettingsFields"                 = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "AgentSettingsValues"                 = @("({0},'OfflineModeEnabled','0',1,1,NULL)", "({0},'UseCacheEvenIfOnline','0',1,1,NULL)", "({0},'UseCacheForActionsProcessing','1',1,1,NULL)", "({0},'processVUEMApps','0',1,1,NULL)", "({0},'processVUEMPrinters','0',1,1,NULL)", "({0},'processVUEMNetDrives','0',1,1,NULL)", "({0},'processVUEMVirtualDrives','0',1,1,NULL)", "({0},'processVUEMRegValues','0',1,1,NULL)", "({0},'processVUEMEnvVariables','0',1,1,NULL)", "({0},'processVUEMPorts','0',1,1,NULL)", "({0},'processVUEMIniFilesOps','0',1,1,NULL)", "({0},'processVUEMExtTasks','0',1,1,NULL)", "({0},'processVUEMFileSystemOps','0',1,1,NULL)", "({0},'processVUEMUserDSNs','0',1,1,NULL)", "({0},'processVUEMFileAssocs','0',1,1,NULL)", "({0},'UIAgentSplashScreenBackGround','',1,1,NULL)", "({0},'UIAgentLoadingCircleColor','',1,1,NULL)", "({0},'UIAgentLbl1TextColor','',1,1,NULL)", "({0},'UIAgentHelpLink','',1,1,NULL)", "({0},'AgentServiceDebugMode','0',1,1,NULL)", "({0},'LaunchVUEMAgentOnLogon','0',1,1,NULL)", "({0},'ProcessVUEMAgentLaunchForAdmins','0',1,1,NULL)", "({0},'LaunchVUEMAgentOnReconnect','0',1,1,NULL)", "({0},'EnableVirtualDesktopCompatibility','0',1,1,NULL)", "({0},'VUEMAgentType','UI',1,1,NULL)", "({0},'VUEMAgentDesktopsExtraLaunchDelay','0',1,1,NULL)", "({0},'VUEMAgentCacheRefreshDelay','30',1,1,NULL)", "({0},'VUEMAgentSQLSettingsRefreshDelay','15',1,1,NULL)", "({0},'DeleteDesktopShortcuts','0',1,1,NULL)", "({0},'DeleteStartMenuShortcuts','0',1,1,NULL)", "({0},'DeleteQuickLaunchShortcuts','0',1,1,NULL)", "({0},'DeleteNetworkDrives','0',1,1,NULL)", "({0},'DeleteNetworkPrinters','0',1,1,NULL)", "({0},'PreserveAutocreatedPrinters','0',1,1,NULL)", "({0},'PreserveSpecificPrinters','0',1,1,NULL)", "({0},'SpecificPreservedPrinters','PDFCreator;PDFMail;Acrobat Distiller;Amyuni',1,1,NULL)", "({0},'EnableAgentLogging','1',1,1,NULL)", "({0},'AgentLogFile','%USERPROFILE%\Citrix WEM Agent.log',1,1,NULL)", "({0},'AgentDebugMode','0',1,1,NULL)", "({0},'RefreshEnvironmentSettings','0',1,1,NULL)", "({0},'RefreshSystemSettings','0',1,1,NULL)", "({0},'RefreshDesktop','0',1,1,NULL)", "({0},'RefreshAppearance','0',1,1,NULL)", "({0},'AgentExitForAdminsOnly','1',1,1,NULL)", "({0},'AgentAllowUsersToManagePrinters','0',1,1,NULL)", "({0},'DeleteTaskBarPinnedShortcuts','0',1,1,NULL)", "({0},'DeleteStartMenuPinnedShortcuts','0',1,1,NULL)", "({0},'InitialEnvironmentCleanUp','0',1,1,NULL)", "({0},'aSyncVUEMAppsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMPrintersProcessing','0',1,1,NULL)", "({0},'aSyncVUEMNetDrivesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMVirtualDrivesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMRegValuesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMEnvVariablesProcessing','0',1,1,NULL)", "({0},'aSyncVUEMPortsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMIniFilesOpsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMExtTasksProcessing','0',1,1,NULL)", "({0},'aSyncVUEMFileSystemOpsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMUserDSNsProcessing','0',1,1,NULL)", "({0},'aSyncVUEMFileAssocsProcessing','0',1,1,NULL)", "({0},'byPassie4uinitCheck','0',1,1,NULL)", "({0},'UIAgentCustomLink','',1,1,NULL)", "({0},'enforceProcessVUEMApps','0',1,1,NULL)", "({0},'enforceProcessVUEMPrinters','0',1,1,NULL)", "({0},'enforceProcessVUEMNetDrives','0',1,1,NULL)", "({0},'enforceProcessVUEMVirtualDrives','0',1,1,NULL)", "({0},'enforceProcessVUEMRegValues','0',1,1,NULL)", "({0},'enforceProcessVUEMEnvVariables','0',1,1,NULL)", "({0},'enforceProcessVUEMPorts','0',1,1,NULL)", "({0},'enforceProcessVUEMIniFilesOps','0',1,1,NULL)", "({0},'enforceProcessVUEMExtTasks','0',1,1,NULL)", "({0},'enforceProcessVUEMFileSystemOps','0',1,1,NULL)", "({0},'enforceProcessVUEMUserDSNs','0',1,1,NULL)", "({0},'enforceProcessVUEMFileAssocs','0',1,1,NULL)", "({0},'revertUnassignedVUEMApps','0',1,1,NULL)", "({0},'revertUnassignedVUEMPrinters','0',1,1,NULL)", "({0},'revertUnassignedVUEMNetDrives','0',1,1,NULL)", "({0},'revertUnassignedVUEMVirtualDrives','0',1,1,NULL)", "({0},'revertUnassignedVUEMRegValues','0',1,1,NULL)", "({0},'revertUnassignedVUEMEnvVariables','0',1,1,NULL)", "({0},'revertUnassignedVUEMPorts','0',1,1,NULL)", "({0},'revertUnassignedVUEMIniFilesOps','0',1,1,NULL)", "({0},'revertUnassignedVUEMExtTasks','0',1,1,NULL)", "({0},'revertUnassignedVUEMFileSystemOps','0',1,1,NULL)", "({0},'revertUnassignedVUEMUserDSNs','0',1,1,NULL)", "({0},'revertUnassignedVUEMFileAssocs','0',1,1,NULL)", "({0},'AgentLaunchExcludeGroups','0',1,1,NULL)", "({0},'AgentLaunchExcludedGroups','',1,1,NULL)", "({0},'InitialDesktopUICleaning','0',1,1,NULL)", "({0},'EnableUIAgentAutomaticRefresh','0',1,1,NULL)", "({0},'UIAgentAutomaticRefreshDelay','30',1,1,NULL)", "({0},'AgentAllowUsersToManageApplications','0',1,1,NULL)", "({0},'HideUIAgentIconInPublishedApplications','0',1,1,NULL)", "({0},'ExecuteOnlyCmdAgentInPublishedApplications','0',1,1,NULL)", "({0},'enforceVUEMAppsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMPrintersFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMNetDrivesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMVirtualDrivesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMRegValuesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMEnvVariablesFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMPortsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMIniFilesOpsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMExtTasksFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMFileSystemOpsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMUserDSNsFiltersProcessing','0',1,1,NULL)", "({0},'enforceVUEMFileAssocsFiltersProcessing','0',1,1,NULL)", "({0},'checkAppShortcutExistence','0',1,1,NULL)", "({0},'appShortcutExpandEnvironmentVariables','0',1,1,NULL)", "({0},'RefreshOnEnvironmentalSettingChange','1',1,1,NULL)", "({0},'HideUIAgentSplashScreen','0',1,1,NULL)", "({0},'processVUEMAppsOnReconnect','0',1,1,NULL)", "({0},'processVUEMPrintersOnReconnect','0',1,1,NULL)", "({0},'processVUEMNetDrivesOnReconnect','0',1,1,NULL)", "({0},'processVUEMVirtualDrivesOnReconnect','0',1,1,NULL)", "({0},'processVUEMRegValuesOnReconnect','0',1,1,NULL)", "({0},'processVUEMEnvVariablesOnReconnect','0',1,1,NULL)", "({0},'processVUEMPortsOnReconnect','0',1,1,NULL)", "({0},'processVUEMIniFilesOpsOnReconnect','0',1,1,NULL)", "({0},'processVUEMExtTasksOnReconnect','0',1,1,NULL)", "({0},'processVUEMFileSystemOpsOnReconnect','0',1,1,NULL)", "({0},'processVUEMUserDSNsOnReconnect','0',1,1,NULL)", "({0},'processVUEMFileAssocsOnReconnect','0',1,1,NULL)", "({0},'AgentAllowScreenCapture','0',1,1,NULL)", "({0},'AgentScreenCaptureEnableSendSupportEmail','0',1,1,NULL)", "({0},'AgentScreenCaptureSupportEmailAddress','',1,1,NULL)", "({0},'AgentScreenCaptureSupportEmailTemplate','',1,1,NULL)", "({0},'AgentEnableApplicationsShortcuts','0',1,1,NULL)", "({0},'UIAgentSkinName','Seven',1,1,NULL)", "({0},'HideUIAgentSplashScreenInPublishedApplications','0',1,1,NULL)", "({0},'MailCustomSubject',NULL,1,1,NULL)", "({0},'MailEnableUseSMTP','0',1,1,NULL)", "({0},'MailEnableSMTPSSL','0',1,1,NULL)", "({0},'MailSMTPPort','0',1,1,NULL)", "({0},'MailSMTPServer','',1,1,NULL)", "({0},'MailSMTPFromAddress','',1,1,NULL)", "({0},'MailSMTPToAddress','',1,1,NULL)", "({0},'MailEnableUseSMTPCredentials','0',1,1,NULL)", "({0},'MailSMTPUser','',1,1,NULL)", "({0},'MailSMTPPassword','',1,1,NULL)", "({0},'HideUIAgentSplashScreenOnReconnect','0',1,1,NULL)", "({0},'AgentDirectoryServiceTimeoutValue','15000',1,1,NULL)", "({0},'AgentBrokerServiceTimeoutValue','15000',1,1,NULL)", "({0},'AgentMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'ConnectionStateChangeNotificationEnabled','0',1,1,NULL)", "({0},'AgentPreventExitForAdmins','0',1,1,NULL)", "({0},'AgentNetworkResourceCheckTimeoutValue','500',1,1,NULL)", "({0},'AgentEnableCrossDomainsUserGroupsSearch','0',1,1,NULL)", "({0},'AgentShutdownAfterIdleEnabled','0',1,1,NULL)", "({0},'AgentShutdownAfterIdleTime','1800',1,1,NULL)", "({0},'AgentShutdownAfterEnabled','0',1,1,NULL)", "({0},'AgentShutdownAfter','8,33333333333333E-02',1,1,NULL)", "({0},'AgentSuspendInsteadOfShutdown','0',1,1,NULL)", "({0},'AgentLaunchIncludeGroups','0',1,1,NULL)", "({0},'AgentLaunchIncludedGroups','',1,1,NULL)", "({0},'DisableAdministrativeRefreshFeedback','0',1,1,NULL)", "({0},'SwitchtoServiceAgent','0',1,1,NULL)", "({0},'UseGPO','0',1,1,NULL)", "({0},'CloudConnectors','',1,1,NULL)", "({0},'AgentSwitchFeatureToggle','1',1,1,NULL)", "({0},'EnableAutoUpgrade','0',1,1,NULL)", "({0},'EnableManualUpgrade','0',1,1,NULL)", "({0},'EnableSpecifiedUpgrade','0',1,1,NULL)", "({0},'UpgradeToVersion','',1,1,NULL)", "({0},'AgentUpgradeExecutionStartTime','4,16666666666667E-02',1,1,NULL)", "({0},'AgentUpgradeExecutionEndTime','0,25',1,1,NULL)", "({0},'AgentAllowUsersToResetCachedActions','0',1,1,NULL)", "({0},'AppsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'PrintersMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'NetDrivesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'VirtualDrivesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'RegValuesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'PortsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'EnvVariablesMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'ExtTasksMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'FileAssocsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'FileSystemOpsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'IniFileOpsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'UserDSNsMaxDegreeOfParallelism','0',1,1,NULL)", "({0},'AppsRetryTimes','0',1,1,NULL)", "({0},'PrintersRetryTimes','3',1,1,NULL)", "({0},'NetDrivesRetryTimes','0',1,1,NULL)", "({0},'VirtualDrivesRetryTimes','0',1,1,NULL)", "({0},'RegValuesRetryTimes','0',1,1,NULL)", "({0},'PortsRetryTimes','0',1,1,NULL)", "({0},'EnvVariablesRetryTimes','0',1,1,NULL)", "({0},'ExtTasksRetryTimes','0',1,1,NULL)", "({0},'FileAssocsRetryTimes','0',1,1,NULL)", "({0},'FileSystemOpsRetryTimes','0',1,1,NULL)", "({0},'IniFileOpsRetryTimes','0',1,1,NULL)", "({0},'UserDSNsRetryTimes','0',1,1,NULL)")
        "AppLockerFields"                     = "IdSite,State,RevisionId,Reserved01,Value,Setting"
        "AppLockerValues"                     = @("({0},1,1,Null,0,'EnableProcessesAppLocker')", "({0},1,1,Null,0,'EnableDLLRuleCollection')", "({0},1,1,Null,0,'CollectionExeEnforcementState')", "({0},1,1,Null,0,'CollectionMsiEnforcementState')", "({0},1,1,Null,0,'CollectionScriptEnforcementState')", "({0},1,1,Null,0,'CollectionAppxEnforcementState')", "({0},1,1,Null,0,'CollectionDllEnforcementState')")
        "CitrixOptimizerConfigurationsFields" = "IdSite,Name,State,Targets,SelectedGroups,UnselectedGroups,IsDefaultTemplate,IdContent,RevisionId,Reserved01"
        "CitrixOptimizerConfigurationsValues" = @("({0},'Citrix_Windows_7.xml',1,1,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,1,1,NULL)", "({0},'Citrix_Windows_10_1607.xml',1,2,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,2,1,NULL)", "({0},'Citrix_Windows_10_1703.xml',1,4,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,3,1,NULL)", "({0},'Citrix_Windows_10_1709.xml',1,8,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,4,1,NULL)", "({0},'Citrix_Windows_10_1803.xml',1,16,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,5,1,NULL)", "({0},'Citrix_Windows_10_1809.xml',1,32,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,6,1,NULL)", "({0},'Citrix_Windows_8.xml',1,64,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,7,1,NULL)", "({0},'Citrix_Windows_Server_2008R2.xml',1,128,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,8,1,NULL)", "({0},'Citrix_Windows_Server_2012R2.xml',1,256,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,9,1,NULL)", "({0},'Citrix_Windows_Server_2016_1607.xml',1,512,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,10,1,NULL)", "({0},'Citrix_Windows_Server_2019_1809.xml',1,1024,'Disable Services;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,11,1,NULL)", "({0},'Citrix_Windows_10_1903.xml',1,2048,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,12,1,NULL)", "({0},'Citrix_Windows_10_1909.xml',1,16384,'Disable Services;Remove Built-in Apps;Disable Scheduled Tasks;Miscellaneous;Maintenance Tasks;Optional Components',NULL,1,13,1,NULL)")
        "EnvironmentalFields"                 = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "EnvironmentalValues"                 = @("({0},'HideCommonPrograms',0,'0',1,1,NULL)", "({0},'HideControlPanel',0,'0',1,1,NULL)", "({0},'RemoveRunFromStartMenu',0,'0',1,1,NULL)", "({0},'HideNetworkIcon',0,'0',1,1,NULL)", "({0},'HideAdministrativeTools',0,'0',1,1,NULL)", "({0},'HideNetworkConnections',0,'0',1,1,NULL)", "({0},'HideHelp',0,'0',1,1,NULL)", "({0},'HideWindowsUpdate',0,'0',1,1,NULL)", "({0},'HideTurnOff',0,'0',1,1,NULL)", "({0},'ForceLogoff',0,'0',1,1,NULL)", "({0},'HideFind',0,'0',1,1,NULL)", "({0},'DisableRegistryEditing',0,'0',1,1,NULL)", "({0},'DisableCmd',0,'0',1,1,NULL)", "({0},'NoNetConnectDisconnect',0,'0',1,1,NULL)", "({0},'Turnoffnotificationareacleanup',1,'0',1,1,NULL)", "({0},'LockTaskbar',1,'0',1,1,NULL)", "({0},'TurnOffpersonalizedmenus',1,'0',1,1,NULL)", "({0},'ClearRecentprogramslist',1,'0',1,1,NULL)", "({0},'RemoveContextMenuManageItem',0,'0',1,1,NULL)", "({0},'HideSpecifiedDrivesFromExplorer',1,'0',1,1,NULL)", "({0},'ExplorerHiddenDrives',1,'',1,1,NULL)", "({0},'DisableDragFullWindows',1,'0',1,1,NULL)", "({0},'DisableSmoothScroll',1,'0',1,1,NULL)", "({0},'DisableCursorBlink',1,'0',1,1,NULL)", "({0},'DisableMinAnimate',1,'0',1,1,NULL)", "({0},'SetInteractiveDelay',1,'0',1,1,NULL)", "({0},'InteractiveDelayValue',1,'40',1,1,NULL)", "({0},'EnableAutoEndTasks',1,'0',1,1,NULL)", "({0},'WaitToKillAppTimeout',1,'20000',1,1,NULL)", "({0},'SetCursorBlinkRate',1,'0',1,1,NULL)", "({0},'CursorBlinkRateValue',1,'-1',1,1,NULL)", "({0},'SetMenuShowDelay',1,'0',1,1,NULL)", "({0},'MenuShowDelayValue',1,'10',1,1,NULL)", "({0},'SetVisualStyleFile',1,'0',1,1,NULL)", "({0},'VisualStyleFileValue',1,'%windir%\resources\Themes\Aero\aero.msstyles',1,1,NULL)", "({0},'SetWallpaper',1,'0',1,1,NULL)", "({0},'Wallpaper',1,'',1,1,NULL)", "({0},'WallpaperStyle',1,'0',1,1,NULL)", "({0},'processEnvironmentalSettings',2,'0',1,1,NULL)", "({0},'RestrictSpecifiedDrivesFromExplorer',1,'0',1,1,NULL)", "({0},'ExplorerRestrictedDrives',1,'',1,1,NULL)", "({0},'HideNetworkInExplorer',1,'0',1,1,NULL)", "({0},'HideLibrairiesInExplorer',1,'0',1,1,NULL)", "({0},'NoProgramsCPL',0,'0',1,1,NULL)", "({0},'NoPropertiesMyComputer',0,'0',1,1,NULL)", "({0},'SetSpecificThemeFile',1,'0',1,1,NULL)", "({0},'SpecificThemeFileValue',1,'%windir%\resources\Themes\aero.theme',1,1,NULL)", "({0},'DisableSpecifiedKnownFolders',1,'0',1,1,NULL)", "({0},'DisabledKnownFolders',1,'',1,1,NULL)", "({0},'DisableSilentRegedit',0,'0',1,1,NULL)", "({0},'DisableCmdScripts',0,'0',1,1,NULL)", "({0},'HideDevicesandPrinters',0,'0',1,1,NULL)", "({0},'processEnvironmentalSettingsForAdmins',2,'0',1,1,NULL)", "({0},'HideSystemClock',0,'0',1,1,NULL)", "({0},'SetDesktopBackGroundColor',0,'0',1,1,NULL)", "({0},'DesktopBackGroundColor',0,'',1,1,NULL)", "({0},'NoMyComputerIcon',1,'0',1,1,NULL)", "({0},'NoRecycleBinIcon',1,'0',1,1,NULL)", "({0},'NoPropertiesRecycleBin',0,'0',1,1,NULL)", "({0},'NoMyDocumentsIcon',1,'0',1,1,NULL)", "({0},'NoPropertiesMyDocuments',0,'0',1,1,NULL)", "({0},'NoNtSecurity',0,'0',1,1,NULL)", "({0},'DisableTaskMgr',0,'0',1,1,NULL)", "({0},'RestrictCpl',0,'0',1,1,NULL)", "({0},'RestrictCplList',0,'Display',1,1,NULL)", "({0},'DisallowCpl',0,'0',1,1,NULL)", "({0},'DisallowCplList',0,'',1,1,NULL)", "({0},'BootToDesktopInsteadOfStart',1,'0',1,1,NULL)", "({0},'DisableTLcorner',0,'0',1,1,NULL)", "({0},'DisableCharmsHint',0,'0',1,1,NULL)", "({0},'NoTrayContextMenu',0,'0',1,1,NULL)", "({0},'NoViewContextMenu',0,'0',1,1,NULL)")
        "GroupPolicyGlobalSettingsFields"     = "IdSite,Name,Value"
        "GroupPolicyGlobalSettingsValues"     = @("({0},'EnableGroupPolicyEnforcement','0')")
        "ItemsFields"                         = "IdSite,Name,DistinguishedName,Description,State,Type,Priority,RevisionId,Reserved01"
        "ItemsValues"                         = @("({0},'S-1-1-0','Everyone','A group that includes all users, even anonymous users and guests. Membership is controlled by the operating system.',1,1,100,1,NULL)", "({0},'S-1-5-32-544','BUILTIN\Administrators','A built-in group. After the initial installation of the operating system, the only member of the group is the Administrator account. When a computer joins a domain, the Domain Admins group is added to the Administrators group. When a server becomes a domain controller, the Enterprise Admins group also is added to the Administrators group.',1,1,100,1,NULL)")
        "KioskFields"                         = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "KioskValues"                         = @("({0},'PowerDontCheckBattery',0,'0',0,1,NULL)", "({0},'PowerShutdownAfterIdleTime',0,'1800',0,1,NULL)", "({0},'PowerShutdownAfterSpecifiedTime',0,'8,33333333333333E-02',0,1,NULL)", "({0},'DesktopModeLogOffWebPortal',0,'0',0,1,NULL)", "({0},'EndSessionOption',0,'0',0,1,NULL)", "({0},'AutologonRegistryForce',0,'0',0,1,NULL)", "({0},'AutologonRegistryIgnoreShiftOverride',0,'0',0,1,NULL)", "({0},'AutologonPassword',0,'',0,1,NULL)", "({0},'AutologonDomain',0,'',0,1,NULL)", "({0},'AutologonUserName',0,'',0,1,NULL)", "({0},'AutologonEnable',0,'0',0,1,NULL)", "({0},'AdministrationHideDisplaySettings',0,'0',0,1,NULL)", "({0},'AdministrationHideKeyboardSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideMouseSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideClientDetails',0,'0',0,1,NULL)", "({0},'AdministrationDisableUnlock',0,'0',0,1,NULL)", "({0},'AdministrationHideWindowsVersion',0,'0',0,1,NULL)", "({0},'AdministrationDisableProgressBar',0,'0',0,1,NULL)", "({0},'AdministrationHidePrinterSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideLogOffOption',0,'0',0,1,NULL)", "({0},'AdministrationHideRestartOption',0,'0',0,1,NULL)", "({0},'AdministrationHideShutdownOption',0,'0',0,1,NULL)", "({0},'AdministrationHideVolumeSettings',0,'0',0,1,NULL)", "({0},'AdministrationHideHomeButton',0,'0',0,1,NULL)", "({0},'AdministrationPreLaunchReceiver',0,'0',0,1,NULL)", "({0},'AdministrationIgnoreLastLanguage',0,'0',0,1,NULL)", "({0},'AdvancedHideTaskbar',0,'0',0,1,NULL)", "({0},'AdvancedLockCtrlAltDel',0,'0',0,1,NULL)", "({0},'AdvancedLockAltTab',0,'0',0,1,NULL)", "({0},'AdvancedFixBrowserRendering',0,'0',0,1,NULL)", "({0},'AdvancedLogOffScreenRedirection',0,'0',0,1,NULL)", "({0},'AdvancedSuppressScriptErrors',0,'0',0,1,NULL)", "({0},'AdvancedShowWifiSettings',0,'0',0,1,NULL)", "({0},'AdvancedHideKioskWhileCitrixSession',0,'0',0,1,NULL)", "({0},'AdvancedFixSslSites',0,'0',0,1,NULL)", "({0},'AdvancedAlwaysShowAdminMenu',0,'0',0,1,NULL)", "({0},'AdvancedFixZOrder',0,'0',0,1,NULL)", "({0},'ToolsAppsList',0,'',0,1,NULL)", "({0},'ToolsEnabled',0,'0',0,1,NULL)", "({0},'IsKioskEnabled',0,'0',0,1,NULL)", "({0},'SitesIsListEnabled',0,'0',0,1,NULL)", "({0},'SitesNamesAndLinks',0,'',0,1,NULL)", "({0},'GeneralStartUrl',0,'',0,1,NULL)", "({0},'GeneralTitle',0,'',0,1,NULL)", "({0},'GeneralShowNavigationButtons',0,'0',0,1,NULL)", "({0},'GeneralWindowMode',0,'0',0,1,NULL)", "({0},'GeneralClockEnabled',0,'0',0,1,NULL)", "({0},'GeneralClockUses12Hours',0,'0',0,1,NULL)", "({0},'GeneralUnlockPassword',0,'',0,1,NULL)", "({0},'GeneralEnableLanguageSelect',0,'0',0,1,NULL)", "({0},'GeneralAutoHideAppPanel',0,'0',0,1,NULL)", "({0},'GeneralEnableAppPanel',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnabled',0,'0',0,1,NULL)", "({0},'ProcessLauncherApplication',0,'',0,1,NULL)", "({0},'ProcessLauncherArgs',0,'',0,1,NULL)", "({0},'ProcessLauncherClearLastUsernameVMWare',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableVMWareViewMode',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableMicrosoftRdsMode',0,'0',0,1,NULL)", "({0},'ProcessLauncherEnableCitrixMode',0,'0',0,1,NULL)", "({0},'SetCitrixReceiverFSOMode',0,'0',0,1,NULL)")
        "ParametersFields"                    = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "ParametersValues"                    = @("({0},'excludedDriveletters','A;B;C;D',1,1,NULL)", "({0},'AllowDriveLetterReuse','0',1,1,NULL)")
        "PersonaFields"                       = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "PersonaValues"                       = @("({0},'PersonaManagementEnabled','0',1,1,NULL)", "({0},'VPEnabled','0',1,1,NULL)", "({0},'UploadProfileInterval','10',1,1,NULL)", "({0},'SetCentralProfileStore','0',1,1,NULL)", "({0},'CentralProfileStore','',1,1,NULL)", "({0},'CentralProfileOverride','0',1,1,NULL)", "({0},'DeleteLocalProfile','0',1,1,NULL)", "({0},'DeleteLocalSettings','0',1,1,NULL)", "({0},'RoamLocalSettings','0',1,1,NULL)", "({0},'EnableBackgroundDownload','0',1,1,NULL)", "({0},'CleanupCLFSFiles','0',1,1,NULL)", "({0},'SetDynamicRoamingFiles','0',1,1,NULL)", "({0},'DynamicRoamingFiles','',1,1,NULL)", "({0},'SetDynamicRoamingFilesExceptions','0',1,1,NULL)", "({0},'DynamicRoamingFilesExceptions','',1,1,NULL)", "({0},'SetBasicRoamingFiles','0',1,1,NULL)", "({0},'BasicRoamingFiles','',1,1,NULL)", "({0},'SetBasicRoamingFilesExceptions','0',1,1,NULL)", "({0},'BasicRoamingFilesExceptions','',1,1,NULL)", "({0},'SetDontRoamFiles','0',1,1,NULL)", "({0},'DontRoamFiles','AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1,NULL)", "({0},'SetDontRoamFilesExceptions','0',1,1,NULL)", "({0},'DontRoamFilesExceptions','',1,1,NULL)", "({0},'SetBackgroundLoadFolders','0',1,1,NULL)", "({0},'BackgroundLoadFolders','',1,1,NULL)", "({0},'SetBackgroundLoadFoldersExceptions','0',1,1,NULL)", "({0},'BackgroundLoadFoldersExceptions','',1,1,NULL)", "({0},'SetExcludedProcesses','0',1,1,NULL)", "({0},'ExcludedProcesses','',1,1,NULL)", "({0},'HideOfflineIcon','0',1,1,NULL)", "({0},'HideFileCopyProgress','0',1,1,NULL)", "({0},'FileCopyMinSize','50',1,1,NULL)", "({0},'EnableTrayIconErrorAlerts','0',1,1,NULL)", "({0},'SetLogPath','0',1,1,NULL)", "({0},'LogPath','',1,1,NULL)", "({0},'SetLoggingDestination','0',1,1,NULL)", "({0},'LogToFile','0',1,1,NULL)", "({0},'LogToDebugPort','0',1,1,NULL)", "({0},'SetLoggingFlags','0',1,1,NULL)", "({0},'LogError','0',1,1,NULL)", "({0},'LogInformation','0',1,1,NULL)", "({0},'LogDebug','0',1,1,NULL)", "({0},'SetDebugFlags','0',1,1,NULL)", "({0},'DebugError','0',1,1,NULL)", "({0},'DebugInformation','0',1,1,NULL)", "({0},'DebugPorts','0',1,1,NULL)", "({0},'AddAdminGroupToRedirectedFolders','0',1,1,NULL)", "({0},'RedirectApplicationData','0',1,1,NULL)", "({0},'ApplicationDataRedirectedPath','',1,1,NULL)", "({0},'RedirectContacts','0',1,1,NULL)", "({0},'ContactsRedirectedPath','',1,1,NULL)", "({0},'RedirectCookies','0',1,1,NULL)", "({0},'CookiesRedirectedPath','',1,1,NULL)", "({0},'RedirectDesktop','0',1,1,NULL)", "({0},'DesktopRedirectedPath','',1,1,NULL)", "({0},'RedirectDownloads','0',1,1,NULL)", "({0},'DownloadsRedirectedPath','',1,1,NULL)", "({0},'RedirectFavorites','0',1,1,NULL)", "({0},'FavoritesRedirectedPath','',1,1,NULL)", "({0},'RedirectHistory','0',1,1,NULL)", "({0},'HistoryRedirectedPath','',1,1,NULL)", "({0},'RedirectLinks','0',1,1,NULL)", "({0},'LinksRedirectedPath','',1,1,NULL)", "({0},'RedirectMyDocuments','0',1,1,NULL)", "({0},'MyDocumentsRedirectedPath','',1,1,NULL)", "({0},'RedirectMyMusic','0',1,1,NULL)", "({0},'MyMusicRedirectedPath','',1,1,NULL)", "({0},'RedirectMyPictures','0',1,1,NULL)", "({0},'MyPicturesRedirectedPath','',1,1,NULL)", "({0},'RedirectMyVideos','0',1,1,NULL)", "({0},'MyVideosRedirectedPath','',1,1,NULL)", "({0},'RedirectNetworkNeighborhood','0',1,1,NULL)", "({0},'NetworkNeighborhoodRedirectedPath','',1,1,NULL)", "({0},'RedirectPrinterNeighborhood','0',1,1,NULL)", "({0},'PrinterNeighborhoodRedirectedPath','',1,1,NULL)", "({0},'RedirectRecentItems','0',1,1,NULL)", "({0},'RecentItemsRedirectedPath','',1,1,NULL)", "({0},'RedirectSavedGames','0',1,1,NULL)", "({0},'SavedGamesRedirectedPath','',1,1,NULL)", "({0},'RedirectSearches','0',1,1,NULL)", "({0},'SearchesRedirectedPath','',1,1,NULL)", "({0},'RedirectSendTo','0',1,1,NULL)", "({0},'SendToRedirectedPath','',1,1,NULL)", "({0},'RedirectStartMenu','0',1,1,NULL)", "({0},'StartMenuRedirectedPath','',1,1,NULL)", "({0},'RedirectStartupItems','0',1,1,NULL)", "({0},'StartupItemsRedirectedPath','',1,1,NULL)", "({0},'RedirectTemplates','0',1,1,NULL)", "({0},'TemplatesRedirectedPath','',1,1,NULL)", "({0},'RedirectTemporaryInternetFiles','0',1,1,NULL)", "({0},'TemporaryInternetFilesRedirectedPath','',1,1,NULL)", "({0},'SetFRExclusions','0',1,1,NULL)", "({0},'FRExclusions','',1,1,NULL)", "({0},'SetFRExclusionsExceptions','0',1,1,NULL)", "({0},'FRExclusionsExceptions','',1,1,NULL)")
        "PrivElevationSettingsFields"         = "IdSite,Setting,Value,RevisionId,Reserved01"
        "PrivElevationSettingsValues"         = @("({0},'EnablePrivilegeElevation',0,1,NULL)", "({0},'EnforceRunAsInvoker',1,1,NULL)", "({0},'EnableApplytoMultiSessionOS',0,1,NULL)")
        "SiteFields"                          = "Name,Description,State,JProperties,RevisionId,Reserved01"
        "SiteValues"                          = "'{0}','{1}',1,'',1,NULL"
        "SystemMonitoringFields"              = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "SystemMonitoringValues"              = @("({0},'EnableSystemMonitoring','0',1,1,NULL)", "({0},'EnableGlobalSystemMonitoring','0',1,1,NULL)", "({0},'EnableProcessActivityMonitoring','0',1,1,NULL)", "({0},'EnableUserExperienceMonitoring','0',1,1,NULL)", "({0},'LocalDatabaseRetentionPeriod','3',1,1,NULL)", "({0},'LocalDataUploadFrequency','4',1,1,NULL)", "({0},'EnableApplicationReportsWindows2K3XPCompliance','0',1,1,NULL)", "({0},'ExcludeProcessesFromApplicationReports','1',1,1,NULL)", "({0},'ExcludedProcessesFromApplicationReports','dwm;taskhost;vmtoolsd;winlogon;csrss;wisptis;dllhost;consent;msiexec;userinit;LogonUI;mscorsvw;SearchProtocolHost;Rundll32;explorer;regsvr32;WmiPrvSE;services;smss;SearchFilterHost;lsass;svchost;lsm;msdtc;wininit;VGAuthService;SearchIndexer;spoolsv;vmtoolsd;vmacthlp;audiodg;VMwareResolutionSet;mobsync;wsqmcons;schtasks;Defrag;conhost;VSSVC;sdclt;MpCmdRun;WMIADAP;encsvc;wfshell;CpSvc;VDARedirector;CpSvc64;SemsService;ctxrdr;PicaSvc2;encsvc;GfxMgr;PicaSessionAgent;CtxGfx;PicaTwiHost;PicaUserAgent;VDARedirector;PicaShell;PicaEuemRelay;CtxMtHost;CtxSensLoader;ssonsvr;concentr;wfcrun32;pnamain;redirector;concentr;pnamain;pnagent;IMAAdvanceSrv;mfcom;ctxxmlss;Citrix.XenApp.Commands.Remoting.Service;HCAService;cmstart;startssonsvr;ctxhide;mmvdhost;runonce;rdpclip;TabTip;InputPersonalization;TabTip32;TSTheme;ngen;XTE;CtxSvcHost;OSPPSVC;TelemetryService;CtxAudioService;picatzrestore;CheckTermSrv;IMATest;RequestTicket;csc;cvtres;ssoncom;UpmUserMsg;CtxPvD;MultimediaRedirector;gpscript;shutdown;splwow64',1,1,NULL)", "({0},'EnableStrictPrivacy','0',1,1,NULL)", "({0},'BusinessDayStartHour','8',1,1,NULL)", "({0},'BusinessDayEndHour','19',1,1,NULL)", "({0},'ReportsBootTimeMinimum','5',1,1,NULL)", "({0},'ReportsLoginTimeMinimum','5',1,1,NULL)", "({0},'EnableWorkDaysFiltering','1',1,1,NULL)", "({0},'WorkDaysFilter','1;1;1;1;1;0;0',1,1,NULL)")
        "SystemUtilitiesFields"               = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "SystemUtilitiesValues"               = @("({0},'EnableFastLogoff',0,'0',1,1,NULL)", "({0},'ExcludeGroupsFromFastLogoff',0,'0',1,1,NULL)", "({0},'FastLogoffExcludedGroups',0,NULL,1,1,NULL)", "({0},'EnableCPUSpikesProtection',1,'0',1,1,NULL)", "({0},'SpikesProtectionCPUUsageLimitPercent',1,'70',1,1,NULL)", "({0},'SpikesProtectionCPUUsageLimitSampleTime',1,'30',1,1,NULL)", "({0},'SpikesProtectionIdlePriorityConstraintTime',1,'180',1,1,NULL)", "({0},'ExcludeProcessesFromCPUSpikesProtection',1,'0',1,1,NULL)", "({0},'CPUSpikesProtectionExcludedProcesses',1,NULL,1,1,NULL)", "({0},'EnableMemoryWorkingSetOptimization',2,'0',1,1,NULL)", "({0},'MemoryWorkingSetOptimizationIdleSampleTime',2,'120',1,1,NULL)", "({0},'ExcludeProcessesFromMemoryWorkingSetOptimization',2,'0',1,1,NULL)", "({0},'MemoryWorkingSetOptimizationExcludedProcesses',2,NULL,1,1,NULL)", "({0},'EnableProcessesBlackListing',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListedProcesses',3,NULL,1,1,NULL)", "({0},'ProcessesManagementBlackListExcludeLocalAdministrators',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListExcludeSpecifiedGroups',3,'0',1,1,NULL)", "({0},'ProcessesManagementBlackListExcludedSpecifiedGroupsList',3,'',1,1,NULL)", "({0},'EnableProcessesWhiteListing',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListedProcesses',3,NULL,1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludeLocalAdministrators',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludeSpecifiedGroups',3,'0',1,1,NULL)", "({0},'ProcessesManagementWhiteListExcludedSpecifiedGroupsList',3,'',1,1,NULL)", "({0},'EnableProcessesManagement',3,'0',1,1,NULL)", "({0},'EnableProcessesClamping',4,'0',1,1,NULL)", "({0},'ProcessesClampingList',4,NULL,1,1,NULL)", "({0},'EnableProcessesAffinity',5,'0',1,1,NULL)", "({0},'ProcessesAffinityList',5,NULL,1,1,NULL)", "({0},'EnableProcessesIoPriority',6,'0',1,1,NULL)", "({0},'ProcessesIoPriorityList',6,NULL,1,1,NULL)", "({0},'EnableProcessesCpuPriority',7,'0',1,1,NULL)", "({0},'ProcessesCpuPriorityList',7,NULL,1,1,NULL)", "({0},'MemoryWorkingSetOptimizationIdleStateLimitPercent',2,'1',1,1,NULL)", "({0},'EnableIntelligentCpuOptimization',1,'0',1,1,NULL)", "({0},'EnableIntelligentIoOptimization',1,'0',1,1,NULL)", "({0},'SpikesProtectionLimitCPUCoreNumber',1,'0',1,1,NULL)", "({0},'SpikesProtectionCPUCoreLimit',1,'1',1,1,NULL)", "({0},'AppLockerControllerManagement',1,'1',1,1,NULL)", "({0},'PrivilegeMgmtControllerManagement',1,'1',1,1,NULL)", "({0},'AppLockerControllerReplaceModeOn',1,'1',1,1,NULL)", "({0},'AutoCPUSpikeProtectionSelected',1,'1',1,1,NULL)", "({0},'EnableCitrixOptimizer',8,'0',1,1,NULL)", "({0},'CitrixOptimizerRunWeekly',8,'0',1,1,NULL)")
        "UPMFields"                           = "IdSite,Name,Value,State,RevisionId,Reserved01"
        "UPMValues"                           = @("({0},'UPMManagementEnabled','0',1,1,NULL)", "({0},'ServiceActive','0',1,1,NULL)", "({0},'SetProcessedGroups','0',1,1,NULL)", "({0},'ProcessedGroupsList','',1,1,NULL)", "({0},'ProcessAdmins','0',1,1,NULL)", "({0},'SetPathToUserStore','0',1,1,NULL)", "({0},'MigrateUserStore','0',1,1,NULL)", "({0},'PathToUserStore','Windows',1,1,NULL)", "({0},'MigrateUserStorePath','',1,1,NULL)", "({0},'PSMidSessionWriteBack','0',1,1,NULL)", "({0},'OfflineSupport','0',1,1,NULL)", "({0},'DeleteCachedProfilesOnLogoff','0',1,1,NULL)", "({0},'SetMigrateWindowsProfilesToUserStore','0',1,1,NULL)", "({0},'MigrateWindowsProfilesToUserStore','1',1,1,NULL)", "({0},'AutomaticMigrationEnabled','0',1,1,NULL)", "({0},'SetLocalProfileConflictHandling','0',1,1,NULL)", "({0},'LocalProfileConflictHandling','1',1,1,NULL)", "({0},'SetTemplateProfilePath','0',1,1,NULL)", "({0},'TemplateProfilePath','',1,1,NULL)", "({0},'TemplateProfileOverridesLocalProfile','0',1,1,NULL)", "({0},'TemplateProfileOverridesRoamingProfile','0',1,1,NULL)", "({0},'SetLoadRetries','0',1,1,NULL)", "({0},'LoadRetries','5',1,1,NULL)", "({0},'SetUSNDBPath','0',1,1,NULL)", "({0},'USNDBPath','',1,1,NULL)", "({0},'XenAppOptimizationEnabled','0',1,1,NULL)", "({0},'XenAppOptimizationPath','',1,1,NULL)", "({0},'ProcessCookieFiles','0',1,1,NULL)", "({0},'DeleteRedirectedFolders','0',1,1,NULL)", "({0},'LoggingEnabled','0',1,1,NULL)", "({0},'SetLogLevels','0',1,1,NULL)", "({0},'LogLevels','0;0;0;0;0;0;0;0;0;0;0',1,1,NULL)", "({0},'SetMaxLogSize','0',1,1,NULL)", "({0},'MaxLogSize','1048576',1,1,NULL)", "({0},'SetPathToLogFile','0',1,1,NULL)", "({0},'PathToLogFile','',1,1,NULL)", "({0},'SetExclusionListRegistry','0',1,1,NULL)", "({0},'ExclusionListRegistry','',1,1,NULL)", "({0},'SetInclusionListRegistry','0',1,1,NULL)", "({0},'InclusionListRegistry','',1,1,NULL)", "({0},'SetSyncExclusionListFiles','0',1,1,NULL)", "({0},'SyncExclusionListFiles','AppData\Roaming\Microsoft\Windows\Start Menu\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Desktop.ini;AppData\Roaming\Microsoft\Windows\Start Menu\Startup\Desktop.ini',1,1,NULL)", "({0},'SetSyncExclusionListDir','0',1,1,NULL)", "({0},'SyncExclusionListDir','`$Recycle.Bin;AppData\Local;AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\LocalLow;AppData\Local\Microsoft\Windows\Temporary Internet Files;AppData\Local\Microsoft\Windows\Burn;AppData\Local\Microsoft\Windows Live;AppData\Local\Microsoft\Windows Live Contacts;AppData\Local\Microsoft\Terminal Server Client;AppData\Local\Microsoft\Messenger;AppData\Local\Microsoft\OneNote;AppData\Local\Microsoft\Outlook;AppData\Local\Windows Live;AppData\Local\Temp;AppData\Local\Sun;AppData\Local\Google\Chrome\User Data\Default\Cache;AppData\Local\Google\Chrome\User Data\Default\Cached Theme Images;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp;AppData\Local\Mozilla',1,1,NULL)", "({0},'SetSyncDirList','0',1,1,NULL)", "({0},'SyncDirList','',1,1,NULL)", "({0},'SetSyncFileList','0',1,1,NULL)", "({0},'SyncFileList','',1,1,NULL)", "({0},'SetMirrorFoldersList','0',1,1,NULL)", "({0},'MirrorFoldersList','',1,1,NULL)", "({0},'SetProfileContainerList','0',1,1,NULL)", "({0},'ProfileContainerList','',1,1,NULL)", "({0},'SetProfileContainerExclusionListDir','0',1,1,NULL)", "({0},'ProfileContainerExclusionListDir','',1,1,NULL)", "({0},'SetProfileContainerInclusionListDir','0',1,1,NULL)", "({0},'ProfileContainerInclusionListDir','',1,1,NULL)", "({0},'SetLargeFileHandlingList','0',1,1,NULL)", "({0},'LargeFileHandlingList','',1,1,NULL)", "({0},'PSEnabled','0',1,1,NULL)", "({0},'PSAlwaysCache','0',1,1,NULL)", "({0},'PSAlwaysCacheSize','0',1,1,NULL)", "({0},'SetPSPendingLockTimeout','0',1,1,NULL)", "({0},'PSPendingLockTimeout','1',1,1,NULL)", "({0},'SetPSUserGroupsList','0',1,1,NULL)", "({0},'PSUserGroupsList','',1,1,NULL)", "({0},'CPEnabled','0',1,1,NULL)", "({0},'SetCPUserGroupList','0',1,1,NULL)", "({0},'CPUserGroupList','',1,1,NULL)", "({0},'SetCPSchemaPath','0',1,1,NULL)", "({0},'CPSchemaPath','',1,1,NULL)", "({0},'SetCPPath','0',1,1,NULL)", "({0},'CPPath','',1,1,NULL)", "({0},'CPMigrationFromBaseProfileToCPStore','0',1,1,NULL)", "({0},'SetExcludedGroups','0',1,1,NULL)", "({0},'ExcludedGroupsList','',1,1,NULL)", "({0},'DisableDynamicConfig','0',1,1,NULL)", "({0},'LogoffRatherThanTempProfile','0',1,1,NULL)", "({0},'SetProfileDeleteDelay','0',1,1,NULL)", "({0},'ProfileDeleteDelay','0',1,1,NULL)", "({0},'TemplateProfileIsMandatory','0',1,1,NULL)", "({0},'PSMidSessionWriteBackReg','0',1,1,NULL)", "({0},'CEIPEnabled','1',1,1,NULL)", "({0},'LastKnownGoodRegistry','0',1,1,NULL)", "({0},'EnableDefaultExclusionListRegistry','0',1,1,NULL)", "({0},'ExclusionDefaultRegistry01','1',1,1,NULL)", "({0},'ExclusionDefaultRegistry02','1',1,1,NULL)", "({0},'ExclusionDefaultRegistry03','1',1,1,NULL)", "({0},'EnableDefaultExclusionListDirectories','0',1,1,NULL)", "({0},'ExclusionDefaultDir01','1',1,1,NULL)", "({0},'ExclusionDefaultDir02','1',1,1,NULL)", "({0},'ExclusionDefaultDir03','1',1,1,NULL)", "({0},'ExclusionDefaultDir04','1',1,1,NULL)", "({0},'ExclusionDefaultDir05','1',1,1,NULL)", "({0},'ExclusionDefaultDir06','1',1,1,NULL)", "({0},'ExclusionDefaultDir07','1',1,1,NULL)", "({0},'ExclusionDefaultDir08','1',1,1,NULL)", "({0},'ExclusionDefaultDir09','1',1,1,NULL)", "({0},'ExclusionDefaultDir10','1',1,1,NULL)", "({0},'ExclusionDefaultDir11','1',1,1,NULL)", "({0},'ExclusionDefaultDir12','1',1,1,NULL)", "({0},'ExclusionDefaultDir13','1',1,1,NULL)", "({0},'ExclusionDefaultDir14','1',1,1,NULL)", "({0},'ExclusionDefaultDir15','1',1,1,NULL)", "({0},'ExclusionDefaultDir16','1',1,1,NULL)", "({0},'ExclusionDefaultDir17','1',1,1,NULL)", "({0},'ExclusionDefaultDir18','1',1,1,NULL)", "({0},'ExclusionDefaultDir19','1',1,1,NULL)", "({0},'ExclusionDefaultDir20','1',1,1,NULL)", "({0},'ExclusionDefaultDir21','1',1,1,NULL)", "({0},'ExclusionDefaultDir22','1',1,1,NULL)", "({0},'ExclusionDefaultDir23','1',1,1,NULL)", "({0},'ExclusionDefaultDir24','1',1,1,NULL)", "({0},'ExclusionDefaultDir25','1',1,1,NULL)", "({0},'ExclusionDefaultDir26','1',1,1,NULL)", "({0},'ExclusionDefaultDir27','1',1,1,NULL)", "({0},'ExclusionDefaultDir28','1',1,1,NULL)", "({0},'ExclusionDefaultDir29','1',1,1,NULL)", "({0},'ExclusionDefaultDir30','1',1,1,NULL)", "({0},'EnableStreamingExclusionList','0',1,1,NULL)", "({0},'StreamingExclusionList','',1,1,NULL)", "({0},'EnableLogonExclusionCheck','0',1,1,NULL)", "({0},'LogonExclusionCheck','0',1,1,NULL)", "({0},'OutlookSearchRoamingEnabled','0',1,1,NULL)", "({0},'SearchBackupRestoreEnabled','0',1,1,NULL)", "({0},'FSLogixSupport','0',1,1,NULL)")
        "USVFields"                           = "IdSite,Name,Type,Value,State,RevisionId,Reserved01"
        "USVValues"                           = @("({0},'processUSVConfiguration',0,'0',1,1,NULL)", "({0},'processUSVConfigurationForAdmins',0,'0',1,1,NULL)", "({0},'SetWindowsRoamingProfilesPath',1,'0',1,1,NULL)", "({0},'WindowsRoamingProfilesPath',1,'',1,1,NULL)", "({0},'SetRDSRoamingProfilesPath',1,'0',1,1,NULL)", "({0},'RDSRoamingProfilesPath',1,'',1,1,NULL)", "({0},'SetRDSHomeDrivePath',1,'0',1,1,NULL)", "({0},'RDSHomeDrivePath',1,'',1,1,NULL)", "({0},'RDSHomeDriveLetter',1,'Z:',1,1,NULL)", "({0},'SetRoamingProfilesFoldersExclusions',2,'0',1,1,NULL)", "({0},'RoamingProfilesFoldersExclusions',2,'AppData\Roaming\Citrix\PNAgent\AppCache;AppData\Roaming\Citrix\PNAgent\Icon Cache;AppData\Roaming\Citrix\PNAgent\ResourceCache;AppData\Roaming\ICAClient\Cache;AppData\Roaming\Macromedia\Flash Player\#SharedObjects;AppData\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys;AppData\Roaming\Sun\Java\Deployment\cache;AppData\Roaming\Sun\Java\Deployment\log;AppData\Roaming\Sun\Java\Deployment\tmp',1,1,NULL)", "({0},'DeleteRoamingCachedProfiles',1,'0',1,1,NULL)", "({0},'AddAdminGroupToRUP',1,'0',1,1,NULL)", "({0},'CompatibleRUPSecurity',1,'0',1,1,NULL)", "({0},'DisableSlowLinkDetect',1,'0',1,1,NULL)", "({0},'SlowLinkProfileDefault',1,'0',1,1,NULL)", "({0},'processFoldersRedirectionConfiguration',3,'0',1,1,NULL)", "({0},'DeleteLocalRedirectedFolders',3,'0',1,1,NULL)", "({0},'processDesktopRedirection',3,'0',1,1,NULL)", "({0},'DesktopRedirectedPath',3,'',1,1,NULL)", "({0},'processStartMenuRedirection',3,'0',1,1,NULL)", "({0},'StartMenuRedirectedPath',3,'',1,1,NULL)", "({0},'processPersonalRedirection',3,'0',1,1,NULL)", "({0},'PersonalRedirectedPath',3,'',1,1,NULL)", "({0},'processPicturesRedirection',3,'0',1,1,NULL)", "({0},'PicturesRedirectedPath',3,'',1,1,NULL)", "({0},'MyPicturesFollowsDocuments',3,'0',1,1,NULL)", "({0},'processMusicRedirection',3,'0',1,1,NULL)", "({0},'MusicRedirectedPath',3,'',1,1,NULL)", "({0},'MyMusicFollowsDocuments',3,'0',1,1,NULL)", "({0},'processVideoRedirection',3,'0',1,1,NULL)", "({0},'VideoRedirectedPath',3,'',1,1,NULL)", "({0},'MyVideoFollowsDocuments',3,'0',1,1,NULL)", "({0},'processFavoritesRedirection',3,'0',1,1,NULL)", "({0},'FavoritesRedirectedPath',3,'',1,1,NULL)", "({0},'processAppDataRedirection',3,'0',1,1,NULL)", "({0},'AppDataRedirectedPath',3,'',1,1,NULL)", "({0},'processContactsRedirection',3,'0',1,1,NULL)", "({0},'ContactsRedirectedPath',3,'',1,1,NULL)", "({0},'processDownloadsRedirection',3,'0',1,1,NULL)", "({0},'DownloadsRedirectedPath',3,'',1,1,NULL)", "({0},'processLinksRedirection',3,'0',1,1,NULL)", "({0},'LinksRedirectedPath',3,'',1,1,NULL)", "({0},'processSearchesRedirection',3,'0',1,1,NULL)", "({0},'SearchesRedirectedPath',3,'',1,1,NULL)")

        "CleanupTables"                       = @("VUEMActionGroups","VUEMApps","VUEMPrinters","VUEMNetDrives","VUEMVirtualDrives","VUEMRegValues","VUEMEnvVariables","VUEMPorts","VUEMIniFilesOps","VUEMExtTasks","VUEMFileSystemOps","VUEMUserDSNs","VUEMFileAssocs","VUEMFiltersRules","VUEMFiltersConditions","VUEMItems","VUEMUserStatistics","VUEMAgentStatistics","VUEMSystemMonitoringData","VUEMActivityMonitoringData","VUEMUserExperienceMonitoringData","VUEMResourcesOptimizationData","VUEMParameters","VUEMAgentSettings","VUEMSystemUtilities","VUEMCitrixOptimizerConfigurations","VUEMEnvironmentalSettings","VUEMUPMSettings","VUEMPersonaSettings","VUEMUSVSettings","VUEMKioskSettings","VUEMSystemMonitoringSettings","VUEMTasks","VUEMStorefrontSettings","VUEMChangesLog","VUEMAgentsLog","VUEMADObjects","AppLockerSettings","PrivElevationSettings","GroupPolicyObjects","GroupPolicyGlobalSettings","EncryptedData","VUEMSites")

        "VUEMExternalTaskReserved"            = $XmlHeader + '<VUEMActionAdvancedOption><Name>ExecuteOnlyAtLogon</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteAtLogon</Name><Value>1</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteAtLogoff</Name><Value>0</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteWhenRefresh</Name><Value>1</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>ExecuteWhenReconnect</Name><Value>1</Value></VUEMActionAdvancedOption>' + $XmlFooter

        "VUEMCitrixOptimizerTargets"          = @{
            1     = "Windows 7 SP1"
            2     = "Windows 10 Version 1607"
            4     = "Windows 10 Version 1703"
            8     = "Windows 10 Version 1709"
            16    = "Windows 10 Version 1803"
            32    = "Windows 10 Version 1809"
            64    = "Windows 8"
            128   = "Windows Server 2008 R2"
            256   = "Windows Server 2012 R2"
            512   = "Windows Server 2016 Version 1607"
            1024  = "Windows Server 2019 Version 1809"
            2048  = "Windows 10 Version 1903"
            4096  = "Windows Server 2016 Version 1709"
            8192  = "Windows Server 2016 Version 1803"
            16384 = "Windows 10 Version 1909"
        }
    }
}

$ActionCategories         = @("Application","Printer","Network Drive","Virtual Drive","Registry Value","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association")
$assignmentPropertiesEnum = @{1="CreateDesktopLink";2="CreateQuickLaunchLink";4="CreateStartMenuLink";8="PinToTaskbar";16="PinToStartMenu";32="AutoStart";"CreateDesktopLink"=1;"CreateQuickLaunchLink"=2;"CreateStartMenuLink"=4;"PinToTaskbar"=8;"PinToStartMenu"=16;"AutoStart"=32}

$defaultIconStream = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAEaSURBVFhH7ZTbCoJAEIaFCCKCCKJnLTpQVBdB14HQ00T0CqUP4AN41puJAVe92F3HRZegHfgQFvH7/1nQMmPmZ+Z8uYJOCm01vJe64PF8cZ+Ftho89DxPC8IAeZ73QpZlJWmattsAfsBavsk0yRsD3Ox7ST3A4uTC/OjC7ODCdO/AZOfAeOvAaPOB4foDg1UVwLZtIUmSqG2AIq9vgNcc5coBKHIWgNec0RhAdAUUOSJrjsRxrLYBihxBMa85QzkARY7ImjOkAURXQJEjKOY1Z0RRpLYBihyRNUe5cgCKHEEprzmjMYDoCqjImiNhGKptgApvA3V57wFkzbUGEMmDIGgfAKH84ShypQBdyn3fFwfQSaE1Y+bvx7K+efsbU5+Ow3MAAAAASUVORK5CYII="

$tableVUEMRegAction = @{
    0 = "SetValue"
    1 = "DeleteValue"
    "SetValue"         = 0
    "DeleteValue"      = 1
}
$tableVUEMRegScope = @{
    0 = "Machine"
    1 = "User"
    "Machine"          = 0
    "User"             = 1
}
$tableVUEMRegType = @{
    "REG_NONE"                       = 0	# No value type
    "REG_SZ"                         = 1	# Unicode null terminated string
    "REG_EXPAND_SZ"                  = 2	# Unicode null terminated string (with environmental variable references)
    "REG_BINARY"                     = 3	# Free form binary
    "REG_DWORD"                      = 4	# 32-bit number
    "REG_DWORD_BIG_ENDIAN"           = 5	# 32-bit number
    "REG_LINK"                       = 6	# Symbolic link (Unicode)
    "REG_MULTI_SZ"                   = 7	# Multiple Unicode strings, delimited by \0, terminated by \0\0
    "REG_RESOURCE_LIST"              = 8  # Resource list in resource map
    "REG_FULL_RESOURCE_DESCRIPTOR"   = 9  # Resource list in hardware description
    "REG_RESOURCE_REQUIREMENTS_LIST" = 10
    "REG_QWORD"                      = 11 # 64-bit number
    0 = "REG_NONE"
    1 = "REG_SZ"
    2 = "REG_EXPAND_SZ"
    3 = "REG_BINARY"
    4 = "REG_DWORD"
    5 = "REG_DWORD_BIG_ENDIAN"
    6 = "REG_LINK"
    7 = "REG_MULTI_SZ"
    8 = "REG_RESOURCE_LIST"
    9 = "REG_FULL_RESOURCE_DESCRIPTOR"
    10 = "REG_RESOURCE_REQUIREMENTS_LIST"
    11 = "REG_QWORD"
}
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
    "Action Groups"         = "ActionGroups"
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
    "Action Groups"         = "IdActionGroup"
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
$tableVUEMAdminPermissions = @{
    "FullAccess"                    = "Full Access"
    "ReadOnly"                      = "Read Only"
    "ActionsCreator"                = "Actions Creator"
    "ActionsManager"                = "Actions Manager"
    "FiltersManager"                = "Filters Manager"
    "AssigmentsManager"             = "Assigments Manager"
    "SystemUtilitiesManager"        = "System Utilities Manager"
    "SystemMonitoringManager"       = "System Monitoring Manager"
    "PoliciesAndProfilesManager"    = "Policies and Profiles Manager"
    "ConfiguredUserManager"         = "Configured User Manager"
    "TransformerManager"            = "Transformer Manager"
    "AdvancedSettingsManager"       = "Advanced Settings Manager"
    "SecurityManager"               = "Security Manager"
    "Full Access"                   = "FullAccess"
    "Read Only"                     = "ReadOnly"
    "Actions Creator"               = "ActionsCreator"
    "Actions Manager"               = "ActionsManager"
    "Filters Manager"               = "FiltersManager"
    "Assigments Manager"            = "AssigmentsManager"
    "System Utilities Manager"      = "SystemUtilitiesManager"
    "System Monitoring Manager"     = "SystemMonitoringManager"
    "Policies and Profiles Manager" = "PoliciesAndProfilesManager"
    "Configured User Manager"       = "ConfiguredUserManager"
    "Transformer Manager"           = "TransformerManager"
    "Advanced Settings Manager"     = "AdvancedSettingsManager"
    "Security Manager"              = "SecurityManager"
}
$tableVUEMAppLockerChangeLogType = @{
    "1.0" = "Exe - File"
    "1.1" = "Exe - Publisher"
    "1.2" = "Exe - Hash"
    "2.0" = "Msi - File"
    "2.1" = "Msi - Publisher"
    "2.2" = "Msi - Hash"
    "3.0" = "Scripts - File"
    "3.1" = "Scripts - Publisher"
    "3.2" = "Scripts - Hash"
    "4.1" = "Appx - Publisher"
    "5.0" = "Dll - File"
    "5.1" = "Dll - Publisher"
    "5.2" = "Dll - Hash"
}
$tableVUEMAppLockerCollectionType = @{
    1 = "Executable"
    2 = "Windows Installer"
    3 = "Scripts"
    4 = "Packaged"
    5 = "DLL"
    "Executable" = 1
    "Windows Installer" = 2
    "Scripts" = 3
    "Packaged" = 4
    "DLL" = 5
}
$tableVUEMAppLockerRuleType = @{
    0 = "PathCondition"
    1 = "PublisherCondition"
    2 = "HashCondition"
    "PathCondition" = 0
    "PublisherCondition" = 1
    "HashCondition" = 2
}
$tableVUEMAppLockerRulePermission = @{
    0 = "Allow"
    1 = "Deny"
    "Allow" = 0
    "Deny" = 1
}

$databaseVersion = ""
$databaseSchema  = ""

## .pol parser code from https://github.com/PowerShell/GPRegistryPolicyParser

###########################################################
#
#  Group Policy - Registry Policy parser module
#
#  Copyright (c) Microsoft Corporation, 2016
#
###########################################################

data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData @'
    InvalidHeader = File '{0}' has an invalid header.
    InvalidVersion = File '{0}' has an invalid version. It should be 1.
    InvalidFormatBracket = File '{0}' has an invalid format. A [ or ] was expected at location {1}.
    InvalidFormatSemicolon = File '{0}' has an invalid format. A ; was expected at location {1}.
    OnlyCreatingKey = Some values are null. Only the registry key is created.
    InvalidPath = Path {0} doesn't point to an existing registry key/property.
    InternalError = Internal error while creating a registry entry for {0}
    InvalidIntegerSize = Invalid size for an integer. Must be less than or equal to 8.
'@
}

$script:REGFILE_SIGNATURE = 0x67655250 # PRef
$script:REGISTRY_FILE_VERSION = 0x00000001 #Initially defined as 1, then incremented each time the file format is changed.

$script:DefaultEntries = @(
    "Software\Policies"
)

Enum RegType {
    REG_NONE                       = 0	# No value type
    REG_SZ                         = 1	# Unicode null terminated string
    REG_EXPAND_SZ                  = 2	# Unicode null terminated string (with environmental variable references)
    REG_BINARY                     = 3	# Free form binary
    REG_DWORD                      = 4	# 32-bit number
    REG_DWORD_LITTLE_ENDIAN        = 4	# 32-bit number (same as REG_DWORD)
    REG_DWORD_BIG_ENDIAN           = 5	# 32-bit number
    REG_LINK                       = 6	# Symbolic link (Unicode)
    REG_MULTI_SZ                   = 7	# Multiple Unicode strings, delimited by \0, terminated by \0\0
    REG_RESOURCE_LIST              = 8  # Resource list in resource map
    REG_FULL_RESOURCE_DESCRIPTOR   = 9  # Resource list in hardware description
    REG_RESOURCE_REQUIREMENTS_LIST = 10
    REG_QWORD                      = 11 # 64-bit number
    REG_QWORD_LITTLE_ENDIAN        = 11 # 64-bit number (same as REG_QWORD)
}

Class GPRegistryPolicy
{
    [string]  $KeyName
    [string]  $ValueName
    [RegType] $ValueType
    [string]  $ValueLength
    [object]  $ValueData

    GPRegistryPolicy()
    {
        $this.KeyName     = $Null
        $this.ValueName   = $Null
        $this.ValueType   = [RegType]::REG_NONE
        $this.ValueLength = 0
        $this.ValueData   = $Null
    }

    GPRegistryPolicy(
            [string]  $KeyName,
            [string]  $ValueName,
            [RegType] $ValueType,
            [string]  $ValueLength,
            [object]  $ValueData
        )
    {
        $this.KeyName     = $KeyName
        $this.ValueName   = $ValueName
        $this.ValueType   = $ValueType
        $this.ValueLength = $ValueLength
        $this.ValueData   = $ValueData
    }

    [string] GetRegTypeString()
    {
        [string] $Result = ""

        switch ($this.ValueType)
        {
            ([RegType]::REG_SZ)        { $Result = "String" }
            ([RegType]::REG_EXPAND_SZ) { $Result = "ExpandString" }
            ([RegType]::REG_BINARY)    { $Result = "Binary" }
            ([RegType]::REG_DWORD)     { $Result = "DWord" }
            ([RegType]::REG_MULTI_SZ)  { $Result = "MultiString" }
            ([RegType]::REG_QWORD)     { $Result = "QWord" }
            default                    { $Result = "" }
        }

        return $Result
    }

    static [RegType] GetRegTypeFromString( [string] $Type )
    {
        $Result = [RegType]::REG_NONE

        switch ($Type)
        {
            "String"       { $Result = [RegType]::REG_SZ }
            "ExpandString" { $Result = [RegType]::REG_EXPAND_SZ }
            "Binary"       { $Result = [RegType]::REG_BINARY }
            "DWord"        { $Result = [RegType]::REG_DWORD }
            "MultiString"  { $Result = [RegType]::REG_MULTI_SZ }
            "QWord"        { $Result = [RegType]::REG_QWORD }
            default        { $Result = [RegType]::REG_NONE }
        }

        return $Result
    }
}

Function New-GPRegistryPolicy
{
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $keyName,
        
        [Parameter(Position=1)]
        [string]
        $valueName = $null,
        
        [Parameter(Position=2)]
        [RegType]
        $valueType = [RegType]::REG_NONE,
        
        [Parameter(Position=3)]
        [string]
        $valueLength = $null,
        
        [Parameter(Position=4)]
        [object]
        $valueData = $null
        )

    $Policy = [GPRegistryPolicy]::new($keyName, $valueName, $valueType, $valueLength, $valueData)

    return $Policy;
}

Function Get-RegType
{
    param (
		[Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Type
    )

    return [GPRegistryPolicy]::GetRegTypeFromString($Type)
}

<# 
.SYNOPSIS
Reads and parses a .pol file.

.DESCRIPTION
Reads a .pol file, parses it and returns an array of Group Policy registry settings.

.PARAMETER Path
Specifies the path to the .pol file.

.EXAMPLE
C:\PS> Parse-PolFile -Path "C:\Registry.pol"
#>
Function Parse-PolFile
{
    [OutputType([Array])]
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]
        $Path
    )

    [Array] $RegistryPolicies = @()
    $index = 0

    [string] $policyContents = Get-Content $Path -Raw
    [byte[]] $policyContentInBytes = Get-Content $Path -Raw -Encoding Byte

    # 4 bytes are the signature PReg
    $signature = [System.Text.Encoding]::ASCII.GetString($policyContents[0..3])
    $index += 4
    Assert ($signature -eq 'PReg') ($LocalizedData.InvalidHeader -f $Path)

    # 4 bytes are the version
    $version = [System.BitConverter]::ToInt32($policyContentInBytes, 4)
    $index += 4
    Assert ($version -eq 1) ($LocalizedData.InvalidVersion -f $Path)

    # Start processing at byte 8
    while($index -lt $policyContents.Length - 2)
    {
        [string]$keyName = $null
        [string]$valueName = $null
        [int]$valueType = $null
        [int]$valueLength = $null

        [object]$value = $null

        # Next UNICODE character should be a [
        $leftbracket = [System.BitConverter]::ToChar($policyContentInBytes, $index)
        Assert ($leftbracket -eq '[') "Missing the openning bracket"
        $index+=2

        # Next UNICODE string will continue until the ; less the null terminator
        $semicolon = $policyContents.IndexOf(";", $index)
        Assert ($semicolon -ge 0) "Failed to locate the semicolon after key name."
        $keyName = [System.Text.Encoding]::UNICODE.GetString($policyContents[($index)..($semicolon-3)]) # -3 to exclude the null termination and ';' characters
        $index = $semicolon + 2

        # Next UNICODE string will continue until the ; less the null terminator
        $semicolon = $policyContents.IndexOf(";", $index)
        Assert ($semicolon -ge 0) "Failed to locate the semicolon after value name."
        $valueName = [System.Text.Encoding]::UNICODE.GetString($policyContents[($index)..($semicolon-3)]) # -3 to exclude the null termination and ';' characters
        $index = $semicolon + 2

        # Next DWORD will continue until the ;
        $semicolon = $index + 4 # DWORD Size
        Assert ([System.BitConverter]::ToChar($policyContentInBytes, $semicolon) -eq ';') "Failed to locate the semicolon after value type."
        $valueType = [System.BitConverter]::ToInt32($policyContentInBytes, $index)
        $index=$semicolon + 2 # Skip ';'

        # Next DWORD will continue until the ;
        $semicolon = $index + 4 # DWORD Size
        Assert ([System.BitConverter]::ToChar($policyContentInBytes, $semicolon) -eq ';') "Failed to locate the semicolon after value length."
        $valueLength = Convert-StringToInt -ValueString $policyContentInBytes[$index..($index+3)]
        $index=$semicolon + 2 # Skip ';'

        if ($valueLength -gt 0)
        {
            # String types less the null terminator for REG_SZ and REG_EXPAND_SZ
            # REG_SZ: string type (ASCII)
            if($valueType -eq [RegType]::REG_SZ)
            {
                [string] $value = [System.Text.Encoding]::UNICODE.GetString($policyContents[($index)..($index+$valueLength-3)]) # -3 to exclude the null termination and ']' characters
                $index += $valueLength
            }

            # REG_EXPAND_SZ: string, includes %ENVVAR% (expanded by caller) (ASCII)
            if($valueType -eq [RegType]::REG_EXPAND_SZ)
            {
                [string] $value = [System.Text.Encoding]::UNICODE.GetString($policyContents[($index)..($index+$valueLength-3)]) # -3 to exclude the null termination and ']' characters
                $index += $valueLength
            }

            # For REG_MULTI_SZ leave the last null terminator
            # REG_MULTI_SZ: multiple strings, delimited by \0, terminated by \0\0 (ASCII)
            if($valueType -eq [RegType]::REG_MULTI_SZ)
            {
                [string] $value = [System.Text.Encoding]::UNICODE.GetString($policyContents[($index)..($index+$valueLength-3)])
                $index += $valueLength
            }

            # REG_BINARY: binary values
            if($valueType -eq [RegType]::REG_BINARY)
            {
                [byte[]] $value = $policyContentInBytes[($index)..($index+$valueLength-1)]
                $index += $valueLength
            }
        }

        # DWORD: (4 bytes) in little endian format
        if($valueType -eq [RegType]::REG_DWORD)
        {
            $value = Convert-StringToInt -ValueString $policyContentInBytes[$index..($index+3)]
            $index += 4
        }

        # QWORD: (8 bytes) in little endian format
        if($valueType -eq [RegType]::REG_QWORD)
        {
            $value = Convert-StringToInt -ValueString $policyContentInBytes[$index..($index+7)]
            $index += 8
        }

        # Next UNICODE character should be a ]
        $rightbracket = $policyContents.IndexOf("]", $index) # Skip over null data value if one exists
        Assert ($rightbracket -ge 0) "Missing the closing bracket."
        $index = $rightbracket + 2

        $entry = New-GPRegistryPolicy $keyName $valueName $valueType $valueLength $value

        $RegistryPolicies += $entry
    }

    return $RegistryPolicies
}

<# 
.SYNOPSIS
Reads registry policies from a list of entries.

.DESCRIPTION
Reads registry policies from a list of entries and returns an array of GPRegistryPolicies.

.PARAMETER Division
Specifies the division from which the registry entries will be read.

.EXAMPLE
C:\PS> Read-RegistryPolicies -Division "LocalMachine"

.EXAMPLE
C:\PS> Read-RegistryPolicies -Division "LocalMachine" -Entries @('Software\Policies\Microsoft\Windows', 'Software\Policies\Microsoft\WindowsFirewall')
#>
Function Read-RegistryPolicies
{
    [OutputType([Array])]
    param (

        [ValidateSet("LocalMachine", "CurrentUser", "Users")]
        [string]
        $Division = "LocalMachine",
		
        [string[]]
        $Entries = $script:DefaultEntries
    )

    [Array] $RegistryPolicies = @()

    switch ($Division) 
    { 
        'LocalMachine' { $Hive = [Microsoft.Win32.Registry]::LocalMachine } 
        'CurrentUser'  { $Hive = [Microsoft.Win32.Registry]::CurrentUser } 
        'Users'        { $Hive = [Microsoft.Win32.Registry]::Users } 
    }

    foreach ($entry in $Entries)
    {
        #if (Test-Path -Path $entry)
        if (IsRegistryKey -Path $entry -Hive $Hive)
        {
            # $entry is a key.
            $Key = $Hive.OpenSubKey($entry)

            # Add the key itself
            $rp = New-GPRegistryPolicy -keyName $entry
            $RegistryPolicies += $rp

            # Check default value
            if ($Key.GetValue(''))
            {
                $info = Get-RegKeyInfo -RegKey $Key -ValueName ''
                $rp = New-GPRegistryPolicy -keyName $entry -valueName '' -valueType $info.Type -valueLength $info.Size -valueData $info.Data
                $RegistryPolicies += $rp
            }
            
            if ($Key.ValueCount -gt 0)
            {
                # Copy values under the key
                $ValueNames = $Key.GetValueNames()
                foreach($value in $ValueNames)
                {
                    if ([System.String]::IsNullOrEmpty($value))
                    {
                        $rp = New-GPRegistryPolicy -keyName $entry
                    }
                    else
                    {
                        $info = Get-RegKeyInfo -RegKey $Key -ValueName $value
                        $rp = New-GPRegistryPolicy -keyName $entry -valueName $value -valueType $info.Type -valueLength $info.Size -valueData $info.Data
                    }
                    $RegistryPolicies += $rp
                }
            }

            if ($Key.SubKeyCount -gt 0)
            {
                # Copy subkeys recursively
                $SubKeyNames = $Key.GetSubKeyNames()
                $newEntries = @()

                foreach($subkey in $SubKeyNames)
                {
                    $newEntry = Join-Path -Path $entry -ChildPath $subkey
                    $newEntries += ,$newEntry
                }

                $RegistryPolicies += Read-RegistryPolicies -Entries $newEntries -Division $Division
            }
        }
        else
        {
            $Tokens = $entry.Split('\')
            $Property = $Tokens[-1]
            $ParentKey = $Tokens[0..($Tokens.Count-2)] -join '\'
            $NoSuchKeyOrProperty = $false
        
            if (IsRegistryKey -Path $ParentKey -Hive $Hive)
            {
                # $entry is a property.
                # [key;value;type;size;data]
        
                $Key = $Hive.OpenSubKey($ParentKey)

                if ($Key.GetValueNames() -icontains $Property)
                {
                    $info = Get-RegKeyInfo -RegKey $Key -ValueName $Property
                    $rp = [GPRegistryPolicy]::new($ParentKey, $Property, $info.Type, $info.Size, $info.Data)
                    $RegistryPolicies += $rp
                }
                else
                {
                    $NoSuchKeyOrProperty = $true
                }
            }
            else
            {
                $NoSuchKeyOrProperty = $true
            }

            if ( $NoSuchKeyOrProperty -and @('Continue', 'SilentlyContinue', 'Ignore' ) -inotcontains $ErrorActionPreference)
            {
                # $entry points to a key/property that doesn't exist.
                $NoSuchKeyOrProperty = $true
                Fail -ErrorMessage ($LocalizedData.InvalidPath -f $entry)
            }
        }
    }

    return $RegistryPolicies
}

Function Assert
{
    param (
        [Parameter(Mandatory)]
        $Condition,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ErrorMessage
    )

    if (!$Condition) 
    {
        Fail -ErrorMessage $ErrorMessage;
    }
}

Function Fail
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ErrorMessage
    )
  
    throw $ErrorMessage
}

<# 
.SYNOPSIS
Returns the type, size and data values of a given registry key.

.DESCRIPTION
Returns the type, size and data values of a given registry key.

.PARAMETER RegKey
Registry Key

.PARAMETER ValueName
The name of the Value under the given registry key
#>
Function Get-RegKeyInfo
{
    param (
		[Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryKey]
        $RegKey,

		[Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $ValueName

    )

    switch ($RegKey.GetValueKind($ValueName))
    {
        "String"       {
            $Type = $RegKey.GetValueKind($ValueName)
            $Data = $RegKey.GetValue($ValueName)
            $Size = $Data.Length
        }

        "ExpandString"       {
            $Type = $RegKey.GetValueKind($ValueName)
            $Data = $RegKey.GetValue($ValueName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $Size = $Data.Length
        }

        "Binary"       {
            $Type = $RegKey.GetValueKind($ValueName)
            $value = $RegKey.GetValue($ValueName)
            $Data = [System.Text.Encoding]::Unicode.GetString($value)
            $Size = $Data.Count
        }

        "DWord"        {
            $Type = $RegKey.GetValueKind($ValueName)
            $Data = $RegKey.GetValue($ValueName)
            $Size = 4
        }

        "MultiString"  {
            $Type = $RegKey.GetValueKind($ValueName)
            $Data = ($RegKey.GetValue($ValueName) -join "`0") + "`0"
            $Size = $Data.Length
        }

        "QWord"        {
            $Type = $RegKey.GetValueKind($ValueName)
            $Data = $RegKey.GetValue($ValueName)
            $Size = 8
        }

        default        {
            $Type = $null
            $Data = $null
            $Size = 0
        }
    }

    return @{
        'Type' = $Type;
        'Size' = $Size;
        'Data' = $Data;
    }
}

Function IsRegistryKey
{
    param (
		[Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Microsoft.Win32.RegistryKey]
        $Hive = [Microsoft.Win32.Registry]::LocalMachine
    )

    $key = $Hive.OpenSubKey($Path)

    if ($key)
    {
        if ($PSVersionTable.PSEdition -ieq 'Core')
        {
            $key.Flush()
            $key.Dispose()
        }
        else
        {
            $key.Close()
        }
        return $true
    }
    else
    {
        return $false
    }
}

Function Convert-StringToInt
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Object[]]
        $ValueString
    )
  
    if ($ValueString.Length -le 4)
    {
        [int32] $result = 0
    }
    elseif ($ValueString.Length -le 8)
    {
        [int64] $result = 0
    }
    else
    {
        Fail -ErrorMessage $LocalizedData.InvalidIntegerSize
    }

    for ($i = $ValueString.Length - 1 ; $i -ge 0 ; $i -= 1)
    {
        $result = $result -shl 8
        $result = $result + ([int][char]$ValueString[$i])
    }

    return $result
}

#endregion