<#
    .Synopsis
    Updates a WEM Registry Entry Action object in the WEM Database.

    .Description
    Updates a WEM Registry Entry Action object in the WEM Database.

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
function Set-WEMRegistryEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,

        [Parameter(Mandatory=$False)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description = "",
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$False)]
        [string]$TargetName,
        [Parameter(Mandatory=$False)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False)]
        [string]$TargetType,
        [Parameter(Mandatory=$False)]
        [string]$TargetValue,
        [Parameter(Mandatory=$False)]
        [bool]$RunOnce = $False,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original action
        $origAction = Get-WEMRegistryEntry -Connection $Connection -IdAction $IdAction

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No Registry Entry action found for Id $($IdAction)"
            Break
        }
        
        # if a new name for the action is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name.Replace("'", "''") -notlike $origAction.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMRegValues WHERE Name LIKE '$($Name.Replace("'", "''"))' AND IdSite = $($origAction.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Action) {
                # name must be unique
                Write-Error "There's already a Registry Entry action named '$($Name.Replace("'", "''"))' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"

        }

        # build the query to update the action
        $SQLQuery = "UPDATE VUEMRegValues SET "
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
                "TargetPath" {
                    $updateFields += "TargetPath = '$($TargetPath.Replace("'", "''"))'"
                    continue
                }
                "TargetType" {
                    $updateFields += "TargetType = '$($TargetType.Replace("'", "''"))'"
                    continue
                }
                "TargetValue" {
                    $updateFields += "TargetValue = '$($TargetValue.Replace("'", "''"))'"
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
            $SQLQuery += "RevisionId = $($origAction.Version + 1) WHERE IdRegValue = $($IdAction)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origAction.Name
            if ($Name) { $objectName = $Name.Replace("'", "''") }

            New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdAction -ChangeType "Update" -ObjectName $objectName -ObjectType "Actions\Registry Value" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
New-Alias -Name Set-WEMRegValue -Value Set-WEMRegistryEntry