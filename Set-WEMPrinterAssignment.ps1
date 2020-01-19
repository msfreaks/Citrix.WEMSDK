<#
    .Synopsis
    Updates a Printer Assignment object in the WEM Database.

    .Description
    Updates a Printer Assignment object in the WEM Database.

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

    .Parameter SetAsDefault
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMPrinterAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [int]$IdRule,
        [Parameter(Mandatory=$False)]
        [bool]$SetAsDefault,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origObject = Get-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Printer"

        # only continue if the object was found
        if (-not $origObject) { 
            Write-Warning "No Printer assignment found for Id $($IdAssignment)"
            Break
        }
        
        # find what needs to be changed
        $checkADObject = $null
        $checkRule = $null
        $checkProperties = $false
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idadobject') -and $IdADObject -ne $origObject.ADObject.IdADobject) { $checkADObject = $IdADObject }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idrule') -and $IdRule -ne $origObject.Rule.IdRule) { $checkRule = $IdRule }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'setasdefault') -and $SetAsDefault -ne ($origObject.AssignmentProperties -like "SetAsDefault")) { $checkProperties = $true }

        # if a new ADObject or RuleObject for the object is entered, check if it's unique
        if ($checkADObject -or $checkRule) {
            $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedPrinters WHERE IdSite = $($origObject.IdSite) AND IdPrinter = $($origObject.IdAssignedObject)"
            if ($checkADObject) { $SQLQuery += " AND IdItem = $($checkADObject)" }
            if ($checkRule) { $SQLQuery += " AND IdFilterRule = $($checkRule)" }

            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.ObjectCount) {
                # name must be unique
                Write-Error "There's already another Printer assignment matching those Ids in the Configuration"
                Break
            }

            Write-Verbose "Assignment is unique: Continue"
        }

        # build the query to update the action
        $updateFields = @()
        if ($checkADObject -or $checkRule -or $checkProperties) {
            $SQLQuery = "UPDATE VUEMAssignedPrinters SET "
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
                    "SetAsDefault" {
                        $updateFields += "isDefault = $([string][int]$SetAsDefault)"
                        continue
                    }
                    Default {}
                }
            }
        }

        # if anything needs to be updated, update the action
        if($updateFields) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            $SQLQuery += "RevisionId = $($origObject.Version + 1) WHERE IdAssignedPrinter = $($IdAssignment)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # grab the updated assignment
            $SQLQuery = "SELECT * FROM VUEMAssignedPrinters WHERE IdAssignedPrinter = $($IdAssignment)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
    
            $Assignment = Get-WEMAssignment -Connection $Connection -IdAssignment $IdAssignment -AssignmentType "Printer"

            # Updating the ChangeLog
            $IdObject = $result.Tables.Rows.IdAssignedPrinter
            New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdObject -ChangeType "Assign" -ObjectName $Assignment.ToString() -ObjectType "Assignments\Printer" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
