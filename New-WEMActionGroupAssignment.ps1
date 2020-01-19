<#
    .Synopsis
    Create a new Action Group Assignment object in the WEM Database.

    .Description
    Create a new Action Group Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdActionGroup
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function New-WEMActionGroupAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdActionGroup,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # check uniqueness
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedActionGroups WHERE IdSite = $($IdSite) AND IdActionGroup = $($IdActionGroup) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already an Assignment object for this combination of ActionGroup, ADObject and Rule in the Configuration"
            Break
        }

        Write-Verbose "Assignment is unique: Continue"

        # grab the ActionGroup
        $actionGroupDriveLetters = @()
        $actionGroupObject = Get-WEMActionGroup -Connection $Connection -IdActionGroup $IdActionGroup

        # if the Action Group contains Drive objects, check the DriveLetter use and uniqueness
        $actionGroupDriveLetters += ($actionGroupObject.Actions | Where-Object { $_.Category -in @("Network Drive", "Virtual Drive") }).AssignmentProperties
        if ($actionGroupDriveLetters) {
            $actionGroupDriveLetters = $actionGroupDriveLetters.Replace("DriveLetter: ", "")

            # grab configuration properties
            $SQLQuery = "SELECT Value AS Exclusions FROM VUEMParameters WHERE IdSite = $($IdSite) AND Name = 'excludedDriveletters'"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            $excludedDriveletters = $result.Tables.Rows.Exclusions
            Write-Verbose "Found excluded driveletters: $($excludedDriveletters)"

            if (Compare-Object -IncludeEqual -ExcludeDifferent $actionGroupDriveletters ($excludedDriveletters -Split ";")) {
                # DriveLetter must not be Excluded
                Write-Error "One or more DriveLetters ('$((Compare-Object -IncludeEqual -ExcludeDifferent $actionGroupDriveletters ($excludedDriveletters -Split ";")).InputObject -Join ",")') is excluded in the Configuration (Exclusions: $($excludedDriveLetters.Replace(";",", ")))"
                break
            }

            $SQLQuery = "SELECT Value AS AllowReuse FROM VUEMParameters WHERE IdSite = $($IdSite) AND Name = 'AllowDriveLetterReuse'"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            $allowDriveletterReuse = [bool][int]$result.Tables.Rows.AllowReuse
            Write-Verbose "Found Driveletter Re-use setting: $([string]$allowDriveletterReuse)"
    
            # drivemapping detected, in all assignments, DriveLetter in combination with IdObject must be unique if re-use is $false
            if (-not $allowDriveletterReuse) {
                $assignedDriveletters = (Get-WEMNetworkDriveAssignment -Connection $Connection -IdSite $IdSite).AssignmentProperties
                if ($assignedDriveletters) { $assignedDriveletters = $assignedDriveletters.Replace("DriveLetter: ", "") }

                if ($assignedDriveletters -and (Compare-Object -IncludeEqual -ExcludeDifferent $actionGroupDriveletters $assignedDriveletters)) {
                    # DriveLetter must be unique
                    Write-Error "There's already a Network Drive object using DriveLetter '$((Compare-Object -IncludeEqual -ExcludeDifferent $actionGroupDriveletters $assignedDriveletters).InputObject -Join ",")' assigned to the same Active Directory object"
                    break
                }
                $assignedDriveletters = (Get-WEMVirtualDriveAssignment -Connection $Connection -IdSite $IdSite).AssignmentProperties
                if ($assignedDriveletters) { $assignedDriveletters = $assignedDriveletters.Replace("DriveLetter: ", "") }

                if ($assignedDriveletters -and (Compare-Object -IncludeEqual -ExcludeDifferent $actionGroupDriveletters $assignedDriveletters)) {
                    # DriveLetter must be unique
                    Write-Error "There's already a Virtual Drive object using DriveLetter '$((Compare-Object -IncludeEqual -ExcludeDifferent $actionGroupDriveletters $assignedDriveletters).InputObject -Join ",")' assigned to the same Active Directory object"
                    break
                }
                $assignedDriveletters = ((Get-WEMActionGroupAssignment -Connection $Connection -IdSite $IdSite).AssignedObject | Where-Object {$_.Actions.Category -in @("Network Drive", "Virtual Drive") }).AssignmentProperties
                if ($assignedDriveletters) { $assignedDriveletters = $assignedDriveletters.Replace("DriveLetter: ", "") }

                if ($assignedDriveletters -and (Compare-Object -IncludeEqual -ExcludeDifferent $actionGroupDriveletters $assignedDriveletters)) {
                    # DriveLetter must be unique
                    Write-Error "There's already an Action Group object with a drive using DriveLetter '$((Compare-Object -IncludeEqual -ExcludeDifferent $actionGroupDriveletters $assignedDriveletters).InputObject -Join ",")' assigned to the same Active Directory object"
                    break
                }
            }
        }

        # Create the assignment and grab the IdAssignedActiongroup, then use that to fill the AssignedActionGroupProperties table using the actions in the AG object

        # build the query to create the assignment
        $SQLQuery = "INSERT INTO VUEMAssignedActionGroups (IdSite,IdActionGroup,IdItem,IdFilterRule,RevisionId) VALUES ($($IdSite),$($IdActionGroup),$($IdADObject),$($IdRule),1)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new assignment
        $SQLQuery = "SELECT * FROM VUEMAssignedActionGroups WHERE IdSite = $($IdSite) AND IdActionGroup = $($IdActionGroup) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        $actionGroupAssignmentId = $result.Tables.Rows.IdAssignedActionGroup

        # select the assignment actions and insert them into AssignedActionGroupProperties
        $SQLQuery = ""
        foreach($actionGroupAction in $actionGroupObject.Actions) {
            $assignedActionProperties = "0"
            if ($actionGroupAction.AssignmentProperties) {
                switch ($actionGroupAction.Category) {
                    "Application" {
                        # calculate assignmentproperties
                        $bits = 0
                        $actionGroupAction.AssignmentProperties | ForEach-Object { $bits += $assignmentPropertiesEnum.Get_Item($_) }
                        $assignedActionProperties = [string]$bits
                        continue
                    }
                    "Printer" {
                        $assignedActionProperties = "1"
                        continue
                    }
                    "Network Drive" {
                        $assignedActionProperties = $actionGroupAction.AssignmentProperties.Replace("DriveLetter: ", "")
                        continue
                    }
                    "Virtual Drive" {
                        $assignedActionProperties = $actionGroupAction.AssignmentProperties.Replace("DriveLetter: ", "")
                        continue
                    }
                    Default {}
                }
            }

            $SQLQuery += "INSERT INTO VUEMAssignedActionGroupsProperties (IdAssignedActionGroup,ActionType,IdAction,Properties,RevisionId) VALUES ($($actionGroupAssignmentId),$($tableVUEMActionType[$actionGroupAction.Category]),$($actionGroupAction.IdAction),'$($assignedActionProperties)',1);"
        }

        # Execute the insert query
        if ($SQLQuery) { $null = Invoke-SQL -Connection $Connection -Query $SQLQuery }
        
        # grab the new assignment
        $Assignment = Get-WEMAssignment -Connection $Connection -IdAssignment $actionGroupAssignmentId -AssignmentType "Action Groups"

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdAssignedNetDrive
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $actionGroupAssignmentId -ChangeType "Assign" -ObjectName $Assignment.ToString() -ObjectType "Assignments\Action Groups" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return $Assignment
    }
}
