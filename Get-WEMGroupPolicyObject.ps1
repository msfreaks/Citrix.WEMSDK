<#
    .Synopsis
    Returns one or more Group Policy Settings Action objects from the WEM Database.

    .Description
    Returns one or more Group Policy Settings Action objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdObject
    ..

    .Parameter Name
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMGroupPolicyObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdObject,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name

        # build query
        $SQLQuery = "SELECT * FROM GroupPolicyObjects"
        if ($IdSite -or $Name -or $IdObject) {
            $SQLQuery += " WHERE "
            if ($IdSite) { 
                $SQLQuery += "IdSite = $($IdSite)"
                if ($Name -or $IdObject) { $SQLQuery += " AND " }
            }
            if ($IdObject) { 
                $SQLQuery += "IdObject = $($IdObject)"
                if ($Name) { $SQLQuery += " AND " }
            }
            if ($Name) { $SQLQuery += "Name LIKE '$($Name.Replace("*","%"))'"}
        }
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # build array of VUEMGroupPolicyObjects returned by the query
        $vuemGPOs = @()
        foreach ($row in $result.Tables.Rows) { $vuemGPOs += New-VUEMGroupPolicySettingsObject -DataRow $row -Connection $Connection }

        return $vuemGPOs
    }
}

