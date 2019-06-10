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

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMApp {

    #required:
    # name
    # application type
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$DisplayName,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$Description = "",
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)][ValidateSet("Enabled","Disabled","Maintenance mode")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)][ValidateSet("Installed application","File / Folder","URL")]
        [string]$Type = "Installed application",
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$StartMenuTarget = "Start Menu\Programs",
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$Parameters = "",
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$WorkingDirectory = "",
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)][ValidateSet("Normal","Minimized","Maximized")]
        [string]$WindowStyle = "Normal",
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$HotKey = "",
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [string]$IconLocation,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IconIndex = 1,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [string]$IconStream,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [bool]$SelfHealingEnabled = $false,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [bool]$EnforceIconLocation = $false,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$EnforceIconXLocation,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$EnforceIconYLocation,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [bool]$DoNotShowInSelfService = $false,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [bool]$CreateShortcutInUserFavoritesFolder = $false,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS Action FROM VUEMApps WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite) AND Type = $($tableVUEMAppType[$Type])"
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
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'displayname')) { $DisplayName = $Name }

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMApps (IdSite,Name,Description,State,AppType,ActionType,DisplayName,StartMenuTarget,TargetPath,Parameters,WorkingDirectory,WindowStyle,IconLocation,IconIndex,Hotkey,IconStream,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMAppType[$Type]),0,'$($DisplayName)','$($StartMenuTarget)','$($TargetPath)','$($Parameters)','$($WorkingDirectory)','$($WindowStyle)','$($IconLocation)',$($IconIndex),'$($HotKey)','$($IconStream)',1,$($actionReserved.OuterXml))"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
    }
}
