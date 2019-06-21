<#
    .Synopsis
    Returns one or more WEM Assignment objects from the WEM Database.

    .Description
    Returns one or more WEM Assignment objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAssignment
    ..

    .Parameter AssignmentType
    ..

    .Parameter IdAssigntObject
    ..

    .Parameter IdADObject
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
function Get-WEMAssignment {
    [CmdletBinding(DefaultParameterSetName="None")]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False)]
        [int]$IdAssignment,
        [Parameter(Mandatory=$False)][ValidateSet("Application","Printer","Network Drive","Virtual Drive","Registry Value","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association","Action Groups")]
        [string]$AssignmentType,
        [Parameter(Mandatory=$False)]
		[int]$IdAssignedObject,
        [Parameter(Mandatory=$False)]
		[int]$IdADObject,
        [Parameter(Mandatory=$False)]
		[int]$IdRule,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # $MyInvocation.BoundParameters.Keys -match

        # if a single type was specified, process only that type. if not, process all types
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'assignmenttype')) {
            Write-Verbose "Limiting result to type '$($AssignmentType)'"
            $vuemAssignmentTypes = @("$($AssignmentType)")
        } else {
            $vuemAssignmentTypes = @("Application","Printer","Network Drive","Virtual Drive","Registry Value","Environment Variable","Port","Ini File Operation","External Task","File System Operation","User DSN","File Association","Action Groups")
        }

        # create empty object array
        $vuemAssignments = @()
        foreach ($vuemAssignmentType in $vuemAssignmentTypes) {
            Write-Verbose "Processing type '$vuemAssignmentType'"
            $vuemAssignments += Get-WEMAssignmentsByType -Connection $Connection -IdSite $IdSite -IdAssignment $IdAssignment -IdAssignedObject $IdAssignedObject -IdADObject $IdADObject -IdRule $IdRule -AssignmentType $vuemAssignmentType
        }

        return $vuemAssignments
    }
}

<#
    .Synopsis
    Helper function that returns one or more WEM Action objects from the WEM Database.

    .Description
    Helper function that returns one or more WEM Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAssignment
    ..

    .Parameter AssignmentType
    ..

    .Parameter IdAssignedObject
    ..

    .Parameter IdADObject
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
function Get-WEMAssignmentsByType {
    param(
        [int]$IdSite = $null,
        [int]$IdAssignment = $null,
        [string]$AssignmentType,
		[int]$IdAssignedObject = $null,
		[int]$IdADObject = $null,
		[int]$IdRule = $null,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    # build query
    $SQLQuery = "SELECT $($tableVUEMActionCategoryId[$AssignmentType].Replace("Id", "IdAssigned")) AS IdAssignment, $($tableVUEMActionCategoryId[$AssignmentType]) AS IdAssignedObject,* FROM VUEMAssigned$($tableVUEMActionCategory[$AssignmentType])"
    $SQLQueryFields = @()

    if ($IdSite) { $SQLQueryFields += "IdSite = $($IdSite)" }
    if ($IdAssignment) { $SQLQueryFields += "$($tableVUEMActionCategoryId[$AssignmentType].Replace("Id", "IdAssigned")) = $($IdAssignment)" }
    if ($IdAssignedObject) { $SQLQueryFields += "$($tableVUEMActionCategoryId[$AssignmentType]) = $($IdAssignedObject)" }
    if ($IdADObject) { $SQLQueryFields += "IdItem = $($IdADObject)" }
    if ($IdRule) { $SQLQueryFields += "IdFilterRule = $($IdRule)" }

    if ($SQLQueryFields) {
        $SQLQuery += " WHERE "
        $SQLQuery += $SQLQueryFields -Join " AND "
    }

    $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

    $vuemAssignments = @()
    foreach ($row in $result.Tables.Rows) { $vuemAssignments += New-VUEMAssignmentObject -DataRow $row -AssignmentType $AssignmentType -Connection $Connection }

    return $vuemAssignments
}