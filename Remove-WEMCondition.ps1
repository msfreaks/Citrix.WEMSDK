<#
    .Synopsis
    Removes a WEM Filter Condition object from the WEM Database.

    .Description
    Removes a WEM Filter Condition object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdCondition
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMCondition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdCondition,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # don't update the default condition
        if ($IdCondition -eq 1) {
            Write-Error "Cannot remove the default Condition"
            Break
        }

        # grab original object
        $origCondition = Get-WEMCondition -Connection $Connection -IdCondition $IdCondition

        # only continue if the condition was found
        if (-not $origCondition) { 
            Write-Warning "No Filter Condition Object found for Id $($IdCondition)"
            Break
        }
        
        # build query
        $SQLQuery = "DELETE FROM VUEMFiltersConditions WHERE IdFilterCondition = $($IdCondition)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # check if we need to remove it from Rules as well
        $SQLQuery = "SELECT * FROM VUEMFiltersRules WHERE IdSite = $($origCondition.IdSite) AND (Conditions LIKE '%;$($IdCondition);%' OR Conditions LIKE '%;$($IdCondition)' OR Conditions LIKE '$($IdCondition);%' OR Conditions = '$($IdCondition)')"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        
        # process results, if any
        foreach($row in $result.Tables.Rows) {
            if ($row.Conditions -eq $IdCondition) {
                # delete the entire Rule (no conditions left), or just remove the condition from the list of conditions
                Remove-WEMRule -Connection $Connection -IdRule $row.IdFilterRule
            } else {
                # update the rule with this condition removed
                $SQLQuery = "UPDATE VUEMFiltersRules SET Conditions = '$(($row.Conditions -Split ";" | Where-Object { $_ -ne $IdCondition}) -Join ";")' WHERE IdFilterRule = $($row.IdFilterRule)"
                $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
            }
        }

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origCondition.IdSite -IdElement $IdCondition -ChangeType "Delete" -ObjectName $origCondition.Name -ObjectType "Filters\Filter Condition" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
