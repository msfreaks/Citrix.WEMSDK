<#
    .Synopsis
    Create a new Printer Assignment object in the WEM Database.

    .Description
    Create a new Printer Assignment object in the WEM Database.

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

    .Parameter SetAsDefault
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function New-WEMPrinterAssignment {
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
        [Parameter(Mandatory=$False)]
        [bool]$SetAsDefault = $false,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # check uniqueness
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAssignedPrinters WHERE IdSite = $($IdSite) AND IdPrinter = $($IdAction) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already an Assignment object for this combination of Action, ADObject and Rule in the Configuration"
            Break
        }

        Write-Verbose "Assignment is unique: Continue"

        # build the query to create the assignment
        $SQLQuery = "INSERT INTO VUEMAssignedPrinters (IdSite,IdPrinter,IdItem,IdFilterRule,isDefault,RevisionId) VALUES ($($IdSite),$($IdAction),$($IdADObject),$($IdRule),$([string][int]$SetAsDefault),1)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new assignment
        $SQLQuery = "SELECT * FROM VUEMAssignedPrinters WHERE IdSite = $($IdSite) AND IdPrinter = $($IdAction) AND IdItem = $($IdADObject) AND IdFilterRule = $($IdRule)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        $Assignment = Get-WEMPrinterAssignment -Connection $Connection -IdSite $IdSite -IdAction $IdAction -IdADObject $IdADObject -IdRule $IdRule

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdAssignedPrinter
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Assign" -ObjectName $Assignment.ToString() -ObjectType "Assignments\Printer" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return $Assignment
    }
}
