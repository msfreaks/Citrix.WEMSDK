<#
    .Synopsis
    Returns one or more WEM AppLocker Rule Assignment objects from the WEM Database.

    .Description
    Returns one or more WEM AppLocker Rule Assignment objects from the WEM Database.

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
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Get-WEMAppLockerRuleAssignment {
    param(
        [int]$IdSite = $null,
        [int]$IdAssigedAppLockerRule = $null,
		[int]$IdADObject = $null,
		[int]$IdRule = $null,
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