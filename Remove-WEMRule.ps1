<#
    .Synopsis
    Removes a Filter Rule object from the WEM Database.

    .Description
    Removes a Filter Rule object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Remove-WEMRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # don't update the default condition
        if ($IdRule -eq 1) {
            Write-Error "Cannot remove the default Rule"
            Break
        }

        # grab original object
        $origRule = Get-WEMRule -Connection $Connection -IdRule $IdRule

        # only continue if the condition was found
        if (-not $origRule) { 
            Write-Warning "No Filter Rule Object found for Id $($IdRule)"
            Break
        }
        
        # build query
        $SQLQuery = "DELETE FROM VUEMFiltersRules WHERE IdFilterRule = $($IdRule)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origRule.IdSite -IdElement $IdRule -ChangeType "Delete" -ObjectName $origRule.Name -ObjectType "Filters\Filter Rule" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
