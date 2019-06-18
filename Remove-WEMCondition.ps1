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

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origCondition.IdSite -IdElement $IdCondition -ChangeType "Delete" -ObjectName $origCondition.Name -ObjectType "Users\User" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
