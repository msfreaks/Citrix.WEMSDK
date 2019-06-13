<#
    .Synopsis
    Create a new Printer Action object in the WEM Database.

    .Description
    Create a new Printer Action object in the WEM Database.

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

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMPrinter {
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
        [Parameter(Mandatory=$False)][ValidateSet("Map Network Printer","Use Device Mapping Printers File")]
        [string]$ActionType = "Map Network Printer",
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

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        ### TO-DO
        ### $ExternalPassword Base64 encoding type before storing in database

        Write-Verbose "Working with database version $($script:databaseVersion)"

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMPrinters WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.Action) {
            # name must be unique
            Write-Error "There's already a printer named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # apply Advanced Option values
        [xml]$actionReserved = $defaultVUEMPrinterReserved
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SelfHealingEnabled"}).Value = [string][int]$SelfHealingEnabled

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMPrinters (IdSite,Name,Description,DisplayName,State,ActionType,TargetPath,UseExtCredentials,ExtLogin,ExtPassword,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)','$($DisplayName)',$($tableVUEMState[$State]),$($tableVUEMPrinterActionType[$ActionType]),'$($TargetPath)',$([int]$UseExternalCredentials),'$($ExternalUsername)','$($ExternalPassword)',1,'$($actionReserved.OuterXml)')"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT IdPrinter AS IdAction FROM VUEMPrinters WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $result.Tables.Rows.IdAction -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\Printer" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        Get-WEMPrinter -Connection $Connection -IdAction $result.Tables.Rows.IdAction
    }
}
