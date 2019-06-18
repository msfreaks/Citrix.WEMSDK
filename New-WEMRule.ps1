<#
    .Synopsis
    Create a new Rule object in the WEM Database.

    .Description
    Create a new Rule object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Name
    ..

    .Parameter Description
    ..

    .Parameter State
    ..

    .Parameter Conditions
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description = "",
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$True)]
        [pscustomobject]$Conditions,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS RuleCount FROM VUEMFiltersRules WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.RuleCount -or $Name -like "always true") {
            # name must be unique
            Write-Error "There's already an Rule object named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # check if Conditions is a Conditions array
        $conditionsOk = $True
        foreach ($object in $Conditions) {
            if (-not $object.IdCondition) {
                $conditionsOk = $false
                break
            }
        }
        if (-not $conditionsOk) {
            Write-Error "Conditions are mandatory and must be an array of Condition objects"
            Break
        }

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMFiltersRules (IdSite,Name,Description,State,Conditions,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),'$($Conditions.IdCondition -join ";")',1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT IdFilterRule AS IdRule FROM VUEMFiltersRules WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $result.Tables.Rows.IdRule -ChangeType "Create" -ObjectName $Name -ObjectType "Filters\Filter Rule" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        Get-WEMRule -Connection $Connection -IdRule $result.Tables.Rows.IdRule
    }
}
