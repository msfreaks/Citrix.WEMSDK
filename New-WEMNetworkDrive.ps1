<#
    .Synopsis
    Create a new Network Drive Action object in the WEM Database.

    .Description
    Create a new Network Drive Action object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Name
    ..

    .Parameter DisplayName
    ..

    .Parameter Description
    ..

    .Parameter State
    ..

    .Parameter ActionType
    ..

    .Parameter TargetPath
    ..

    .Parameter UseExternalCredentials
    ..

    .Parameter ExternalUsername
    ..

    .Parameter ExternalPassword
    ..

    .Parameter SelfHealingEnabled
    ..

    .Parameter SetAsHomeDriveEnabled
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMNetworkDrive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$DisplayName,
        [Parameter(Mandatory=$False)]
        [string]$Description = "",
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$False)][ValidateSet("Map Network Drive")]
        [string]$ActionType = "Map Network Drive",
        [Parameter(Mandatory=$True)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False)]
        [bool]$UseExternalCredentials = $False,
        [Parameter(Mandatory=$False)]
        [string]$ExternalUsername = $null,
        [Parameter(Mandatory=$False)]
        [string]$ExternalPassword = $null,
        [Parameter(Mandatory=$False)]
        [bool]$SelfHealingEnabled = $false,
        [Parameter(Mandatory=$False)]
        [bool]$SetAsHomeDriveEnabled = $false,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        ### TO-DO
        ### $ExternalPassword Base64 encoding type before storing in database

        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $DisplayName = ConvertTo-StringEscaped $DisplayName
        $Description = ConvertTo-StringEscaped $Description
        $TargetPath = ConvertTo-StringEscaped $TargetPath
        $ExternalUsername =  ConvertTo-StringEscaped $ExternalUsername

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMNetDrives WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already a Network Drive object named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # apply Advanced Option values
        [xml]$actionReserved = $defaultVUEMNetworkDriveReserved
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SelfHealingEnabled"}).Value = [string][int]$SelfHealingEnabled
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SetAsHomeDriveEnabled"}).Value = [string][int]$SetAsHomeDriveEnabled

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMNetDrives (IdSite,Name,Description,DisplayName,State,ActionType,TargetPath,UseExtCredentials,ExtLogin,ExtPassword,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)','$($DisplayName)',$($tableVUEMState[$State]),$($tableVUEMNetDriveActionType[$ActionType]),'$($TargetPath)',$([int]$UseExternalCredentials),'$($ExternalUsername)','$($ExternalPassword)',1,'$($actionReserved.OuterXml)')"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT * FROM VUEMNetDrives WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdNetDrive
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\Network Drive" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return New-VUEMNetDriveObject -DataRow $result.Tables.Rows
        #Get-WEMNetworkDrive -Connection $Connection -IdAction $IdObject
    }
}
New-Alias -Name New-WEMNetDrive -Value New-WEMNetworkDrive