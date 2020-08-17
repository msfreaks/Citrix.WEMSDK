<#
    .Synopsis
    Create a new Group Policy Settings Assignment object in the WEM Database.

    .Description
    Create a new Group Policy Settings object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdObject
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Priority
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function New-WEMGroupPolicyObjectAssignment  {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdObject,
        [Parameter(Mandatory=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$True)]
        [int]$IdRule,
        [Parameter(Mandatory=$False)][ValidateRange(0,9999)]
        [int]$Priority = 50,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # check uniqueness
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM GroupPolicyAssignments WHERE IdSite = $($IdSite) AND IdObject = $($IdObject) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already an Assignment object for this combination of Group Policy Object, ADObject and Rule in the Configuration"
            Break
        }

        Write-Verbose "Assignment is unique: Continue"

        # build the query to create the assignment
        $SQLQuery = "INSERT INTO GroupPolicyAssignments (IdSite,IdObject,IdItem,IdFilterRule,Priority,IdInternal,RevisionId) VALUES ($($IdSite),$($IdObject),$($IdADObject),$($IdRule),$($Priority),'$((New-Guid).ToString().ToUpper())',1)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new assignment
        $SQLQuery = "SELECT * FROM GroupPolicyAssignments WHERE IdSite = $($IdSite) AND IdObject = $($IdObject) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        $Assignment = Get-WEMGroupPolicyObjectAssignment -Connection $Connection -IdSite $IdSite -IdObject $IdObject -IdADObject $IdADObject -IdRule $IdRule

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdObject
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Assign" -ObjectName "$($Assignment.AssignedObject.ToString()) ($($Assignment.AssignedObject.Guid.ToString().ToLower()))" -ObjectType "Assignments\Group Policy" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return $Assignment
    }
}
