<#
    .Synopsis
    Updates a Assignment object in the WEM Database.

    .Description
    Updates a Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter AssignmentType
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        [Parameter(Mandatory=$False)][ValidateSet("Registry Value","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association","Action Groups")]
        [string]$AssignmentType,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origObject = Get-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType $AssignmentType

        # only continue if the object was found
        if (-not $origObject) { 
            Write-Warning "No $($AssignmentType) assignment found for Id $($IdAssignment)"
            Break
        }
        
        # find what needs to be changed
        $checkADObject = $null
        $checkRule = $null
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idadobject') -and $IdADObject -ne $origObject.ADObject.IdADobject) { $checkADObject = $IdADObject }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idrule') -and $IdRule -ne $origObject.Rule.IdRule) { $checkRule = $IdRule }

        # if a new ADObject or RuleObject for the object is entered, check if it's unique
        if ($checkADObject -or $checkRule) {
            $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssigned$($tableVUEMActionCategory[$AssignmentType]) WHERE IdSite = $($origObject.IdSite) AND $($tableVUEMActionCategoryId[$AssignmentType]) = $($origObject.IdAssignedObject)"
            if ($checkADObject) { $SQLQuery += " AND IdItem = $($checkADObject)" }
            if ($checkRule) { $SQLQuery += " AND IdFilterRule = $($checkRule)" }

            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.ObjectCount) {
                # name must be unique
                Write-Error "There's already another $($AssignmentType) assignment matching those Ids in the Configuration"
                Break
            }

            Write-Verbose "Assignment is unique: Continue"
        }

        # build the query to update the action
        $updateFields = @()
        if ($checkADObject -or $checkRule -or $checkProperties) {
            $SQLQuery = "UPDATE VUEMAssigned$($tableVUEMActionCategory[$AssignmentType]) SET "
            $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "idassignment" }
            foreach ($key in $keys) {
                switch ($key) {
                    "IdADObject" {
                        $updateFields += "IdItem = $($IdADObject)"
                        continue
                    }
                    "IdRule" {
                        $updateFields += "IdFilterRule = $($IdRule)"
                        continue
                    }
                    Default {}
                }
            }
        }
        
        # if anything needs to be updated, update the action
        if($updateFields) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            $SQLQuery += "RevisionId = $($origObject.Version + 1) WHERE $($tableVUEMActionCategoryId[$AssignmentType].Replace("Id", "IdAssigned")) = $($IdAssignment)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # grab the new assignment
            $SQLQuery = "SELECT $($tableVUEMActionCategoryId[$AssignmentType].Replace("Id", "IdAssigned")) AS IdAssignment,* FROM VUEMAssigned$($tableVUEMActionCategory[$AssignmentType]) WHERE $($tableVUEMActionCategoryId[$AssignmentType].Replace("Id", "IdAssigned")) = $($IdAssignment)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

            $Assignment = Get-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType $AssignmentType

            # Updating the ChangeLog (use ID for the assignment, not the action!)
            $IdObject = $result.Tables.Rows.IdAssignment
            New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdObject -ChangeType "Assign" -ObjectName $Assignment.ToString() -ObjectType "Assignments\$($AssignmentType)" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}

<#
    .Synopsis
    Updates a Registry Entry Assignment object in the WEM Database.

    .Description
    Updates a Registry Entry Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMRegistryEntryAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "Registry Value"

        return Set-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name Set-WEMRegValueAssignment -Value Set-WEMRegistryEntryAssignment

<#
    .Synopsis
    Updates a Environment Variable Assignment object in the WEM Database.

    .Description
    Updates a Environment Variable Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMEnvironmentVariableAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "Environment Variable"

        return Set-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name Set-WEMEnvVariableAssignment -Value Set-WEMEnvironmentVariableAssignment

<#
    .Synopsis
    Updates a Port Assignment object in the WEM Database.

    .Description
    Updates a Port Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMPortAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "Port"

        return Set-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}

<#
    .Synopsis
    Updates a Ini File Operation Assignment object in the WEM Database.

    .Description
    Updates a Ini File Operation Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMIniFileOperationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "Ini File Operation"

        return Set-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name Set-WEMIniFilesOpAssignment -Value Set-WEMIniFileOperationAssignment

<#
    .Synopsis
    Updates a External Task Assignment object in the WEM Database.

    .Description
    Updates a External Task Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMExternalTaskAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "External Task"

        return Set-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name Set-WEMExtTaskAssignment -Value Set-WEMExternalTaskAssignment

<#
    .Synopsis
    Updates a File System Operation Assignment object in the WEM Database.

    .Description
    Updates a File System Operation Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMFileSystemOperationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "File System Operation"

        return Set-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name Set-WEMFileSystemOpAssignment -Value Set-WEMFileSystemOperationAssignment

<#
    .Synopsis
    Updates a User DSN Assignment object in the WEM Database.

    .Description
    Updates a User DSN Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMUserDSNAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "User DSN"

        return Set-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}

<#
    .Synopsis
    Updates a File Association Assignment object in the WEM Database.

    .Description
    Updates a File Association Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMFileAssociationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "File Association"

        return Set-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name Set-WEMFileAssocAssignment -Value Set-WEMFileAssociationAssignment

<#
    .Synopsis
    Updates a Action Group Assignment object in the WEM Database.

    .Description
    Updates a Action Group Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMActionGroupAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "Action Groups"

        return Set-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
