<#
    .Synopsis
    Updates a WEM Network Drive Action object in the WEM Database.

    .Description
    Updates a WEM Network Drive Action object in the WEM Database.

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
function Set-WEMNetworkDrive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,

        [Parameter(Mandatory=$False)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$DisplayName,
        [Parameter(Mandatory=$False)]
        [string]$Description = "",
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$False)]
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

        # grab original action
        $origAction = Get-WEMNetworkDrive -Connection $Connection -IdAction $IdAction

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No Network Drive action found for Id $($IdAction)"
            Break
        }
        
        # if a new name for the action is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name.Replace("'", "''") -notlike $origAction.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMNetDrives WHERE Name LIKE '$($Name.Replace("'", "''"))' AND IdSite = $($origAction.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Action) {
                # name must be unique
                Write-Error "There's already a Network Drive action named '$($Name.Replace("'", "''"))' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"

        }

        # grab default action xml (advanced options) and set individual advanced option variables
        [xml]$actionReserved = $defaultVUEMNetworkDriveReserved
        $actionSelfHealingEnabled                  = [string][int]$origAction.SelfHealingEnabled
        $actionSetAsHomeDriveEnabled               = [string][int]$origAction.SetAsHomeDriveEnabled

        # build the query to update the action
        $SQLQuery = "UPDATE VUEMNetDrives SET "
        $updateFields = @()
        $updateAdvanced = $false
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "IdAction" }
        foreach ($key in $keys) {
            switch ($key) {
                "Name" {
                    $updateFields += "Name = '$($Name.Replace("'", "''"))'"
                    continue
                }
                "DisplayName" {
                    $updateFields += "DisplayName = '$($DisplayName.Replace("'", "''"))'"
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
                "UseExternalCredentials" {
                    $updateFields += "UseExtCredentials = $([int]$UseExternalCredentials)"
                    continue
                }
                "ExternalUsername" {
                    $updateFields += "ExtLogin = '$($ExternalUsername.Replace("'", "''"))'"
                    continue
                }
                "ExternalPassword" {
                    ### TO-DO
                    ### $ExternalPassword Base64 encoding type before storing in database

                    $updateFields += "ExtPassword = '$($ExternalPassword)'"
                    continue
                }
                "SelfHealingEnabled" {
                    $updateAdvanced = $True
                    $actionSelfHealingEnabled = [string][int]$SelfHealingEnabled
                    continue
                }
                "SetAsHomeDriveEnabled" {
                    $updateAdvanced = $True
                    $actionSelfHealingEnabled = [string][int]$SetAsHomeDriveEnabled
                    continue
                }
                Default {}
            }
        }

        # apply actual Advanced Option values
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SelfHealingEnabled"}).Value    = $actionSelfHealingEnabled
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SetAsHomeDriveEnabled"}).Value = $actionSetAsHomeDriveEnabled

        # if anything needs to be updated, update the action
        if($updateFields -or $updateAdvanced) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            if ($updateAdvanced) { $SQLQuery += "Reserved01 = '$($actionReserved.OuterXml)', " }
            $SQLQuery += "RevisionId = $($origAction.Version + 1) WHERE IdNetDrive = $($IdAction)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origAction.Name
            if ($Name) { $objectName = $Name.Replace("'", "''") }

            New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdAction -ChangeType "Update" -ObjectName $objectName -ObjectType "Actions\Network Drive" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
New-Alias -Name Set-WEMNetDrive -Value Set-WEMNetworkDrive