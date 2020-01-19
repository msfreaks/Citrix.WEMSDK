<#
    .Synopsis
    Returns one or more Assignment objects from the WEM Database.

    .Description
    Returns one or more Assignment objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAssignment
    ..

    .Parameter AssignmentType
    ..

    .Parameter IdAssigntObject
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMAssignment {
    [CmdletBinding(DefaultParameterSetName="None")]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)][ValidateSet("Application","Printer","Network Drive","Virtual Drive","Registry Value","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association","Action Groups")]
        [string]$AssignmentType,
        [Parameter(Mandatory=$False)]
		[int]$IdAssignedObject,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # $MyInvocation.BoundParameters.Keys -match

        # if a single type was specified, process only that type. if not, process all types
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'assignmenttype')) {
            Write-Verbose "Limiting result to type '$($AssignmentType)'"
            $vuemAssignmentTypes = @("$($AssignmentType)")
        } else {
            $vuemAssignmentTypes = @("Application","Printer","Network Drive","Virtual Drive","Registry Value","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association","Action Groups")
        }

        # create empty object array
        $vuemAssignments = @()
        foreach ($vuemAssignmentType in $vuemAssignmentTypes) {
            Write-Verbose "Processing type '$vuemAssignmentType'"
            $vuemAssignments += Get-WEMAssignmentsByType -Connection $Connection -IdSite $IdSite -IdAssignment $IdAssignment -IdAssignedObject $IdAssignedObject -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $vuemAssignmentType
        }

        return $vuemAssignments
    }
}

<#
    .Synopsis
    Helper function that returns one or more Action objects from the WEM Database.

    .Description
    Helper function that returns one or more Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAssignment
    ..

    .Parameter AssignmentType
    ..

    .Parameter IdAssignedObject
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMAssignmentsByType {
    param(
        [int]$IdSite = $null,
        [int]$IdAssignment = $null,
        [string]$AssignmentType,
		[int]$IdAssignedObject = $null,
		[int]$IdADObject = $null,
		[int]$IdRule = $null,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    # build query
    $SQLQuery = "SELECT $($tableVUEMActionCategoryId[$AssignmentType].Replace("Id", "IdAssigned")) AS IdAssignment, $($tableVUEMActionCategoryId[$AssignmentType]) AS IdAssignedObject,* FROM VUEMAssigned$($tableVUEMActionCategory[$AssignmentType])"
    $SQLQueryFields = @()

    if ($IdSite) { $SQLQueryFields += "IdSite = $($IdSite)" }
    if ($IdAssignment) { $SQLQueryFields += "$($tableVUEMActionCategoryId[$AssignmentType].Replace("Id", "IdAssigned")) = $($IdAssignment)" }
    if ($IdAssignedObject) { $SQLQueryFields += "$($tableVUEMActionCategoryId[$AssignmentType]) = $($IdAssignedObject)" }
    if ($IdADObject) { $SQLQueryFields += "IdItem = $($IdADObject)" }
    if ($IdRule) { $SQLQueryFields += "IdFilterRule = $($IdRule)" }

    if ($SQLQueryFields) {
        $SQLQuery += " WHERE "
        $SQLQuery += $SQLQueryFields -Join " AND "
    }

    $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

    $vuemAssignments = @()
    foreach ($row in $result.Tables.Rows) { $vuemAssignments += New-VUEMAssignmentObject -DataRow $row -AssignmentType $AssignmentType -Connection $Connection }

    return $vuemAssignments
}

<#
    .Synopsis
    Returns one or more Action Group Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more Action Group Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdActionGroup
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMActionGroupAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdActionGroup,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdActionGroup -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "Action Groups"

    }    
}

<#
    .Synopsis
    Returns one or more Application Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more Application Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMApplicationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "Application"

    }    
}
New-Alias -Name Get-WEMAppAssignment -Value Get-WEMApplicationAssignment

<#
    .Synopsis
    Returns one or more Printer Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more Printer Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMPrinterAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "Printer"

    }    
}

<#
    .Synopsis
    Returns one or more Network Drive Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more Network Drive Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMNetworkDriveAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "Network Drive"

    }    
}
New-Alias -Name Get-WEMNetDriveAssignment -Value Get-WEMNetworkDriveAssignment

<#
    .Synopsis
    Returns one or more Virtual Drive Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more Virtual Drive Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMVirtualDriveAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "Virtual Drive"

    }    
}

<#
    .Synopsis
    Returns one or more Registry Entry Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more Registry Entry Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMRegistryEntryAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "Registry Value"

    }    
}
New-Alias -Name Get-WEMRegValueAssignment -Value Get-WEMRegistryEntryAssignment

<#
    .Synopsis
    Returns one or more Environment Variable Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more Environment Variable Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMEnvironmentVariableAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "Environment Variable"

    }    
}
New-Alias -Name Get-WEMEnvVariableAssignment -Value Get-WEMEnvironmentVariableAssignment

<#
    .Synopsis
    Returns one or more Port Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more Port Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMPortAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "Port"

    }    
}

<#
    .Synopsis
    Returns one or more Ini File Operation Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more Ini File Operation Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMIniFileOperationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "Ini File Operation"

    }    
}
New-Alias -Name Get-WEMIniFilesOpAssignment -Value Get-WEMIniFileOperationAssignment

<#
    .Synopsis
    Returns one or more External Task Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more External Task Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMExternalTaskAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "External Task"

    }    
}
New-Alias -Name Get-WEMExtTaskAssignment -Value Get-WEMExternalTaskAssignment

<#
    .Synopsis
    Returns one or more File System Operation Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more File System Operation Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMFileSystemOperationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "File System Operation"

    }    
}
New-Alias -Name Get-WEMFileSystemOpAssignment -Value Get-WEMFileSystemOperationAssignment

<#
    .Synopsis
    Returns one or more User DSN Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more User DSN Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMUserDSNAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "User DSN"

    }    
}

<#
    .Synopsis
    Returns one or more File Association Assignment objects from the WEM Database based on Category.

    .Description
    Returns one or more File Association Assignment objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMFileAssociationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
		[int]$IdAction,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAssignment -Connection $Connection -IdSite $IdSite -IdAssignedObject $IdAction -IdADObject $IdADObject -IdRule $IdRule -AssignmentType "File Association"

    }    
}
New-Alias -Name Get-WEMFileAssocAssignment -Value Get-WEMFileAssociationAssignment
