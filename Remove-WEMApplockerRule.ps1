<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER IdSite
Parameter description

.PARAMETER IdAppLockerRule
Parameter description

.PARAMETER Connection
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Remove-WEMAppLockerRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAppLockerRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab the object to delete
        $rule = Get-WEMAppLockerRule -Connection $Connection -IdAppLockerRule $IdAppLockerRule

        # build query
        $SQLQuery = "EXEC DeleteAppLockerRule @IdRule=$($IdAppLockerRule)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $rule.IdSite -IdElement $IdAppLockerRule -ChangeType "Delete" -ObjectName $vuemAppLockerRule.Name -ObjectType "AppLocker Rule" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}