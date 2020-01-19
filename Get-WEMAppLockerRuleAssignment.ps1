<#
    .Synopsis
    Returns one or more AppLocker Rule Assignment objects from the WEM Database.

    .Description
    Returns one or more AppLocker Rule Assignment objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdAssigedAppLockerRule
    ..

    .Parameter IdADObject
    ..

    .Parameter IdRule
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMAppLockerRuleAssignment {
    param(
        [Parameter(Mandatory=$False,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite = $null,
        [Parameter(Mandatory=$False,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAssigedAppLockerRule = $null,
        [Parameter(Mandatory=$False,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
		[int]$IdADObject = $null,
        [Parameter(Mandatory=$False,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
		[int]$IdRule = $null,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    # build query
    $SQLQuery = "SELECT * FROM AppLockerRuleAssignments"
    $SQLQueryFields = @()

    if ($IdSite) { $SQLQueryFields += "IdSite = $($IdSite)" }
    if ($IdAssigedAppLockerRule) { $SQLQueryFields += "IdAssigedAppLockerRule = $($IdAssigedAppLockerRule)" }
    if ($IdADObject) { $SQLQueryFields += "IdItem = $($IdADObject)" }
    if ($IdRule) { $SQLQueryFields += "IdAppLockerRule = $($IdRule)" }

    if ($SQLQueryFields) {
        $SQLQuery += " WHERE "
        $SQLQuery += $SQLQueryFields -Join " AND "
    }

    $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

    $vuemADObjects = @()
    foreach ($row in $result.Tables.Rows) { $vuemADObjects += Get-WEMADUserObject -Connection $Connection -IdSite $row.IdSite -IdADObject $row.Iditem }

    return $vuemADObjects
}