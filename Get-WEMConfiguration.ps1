<#
    .Synopsis
    Returns one or more WEM Configuration objects from the WEM Database.

    .Description
    Returns one or more WEM Configuration objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter Name
    ..

    .Parameter IdSite
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMConfiguration {
    [CmdletBinding(DefaultParameterSetName="byName")]
    param(
        [Parameter(Mandatory=$False, ParameterSetName="byName")]
        [string]$Name,
        [Parameter(Mandatory=$False, ParameterSetName="byId")]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ParameterSetName="byName")]
        [Parameter(Mandatory=$True, ParameterSetName="byId")]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {

        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # build query
        $SQLQuery = "SELECT * FROM VUEMSites"
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name')) { $SQLQuery += " WHERE Name = '$($Name)'" }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idsite')) { $SQLQuery += " WHERE IdSite = $($IdSite)" }
        
        # execute query
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        #return $result.Tables.Rows

        $vuemSites = @()
        foreach ($row in $result.Tables.Rows) { $vuemSites += New-VUEMSiteObject -DataRow $row }

        return $vuemSites
    }
}
