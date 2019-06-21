<#
    .Synopsis
    Removes a WEM Assignment object from the WEM Database.

    .Description
    Removes a WEM Assignment object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAssignment
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
function Remove-WEMAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)][ValidateSet("Application","Printer","Network Drive","Virtual Drive","Registry Value","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association","Action Groups")]
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
            Write-Warning "No Assignment Object found for Id $($IdAssignment) of type $($AssignmentType)"
            Break
        }

        # build query
        $SQLQuery = "DELETE FROM VUEMAssigned$($tableVUEMActionCategory[$AssignmentType]) WHERE $($tableVUEMActionCategoryId[$AssignmentType]) = $($origObject.IdAssignedObject) AND IdItem = $($origObject.ADObject.IdADObject)"
        write-verbose $SQLQuery
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdAssignment -ChangeType "Unassign" -ObjectName $origObject.ToString() -ObjectType "Assignments\$($AssignmentType)" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        #>
    }
}
