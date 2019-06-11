<#
    .Synopsis
    Updates a WEM Application Action object in the WEM Database.

    .Description
    Updates a WEM Application Action object in the WEM Database.

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

    .Parameter StartMenuTarget
    ..

    .Parameter TargetPath
    ..

    .Parameter Parameters
    ..

    .Parameter WorkingDirectory
    ..

    .Parameter WindowStyle
    ..

    .Parameter HotKey
    ..

    .Parameter IconLocation
    ..

    .Parameter IconIndex
    ..

    .Parameter IconStream
    ..

    .Parameter SelfHealingEnabled
    ..

    .Parameter EnforceIconLocation
    ..

    .Parameter EnforceIconXLocation
    ..

    .Parameter EnforceIconYLocation
    ..

    .Parameter DoNotShowInSelfService
    ..

    .Parameter CreateShortcutInUserFavoritesFolder
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMApplication {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,

        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$DisplayName,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$Description,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)][ValidateSet("Enabled","Disabled","Maintenance mode")]
        [string]$State,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$StartMenuTarget,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$Parameters,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)][ValidateSet("Normal","Minimized","Maximized")]
        [string]$WindowStyle,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$HotKey,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$IconLocation,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$IconIndex,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$IconStream,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [bool]$SelfHealingEnabled,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [bool]$EnforceIconLocation,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$EnforceIconXLocation,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$EnforceIconYLocation,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [bool]$DoNotShowInSelfService,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [bool]$CreateShortcutInUserFavoritesFolder,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original action
        $origAction = Get-WEMAction -Connection $Connection -IdAction $IdAction

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No Application action found for Id $($IdAction)"
            Break
        }
        
        # if a new name for the action is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name -notlike $origAction.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMApps WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Action) {
                # name must be unique
                Write-Error "There's already an application named '$($Name)' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"

        }

        # grab default action xml (advanced options) and set individual advanced option variables
        [xml]$actionReserved = $defaultVUEMAppReserved
        $actionSelfHealingEnabled                  = [string][int]$origAction.SelfHealingEnabled
        $actionEnforceIconLocation                 = [string][int]$origAction.EnforceIconLocation
        $actionEnforceIconXValue                   = [string]$origAction.EnforceIconXValue
        $actionEnforceIconYValue                   = [string]$origAction.EnforceIconYValue
        $actionDoNotShowInSelfService              = [string][int]$origAction.DoNotShowInSelfService
        $actionCreateShortcutInUserFavoritesFolder = [string][int]$origAction.CreateShortcutInUserFavoritesFolder

        # build the query to update the action
        $SQLQuery = "UPDATE VUEMApps SET "
        $updateFields = @()
        $updateAdvanced = $false
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "IdAction" }
        foreach ($key in $keys) {
            switch ($key) {
                "Name" {
                    $updateFields += "Name = '$($Name)'"
                    continue
                }
                "DisplayName" {
                    $updateFields += "DisplayName = '$($DisplayName)'"
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
                "StartMenuTarget" {
                    $updateFields += "StartMenuTarget = '$($StartMenuTarget)'"
                    continue
                }
                "TargetPath" {
                    $updateFields += "TargetPath = '$($TargetPath)'"
                    continue
                }
                "Parameters" {
                    $updateFields += "Parameters = '$($Parameters)'"
                    continue
                }
                "WorkingDirectory" {
                    $updateFields += "WorkingDirectory = '$($WorkingDirectory)'"
                    continue
                }
                "WindowStyle" {
                    $updateFields += "WindowStyle = '$($WindowStyle)'"
                    continue
                }
                "HotKey" {
                    $updateFields += "HotKey = '$($HotKey)'"
                    continue
                }
                "IconLocation" {
                    $updateFields += "IconLocation = '$($IconLocation)'"
                    continue
                }
                "IconIndex" {
                    $updateFields += "IconIndex = $($IconIndex)"
                    continue
                }
                "IconStream" {
                    $updateFields += "IconStream = '$($IconStream)'"
                    continue
                }
                "SelfHealingEnabled" {
                    $updateAdvanced = $True
                    $actionSelfHealingEnabled = [string][int]$SelfHealingEnabled
                    continue
                }
                "EnforceIconLocation" {
                    $updateAdvanced = $True
                    $actionEnforceIconLocation = [string][int]$EnforceIconLocation
                    continue
                }
                "EnforcedIconXValue" {
                    $updateAdvanced = $True
                    $actionEnforceIconXValue = [string]$EnforceIconXValue
                    continue
                }
                "EnforcedIconYValue" {
                    $updateAdvanced = $True
                    $actionEnforceIconYValue = [string]$EnforceIconYValue
                    continue
                }
                "DoNotShowInSelfService" {
                    $updateAdvanced = $True
                    $actionDoNotShowInSelfService = [string][int]$DoNotShowInSelfService
                    continue
                }
                "CreateShortcutInUserFavoritesFolder" {
                    $updateAdvanced = $True
                    $actionCreateShortcutInUserFavoritesFolder = [string][int]$CreateShortcutInUserFavoritesFolder
                    continue
                }
                Default {}
            }
        }

        # apply actual Advanced Option values
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SelfHealingEnabled"}).Value                   = $actionSelfHealingEnabled
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforceIconLocation"}).Value                  = $actionEnforceIconLocation
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforcedIconXValue"}).Value                   = $actionEnforceIconXValue
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforcedIconYValue"}).Value                   = $actionEnforceIconYValue
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "DoNotShowInSelfService"}).Value               = $actionDoNotShowInSelfService
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "CreateShortcutInUserFavoritesFolder"}).Value  = $actionCreateShortcutInUserFavoritesFolder

        # if anything needs to be updated, update the action
        if($updateFields -or $updateAdvanced) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            if ($updateAdvanced) { $SQLQuery += "Reserved01 = '$($actionReserved.OuterXml)', " }
            $SQLQuery += "RevisionId = $($origAction.Version + 1) WHERE IdApplication = $($IdAction)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdAction -ChangeType "Update" -ObjectName $Name -ObjectType "Actions\Application" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
New-Alias -Name Set-WEMApp -Value Set-WEMApplication