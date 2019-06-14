<#
    .Synopsis
    Updates a WEM Ini File Operation Action object in the WEM Database.

    .Description
    Updates a WEM Ini File Operation Action object in the WEM Database.

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
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMIniFileOperation {
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
        [string]$TargetPath,
        [Parameter(Mandatory=$False)]
        [string]$TargetSectionName,
        [Parameter(Mandatory=$False)]
        [string]$TargetValueName,
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
        $origAction = Get-WEMIniFileOperation -Connection $Connection -IdAction $IdAction

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No Ini File Operation action found for Id $($IdAction)"
            Break
        }
        
        # if a new name for the action is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name -notlike $origAction.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMIniFilesOps WHERE Name LIKE '$($Name)' AND IdSite = $($origAction.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Action) {
                # name must be unique
                Write-Error "There's already a Ini File Operation action named '$($Name)' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"

        }

        # build the query to update the action
        $SQLQuery = "UPDATE VUEMIniFilesOps SET "
        $updateFields = @()
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "IdAction" }
        foreach ($key in $keys) {
            switch ($key) {
                "Name" {
                    $updateFields += "Name = '$($Name)'"
                    continue
                }
                "Description" {
                    $updateFields += "Description = '$($Description)'"
                    continue
                }
                "State" {
                    $updateFields += "State = $($tableVUEMState["$State"])"
                    continue
                }
                "TargetPath" {
                    $updateFields += "TargetPath = '$($TargetPath)'"
                    continue
                }
                "TargetSectionName" {
                    $updateFields += "TargetSectionName = '$($TargetSectionName)'"
                    continue
                }
                "TargetValueName" {
                    $updateFields += "TargetValueName = '$($TargetValueName)'"
                    continue
                }
                "TargetValue" {
                    $updateFields += "TargetValue = '$($TargetValue)'"
                    continue
                }
                "TargetPath" {
                    $updateFields += "TargetPath = '$($TargetPath)'"
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
            $SQLQuery += "RevisionId = $($origAction.Version + 1) WHERE IdIniFileOp = $($IdAction)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origAction.Name
            if ($Name) { $objectName = $Name }

            New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdAction -ChangeType "Update" -ObjectName $objectName -ObjectType "Actions\Ini File Operation" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
New-Alias -Name Set-WEMIniFilesOp -Value Set-WEMIniFileOperation