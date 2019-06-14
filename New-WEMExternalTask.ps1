<#
    .Synopsis
    Create a new External Task Action object in the WEM Database.

    .Description
    Create a new External Task Action object in the WEM Database.

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

    .Parameter ActionType
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
function New-WEMExternalTask {
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
        [Parameter(Mandatory=$False)][ValidateSet("Execute External Task")]
        [string]$ActionType = "Execute External Task",
        [Parameter(Mandatory=$True)]
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

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description
        $TargetPath = ConvertTo-StringEscaped $TargetPath
        $TargetArguments =  ConvertTo-StringEscaped $TargetArguments

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMExtTasks WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.Action) {
            # name must be unique
            Write-Error "There's already an External Task named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # apply Advanced Option values
        [xml]$actionReserved = $defaultVUEMExternalTaskReserved
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteOnlyAtLogon"}).Value = [string][int]$ExecuteOnlyAtLogon

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMExtTasks (IdSite,Name,Description,State,ActionType,TargetPath,TargetArgs,RunHidden,WaitForFinish,TimeOut,ExecOrder,RunOnce,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMExtTaskActionType[$ActionType]),'$($TargetPath)','$($TargetArguments)',$([int]$RunHidden),$([int]$WaitForFinish),$($TimeOut),$($ExecutionOrder),$([int]$RunOnce),1,'$($actionReserved.OuterXml)')"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT IdExtTask AS IdAction FROM VUEMExtTasks WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $result.Tables.Rows.IdAction -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\External Task" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        Get-WEMExternalTask -Connection $Connection -IdAction $result.Tables.Rows.IdAction
    }
}
New-Alias -Name New-WEMExtTask -Value New-WEMExternalTask