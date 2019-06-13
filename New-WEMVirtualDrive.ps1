<#
    .Synopsis
    Create a new Virtual Drive Action object in the WEM Database.

    .Description
    Create a new Virtual Drive Action object in the WEM Database.

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

    .Parameter SetAsHomeDriveEnabled
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMVirtualDrive {
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
        [Parameter(Mandatory=$False)][ValidateSet("Map Virtual Drive")]
        [string]$ActionType = "Map Virtual Drive",
        [Parameter(Mandatory=$True)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False)]
        [bool]$SetAsHomeDriveEnabled = $false,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMVirtualDrives WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.Action) {
            # name must be unique
            Write-Error "There's already a Virtual Drive named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # apply Advanced Option values
        [xml]$actionReserved = $defaultVUEMVirtualDriveReserved
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SetAsHomeDriveEnabled"}).Value = [string][int]$SetAsHomeDriveEnabled

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMVirtualDrives (IdSite,Name,Description,State,ActionType,TargetPath,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMVirtualDriveActionType[$ActionType]),'$($TargetPath)',1,'$($actionReserved.OuterXml)')"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT IdVirtualDrive AS IdAction FROM VUEMVirtualDrives WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $result.Tables.Rows.IdAction -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\Virtual Drive" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        Get-WEMNetworkDrive -Connection $Connection -IdAction $result.Tables.Rows.IdAction
    }
}
