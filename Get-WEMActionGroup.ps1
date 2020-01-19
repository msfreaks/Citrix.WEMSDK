<#
    .Synopsis
    Returns one or more Action Group objects from the WEM Database.

    .Description
    Returns one or more Action Group objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdActionGroup
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMActionGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdActionGroup,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # build query
        $SQLQuery = "SELECT * FROM VUEMActionGroups"
        if ($IdSite -or $Name -or $IdActionGroup) {
            $SQLQuery += " WHERE "
            if ($IdSite) { 
                $SQLQuery += "IdSite = $($IdSite)"
                if ($Name -or $IdActionGroup) { $SQLQuery += " AND " }
            }
            if ($IdActionGroup) { 
                $SQLQuery += "IdActionGroup = $($IdActionGroup)"
                if ($Name) { $SQLQuery += " AND " }
            }
            if ($Name) { $SQLQuery += "Name LIKE '$($Name.Replace("*","%"))'"}
        }
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # build array of VUEMActionGroups returned by the query
        $vuemObjects = @()
        foreach ($row in $result.Tables.Rows) { $vuemObjects += New-VUEMActionGroupObject -DataRow $row -Connection $Connection }

        return $vuemObjects
    }
}
