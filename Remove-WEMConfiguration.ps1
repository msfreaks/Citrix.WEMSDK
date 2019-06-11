<#
    .Synopsis
    Removes a WEM Configuration object from WEM Database recursively.

    .Description
    Removes a WEM Configuration object from WEM Database recursively.

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
function Remove-WEMConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        if ($IdSite -eq 1) {
            Write-Error "You cannot remove the default site"
            Break
        }

        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab extra properties
        $SQLQuery = "SELECT Name FROM VUEMSites WHERE IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        $Name = $result.Tables.Rows.Name

        # only continue if the site was found
        if (-not $Name) { 
            Write-Warning "No site found with IdSite $($IdSite)"
            Break
        }

        # delete all table data associated with this site
        $SQLQuery = ""
        foreach ($table in $cleanupTables[$script:databaseVersion]) {
            $SQLQuery += "DELETE FROM $($table) WHERE IdSite = $($IdSite);"
        }
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite -1 -IdElement $IdSite -ChangeType "Delete" -ObjectName $Name -ObjectType "Global\Site" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
