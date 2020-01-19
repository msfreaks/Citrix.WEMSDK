<#
    .Synopsis
    Create a new Application Assignment object in the WEM Database.

    .Description
    Create a new Application Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAction
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter AssignmentProperties
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function New-WEMApplicationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,
        [Parameter(Mandatory=$False)][ValidateSet("CreateDesktopLink","CreateQuickLaunchLink","CreateStartMenuLink","PinToTaskbar","PinToStartMenu","AutoStart")]
        [string[]]$AssignmentProperties = "CreateStartMenuLink",

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # check uniqueness
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedApps WHERE IdSite = $($IdSite) AND IdApplication = $($IdAction) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already an Assignment object for this combination of Action, ADObject and Rule in the Configuration"
            Break
        }

        Write-Verbose "Assignment is unique: Continue"

        # build the query to create the assignment
        $SQLQuery = "INSERT INTO VUEMAssignedApps (IdSite,IdApplication,IdItem,IdFilterRule,isDesktop,isQuickLaunch,isStartMenu,isPinToTaskbar,isPinToStartMenu,isAutoStart,RevisionId) VALUES ($($IdSite),$($IdAction),$($IdADObject),$($IdRule),$([string][int]($Assignmentproperties -contains "CreateDesktopLink")),$([string][int]($Assignmentproperties -contains "CreateQuickLaunchLink")),$([string][int]($Assignmentproperties -contains "CreateStartMenuLink")),$([string][int]($Assignmentproperties -contains "PinToTaskbar")),$([string][int]($Assignmentproperties -contains "PinToStartMenu")),$([string][int]($Assignmentproperties -contains "AutoStart")),1)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new assignment
        $SQLQuery = "SELECT * FROM VUEMAssignedApps WHERE IdSite = $($IdSite) AND IdApplication = $($IdAction) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        $Assignment = Get-WEMApplicationAssignment -Connection $Connection -IdSite $IdSite -IdAction $IdAction -IdADObject $IdADObject -IdRule $IdRule

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdAssignedApplication
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Assign" -ObjectName $Assignment.ToString() -ObjectType "Assignments\Application" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return $Assignment
    }
}
New-Alias -Name New-WEMAppAssignment -Value New-WEMApplicationAssignment
