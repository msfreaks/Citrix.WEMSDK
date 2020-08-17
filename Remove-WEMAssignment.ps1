<#
    .Synopsis
    Removes a Assignment object from the WEM Database.

    .Description
    Removes a Assignment object from the WEM Database.

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
    Author: Arjan Mensch
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
    Removes a Action Group Assignment object from the WEM Database.

    .Description
    Removes a Action Group Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
    Removes a Application Assignment object from the WEM Database.

    .Description
    Removes a Application Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
    Removes a Printer Assignment object from the WEM Database.

    .Description
    Removes a Printer Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
    Removes a Network Drive Assignment object from the WEM Database.

    .Description
    Removes a Network Drive Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
    Removes a Virtual Drive Assignment object from the WEM Database.

    .Description
    Removes a Virtual Drive Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
    Removes a Registry Entry Assignment object from the WEM Database.

    .Description
    Removes a Registry Entry Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
    Removes a Environment Variable Assignment object from the WEM Database.

    .Description
    Removes a Environment Variable Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
    Removes a Port Assignment object from the WEM Database.

    .Description
    Removes a Port Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
    Removes a Group Policy Settings Assignment object from the WEM Database.

    .Description
    Removes a Group Policy Settings Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Remove-WEMGroupPolicyObjectAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # grab original object
        $origObject = Get-WEMGroupPolicyObjectAssignment -Connection $Connection -IdAssignment $IdAssignment

        # only continue if the object was found
        if (-not $origObject) { 
            Write-Warning "No Group Policy Settings Assignment Object found for Id $($IdAssignment)"
            Break
        }

        # build query
        $SQLQuery = "DELETE FROM GroupPolicyAssignments WHERE IdAssignment = $($origObject.IdAssignment)"
        write-verbose $SQLQuery
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdAssignment -ChangeType "Unassign" -ObjectName "$($origObject.AssignedObject.ToString()) ($($origObject.AssignedObject.Guid.ToString().ToLower()))" -ObjectType "Assignments\Group Policy" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        #>
    }
}

<#
    .Synopsis
    Removes a Ini File Operation Assignment object from the WEM Database.

    .Description
    Removes a Ini File Operation Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

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
    Removes a External Task Assignment object from the WEM Database.

    .Description
    Removes a External Task Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
    Removes a File System Operation Assignment object from the WEM Database.

    .Description
    Removes a File System Operation Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
    Removes a User DSN Assignment object from the WEM Database.

    .Description
    Removes a User DSN Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
    Removes a File Association Assignment object from the WEM Database.

    .Description
    Removes a File Association Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
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
