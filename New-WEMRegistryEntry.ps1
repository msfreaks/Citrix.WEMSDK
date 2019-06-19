<#
    .Synopsis
    Create a new Registry Entry Action object in the WEM Database.

    .Description
    Create a new Registry Entry Action object in the WEM Database.

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

    .Parameter TargetName
    ..

    .Parameter TargetPath
    ..

    .Parameter TargetType
    ..

    .Parameter TargetValue
    ..

    .Parameter RunOnce
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMRegistryEntry {
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
        [Parameter(Mandatory=$False)][ValidateSet("Create / Set Registry Value", "Delete Registry Value")]
        [string]$ActionType = "Create / Set Registry Value",
        [Parameter(Mandatory=$True)]
        [string]$TargetName,
        [Parameter(Mandatory=$True)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False)][ValidateSet("REG_DWORD", "REG_QDWORD", "REG_SZ", "REG_EXPAND_SZ")]
        [string]$TargetType,
        [Parameter(Mandatory=$False)]
        [string]$TargetValue,
        [Parameter(Mandatory=$False)]
        [bool]$RunOnce = $True,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description
        $TargetName =  ConvertTo-StringEscaped $TargetName
        $TargetPath = ConvertTo-StringEscaped $TargetPath
        $TargetType =  ConvertTo-StringEscaped $TargetType
        $TargetValue =  ConvertTo-StringEscaped $TargetValue

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMRegValues WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already a Registry Entry object named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMRegvalues (IdSite,Name,Description,State,ActionType,TargetRoot,TargetName,TargetPath,TargetType,TargetValue,RunOnce,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMRegValueActionType[$ActionType]),NULL,'$($TargetName)','$($TargetPath)','$($TargetType)','$($TargetValue)',$([int]$RunOnce),1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT * FROM VUEMRegValues WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdRegValue
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\Registry Value" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return New-VUEMRegValueObject -DataRow $result.Tables.Rows
        #Get-WEMRegistryEntry -Connection $Connection -IdAction $IdObject
    }
}
New-Alias -Name New-WEMRegValue -Value New-WEMRegistryEntry