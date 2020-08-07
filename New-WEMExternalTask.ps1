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

    .Parameter ExecuteAtLogon
    ..

    .Parameter ExecuteAtLogoff
    ..

    .Parameter ExecuteWhenRefresh
    ..

    .Parameter ExecuteWhenReconnect
    ..

    .Parameter ExecuteOnlyAtLogon
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
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
        [bool]$ExecuteAtLogon = $True,
        [Parameter(Mandatory=$False)]
        [bool]$ExecuteAtLogoff = $False,
        [Parameter(Mandatory=$False)]
        [bool]$ExecuteWhenRefresh = $True,
        [Parameter(Mandatory=$False)]
        [bool]$ExecuteWhenReconnect = $True,
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
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMExtTasks WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already an External Task object named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # warn the user for use of the parameters combined with certain database versions
        if ($script:databaseSchema -ge 2003 -and $ExecuteOnlyAtLogon) {
            Write-Warning "Usage of the parameter ExecuteOnlyAtLogon is depricated as of version 2003. Ignoring value."
        }
        if ($script:databaseSchema -lt 2003 -and ($ExecuteAtLogon -or $ExecuteAtLogoff -or $ExecuteWhenReconnect -or $ExecuteWhenReconnect)) {
            Write-Warning "Usage of the parameters ExecuteAtLogon, ExecuteAtLogoff, ExecuteWhenRefresh, and ExecuteWhenReconnect are not valid for this WEM version. Ignoring values."
        }

        # apply Advanced Option values
        [xml]$actionReserved = $defaultVUEMExternalTaskReserved
        Write-Verbose "Checking databaseSchema additions for $($script:databaseSchema)"
        if ($configurationSettings."$($script:databaseSchema)".VUEMExternalTaskReserved) {
            [xml]$actionReserved = $configurationSettings.$script:databaseSchema.VUEMExternalTaskReserved
            ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteAtLogon"}).Value = [string][int]$ExecuteAtLogon
            ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteAtLogoff"}).Value = [string][int]$ExecuteAtLogoff
            ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteWhenRefresh"}).Value = [string][int]$ExecuteWhenRefresh
            ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteWhenReconnect"}).Value = [string][int]$ExecuteWhenReconnect
        } else {
            ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecuteOnlyAtLogon"}).Value = [string][int]$ExecuteOnlyAtLogon
        }

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMExtTasks (IdSite,Name,Description,State,ActionType,TargetPath,TargetArgs,RunHidden,WaitForFinish,TimeOut,ExecOrder,RunOnce,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMExtTaskActionType[$ActionType]),'$($TargetPath)','$($TargetArguments)',$([int]$RunHidden),$([int]$WaitForFinish),$($TimeOut),$($ExecutionOrder),$([int]$RunOnce),1,'$($actionReserved.OuterXml)')"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT * FROM VUEMExtTasks WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdExtTask
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\External Task" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return New-VUEMExtTaskObject -DataRow $result.Tables.Rows
        #Get-WEMExternalTask -Connection $Connection -IdAction $result.Tables.Rows.IdAction
    }
}
New-Alias -Name New-WEMExtTask -Value New-WEMExternalTask