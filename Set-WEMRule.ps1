<#
    .Synopsis
    Updates a WEM Filter Rule object in the WEM Database.

    .Description
    Updates a WEM Filter Rule object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdRule
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
function Set-WEMRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$False)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State,
        [Parameter(Mandatory=$False)]
        [pscustomobject]$Conditions,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # don't update the default rule
        if ($IdRule -eq 1) {
            Write-Error "Cannot update the default Rule"
            Break
        }

        # grab original rule
        $origRule = Get-WEMRule -Connection $Connection -IdRule $IdRule

        # only continue if the rule was found
        if (-not $origRule) { 
            Write-Warning "No Rule object found for Id $($IdRule)"
            Break
        }

        # check if Conditions is a Conditions array
        if ([bool]($MyInvocation.BoundParameters.Keys -contains 'conditions')) {
            $conditionsOk = $true
            foreach ($object in $Conditions) {
                if (-not $object.IdCondition) {
                    $conditionsOk = $false
                    break
                }
            }
            if (-not $conditionsOk -or -not $Conditions) {
                Write-Error "When passing Conditions make sure you are passing an array of Condition objects"
                Break
            }
        }

        # build the query to update the rule
        $SQLQuery = "UPDATE VUEMFiltersRules SET "
        $updateFields = @()
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "idrule" }
        foreach ($key in $keys) {
            switch ($key) {
                "Name" {
                    $updateFields += "Name = '$($Name.Replace("'", "''"))'"
                    continue
                }
                "Description" {
                    $updateFields += "Description = '$($Description.Replace("'", "''"))'"
                    continue
                }
                "State" {
                    $updateFields += "State = $($tableVUEMState["$State"])"
                    continue
                }
                "Conditions" {
                    $updateFields += "Conditions = '$($Conditions.IdCondition -Join ";")'"
                    continue
                }
                Default {}
            }
        }

        # if anything needs to be updated, update the rule
        if($updateFields) { 
            $SQLQuery += "{0}, " -f ($updateFields -join ", ")
            $SQLQuery += "RevisionId = $($origRule.Version + 1) WHERE IdFilterRule = $($IdRule)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origRule.Name
            if ($Name) { $objectName = $Name.Replace("'", "''") }
            
            New-ChangesLogEntry -Connection $Connection -IdSite $origRule.IdSite -IdElement $IdRule -ChangeType "Update" -ObjectName $objectName -ObjectType "Filters\Filter Rule" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}