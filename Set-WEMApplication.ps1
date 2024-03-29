<#
    .Synopsis
    Updates a Application Action object in the WEM Database.

    .Description
    Updates a Application Action object in the WEM Database.

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

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMApplication {
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
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled","Maintenance mode")]
        [string]$State,
        [Parameter(Mandatory=$False)]
        [string]$StartMenuTarget,
        [Parameter(Mandatory=$False)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False)]
        [string]$Parameters,
        [Parameter(Mandatory=$False)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory=$False)][ValidateSet("Normal","Minimized","Maximized")]
        [string]$WindowStyle,
        [Parameter(Mandatory=$False)]
        [string]$HotKey,
        [Parameter(Mandatory=$False)]
        [string]$IconLocation,
        [Parameter(Mandatory=$False)]
        [int]$IconIndex,
        [Parameter(Mandatory=$False)]
        [string]$IconStream,
        [Parameter(Mandatory=$False)]
        [bool]$SelfHealingEnabled,
        [Parameter(Mandatory=$False)]
        [bool]$EnforceIconLocation,
        [Parameter(Mandatory=$False)]
        [int]$EnforceIconXLocation,
        [Parameter(Mandatory=$False)]
        [int]$EnforceIconYLocation,
        [Parameter(Mandatory=$False)]
        [bool]$DoNotShowInSelfService,
        [Parameter(Mandatory=$False)]
        [bool]$CreateShortcutInUserFavoritesFolder,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original action
        $origAction = Get-WEMApplication -Connection $Connection -IdAction $IdAction

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No Application action found for Id $($IdAction)"
            Break
        }
        
        # if a new name for the action is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name.Replace("'", "''") -notlike $origAction.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMApps WHERE Name LIKE '$($Name.Replace("'", "''"))' AND IdSite = $($origAction.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Action) {
                # name must be unique
                Write-Error "There's already an Application action named '$($Name.Replace("'", "''"))' in the Configuration"
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
                "StartMenuTarget" {
                    $updateFields += "StartMenuTarget = '$($StartMenuTarget.Replace("'", "''"))'"
                    continue
                }
                "TargetPath" {
                    $updateFields += "TargetPath = '$($TargetPath.Replace("'", "''"))'"
                    if ([bool]($MyInvocation.BoundParameters.Keys -notmatch 'iconstream')) {
                        $updateFields += "IconStream = '$(Get-IconStream -IconLocation $TargetPath)'"
                    }
                    continue
                }
                "Parameters" {
                    $updateFields += "Parameters = '$($Parameters.Replace("'", "''"))'"
                    continue
                }
                "WorkingDirectory" {
                    $updateFields += "WorkingDirectory = '$($WorkingDirectory.Replace("'", "''"))'"
                    continue
                }
                "WindowStyle" {
                    $updateFields += "WindowStyle = '$($WindowStyle.Replace("'", "''"))'"
                    continue
                }
                "HotKey" {
                    $updateFields += "HotKey = '$($HotKey.Replace("'", "''"))'"
                    continue
                }
                "IconLocation" {
                    $updateFields += "IconLocation = '$($IconLocation.Replace("'", "''"))'"
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
            $objectName = $origAction.Name
            if ($Name) { $objectName = $Name.Replace("'", "''") }
            
            New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdAction -ChangeType "Update" -ObjectName $objectName -ObjectType "Actions\Application" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
New-Alias -Name Set-WEMApp -Value Set-WEMApplication
