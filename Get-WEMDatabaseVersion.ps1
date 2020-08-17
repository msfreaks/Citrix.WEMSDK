<#
    .Synopsis
    Returns the WEM Database version.

    .Description
    Returns the WEM Database version.

    .Link
    https://msfreaks.wordpress.com

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMDatabaseVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # build query
        $SQLQuery = "SELECT value FROM VUEMParameters WHERE IdSite = 1 AND Name = 'VersionInfo'"
        $result = Invoke-SQL -Connection $connection -Query $SQLQuery
    
        return ([version]$result.Tables.Rows.value)
    }
}
