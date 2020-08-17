<#
    .Synopsis
    Updates a Group Policy Settings Assignment object in the WEM Database.

    .Description
    Updates a Group Policy Settings Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdObject
    ..

    .Parameter IdADObject
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
function Set-WEMGroupPolicyObjectAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        [Parameter(Mandatory=$False)][ValidateRange(0,9999)]
        [int]$Priority,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # grab original object
        $origObject = Get-WEMGroupPolicyObjectAssignment -Connection $Connection -IdAssignment $IdAssignment

        # only continue if the object was found
        if (-not $origObject) { 
            Write-Warning "No Group Policy Object assignment found for Id $($IdAssignment)"
            Break
        }
        
        # find what needs to be changed
        $checkADObject = $null
        $checkRule = $null
        $checkProperties = $false
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idadobject') -and $IdADObject -ne $origObject.ADObject.IdADobject) { $checkADObject = $IdADObject }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idrule') -and $IdRule -ne $origObject.Rule.IdRule) { $checkRule = $IdRule }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'priority') -and $Priotiry -ne $origObject.Priority) { $checkProperties = $true }

        # if a new ADObject or RuleObject for the object is entered, check if it's unique
        if ($checkADObject -or $checkRule) {
            $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM GroupPolicyAssignments WHERE IdSite = $($origObject.IdSite) AND IdObject = $($origObject.IdAssignedObject)"
            if ($checkADObject) { $SQLQuery += " AND IdItem = $($checkADObject)" }
            if ($checkRule) { $SQLQuery += " AND IdFilterRule = $($checkRule)" }

            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.ObjectCount) {
                # name must be unique
                Write-Error "There's already another Group Policy Object assignment matching those Ids in the Configuration"
                Break
            }

            Write-Verbose "Assignment is unique: Continue"
        }

        # build the query to update the action
        $updateFields = @()
        if ($checkADObject -or $checkRule -or $checkProperties) {
            $SQLQuery = "UPDATE GroupPolicyAssignments SET "
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
                    "Priority" {
                        $updateFields += "Priority = $($Priority)"
                        continue
                    }
                    Default {}
                }
            }
        }
        
        # if anything needs to be updated, update the action
        if($updateFields) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            $SQLQuery += "RevisionId = $($origObject.Version + 1) WHERE IdAssignment = $($IdAssignment)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # grab the updated assignment
            $SQLQuery = "SELECT * FROM GroupPolicyAssignments WHERE IdAssignment = $($IdAssignment)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
    
            $Assignment = Get-WEMGroupPolicyObjectAssignment -Connection $Connection -IdAssignment $IdAssignment

            # Updating the ChangeLog
            $IdObject = $result.Tables.Rows.IdAssignment
            New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdObject -ChangeType "Update" -ObjectName "$($Assignment.AssignedObject.ToString()) ($($Assignment.AssignedObject.Guid.ToString().ToLower()))" -ObjectType "Assignments\Group Policy" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
