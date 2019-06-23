<#
    .Synopsis
    Updates a WEM Network Drive Assignment object in the WEM Database.

    .Description
    Updates a WEM Network Drive Assignment object in the WEM Database.

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

    .Parameter DriveLetter
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMVirtualDriveAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        [Parameter(Mandatory=$False)][ValidatePattern('^[a-zA-Z]+$')][ValidateLength(1,1)]
        [string]$DriveLetter,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origObject = Get-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Virtual Drive"

        # only continue if the object was found
        if (-not $origObject) { 
            Write-Warning "No Virtual Drive assignment found for Id $($IdAssignment)"
            Break
        }
        
        # find what needs to be changed
        $checkADObject = $null
        $checkRule = $null
        $checkProperties = $false
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idadobject') -and $IdADObject -ne $origObject.ADObject.IdADobject) { $checkADObject = $IdADObject }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idrule') -and $IdRule -ne $origObject.Rule.IdRule) { $checkRule = $IdRule }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'driveletter') -and $DriveLetter.ToUpper() -ne $origObject.AssignmentProperties.Replace("DriveLetter: ","")) { $checkProperties = $true }

        # if a new ADObject or RuleObject for the object is entered, check if it's unique
        if ($checkADObject -or $checkRule) {
            $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedVirtualDrives WHERE IdSite = $($origObject.IdSite) AND IdVirtualDrive = $($origObject.IdAssignedObject)"
            if ($checkADObject) { $SQLQuery += " AND IdItem = $($checkADObject)" }
            if ($checkRule) { $SQLQuery += " AND IdFilterRule = $($checkRule)" }

            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.ObjectCount) {
                # name must be unique
                Write-Error "There's already another Virtual Drive assignment matching those Ids in the Configuration"
                Break
            }

            Write-Verbose "Assignment is unique: Continue"
        }

        # if a driveletter was entered check if driveletter is allowed
        if ($checkProperties -or $IdADObject) {
            if ($IdADObject -and -not $checkProperties) { $DriveLetter = $origObject.AssignmentProperties.Replace("DriveLetter: ","")}
            $DriveLetter = $DriveLetter.ToUpper()

            # if IdObject was entered, we should check that, else check original object id
            $idItem = $origObject.ADObject.IdADObject
            if ($checkADObject) { $idItem = $checkADObject}

            # grab configuration properties
            $SQLQuery = "SELECT Value AS Exclusions FROM VUEMParameters WHERE IdSite = $($origObject.IdSite) AND Name = 'excludedDriveletters'"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            $excludedDriveletters = $result.Tables.Rows.Exclusions
            Write-Verbose "Found excluded driveletters: $($excludedDriveletters)"
    
            # DriveLetter must not be excluded in the Configuration
            if (($excludedDriveLetters -split ";") -contains $DriveLetter) {
                # DriveLetter must not be Excluded
                Write-Error "DriveLetter '$($DriveLetter)' is excluded in the Configuration (Exclusions: $($excludedDriveLetters.Replace(";",", ")))"
                break
            }
    
            $SQLQuery = "SELECT Value AS AllowReuse FROM VUEMParameters WHERE IdSite = $($origObject.IdSite) AND Name = 'AllowDriveLetterReuse'"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            $allowDriveletterReuse = [bool][int]$result.Tables.Rows.AllowReuse
            Write-Verbose "Found Driveletter Re-use setting: $([string]$allowDriveletterReuse)"
    
            # drivemapping detected, in all assignments, DriveLetter in combination with IdObject must be unique if re-use is $false
            if (-not $allowDriveletterReuse) {
                $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedNetDrives WHERE IdSite = $($origObject.IdSite) AND IdItem = $($idItem) AND DriveLetter = '$($DriveLetter)'"
                $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                if ($result.Tables.Rows.ObjectCount) {
                    # DriveLetter must be unique
                    Write-Error "There's already a Network Drive object using DriveLetter '$($DriveLetter)' assigned to that Active Directory object"
                    break
                }
                $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedVirtualDrives WHERE IdSite = $($origObject.IdSite) AND IdItem = $($idItem) AND DriveLetter = '$($DriveLetter)'"
                $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                if ($result.Tables.Rows.ObjectCount) {
                    # DriveLetter must be unique
                    Write-Error "There's already a Virtual Drive object using DriveLetter '$($DriveLetter)' assigned to that Active Directory object"
                    break
                }
                $foundLetter = $false
                $SQLQuery = "SELECT IdAssignedActionGroup FROM VUEMAssignedActionGroups WHERE IdSite = $($origObject.IdSite) AND IdItem = $($idItem)"
                $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                foreach($row in $result.Tables.Rows) {
                    $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedActionGroupsProperties WHERE IdAssignedActionGroup = $($row.IdAssignedActionGroup) AND Properties = '$($DriveLetter)'"
                    $subResult = Invoke-SQL -Connection $Connection -Query $SQLQuery
                    if ($subResult.Tables.Rows.ObjectCount) {
                        # DriveLetter must be unique
                        $foundLetter = $true
                        Write-Error "There's already an object in an Action Group using DriveLetter '$($DriveLetter)' assigned to that Active Directory object"
                        break
                    }
                }
                if($foundLetter) { break }
            }
        }

        # build the query to update the action
        $updateFields = @()
        if ($checkADObject -or $checkRule -or $checkProperties) {
            $SQLQuery = "UPDATE VUEMAssignedVirtualDrives SET "
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
                    "DriveLetter" {
                        $updateFields += "DriveLetter = '$($DriveLetter)'"
                        continue
                    }
                    Default {}
                }
            }
        }
        
        # if anything needs to be updated, update the action
        if($updateFields) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            $SQLQuery += "RevisionId = $($origObject.Version + 1) WHERE IdAssignedVirtualDrive = $($IdAssignment)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # grab the updated assignment
            $SQLQuery = "SELECT * FROM VUEMAssignedVirtualDrives WHERE IdAssignedVirtualDrive = $($IdAssignment)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

            $Assignment = Get-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Virtual Drive"

            # Updating the ChangeLog
            $IdObject = $result.Tables.Rows.IdAssignedVirtualDrive
            New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdObject -ChangeType "Assign" -ObjectName $Assignment.ToString() -ObjectType "Assignments\Virtual Drive" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
