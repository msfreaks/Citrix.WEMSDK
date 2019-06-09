function Set-WEMApp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdApplication,

        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$DisplayName,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [string]$Description,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
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
        [int]$SelfHealingEnabled,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$EnforceIconLocation,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$EnforceIconXLocation,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$EnforceIconYLocation,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$DoNotShowInSelfService,
        [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True)]
        [int]$CreateShortcutInUserFavoritesFolder,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $origAction = Get-WEMApp -Connection $Connection -IdApplication $IdApplication

        $SQLQuery = "UPDATE VUEMApps SET "
        $updateFields = @()
        $updateAdvanced = $false
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "IdApplication" }
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
                    $updateFields += "State = $($State)"
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
                    continue
                }
                "EnforceIconLocation" {
                    $updateAdvanced = $True
                    continue
                }
                "EnforcedIconXValue" {
                    $updateAdvanced = $True
                    continue
                }
                "EnforcedIconYValue" {
                    $updateAdvanced = $True
                    continue
                }
                "DoNotShowInSelfService" {
                    $updateAdvanced = $True
                    continue
                }
                "CreateShortcutInUserFavoritesFolder" {
                    $updateAdvanced = $True
                    continue
                }
                Default {}
            }
        }

        $updateReserved = '<?xml version="1.0" encoding="utf-8"?><ArrayOfVUEMActionAdvancedOption xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><VUEMActionAdvancedOption><Name>SelfHealingEnabled</Name><Value>'
        if ([bool]($keys -match "SelfHealingEnabled")) {
            $updateReserved += $SelfHealingEnabled
        } else {
            $updateReserved += $origAction.SelfHealingEnabled
        }
        $updateReserved += '</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>EnforceIconLocation</Name><Value>'
        if ([bool]($keys -match "EnforceIconLocation")) {
            $updateReserved += $EnforceIconLocation
        } else {
            $updateReserved += $origAction.EnforceIconLocation
        }
        $updateReserved += '</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>EnforcedIconXValue</Name><Value>'
        if ([bool]($keys -match "EnforcedIconXValue")) {
            $updateReserved += $EnforcedIconXValue
        } else {
            $updateReserved += $origAction.EnforcedIconXValue
        }
        $updateReserved += '</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>EnforcedIconYValue</Name><Value>'
        if ([bool]($keys -match "EnforcedIconYValue")) {
            $updateReserved += $EnforcedIconYValue
        } else {
            $updateReserved += $origAction.EnforcedIconYValue
        }
        $updateReserved += '</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>DoNotShowInSelfService</Name><Value>'
        if ([bool]($keys -match "DoNotShowInSelfService")) {
            $updateReserved += $DoNotShowInSelfService
        } else {
            $updateReserved += $origAction.DoNotShowInSelfService
        }
        $updateReserved += '</Value></VUEMActionAdvancedOption><VUEMActionAdvancedOption><Name>CreateShortcutInUserFavoritesFolder</Name><Value>'
        if ([bool]($keys -match "CreateShortcutInUserFavoritesFolder")) {
            $updateReserved += $CreateShortcutInUserFavoritesFolder
        } else {
            $updateReserved += $origAction.CreateShortcutInUserFavoritesFolder
        }
        $updateReserved += '</Value></VUEMActionAdvancedOption></ArrayOfVUEMActionAdvancedOption>'

        if($updateFields -or $updateAdvanced) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            if ($updateAdvanced) { $SQLQuery += "Reserved01 = '$($updateReserved)', " }
            $SQLQuery += "RevisionId = $($origAction.Version + 1) WHERE IdApplication = $($IdApplication)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
