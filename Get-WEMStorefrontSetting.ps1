<#
    .Synopsis
    Returns one or more Storefront Setting objects from the WEM Database.

    .Description
    Returns one or more Storefront Setting objects from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter StorefrontUrl
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMStorefrontSetting {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdStorefrontSetting,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$StorefrontUrl,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # build query
        $SQLQuery = "SELECT * FROM VUEMStorefrontSettings"
        if ($IdSite -or $StorefrontUrl -or $IdStorefrontSetting) {
            $SQLQuery += " WHERE "
            if ($IdSite) { 
                $SQLQuery += "IdSite = $($IdSite)"
                if ($StorefrontUrl -or $IdStorefrontSetting) { $SQLQuery += " AND " }
            }
            if ($IdStorefrontSetting) { 
                $SQLQuery += "IdItem = $($IdStorefrontSetting)"
                if ($StorefrontUrl) { $SQLQuery += " AND " }
            }
            if ($StorefrontUrl) { $SQLQuery += "Url LIKE '$($StorefrontUrl.Replace("*","%").Replace("'","''"))'"}
        }
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # build array of VUEMItems returned by the query
        $vuemStorefrontSettings = @()
        foreach ($row in $result.Tables.Rows) { $vuemStorefrontSettings += New-VUEMStorefrontSettingObject -DataRow $row }

        return $vuemStorefrontSettings
    }
}
