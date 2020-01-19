<#
    .Synopsis
    Create a new Ini File Operation Action object in the WEM Database.

    .Description
    Create a new Ini File Operation Action object in the WEM Database.

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

    .Parameter TargetSectionName
    ..

    .Parameter TargetValueName
    ..

    .Parameter TargetValue
    ..

    .Parameter RunOnce
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function New-WEMIniFileOperation {
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
        [Parameter(Mandatory=$False)][ValidateSet("Write Ini File Value")]
        [string]$ActionType = "Write Ini File Value",
        [Parameter(Mandatory=$True)]
        [string]$TargetPath,
        [Parameter(Mandatory=$True)]
        [string]$TargetSectionName,
        [Parameter(Mandatory=$True)]
        [string]$TargetValueName,
        [Parameter(Mandatory=$False)]
        [string]$TargetValue,
        [Parameter(Mandatory=$False)]
        [bool]$RunOnce = $true,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description
        $TargetSectionName = ConvertTo-StringEscaped $TargetSectionName
        $TargetValueName =  ConvertTo-StringEscaped $TargetValueName
        $TargetValue =  ConvertTo-StringEscaped $TargetValue

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMIniFilesOps WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already a Ini File Operation object named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMIniFilesOps (IdSite,Name,Description,State,ActionType,TargetPath,TargetSectionName,TargetValueName,TargetValue,RunOnce,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMIniFileOpActionType[$ActionType]),'$($TargetPath)','$($TargetSectionName)','$($TargetValueName)','$($TargetValueName)',$([int]$RunOnce),1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT * FROM VUEMIniFilesOps WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdIniFileOp
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\Ini File Operation" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return New-VUEMIniFileOpObject -DataRow $result.Tables.Rows
        #Get-WEMIniFileOperation -Connection $Connection -IdAction $IdObject
    }
}
New-Alias -Name New-IniFilesOp -Value New-WEMIniFileOperation