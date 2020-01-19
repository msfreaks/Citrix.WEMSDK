<#
    .Synopsis
    Returns one or more Administrator objects from the WEM Database.

    .Description
    Returns one or more Administrator objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAdministrator
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMAdministrator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAdministrator,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # build query
        $SQLQuery = "SELECT * FROM VUEMAdministrators"
        if ($IdSite -or $Name -or $IdAdministrator) {
            $SQLQuery += " WHERE "
            if ($IdSite) { 
                $SQLQuery += "Permissions LIKE '%<idSite>$($IdSite)</idSite>%'"
                if ($Name -or $IdAdministrator) { $SQLQuery += " AND " }
            }
            if ($IdAdministrator) { 
                $SQLQuery += "IdAdmin = $($IdAdministrator)"
                if ($Name) { $SQLQuery += " AND " }
            }
            if ($Name) { $SQLQuery += "Name LIKE '$($Name.Replace("*","%").Replace("'","''"))'"}
        }
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # build array of VUEMitems returned by the query
        $vuemAdminObjects = @()
        foreach ($row in $result.Tables.Rows) { $vuemAdminObjects += New-VUEMAdminObject -Connection $Connection -DataRow $row }

        return $vuemAdminObjects
    }
}
