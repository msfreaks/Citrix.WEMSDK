<#
    .Synopsis
    Updates a Environment Variable Action object in the WEM Database.

    .Description
    Updates a Environment Variable Action object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Description
    ..

    .Parameter State
    ..

    .Parameter VariableName
    ..

    .Parameter VariableValue
    ..

    .Parameter ExecutionOrder
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMEnvironmentVariable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,

        [Parameter(Mandatory=$False)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State,
        [Parameter(Mandatory=$False)]
        [string]$VariableName,
        [Parameter(Mandatory=$False)]
        [string]$VariableValue,
        [Parameter(Mandatory=$False)]
        [int]$ExecutionOrder,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original action
        $origAction = Get-WEMEnvironmentVariable -Connection $Connection -IdAction $IdAction

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No Environment Variable action found for Id $($IdAction)"
            Break
        }
        
        # if a new name for the action is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name.Replace("'", "''") -notlike $origAction.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMEnvVariables WHERE Name LIKE '$($Name.Replace("'", "''"))' AND IdSite = $($origAction.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Action) {
                # name must be unique
                Write-Error "There's already an Environment Variable action named '$($Name.Replace("'", "''"))' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"

        }

        # grab default action xml (advanced options) and set individual advanced option variables
        [xml]$actionReserved = $defaultVUEMEnvironmentVariableReserved
        $actionExecutionOrder = [string][int]$origAction.ExecutionOrder

        # build the query to update the action
        $SQLQuery = "UPDATE VUEMEnvVariables SET "
        $updateFields = @()
        $updateAdvanced = $false
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "IdAction" }
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
                "VariableName" {
                    $updateFields += "VariableName = '$($VariableName.Replace("'", "''"))'"
                    continue
                }
                "VariableValue" {
                    $updateFields += "VariableValue = '$($VariableValue.Replace("'", "''"))'"
                    continue
                }
                "ExecutionOrder" {
                    $updateAdvanced = $True
                    $actionExecutionOrder = [string][int]$ExecutionOrder
                    continue
                }
                Default {}
            }
        }

        # apply actual Advanced Option values
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecOrder"}).Value    = $actionExecutionOrder

        # if anything needs to be updated, update the action
        if($updateFields -or $updateAdvanced) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            if ($updateAdvanced) { $SQLQuery += "Reserved01 = '$($actionReserved.OuterXml)', " }
            $SQLQuery += "RevisionId = $($origAction.Version + 1) WHERE IdEnvVariable = $($IdAction)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origAction.Name
            if ($Name) { $objectName = $Name.Replace("'", "''") }

            New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdAction -ChangeType "Update" -ObjectName $objectName -ObjectType "Actions\Environment Variable" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
New-Alias -Name Set-WEMEnvVariable -Value Set-WEMEnvironmentVariable
