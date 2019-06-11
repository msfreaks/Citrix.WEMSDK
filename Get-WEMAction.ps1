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
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)][ValidateSet("Application","Printer","Network Drive","Virtual Drive","Registry Entry","Environment Variable","Port","Ini File","External Task","File System Operation","User DSN","File Association")]
        [string]$Category,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # if a single category was specified, process only that type. if not, process all categories
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'category')) {
            Write-Verbose "Limiting result to category '$($Category)'"
            $vuemActionCategories = @($Category)
        } else {
            $vuemActionCategories = @("Application","Printer","Network Drive","Virtual Drive","Registry Entry","Environment Variable","Port","Ini File","External Task","File System Operation","User DSN","File Association")
        }

        # create empty Action array
        $vuemActions = @()

        foreach ($vuemActionCategory in $vuemActionCategories) {
            Write-Verbose "Processing category '$vuemActionCategory'"
            $vuemActions += Get-ActionsByCategory -Connection $Connection -IdSite $IdSite -IdAction $IdAction -Name $Name -Category $vuemActionCategory
        }

        Return $vuemActions
    }
}

function Get-ActionsByCategory {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [int]$IdSite = $null,
        [int]$IdAction = $null,
        [string]$Name = $null,
        [string]$Category
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
    if ($Category -like "ini file")              { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMIniFileOpObject -DataRow $row } }
    if ($Category -like "external task")         { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMExtTaskObject -DataRow $row } }
    if ($Category -like "file system operation") { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMFileSystemOpObject -DataRow $row } }
    if ($Category -like "user dsn")              { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMUserDSNObject -DataRow $row } }
    if ($Category -like "file association")      { foreach ($row in $result.Tables.Rows) { $vuemActions += New-VUEMFileAssocObject -DataRow $row } }

    return $vuemActions
}