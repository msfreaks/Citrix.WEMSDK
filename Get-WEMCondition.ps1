<#
    .Synopsis
    Returns one or more Filter Condition objects from the WEM Database.

    .Description
    Returns one or more Filter Condition objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdCondition
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMCondition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdCondition,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # build query
        $SQLQuery = "SELECT * FROM VUEMFiltersConditions"
        if ($IdSite -or $Name -or $IdCondition) {
            $SQLQuery += " WHERE "
            if ($IdSite) { 
                $SQLQuery += "IdSite = $($IdSite)"
                if ($Name -or $IdCondition) { $SQLQuery += " AND " } else { $SQLQuery += " OR Name LIKE 'Always True'" }
            }
            if ($IdCondition) { 
                $SQLQuery += "IdFilterCondition = $($IdCondition)"
                if ($Name) { $SQLQuery += " AND " }
            }
            if ($Name) { $SQLQuery += "Name LIKE '$($Name.Replace("*","%").Replace("'","''"))'"}
        }
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # build array of VUEMItems returned by the query
        $vuemConditions = @()
        foreach ($row in $result.Tables.Rows) { $vuemConditions += New-VUEMCondition -DataRow $row }

        return $vuemConditions
    }
}
