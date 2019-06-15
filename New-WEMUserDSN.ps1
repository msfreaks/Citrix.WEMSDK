<#
    .Synopsis
    Create a new User DSN Action object in the WEM Database.

    .Description
    Create a new User DSN Action object in the WEM Database.

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

    .Parameter TargetDriverName
    ..

    .Parameter TargetServerName
    ..

    .Parameter TargetDatabaseName
    ..

    .Parameter UseExternalCredentials
    ..

    .Parameter ExternalUsername
    ..

    .Parameter ExternalPassword
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
function New-WEMUserDSN {
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
        [Parameter(Mandatory=$False)][ValidateSet("Create / Edit User DSN")]
        [string]$ActionType = "Create / Edit User DSN",
        [Parameter(Mandatory=$True)]
        [string]$TargetName,
        [Parameter(Mandatory=$True)]
        [string]$TargetDriverName,
        [Parameter(Mandatory=$True)]
        [string]$TargetServerName,
        [Parameter(Mandatory=$True)]
        [string]$TargetDatabaseName,
        [Parameter(Mandatory=$False)]
        [bool]$UseExternalCredentials = $False,
        [Parameter(Mandatory=$False)]
        [string]$ExternalUsername = $null,
        [Parameter(Mandatory=$False)]
        [string]$ExternalPassword = $null,
        [Parameter(Mandatory=$False)]
        [bool]$RunOnce = $true,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        ### TO-DO
        ### $ExternalPassword Base64 encoding type before storing in database

        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description
        $TargetName = ConvertTo-StringEscaped $TargetName
        $TargetDriverName = ConvertTo-StringEscaped $TargetDriverName
        $TargetServerName = ConvertTo-StringEscaped $TargetServerName
        $TargetDatabaseName = ConvertTo-StringEscaped $TargetDatabaseName
        $ExternalUsername =  ConvertTo-StringEscaped $ExternalUsername

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMUserDSNs WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.Action) {
            # name must be unique
            Write-Error "There's already a User DSN named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMUserDSNs (IdSite,Name,Description,State,ActionType,TargetName,TargetDriverName,TargetServerName,TargetDatabaseName,UseExtCredentials,ExtLogin,ExtPassword,RunOnce,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMUserDSNActionType[$ActionType]),'$($TargetName)','$($TargetDriverName)','$($TargetServerName)','$($TargetDatabaseName)',$([int]$UseExternalCredentials),'$($ExternalUsername)','$($ExternalPassword)','$([int]$RunOnce)',1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT IdUserDSN AS IdAction FROM VUEMUserDSNs WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $result.Tables.Rows.IdAction -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\User DSN" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        Get-WEMUserDSN -Connection $Connection -IdAction $result.Tables.Rows.IdAction
    }
}