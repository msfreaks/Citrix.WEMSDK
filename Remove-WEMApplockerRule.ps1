<#
    .Synopsis
    Removes a AppLocker Rule object from the WEM Database.

    .Description
    Removes a AppLocker Rule object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Remove-WEMAppLockerRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab the object to delete
        $rule = Get-WEMAppLockerRule -Connection $Connection -IdRule $IdRule

        # build query
        $SQLQuery = "EXEC DeleteAppLockerRule @IdRule=$($IdRule)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $rule.IdSite -IdElement $IdRule -ChangeType "Delete" -ObjectName $vuemAppLockerRule.Name -ObjectType "AppLocker Rule" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
