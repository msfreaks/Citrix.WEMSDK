<#
    .Synopsis
    Create a new Assignment object in the WEM Database.

    .Description
    Create a new Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,
        [Parameter(Mandatory=$False)][ValidateSet("Registry Value","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association")]
        [string]$AssignmentType,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # check uniqueness
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssigned$($tableVUEMActionCategory[$AssignmentType]) WHERE IdSite = $($IdSite) AND $($tableVUEMActionCategoryId[$AssignmentType]) = $($IdAction) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already an Assignment object for this combination of Action, ADObject and Rule in the Configuration"
            Break
        }

        Write-Verbose "Assignment is unique: Continue"

        # build the query to create the assignment
        $SQLQuery = "INSERT INTO VUEMAssigned$($tableVUEMActionCategory[$AssignmentType]) (IdSite,$($tableVUEMActionCategoryId[$AssignmentType]),IdItem,IdFilterRule,RevisionId) VALUES ($($IdSite),$($IdAction),$($IdADObject),$($IdRule),1)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new assignment
        $SQLQuery = "SELECT $($tableVUEMActionCategoryId[$AssignmentType].Replace("Id", "IdAssigned")) AS IdAssignment,* FROM VUEMAssigned$($tableVUEMActionCategory[$AssignmentType]) WHERE IdSite = $($IdSite) AND $($tableVUEMActionCategoryId[$AssignmentType]) = $($IdAction) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        $Assignment = Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType

        # Updating the ChangeLog (use ID for the assignment, not the action!)
        $IdObject = $result.Tables.Rows.IdAssignment
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Assign" -ObjectName $Assignment.ToString() -ObjectType "Assignments\$($AssignmentType)" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return $Assignment
    }
}

<#
    .Synopsis
    Create a new Registry Entry Assignment object in the WEM Database.

    .Description
    Create a new Registry Entry Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMRegistryEntryAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "Registry Value"

        return New-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAction $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name New-WEMRegValueAssignment -Value New-WEMRegistryEntryAssignment

<#
    .Synopsis
    Create a new Environment Variable Assignment object in the WEM Database.

    .Description
    Create a new Environment Variable Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMEnvironmentVariableAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "Environment Variable"

        return New-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAction $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name New-WEMEnvVariableAssignment -Value New-WEMEnvironmentVariableAssignment

<#
    .Synopsis
    Create a new Port Assignment object in the WEM Database.

    .Description
    Create a new Port Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMPortAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "Port"

        return New-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAction $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}

<#
    .Synopsis
    Create a new Ini File Operation Assignment object in the WEM Database.

    .Description
    Create a new Ini File Operation Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMIniFileOperationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "Ini File Operation"

        return New-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAction $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name New-WEMIniFilesOpAssignment -Value New-WEMIniFileOperationAssignment

<#
    .Synopsis
    Create a new External Task Assignment object in the WEM Database.

    .Description
    Create a new External Task Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMExternalTaskAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "External Task"

        return New-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAction $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name New-WEMExtTaskAssignment -Value New-WEMExternalTaskAssignment

<#
    .Synopsis
    Create a new File System Operation Assignment object in the WEM Database.

    .Description
    Create a new File System Operation Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMFileSystemOperationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "File System Operation"

        return New-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAction $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name New-WEMFileSystemOpAssignment -Value New-WEMFileSystemOperationAssignment

<#
    .Synopsis
    Create a new User DSN Assignment object in the WEM Database.

    .Description
    Create a new User DSN Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMUserDSNAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "User DSN"

        return New-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAction $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}

<#
    .Synopsis
    Create a new File Association Assignment object in the WEM Database.

    .Description
    Create a new File Association Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMFileAssociationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "File Association"

        return New-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAction $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name New-WEMFileAssocAssignment -Value New-WEMFileAssociationAssignment
