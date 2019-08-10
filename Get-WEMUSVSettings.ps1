<#
    .Synopsis
    Returns a WEM USV Settings object from the WEM Database.

    .Description
    Returns a WEM USV Settings object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMUSVSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {

        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # only continue if a valid IdSite was passed
        if(-not (Get-WEMConfiguration -Connection $Connection -IdSite $IdSite)) {
            Write-Warning "No site found with IdSite $($IdSite)"
            Break
        }

        # create the object
        $configObject = @{}

        # grab the updated object
        $SQLQuery = "SELECT * FROM VUEMUSVSettings WHERE IdSite = $($IdSite) ORDER BY IdItem"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # cycle through all the properties
        foreach($row in $result.Tables.Rows) {
            $configObject.($row.Name) = $row.Value
        }

        # return the final object
        return $configObject 
    }
}
