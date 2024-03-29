<#
    .Synopsis
    Create a new Environment Variable Action object in the WEM Database.

    .Description
    Create a new Environment Variable Action object in the WEM Database.

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
function New-WEMEnvironmentVariable {
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
        [Parameter(Mandatory=$False)][ValidateSet("Create / Set Environment Variable")]
        [string]$ActionType = "Create / Set Environment Variable",
        [Parameter(Mandatory=$True)]
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

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description
        $VariableName = ConvertTo-StringEscaped $VariableName
        $VariableValue =  ConvertTo-StringEscaped $VariableValue
        
        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMEnvVariables WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already a Environment Variable object named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # apply Advanced Option values
        [xml]$actionReserved = $defaultVUEMEnvironmentVariableReserved
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecOrder"}).Value = [string][int]$ExecutionOrder
        
        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMEnvVariables (IdSite,Name,Description,State,ActionType,VariableName,VariableValue,VariableType,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMEnvVariableActionType[$ActionType]),'$($VariableName)','$($VariableValue)','User',1,'$($actionReserved.OuterXml)')"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT * FROM VUEMEnvVariables WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdEnvVariable
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\Environment Variable" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return New-VUEMEnvVariableObject -DataRow $result.Tables.Rows
        #Get-WEMEnvironmentVariable -Connection $Connection -IdAction $IdObject
    }
}
New-Alias -Name New-WEMEnvVariable -Value New-WEMEnvironmentVariable