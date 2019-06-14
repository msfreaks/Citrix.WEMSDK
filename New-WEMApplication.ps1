<#
    .Synopsis
    Create a new Application Action object in the WEM Database.

    .Description
    Create a new Application Action object in the WEM Database.

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
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMApplication {
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
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled","Maintenance mode")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$False)][ValidateSet("Installed application","File / Folder","URL")]
        [string]$Type = "Installed application",
        [Parameter(Mandatory=$False)]
        [string]$StartMenuTarget,
        [Parameter(Mandatory=$True)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False)]
        [string]$Parameters = "",
        [Parameter(Mandatory=$False)]
        [string]$WorkingDirectory = "",
        [Parameter(Mandatory=$False)][ValidateSet("Normal","Minimized","Maximized")]
        [string]$WindowStyle = "Normal",
        [Parameter(Mandatory=$False)]
        [string]$HotKey = "None",
        [Parameter(Mandatory=$False)]
        [string]$IconLocation,
        [Parameter(Mandatory=$False)]
        [int]$IconIndex = 0,
        [Parameter(Mandatory=$False)]
        [string]$IconStream,
        [Parameter(Mandatory=$False)]
        [bool]$SelfHealingEnabled = $false,
        [Parameter(Mandatory=$False)]
        [bool]$EnforceIconLocation = $false,
        [Parameter(Mandatory=$False)]
        [int]$EnforceIconXLocation,
        [Parameter(Mandatory=$False)]
        [int]$EnforceIconYLocation,
        [Parameter(Mandatory=$False)]
        [bool]$DoNotShowInSelfService = $false,
        [Parameter(Mandatory=$False)]
        [bool]$CreateShortcutInUserFavoritesFolder = $false,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $DisplayName = ConvertTo-StringEscaped $DisplayName
        $Description = ConvertTo-StringEscaped $Description
        $StartMenuTarget = ConvertTo-StringEscaped $StartMenuTarget
        $TargetPath = ConvertTo-StringEscaped $TargetPath
        $Parameters =  ConvertTo-StringEscaped $Parameters
        $WorkingDirectory =  ConvertTo-StringEscaped $WorkingDirectory
        $HotKey =  ConvertTo-StringEscaped $HotKey
        $IconLocation =  ConvertTo-StringEscaped $IconLocation

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMApps WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.Action) {
            # name must be unique
            Write-Error "There's already an application named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # apply Advanced Option values
        [xml]$actionReserved = $defaultVUEMAppReserved
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SelfHealingEnabled"}).Value                   = [string][int]$SelfHealingEnabled
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforceIconLocation"}).Value                  = [string][int]$EnforceIconLocation
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforcedIconXValue"}).Value                   = [string]$EnforceIconXValue
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforcedIconYValue"}).Value                   = [string]$EnforceIconYValue
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "DoNotShowInSelfService"}).Value               = [string][int]$DoNotShowInSelfService
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "CreateShortcutInUserFavoritesFolder"}).Value  = [string][int]$CreateShortcutInUserFavoritesFolder

        # build optional values
        if ([bool]($MyInvocation.BoundParameters.Keys -notmatch 'displayname')) { $DisplayName = $Name }
        if ([bool]($MyInvocation.BoundParameters.Keys -notmatch 'iconlocation')) { $IconLocation = $TargetPath }
        if ([bool]($MyInvocation.BoundParameters.Keys -notmatch 'startmenutarget')) { $StartMenuTarget = "Start Menu\Programs" }
        if ($Type -like "URL") { $WorkingDirectory = "Url" }
        if ($Type -like "File / Folder") { $WorkingDirectory = "File" }

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMApps (IdSite,Name,Description,State,AppType,ActionType,DisplayName,StartMenuTarget,TargetPath,Parameters,WorkingDirectory,WindowStyle,IconLocation,IconIndex,Hotkey,IconStream,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMAppType[$Type]),0,'$($DisplayName)','$($StartMenuTarget)','$($TargetPath)','$($Parameters)','$($WorkingDirectory)','$($WindowStyle)','$($IconLocation)',$($IconIndex),'$($HotKey)','$($IconStream)',1,'$($actionReserved.OuterXml)')"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT IdApplication AS IdAction FROM VUEMApps WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $result.Tables.Rows.IdAction -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\Application" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        Get-WEMApplication -Connection $Connection -IdAction $result.Tables.Rows.IdAction
    }
}
New-Alias -Name New-WEMApp -Value New-WEMApplication