<#
    .Synopsis
    Returns one or more WEM Filter Rule objects from the WEM Database.

    .Description
    Returns one or more WEM Filter Rule objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdRule
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
function Get-WEMRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdRule,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # todo:
        # If both Site and IdRule is entered and IdRule = 1, default rule is not returned!!
        
        # build query
        $SQLQuery = "SELECT * FROM VUEMFiltersRules"
        if ($IdSite -or $Name -or $IdRule) {
            $SQLQuery += " WHERE "
            if ($IdSite) { 
                $SQLQuery += "IdSite = $($IdSite)"
                if ($Name -or $IdRule) { $SQLQuery += " AND " } else { $SQLQuery += " OR Name LIKE 'Always True'" }
            }
            if ($IdRule) { 
                $SQLQuery += "IdFilterRule = $($IdRule)"
                if ($Name) { $SQLQuery += " AND " }
            }
            if ($Name) { $SQLQuery += "Name LIKE '$($Name.Replace("*","%"))'"}
        }
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # build array of VUEMItems returned by the query
        $vuemRules = @()
        foreach ($row in $result.Tables.Rows) { $vuemRules += New-VUEMRule -DataRow $row -Connection $Connection }

        return $vuemRules
    }
}
