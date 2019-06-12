<#
    .Synopsis
    Updates a WEM Printer Action object in the WEM Database.

    .Description
    Updates a WEM Printer Action object in the WEM Database.

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
function Set-WEMPrinter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,

        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [string]$DisplayName,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [string]$Description = "",
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)][ValidateSet("Enabled","Disabled")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)][ValidateSet("Map Network Printer","Use Device Mapping Printers File")]
        [string]$ActionType = "Map Network Printer",
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [bool]$UseExternalCredentials = $False,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [string]$ExternalUsername = $null,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [string]$ExternalPassword = $null,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [bool]$SelfHealingEnabled = $false,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        ### TO-DO
        ### $ExternalPassword Base64 encoding type before storing in database

        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original action
        $origAction = Get-WEMPrinter -Connection $Connection -IdAction $IdAction

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No Printer action found for Id $($IdAction)"
            Break
        }
        
        # if a new name for the action is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name -notlike $origAction.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMPrinters WHERE Name LIKE '$($Name)' AND IdSite = $($origAction.$IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Action) {
                # name must be unique
                Write-Error "There's already a Printer action named '$($Name)' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"

        }

        # grab default action xml (advanced options) and set individual advanced option variables
        [xml]$actionReserved = $defaultVUEMAppReserved
        $actionSelfHealingEnabled                  = [string][int]$origAction.SelfHealingEnabled

        # build the query to update the action
        $SQLQuery = "UPDATE VUEMPrinters SET "
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