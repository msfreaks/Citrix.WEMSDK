<#
    .Synopsis
    Updates a WEM User DSN Action object in the WEM Database.

    .Description
    Updates a WEM User DSN Action object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Name
    ..

    .Parameter Description
    ..

    .Parameter State
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
function Set-WEMUserDSN {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,

        [Parameter(Mandatory=$False)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$DisplayName,
        [Parameter(Mandatory=$False)]
        [string]$Description,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State,
        [Parameter(Mandatory=$False)]
        [string]$TargetName,
        [Parameter(Mandatory=$False)]
        [string]$TargetDriverName,
        [Parameter(Mandatory=$False)]
        [string]$TargetServerName,
        [Parameter(Mandatory=$False)]
        [string]$TargetDatabaseName,
        [Parameter(Mandatory=$False)]
        [bool]$UseExternalCredentials,
        [Parameter(Mandatory=$False)]
        [string]$ExternalUsername,
        [Parameter(Mandatory=$False)]
        [string]$ExternalPassword,
        [Parameter(Mandatory=$False)]
        [bool]$RunOnce,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        ### TO-DO
        ### $ExternalPassword Base64 encoding type before storing in database

        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original action
        $origAction = Get-WEMUserDSN -Connection $Connection -IdAction $IdAction

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No User DSN action found for Id $($IdAction)"
            Break
        }
        
        # if a new name for the action is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name.Replace("'", "''") -notlike $origAction.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMUserDSNs WHERE Name LIKE '$($Name.Replace("'", "''"))' AND IdSite = $($origAction.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Action) {
                # name must be unique
                Write-Error "There's already a User DSN action named '$($Name.Replace("'", "''"))' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"

        }

        # build the query to update the action
        $SQLQuery = "UPDATE VUEMUserDSNs SET "
        $updateFields = @()
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "IdAction" }
        foreach ($key in $keys) {
            switch ($key) {
                "Name" {
                    $updateFields += "Name = '$($Name.Replace("'", "''"))'"
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
                "TargetName" {
                    $updateFields += "TargetName = '$($TargetName.Replace("'", "''"))'"
                    continue
                }
                "TargetDriverName" {
                    $updateFields += "TargetDriverName = '$($TargetDriverName.Replace("'", "''"))'"
                    continue
                }
                "TargetServerName" {
                    $updateFields += "TargetServerName = '$($TargetServerName.Replace("'", "''"))'"
                    continue
                }
                "TargetDatabaseName" {
                    $updateFields += "TargetDatabaseName = '$($TargetDatabaseName.Replace("'", "''"))'"
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
                "RunOnce" {
                    $updateFields += "RunOnce = $([int]$RunOnce)"
                    continue
                }
                Default {}
            }
        }

        # if anything needs to be updated, update the action
        if($updateFields) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            $SQLQuery += "RevisionId = $($origAction.Version + 1) WHERE IdUserDSN = $($IdAction)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origAction.Name
            if ($Name) { $objectName = $Name.Replace("'", "''") }

            New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdAction -ChangeType "Update" -ObjectName $objectName -ObjectType "Actions\User DSN" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
