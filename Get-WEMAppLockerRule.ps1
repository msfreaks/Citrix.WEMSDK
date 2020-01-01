<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER IdSite
Parameter description

.PARAMETER IdRule
Parameter description

.PARAMETER AppLockerRuleGuid
Parameter description

.PARAMETER Name
Parameter description

.PARAMETER Connection
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-WEMAppLockerRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$False,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdRule,
        [Parameter(Mandatory=$False,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [string]$AppLockerRuleGuid,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name = $null,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # build query
        $SQLQuery = "SELECT * FROM AppLockerRules"
        if ($IdSite -or $Name -or $IdRule) {
            $SQLQuery += " WHERE "
            if ($IdSite) { 
                $SQLQuery += "IdSite = $($IdSite)"
                if ($IdRule -or $AppLockerRuleGuid -or $Name) { $SQLQuery += " AND " }
            }
            if ($IdRule) {
                $SQLQuery += "IdRule = $($IdRule)"
                if ($AppLockerRuleGuid -or $Name) { $SQLQuery += " AND " }
            }
            if ($AppLockerRuleGuid) { 
                $SQLQuery += "RuleGuid = '$($AppLockerRuleGuid.ToUpper())'"
                if ($Name) { $SQLQuery += " AND " }
            }
            if ($Name) { $SQLQuery += "Name LIKE '$($Name.Replace("*","%").Replace("'","''"))'"}
        }
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # build array of VUEMItems returned by the query
        $vuemAppLockerRules = @()
        foreach ($row in $result.Tables.Rows) { $vuemAppLockerRules += New-VUEMAppLockerRule -DataRow $row -Connection $Connection }

        return $vuemAppLockerRules
    }
}