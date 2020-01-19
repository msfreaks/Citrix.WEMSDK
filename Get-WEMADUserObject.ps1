<#
    .Synopsis
    Returns one or more Active Directory User or Group objects from the WEM Database.

    .Description
    Returns one or more Active Directory User or Group objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdADObject
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMADUserObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # build query
        $SQLQuery = "SELECT * FROM VUEMItems"
        if ($IdSite -or $Name -or $IdADObject) {
            $SQLQuery += " WHERE "
            if ($IdSite) { 
                $SQLQuery += "IdSite = $($IdSite)"
                if ($Name -or $IdADObject) { $SQLQuery += " AND " }
            }
            if ($IdADObject) { 
                $SQLQuery += "IdItem = $($IdADObject)"
                if ($Name) { $SQLQuery += " AND " }
            }
            if ($Name) { $SQLQuery += "Name LIKE '$($Name.Replace("*","%"))'"}
        }
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # build array of VUEMItems returned by the query
        $vuemADUserObjects = @()
        foreach ($row in $result.Tables.Rows) { $vuemADUserObjects += New-VUEMADUserObject -DataRow $row }

        return $vuemADUserObjects
    }
}
