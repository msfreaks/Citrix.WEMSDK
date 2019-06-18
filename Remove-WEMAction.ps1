<#
    .Synopsis
    Removes a WEM Action object from the WEM Database.

    .Description
    Removes a WEM Action object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Category
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMAction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [string]$Category,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original action
        $origAction = Get-WEMAction -Connection $Connection -IdAction $IdAction -Category $Category

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No action found for Id $($IdAction)"
            Break
        }
        
        # build query
        $SQLQuery = "DELETE FROM VUEM$($tableVUEMActionCategory[$origAction.Category]) WHERE $($tableVUEMActionCategoryId[$origAction.Category]) = $($IdAction)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdAction -ChangeType "Delete" -ObjectName $origAction.Name -ObjectType "Actions\$($origAction.Category)" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}

<#
    .Synopsis
    Removes a WEM Application object from the WEM Database.

    .Description
    Removes a WEM Application object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMApplication {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "Application"
    }
}
New-Alias -Name Remove-WEMApp -Value Remove-WEMApplication

<#
    .Synopsis
    Removes a WEM Printer object from the WEM Database.

    .Description
    Removes a WEM Printer object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMPrinter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "Printer"
    }
}

<#
    .Synopsis
    Removes a WEM Network Drive object from the WEM Database.

    .Description
    Removes a WEM Network Drive object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMNetworkDrive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "Network Drive"
    }
}
New-Alias -Name Remove-WEMNetDrive -Value Remove-WEMNetworkDrive

<#
    .Synopsis
    Removes a WEM Virtual Drive object from the WEM Database.

    .Description
    Removes a WEM Virtual Drive object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMVirtualDrive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "Virtual Drive"
    }
}

<#
    .Synopsis
    Removes a WEM Registry Entry object from the WEM Database.

    .Description
    Removes a WEM Registry Entry object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMRegistryEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "Registry Value"
    }
}
New-Alias -Name Remove-WEMRegValue -Value Remove-WEMRegistryEntry

<#
    .Synopsis
    Removes a WEM Environmental Variable object from the WEM Database.

    .Description
    Removes a WEM Environmental Variable object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMEnvironmentVariable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "Environment Variable"
    }
}
New-Alias -Name Remove-WEMEnvVariable -Value Remove-WEMEnvironmentVariable

<#
    .Synopsis
    Removes a WEM Port object from the WEM Database.

    .Description
    Removes a WEM Port object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMPort {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "Port"
    }
}

<#
    .Synopsis
    Removes a WEM Ini File Operation object from the WEM Database.

    .Description
    Removes a WEM Ini File Operation object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMIniFileOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "Ini File Operation"
    }
}
New-Alias -Name Remove-WEMIniFilesOp -Value Remove-WEMIniFileOperation

<#
    .Synopsis
    Removes a WEM External Task object from the WEM Database.

    .Description
    Removes a WEM External Task object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMExternalTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "External Task"
    }
}
New-Alias -Name Remove-WEMExtTask -Value Remove-WEMExternalTask

<#
    .Synopsis
    Removes a WEM File System Operation object from the WEM Database.

    .Description
    Removes a WEM File System Operation object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMFileSystemOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "File System Operation"
    }
}
New-Alias -Name Remove-WEMFileSystemOp -Value Remove-WEMFileSystemOperation

<#
    .Synopsis
    Removes a WEM User DSN object from the WEM Database.

    .Description
    Removes a WEM User DSN object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMUserDSN {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "User DSN"
    }
}

<#
    .Synopsis
    Removes a WEM File Association object from the WEM Database.

    .Description
    Removes a WEM File Association object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMFileAssociation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Remove-WEMAction -Connection $Connection -IdAction $IdAction -Category "File Association"
    }
}
New-Alias -Name Remove-WEMFileAssoc -Value Remove-WEMFileAssociation


