<#
    .Synopsis
    Retrieves WEM Apps from WEM Database.

    .Description
    Retrieves WEM Apps from WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdApplication
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMApp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$IdApplication,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # build query
        $SQLQuery = "SELECT * FROM VUEMApps"
        if ($IdSite -or $Name -or $IdApplication) {
            $SQLQuery += " WHERE "
            if ($IdSite) { 
                $SQLQuery += "IdSite = $($IdSite)"
                if ($Name -or $IdApplication) { $SQLQuery += " AND " }
            }
            if ($IdApplication) { 
                $SQLQuery += "IdApplication = $($IdApplication)"
                if ($Name) { $SQLQuery += " AND " }
            }
            if ($Name) { $SQLQuery += "Name LIKE '$($Name.Replace("*","%"))'"}
        }
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # build array of VUEMApps returned by the query
        $vuemApps = @()

        foreach ($row in $result.Tables.Rows) {
            $vuemAppReserved = $row.Reserved01
            [xml]$vuemAppXml = $vuemAppReserved.Substring($vuemAppReserved.ToLower().IndexOf("<array"))
            $vuemApps += [pscustomobject] @{
                'IdApplication' = [int]$row.IdApplication
                'IdSite' = [int]$row.IdSite
                'Name' = [string]$row.Name
                'DisplayName' = [string]$row.DisplayName
                'Description' = [string]$row.Description
                'State' = [int]$row.State
                'Type' = [int]$row.AppType
                'Action' = [int]$row.ActionType
                'StartMenuTarget' = [string]$row.StartMenuTarget
                'TargetPath' = [string]$row.TargetPath
                'Parameters' = [string]$row.Parameters
                'WorkingDirectory' = [string]$row.WorkingDirectory
                'WindowStyle' = [string]$row.WindowStyle
                'HotKey' = [string]$row.Hotkey
                'IconLocation' = [string]$row.IconLocation
                'IconIndex' = [int]$row.IconIndex
                'IconStream' = [string]$row.IconStream
                'SelfHealingEnabled' = [int]($vuemAppXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "SelfHealingEnabled"}).Value
                'EnforceIconLocation' = [int]($vuemAppXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforceIconLocation"}).Value
                'EnforceIconXLocation' = [int]($vuemAppXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforceIconXLocation"}).Value
                'EnforceIconYLocation' = [int]($vuemAppXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "EnforceIconYLocation"}).Value
                'DoNotShowInSelfService' = [int]($vuemAppXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "DoNotShowInSelfService"}).Value
                'CreateShortcutInUserFavoritesFolder' = [int]($vuemAppXml.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "CreateShortcutInUserFavoritesFolder"}).Value
                'Version' = [int]$row.RevisionId
            }
        }

        Return $vuemApps
    }
}
