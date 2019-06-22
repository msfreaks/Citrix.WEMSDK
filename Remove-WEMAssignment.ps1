<#
    .Synopsis
    Removes a WEM Assignment object from the WEM Database.

    .Description
    Removes a WEM Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
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
function Remove-WEMAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)][ValidateSet("Application","Printer","Network Drive","Virtual Drive","Registry Value","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association","Action Groups")]
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
            Write-Warning "No Assignment Object found for Id $($IdAssignment) of type $($AssignmentType)"
            Break
        }

        # build query
        $SQLQuery = "DELETE FROM VUEMAssigned$($tableVUEMActionCategory[$AssignmentType]) WHERE $($tableVUEMActionCategoryId[$AssignmentType]) = $($origObject.IdAssignedObject) AND IdItem = $($origObject.ADObject.IdADObject)"
        write-verbose $SQLQuery
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdAssignment -ChangeType "Unassign" -ObjectName $origObject.ToString() -ObjectType "Assignments\$($AssignmentType)" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        #>
    }
}

<#
    .Synopsis
    Removes a WEM Action Group Assignment object from the WEM Database.

    .Description
    Removes a WEM Action Group Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMActionGroupAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Action Groups"
    }
}

<#
    .Synopsis
    Removes a WEM Application Assignment object from the WEM Database.

    .Description
    Removes a WEM Application Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMApplicationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Application"
    }
}
New-Alias -Name Remove-WEMAppAssignment -Value Remove-WEMApplicationAssignment

<#
    .Synopsis
    Removes a WEM Printer Assignment object from the WEM Database.

    .Description
    Removes a WEM Printer Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMPrinterAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Printer"
    }
}

<#
    .Synopsis
    Removes a WEM Network Drive Assignment object from the WEM Database.

    .Description
    Removes a WEM Network Drive Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMNetworkDriveAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Network Drive"
    }
}
New-Alias -Name Remove-WEMNetDriveAssignment -Value Remove-WEMNetworkDriveAssignment

<#
    .Synopsis
    Removes a WEM Virtual Drive Assignment object from the WEM Database.

    .Description
    Removes a WEM Virtual Drive Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMVirtualDriveAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Virtual Drive"
    }
}

<#
    .Synopsis
    Removes a WEM Registry Entry Assignment object from the WEM Database.

    .Description
    Removes a WEM Registry Entry Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMRegistryEntryAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Registry Value"
    }
}
New-Alias -Name Remove-WEMRegValueAssignment -Value Remove-WEMRegistryEntryAssignment

<#
    .Synopsis
    Removes a WEM Environment Variable Assignment object from the WEM Database.

    .Description
    Removes a WEM Environment Variable Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMEnvironmentVariableAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Environment Variable"
    }
}
New-Alias -Name Remove-WEMEnvVariableAssignment -Value Remove-WEMEnvironmentVariableAssignment

<#
    .Synopsis
    Removes a WEM Port Assignment object from the WEM Database.

    .Description
    Removes a WEM Port Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMPortAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Port"
    }
}

<#
    .Synopsis
    Removes a WEM Ini File Operation Assignment object from the WEM Database.

    .Description
    Removes a WEM Ini File Operation Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMIniFileOperationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Ini File Operation"
    }
}
New-Alias -Name Remove-WEMIniFilesOpAssignment -Value Remove-WEMIniFileOperationAssignment

<#
    .Synopsis
    Removes a WEM External Task Assignment object from the WEM Database.

    .Description
    Removes a WEM External Task Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMExternalTaskAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "External Task"
    }
}
New-Alias -Name Remove-WEMExtTaskAssignment -Value Remove-WEMExternalTaskAssignment

<#
    .Synopsis
    Removes a WEM File System Operation Assignment object from the WEM Database.

    .Description
    Removes a WEM File System Operation Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMFileSystemOperationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "File System Operation"
    }
}
New-Alias -Name Remove-WEMFileSystemOpAssignment -Value Remove-WEMFileSystemOperationAssignment

<#
    .Synopsis
    Removes a WEM User DSN Assignment object from the WEM Database.

    .Description
    Removes a WEM User DSN Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMUserDSNAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "User DSN"
    }
}

<#
    .Synopsis
    Removes a WEM File Association Assignment object from the WEM Database.

    .Description
    Removes a WEM File Association Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMFileAssociationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "File Association"
    }
}
New-Alias -Name Remove-WEMFileAssocAssignment -Value Remove-WEMFileAssociationAssignment
