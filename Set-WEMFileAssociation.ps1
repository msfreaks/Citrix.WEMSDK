<#
    .Synopsis
    Updates a WEM File Association Action object in the WEM Database.

    .Description
    Updates a WEM File Association Action object in the WEM Database.

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

    .Parameter ActionType
    ..

    .Parameter FileExtension
    ..

    .Parameter ProgramId
    ..

    .Parameter Action
    ..

    .Parameter IsDefault
    ..

    .Parameter TargetPath
    ..

    .Parameter TargetCommand
    ..

    .Parameter TargetOverwrite
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
function Set-WEMFileAssociation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,

        [Parameter(Mandatory=$False)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State,
        [Parameter(Mandatory=$False)]
        [string]$FileExtension,
        [Parameter(Mandatory=$False)]
        [string]$ProgramId,
        [Parameter(Mandatory=$False)][ValidateSet("open", "edit", "print")]
        [string]$Action,
        [Parameter(Mandatory=$False)]
        [bool]$IsDefault,
        [Parameter(Mandatory=$False)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False)]
        [string]$TargetCommand,
        [Parameter(Mandatory=$False)]
        [bool]$TargetOverwrite,
        [Parameter(Mandatory=$False)]
        [bool]$RunOnce,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original action
        $origAction = Get-WEMFileAssociation -Connection $Connection -IdAction $IdAction

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No File Association action found for Id $($IdAction)"
            Break
        }
        
        # if a new name for the action is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name.Replace("'", "''") -notlike $origAction.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMFileAssocs WHERE Name LIKE '$($Name.Replace("'", "''"))' AND IdSite = $($origAction.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Action) {
                # name must be unique
                Write-Error "There's already a File Association action named '$($Name.Replace("'", "''"))' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"

        }

        # build the query to update the action
        $SQLQuery = "UPDATE VUEMFileAssocs SET "
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
                "FileExtension" {
                    $updateFields += "FileExtension = '$($FileExtension.Replace("'", "''"))'"
                    continue
                }
                "ProgramId" {
                    $updateFields += "ProgramId = '$($ProgramId.Replace("'", "''"))'"
                    continue
                }
                "Action" {
                    $updateFields += "Action = '$($Action.Replace("'", "''"))'"
                    continue
                }
                "IsDefault" {
                    $updateFields += "IsDefault = $([int]$IsDefault)"
                    continue
                }
                "TargetPath" {
                    $updateFields += "TargetPath = '$($TargetPath.Replace("'", "''"))'"
                    continue
                }
                "TargetCommand" {
                    $updateFields += "TargetCommand = '$($TargetCommand.Replace("'", "''"))'"
                    continue
                }
                "TargetOverwrite" {
                    $updateFields += "TargetOverwrite = $([int]$TargetOverwrite)"
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
            $SQLQuery += "RevisionId = $($origAction.Version + 1) WHERE IdFileAssoc = $($IdAction)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origAction.Name
            if ($Name) { $objectName = $Name.Replace("'", "''") }

            New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdAction -ChangeType "Update" -ObjectName $objectName -ObjectType "Actions\File Association" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
New-Alias -Name Set-WEMFileAssoc -Value Set-WEMFileAssociation