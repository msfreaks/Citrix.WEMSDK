<#
    .Synopsis
    Updates a WEM External Task Action object in the WEM Database.

    .Description
    Updates a WEM External Task Action object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter DisplayName
    ..

    .Parameter Description
    ..

    .Parameter State
    ..

    .Parameter TargetPath
    ..

    .Parameter TargetArguments
    ..

    .Parameter RunHidden
    ..

    .Parameter WaitForFinish
    ..

    .Parameter TimeOut
    ..

    .Parameter ExecutionOrder
    ..

    .Parameter RunOnce
    ..

    .Parameter ExecuteOnlyAtLogon
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMExternalTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,

        [Parameter(Mandatory=$False)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description = "",
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$False)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False)]
        [string]$TargetArguments,
        [Parameter(Mandatory=$False)]
        [bool]$RunHidden = $False,
        [Parameter(Mandatory=$False)]
        [bool]$WaitForFinish = $True,
        [Parameter(Mandatory=$False)]
        [int]$TimeOut = 30,
        [Parameter(Mandatory=$False)]
        [int]$ExecutionOrder = 0,
        [Parameter(Mandatory=$False)]
        [bool]$RunOnce = $True,
        [Parameter(Mandatory=$False)]
        [bool]$ExecuteOnlyAtLogon = $False,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original action
        $origAction = Get-WEMExternalTask -Connection $Connection -IdAction $IdAction

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No External Task action found for Id $($IdAction)"
            Break
        }
        
        # if a new name for the action is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name.Replace("'", "''") -notlike $origAction.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMExtTasks WHERE Name LIKE '$($Name.Replace("'", "''"))' AND IdSite = $($origAction.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Action) {
                # name must be unique
                Write-Error "There's already a External Task action named '$($Name.Replace("'", "''"))' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"

        }

        # grab default action xml (advanced options) and set individual advanced option variables
        [xml]$actionReserved = $defaultVUEMExternalTaskReserved
        $actionExecuteOnlyAtLogon = [string][int]$origAction.ExecuteOnlyAtLogon

        # build the query to update the action
        $SQLQuery = "UPDATE VUEMExtTasks SET "
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
                "TargetPath" {
                    $updateFields += "TargetPath = '$($TargetPath.Replace("'", "''"))'"
                    continue
                }
                "TargetArguments" {
                    $updateFields += "TargetArgs = '$($TargetArguments.Replace("'", "''"))'"
                    continue
                }
                "RunHidden" {
                    $updateFields += "RunHidden = $([int]$RunHidden)"
                    continue
                }
                "WaitForFinish" {
                    $updateFields += "WaitForFinish = $([int]$WaitForFinish)"
                    continue
                }
                "TimeOut" {
                    $updateFields += "TimeOut = $($TimeOut)"
                    continue
                }
                "ExecutionOrder" {
                    $updateFields += "ExecOrder = $($ExecutionOrder)"
                    continue
                }
                "RunOnce" {
                    $updateFields += "RunOnce = $([int]$RunOnce)"
                    continue
                }
                "ExecuteOnlyAtLogon" {
                    $updateAdvanced = $True
                    $actionExecuteOnlyAtLogon = [string][int]$ExecuteOnlyAtLogon
                    continue
                }
                Default {}
            }
        }

        # apply actual Advanced Option values
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteOnlyAtLogon"}).Value = $actionExecuteOnlyAtLogon

        # if anything needs to be updated, update the action
        if($updateFields -or $updateAdvanced) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            if ($updateAdvanced) { $SQLQuery += "Reserved01 = '$($actionReserved.OuterXml)', " }
            $SQLQuery += "RevisionId = $($origAction.Version + 1) WHERE IdExtTask = $($IdAction)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origAction.Name
            if ($Name) { $objectName = $Name.Replace("'", "''") }

            New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdAction -ChangeType "Update" -ObjectName $objectName -ObjectType "Actions\External Task" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
New-Alias -Name Set-WEMExtTask -Value Set-WEMExternalTask