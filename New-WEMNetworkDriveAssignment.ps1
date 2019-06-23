<#
    .Synopsis
    Create a new Network Drive Assignment object in the WEM Database.

    .Description
    Create a new Network Drive Assignment object in the WEM Database.

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

    .Parameter DriveLetter
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMNetworkDriveAssignment {
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
        [Parameter(Mandatory=$True)][ValidatePattern('^[a-zA-Z]+$')][ValidateLength(1,1)]
        [string]$DriveLetter,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # check uniqueness
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedNetDrives WHERE IdSite = $($IdSite) AND IdNetDrive = $($IdAction) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already an Assignment object for this combination of Action, ADObject and Rule in the Configuration"
            Break
        }

        Write-Verbose "Assignment is unique: Continue"

        # check if driveletter is allowed
        $DriveLetter = $DriveLetter.ToUpper()

        # grab configuration properties
        $SQLQuery = "SELECT Value AS Exclusions FROM VUEMParameters WHERE IdSite = $($IdSite) AND Name = 'excludedDriveletters'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        $excludedDriveletters = $result.Tables.Rows.Exclusions
        Write-Verbose "Found excluded driveletters: $($excludedDriveletters)"

        # DriveLetter must not be excluded in the Configuration
        if (($excludedDriveLetters -split ";") -contains $DriveLetter) {
            # DriveLetter must not be Excluded
            Write-Error "DriveLetter '$($DriveLetter)' is excluded in the Configuration (Exclusions: $($excludedDriveLetters.Replace(";",", ")))"
            break
        }

        $SQLQuery = "SELECT Value AS AllowReuse FROM VUEMParameters WHERE IdSite = $($IdSite) AND Name = 'AllowDriveLetterReuse'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        $allowDriveletterReuse = [bool][int]$result.Tables.Rows.AllowReuse
        Write-Verbose "Found Driveletter Re-use setting: $([string]$allowDriveletterReuse)"

        # drivemapping detected, in all assignments, DriveLetter in combination with IdObject must be unique if re-use is $false
        if (-not $allowDriveletterReuse) {
            $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedNetDrives WHERE IdSite = $($IdSite) AND IdItem = $($IdADObject) AND DriveLetter = '$($DriveLetter)'"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.ObjectCount) {
                # DriveLetter must be unique
                Write-Error "There's already a Network Drive object using DriveLetter '$($DriveLetter)' assigned to the same Active Directory object"
                break
            }
            $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedVirtualDrives WHERE IdSite = $($IdSite) AND IdItem = $($IdADObject) AND DriveLetter = '$($DriveLetter)'"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.ObjectCount) {
                # DriveLetter must be unique
                Write-Error "There's already a Virtual Drive object using DriveLetter '$($DriveLetter)' assigned to the same Active Directory object"
                break
            }
            $foundLetter = $false
            $SQLQuery = "SELECT IdAssignedActionGroup FROM VUEMAssignedActionGroups WHERE IdSite = $($IdSite) AND IdItem = $($IdADObject)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            foreach($row in $result.Tables.Rows) {
                $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedActionGroupsProperties WHERE IdAssignedActionGroup = $($row.IdAssignedActionGroup) AND Properties = '$($DriveLetter)'"
                $subResult = Invoke-SQL -Connection $Connection -Query $SQLQuery
                if ($subResult.Tables.Rows.ObjectCount) {
                    # DriveLetter must be unique
                    $foundLetter = $true
                    Write-Error "There's already an object in an Action Group using DriveLetter '$($DriveLetter)' assigned to the same Active Directory object"
                    break
                }
            }
            if($foundLetter) { break }
        }

        # build the query to create the assignment
        $SQLQuery = "INSERT INTO VUEMAssignedNetDrives (IdSite,IdNetDrive,IdItem,IdFilterRule,DriveLetter,RevisionId) VALUES ($($IdSite),$($IdAction),$($IdADObject),$($IdRule),'$($DriveLetter)',1)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new assignment
        $SQLQuery = "SELECT * FROM VUEMAssignedNetDrives WHERE IdSite = $($IdSite) AND IdNetDrive = $($IdAction) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        $Assignment = Get-WEMNetWorkDriveAssignment -Connection $Connection -IdSite $IdSite -IdAction $IdAction -IdADObject $IdADObject -IdRule $IdRule

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdAssignedNetDrive
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Assign" -ObjectName $Assignment.ToString() -ObjectType "Assignments\Network Drive" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return $Assignment
    }
}
New-Alias -Name New-WEMNetDriveAssignment -Value New-WEMNetworkDriveAssignment