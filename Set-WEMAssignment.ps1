<#
    .Synopsis
    Updates a WEM Assignment object in the WEM Database.

    .Description
    Updates a WEM Assignment object in the WEM Database.

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

    .Parameter AssignmentType
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        [Parameter(Mandatory=$False)][ValidateSet("Registry Value","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association")]
        [string]$AssignmentType,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origObject = Get-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType $AssignmentType

        # only continue if the object was found
        if (-not $origObject) { 
            Write-Warning "No $($AssignmentType) assignment found for Id $($IdAssignment)"
            Break
        }
        
        # find what needs to be changed
        $checkADObject = $null
        $checkRule = $null
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idadobject') -and $IdADObject -ne $origObject.ADObject.IdADobject) { $checkADObject = $IdADObject }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idrule') -and $IdRule -ne $origObject.Rule.IdRule) { $checkRule = $IdRule }

        # if a new ADObject or RuleObject for the object is entered, check if it's unique
        if ($checkADObject -or $checkRule) {
            $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssigned$($tableVUEMActionCategory[$AssignmentType]) WHERE IdSite = $($origObject.IdSite) AND $($tableVUEMActionCategoryId[$AssignmentType]) = $($origObject.IdAssignedObject)"
            if ($checkADObject) { $SQLQuery += " AND IdItem = $($checkADObject)" }
            if ($checkRule) { $SQLQuery += " AND IdFilterRule = $($checkRule)" }

            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.ObjectCount) {
                # name must be unique
                Write-Error "There's already another $($AssignmentType) assignment matching those Ids in the Configuration"
                Break
            }

            Write-Verbose "Assignment is unique: Continue"
        }

        # build the query to update the action
        $updateFields = @()
        if ($checkADObject -or $checkRule -or $checkProperties) {
            $SQLQuery = "UPDATE VUEMAssigned$($tableVUEMActionCategory[$AssignmentType]) SET "
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
                    Default {}
                }
            }
        }
        
        # if anything needs to be updated, update the action
        if($updateFields) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            $SQLQuery += "RevisionId = $($origObject.Version + 1) WHERE $($tableVUEMActionCategoryId[$AssignmentType].Replace("Id", "IdAssigned")) = $($IdAssignment)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # grab the new assignment
            $SQLQuery = "SELECT $($tableVUEMActionCategoryId[$AssignmentType].Replace("Id", "IdAssigned")) AS IdAssignment,* FROM VUEMAssigned$($tableVUEMActionCategory[$AssignmentType]) WHERE $($tableVUEMActionCategoryId[$AssignmentType].Replace("Id", "IdAssigned")) = $($IdAssignment)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

            $Assignment = Get-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType $AssignmentType

            # Updating the ChangeLog (use ID for the assignment, not the action!)
            $IdObject = $result.Tables.Rows.IdAssignment
            New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdObject -ChangeType "Assign" -ObjectName $Assignment.ToString() -ObjectType "Assignments\$($AssignmentType)" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}

<#
    .Synopsis
    Updates a Registry Entry Assignment object in the WEM Database.

    .Description
    Updates a Registry Entry Assignment object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
    ..

    .Parameter IdAdObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMRegistryEntryAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        $AssignmentType = "Registry Value"

        return Set-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $AssignmentType
    }
}
New-Alias -Name Set-WEMRegValueAssignment -Value Set-WEMRegistryEntryAssignment

