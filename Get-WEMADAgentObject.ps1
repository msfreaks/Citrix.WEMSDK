<#
    .Synopsis
    Returns one or more WEM Active Directory Agent or OU objects from the WEM Database.

    .Description
    Returns one or more WEM Active Directory Agent or OU objects from the WEM Database.

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
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMADAgentObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$ADObjectId,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # build query
        $SQLQuery = "SELECT * FROM VUEMADObjects WHERE "
        if ($IdSite) { $SQLQuery += "IdSite = $($IdSite) AND " }
        if ($IdADObject) { $SQLQuery += "IdADObject = $($IdADObject) AND " }
        if ($Name) { $SQLQuery += "Name LIKE '$($Name.Replace("*","%"))' AND " }
        if ($ADObjectId) { $SQLQuery += "ADObjectId LIKE '$($ADObjectId.Replace("*","%"))' AND " }
        $SQLQuery += "(Type = 4 OR Type = 8)"

        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # build array of VUEMItems returned by the query
        $vuemADAgentObjects = @()
        foreach ($row in $result.Tables.Rows) { $vuemADAgentObjects += New-VUEMADAgentObject -DataRow $row }

        return $vuemADAgentObjects
    }
}
