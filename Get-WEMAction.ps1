<#
    .Synopsis
    Returns one or more WEM Action objects from the WEM Database.

    .Description
    Returns one or more WEM Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMAction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)][ValidateSet("Application","Printer","Network Drive","Virtual Drive","Registry Entry","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association")]
        [string]$Category,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # if a single category was specified, process only that type. if not, process all categories
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'category')) {
            Write-Verbose "Limiting result to category '$($Category)'"
            $vuemActionCategories = @("$($Category)")
        } else {
            $vuemActionCategories = @("Application","Printer","Network Drive","Virtual Drive","Registry Entry","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association")
        }

        # create empty Action array
        $vuemActions = @()
        foreach ($vuemActionCategory in $vuemActionCategories) {
            Write-Verbose "Processing category '$vuemActionCategory'"
            $vuemActions += Get-WEMActionsByCategory -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category $vuemActionCategory
        }

        Return $vuemActions
    }
}

<#
    .Synopsis
    Helper function that returns one or more WEM Action objects from the WEM Database.

    .Description
    Helper function that returns one or more WEM Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
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
function Get-WEMActionsByCategory {
    param(
        [int]$IdSite = $null,
        [int]$IdAction = $null,
        [string]$Name = $null,
        [string]$Category,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    # build query
    $SQLQuery = "SELECT * FROM VUEM$($tableVUEMActionCategory[$Category])"
    if ($IdSite -or $Name -or $IdAction) {
        $SQLQuery += " WHERE "
        if ($IdSite) { 
            $SQLQuery += "IdSite = $($IdSite)"
            if ($Name -or $IdAction) { $SQLQuery += " AND " }
        }
        if ($IdAction) { 
            $SQLQuery += "$($tableVUEMActionCategoryId[$Category]) = $($IdAction)"
            if ($Name) { $SQLQuery += " AND " }
        }
        if ($Name) { $SQLQuery += "Name LIKE '$($Name.Replace("*","%"))'"}
    }
    $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

    # build array of VUEMActions returned by the query
    $vuemActions = @()
    if ($Category -like "application")           { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMApplicationObject -DataRow $row } }
    if ($Category -like "printer")               { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMPrinterObject -DataRow $row } }
    if ($Category -like "network drive")         { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMNetDriveObject -DataRow $row } }
    if ($Category -like "virtual drive")         { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMVirtualDriveObject -DataRow $row } }
    if ($Category -like "registry entry")        { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMRegValueObject -DataRow $row } }
    if ($Category -like "environment variable")  { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMEnvVariableObject -DataRow $row } }
    if ($Category -like "port")                  { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMPortObject -DataRow $row } }
    if ($Category -like "ini file operation")    { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMIniFileOpObject -DataRow $row } }
    if ($Category -like "external task")         { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMExtTaskObject -DataRow $row } }
    if ($Category -like "file system operation") { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMFileSystemOpObject -DataRow $row } }
    if ($Category -like "user dsn")              { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMUserDSNObject -DataRow $row } }
    if ($Category -like "file association")      { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMFileAssocObject -DataRow $row } }

    return $vuemActions
}

<#
    .Synopsis
    Returns one or more WEM Application Action objects from the WEM Database based on Category.

    .Description
    Returns one or more WEM Application Action objects from the WEM Database based on Category.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMApplication {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "Application"

    }    
}
New-Alias -Name Get-WEMApp -Value Get-WEMApplication

<#
    .Synopsis
    Returns one or more WEM Printer Action objects from the WEM Database.

    .Description
    Returns one or more WEM Printer Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMPrinter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "Printer"
    }    
}

<#
    .Synopsis
    Returns one or more WEM Network Drive Action objects from the WEM Database.

    .Description
    Returns one or more WEM Network Drive Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMNetworkDrive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "Network Drive"
    }    
}
New-Alias -Name Get-WEMNetDrive -Value Get-WEMNetworkDrive

<#
    .Synopsis
    Returns one or more WEM Virtual Drive Action objects from the WEM Database.

    .Description
    Returns one or more WEM Virtual Drive Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMVirtualDrive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "Virtual Drive"
    }    
}

<#
    .Synopsis
    Returns one or more WEM Registry Entry Action objects from the WEM Database.

    .Description
    Returns one or more WEM Registry Entry Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMRegistryEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "Registry Entry"
    }    
}
New-Alias -Name Get-WEMRegValue -Value Get-WEMRegistryEntry

<#
    .Synopsis
    Returns one or more WEM Environment Variable Action objects from the WEM Database.

    .Description
    Returns one or more WEM Environment Variable Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMEnvironmentVariable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "Environment Variable"
    }    
}
New-Alias -Name Get-WEMEnvVariable -Value Get-WEMEnvironmentVariable

<#
    .Synopsis
    Returns one or more WEM Port Action objects from the WEM Database.

    .Description
    Returns one or more WEM Port Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMPort {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "Port"
    }    
}

<#
    .Synopsis
    Returns one or more WEM Ini File Operation Action objects from the WEM Database.

    .Description
    Returns one or more WEM Ini File Operation Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMIniFileOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "Ini File Operation"
    }    
}
New-Alias -Name Get-WEMIniFilesOp -Value Get-WEMIniFileOperation

<#
    .Synopsis
    Returns one or more WEM External Task Action objects from the WEM Database.

    .Description
    Returns one or more WEM External Task Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMExternalTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "External Task"
    }    
}
New-Alias -Name Get-WEMExtTask -Value Get-WEMExternalTask

<#
    .Synopsis
    Returns one or more WEM File System Operation Action objects from the WEM Database.

    .Description
    Returns one or more WEM File System Operation Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMFileSystemOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "File System Operation"
    }    
}
New-Alias -Name Get-WEMFileSystemOp -Value Get-WEMFileSystemOperation

<#
    .Synopsis
    Returns one or more WEM User DSN Action objects from the WEM Database.

    .Description
    Returns one or more WEM User DSN Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMUserDSN {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "User DSN"
    }    
}

<#
    .Synopsis
    Returns one or more WEM File Association Action objects from the WEM Database.

    .Description
    Returns one or more WEM File Association Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMFileAssociation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        Get-WEMAction -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category "File Association"
    }    
}
New-Alias -Name Get-WEMFileAssoc -Value Get-WEMFileAssociation
