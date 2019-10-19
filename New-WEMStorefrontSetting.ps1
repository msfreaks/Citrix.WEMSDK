<#
    .Synopsis
    Create a new Storefront Setting object in the WEM Database.

    .Description
    Create a new Storefront Setting object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter StorefrontUrl
    ..

    .Parameter Description
    ..

    .Parameter State
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMStorefrontSetting {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [string]$StorefrontUrl,
        [Parameter(Mandatory=$False)]
        [string]$Description = "",
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $StorefrontUrl = ConvertTo-StringEscaped $StorefrontUrl
        $Description = ConvertTo-StringEscaped $Description

        # name is unique if it's not yet used in the site 
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMStorefrontSettings WHERE Url LIKE '$($StorefrontUrl)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already a Storefront Settings object for '$($StorefrontUrl)' in the Configuration"
            Break
        }

        Write-Verbose "StorefrontUrl is unique: Continue"

        # build optional values

        # build the query to update the table
        $SQLQuery = "INSERT INTO VUEMStorefrontSettings (IdSite,Url,Description,State,RevisionId,Reserved01) VALUES ($($IdSite),'$($StorefrontUrl)','$($Description)',$($tableVUEMState[$State]),1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new record
        $SQLQuery = "SELECT * FROM VUEMStorefrontSettings WHERE IdSite = $($IdSite) AND Url = '$($StorefrontUrl)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # BUG IN THIS FUNCTIONALITY!
        # ChangeLog DOES not get updated when you enter a Storefront Settings object in the WEM Administration Console
        # Updating the ChangeLog
        
        # $IdObject = $result.Tables.Rows.IdItem
        # New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName $IdObject -ObjectType "Unknown Object" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return New-VUEMStorefrontSettingObject -DataRow $result.Tables.Rows
    }
}
