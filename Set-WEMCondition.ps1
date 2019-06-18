<#
    .Synopsis
    Updates a WEM Condition object in the WEM Database.

    .Description
    Updates a WEM Condition object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdCondition
    ..

    .Parameter Name
    ..

    .Parameter Description
    ..

    .Parameter State
    ..

    .Parameter TestValue
    ..

    .Parameter TestResult
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMCondition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdCondition,

        [Parameter(Mandatory=$False)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State,
        [Parameter(Mandatory=$False)]
        [string]$TestValue,
        [Parameter(Mandatory=$False)]
        [string]$TestResult,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # don't update the default condition
        if ($IdCondition -eq 1) {
            Write-Error "Cannot update the default Condition"
            Break
        }

        # grab original condition
        $origCondition = Get-WEMCondition -Connection $Connection -IdCondition $IdCondition

        # only continue if the condition was found
        if (-not $origCondition) { 
            Write-Warning "No Condition object found for Id $($IdCondition)"
            Break
        }
        
        # if a new name for the Condition is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name.Replace("'", "''") -notlike $origCondition.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Condition FROM VUEMFiltersConditions WHERE Name LIKE '$($Name.Replace("'", "''"))' AND IdSite = $($origCondition.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Condition) {
                # name must be unique
                Write-Error "There's already an Filter Condition object named '$($Name.Replace("'", "''"))' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"
        }

        # build optional values
        $requiredTestValue = -not $tableVUEMFiltersConditionType[$tableVUEMFiltersConditionType[$origCondition.Type]].UseName
        $validatedTestResult = ($null -ne $tableVUEMFiltersConditionType[$tableVUEMFiltersConditionType[$origCondition.Type]].TestedResult)

        if (-not $requiredTestValue -and [bool]($MyInvocation.BoundParameters.Keys -contains 'testvalue' -and ($TestValue -notlike $origAction.Type))) {
            Write-Error "If you update a condition of type '$($origCondition.Type)', you cannot provide a value for 'TestValue' other than '$($origCondition.Type)'"
            Break
        }
        if ($validatedTestResult -and [bool]($MyInvocation.BoundParameters.Keys -contains 'testresult') -and [bool]($tableVUEMFiltersConditionType[$tableVUEMFiltersConditionType[$origCondition.Type]].TestedResult -notcontains $TestResult)) {
            Write-Error "If you update a condition of type '$($origCondition.Type)', you must provide a value for 'TestResult' matching one of [$($tableVUEMFiltersConditionType[$tableVUEMFiltersConditionType[$origCondition.Type]].TestedResult -join ", ")]"
            Break
        }

        # build the query to update the action
        $SQLQuery = "UPDATE VUEMFiltersConditions SET "
        $updateFields = @()
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "idcondition" }
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
                "TestValue" {
                    $updateFields += "TestValue = '$($TestValue.Replace("'", "''"))'"
                    continue
                }
                "TestResult" {
                    $updateFields += "TestResult = '$($TestResult.Replace("'", "''"))'"
                    continue
                }
                Default {}
            }
        }

        # if anything needs to be updated, update the action
        if($updateFields) { 
            $SQLQuery += "{0}, " -f ($updateFields -join ", ")
            $SQLQuery += "RevisionId = $($origConditions.Version + 1) WHERE IdFilterCondition = $($IdCondition)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origCondition.Name
            if ($Name) { $objectName = $Name.Replace("'", "''") }
            
            New-ChangesLogEntry -Connection $Connection -IdSite $origCondition.IdSite -IdElement $IdCondition -ChangeType "Update" -ObjectName $objectName -ObjectType "Filters\Filter Condition" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}