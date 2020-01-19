<#
    .Synopsis
    Updates a Application Assignment object in the WEM Database.

    .Description
    Updates a Application Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAction
    ..

    .Parameter IdADObject
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
function Set-WEMApplicationAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        [Parameter(Mandatory=$False)][ValidateSet("CreateDesktopLink","CreateQuickLaunchLink","CreateStartMenuLink","PinToTaskbar","PinToStartMenu","AutoStart")]
        [string[]]$AssignmentProperties,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origObject = Get-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Application"

        # only continue if the object was found
        if (-not $origObject) { 
            Write-Warning "No Application assignment found for Id $($IdAssignment)"
            Break
        }
        
        # find what needs to be changed
        $checkADObject = $null
        $checkRule = $null
        $checkProperties = $null
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idadobject') -and $IdADObject -ne $origObject.ADObject.IdADobject) { $checkADObject = $IdADObject }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idrule') -and $IdRule -ne $origObject.Rule.IdRule) { $checkRule = $IdRule }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'assignmentproperties') -and (Compare-Object -ReferenceObject $origObject.AssignmentProperties -DifferenceObject $AssignmentProperties -PassThru)) { $checkProperties = $AssignmentProperties }

        # if a new ADObject or RuleObject for the object is entered, check if it's unique
        if ($checkADObject -or $checkRule) {
            $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedApps WHERE IdSite = $($origObject.IdSite) AND IdApplication = $($origObject.IdAssignedObject)"
            if ($checkADObject) { $SQLQuery += " AND IdItem = $($checkADObject)" }
            if ($checkRule) { $SQLQuery += " AND IdFilterRule = $($checkRule)" }

            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.ObjectCount) {
                # name must be unique
                Write-Error "There's already another Application assignment matching those Ids in the Configuration"
                Break
            }

            Write-Verbose "Assignment is unique: Continue"
        }

        # build the query to update the action
        $updateFields = @()
        if ($checkADObject -or $checkRule -or $checkProperties) {
            $SQLQuery = "UPDATE VUEMAssignedApps SET "
            $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "idassignment" }
            foreach ($key in $keys) {
                switch ($key) {
                    "IdADObject" {
                        $updateFields += "IdItem = $($IdADObject)"
                        continue
                    }
                    "IdRule" {
                        $updateFields += "IdFilterRule = $($IdRule)"
                        continue
                    }
                    "AssignmentProperties" {
                        $updateFields += "isDesktop = $([string][int]($Assignmentproperties -contains "CreateDesktopLink"))"
                        $updateFields += "isQuickLaunch = $([string][int]($Assignmentproperties -contains "CreateQuickLaunchLink"))"
                        $updateFields += "isStartMenu = $([string][int]($Assignmentproperties -contains "CreateStartMenuLink"))"
                        $updateFields += "isPinToTaskbar = $([string][int]($Assignmentproperties -contains "PinToTaskbar"))"
                        $updateFields += "isPinToStartMenu = $([string][int]($Assignmentproperties -contains "PinToStartMenu"))"
                        $updateFields += "isAutoStart = $([string][int]($Assignmentproperties -contains "AutoStart"))"
                        continue
                    }
                    Default {}
                }
            }
        }
        
        # if anything needs to be updated, update the action
        if($updateFields) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            $SQLQuery += "RevisionId = $($origObject.Version + 1) WHERE IdAssignedApplication = $($IdAssignment)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # grab the updated assignment
            $SQLQuery = "SELECT * FROM VUEMAssignedApps WHERE IdAssignedApplication = $($IdAssignment)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        
            $Assignment = Get-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Application"

            # Updating the ChangeLog
            $IdObject = $result.Tables.Rows.IdAssignedApplication
            New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdObject -ChangeType "Assign" -ObjectName $Assignment.ToString() -ObjectType "Assignments\Application" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
New-Alias -Name Set-WEMAppAssignment -Value Set-WEMApplicationAssignment
