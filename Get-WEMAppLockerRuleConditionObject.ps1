<#
    .Synopsis
    Returns one or more AppLocker Rule Condition objects from the WEM Database.

    .Description
    Returns one or more AppLocker Rule Condition objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdRule
    ..

    .Parameter IdCondition
    ..

    .Parameter Type
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMAppLockerRuleConditionObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdRule = $null,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdCondition = $null,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)][ValidateSet("PathCondition","PublisherCondition","HashCondition")]
        [string]$Type = $null,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # set variables
        $vuemObjects = @()

        # build query
        if ($Type) {
            $vuemObjects += Get-WEMAppLockerRuleConditionObjectByType -IdRule $IdRule -IdCondition $IdCondition -Type $Type -Connection $Connection
        } else {
            $vuemObjects += Get-WEMAppLockerRuleConditionObjectByType -IdRule $IdRule -IdCondition $IdCondition -Type "PathCondition" -Connection $Connection
            $vuemObjects += Get-WEMAppLockerRuleConditionObjectByType -IdRule $IdRule -IdCondition $IdCondition -Type "PublisherCondition" -Connection $Connection
            $vuemObjects += Get-WEMAppLockerRuleConditionObjectByType -IdRule $IdRule -IdCondition $IdCondition -Type "HashCondition" -Connection $Connection
        }

        # return the VUEMItems
        return $vuemObjects
    }
}

<#
    .Synopsis
    Helper function that returns one or more AppLocker Rule Condition objects from the WEM Database.

    .Description
    Helper function that returns one or more AppLocker Rule Condition objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdRule
    ..

    .Parameter IdCondition
    ..

    .Parameter Type
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMAppLockerRuleConditionObjectByType {
    param (
        [int]$IdRule,
        [int]$IdCondition,
        [string]$Type,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    # build query based on Type
    $SQLQuery = "SELECT * FROM AppLockerRule$($Type)s"
    if ($IdRule -or $IdCondition) {
        $SQLQuery += " WHERE "
        if ($IdRule) { 
            $SQLQuery += "IdRule = $($IdRule)"
            if ($IdCondition) { $SQLQuery += " AND " }
        }
        if ($IdCondition) { $SQLQuery += "IdCondition = $($IdCondition)" }
    }
    $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

    # build array of VUEMItems returned by the query
    $vuemConditionsByType = @()
    foreach ($row in $result.Tables.Rows) { $vuemConditionsByType += New-VUEMAppLockerRuleCondition -Type $Type -DataRow $row -Connection $Connection }

    # return the VUEMItems
    return $vuemConditionsByType
}
