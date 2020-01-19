<#
    .Synopsis
    Removes a Storefront Setting object from the WEM Database.

    .Description
    Removes a Storefront Setting object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdStorefrontSetting
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Remove-WEMStorefrontSetting {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdStorefrontSetting,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origObject = Get-WEMStorefrontSetting -Connection $Connection -IdStorefrontSetting $IdStorefrontSetting

        # only continue if the action was found
        if (-not $origObject) { 
            Write-Warning "No Storefront Setting Object found for Id $($IdStorefrontSetting)"
            Return
        }
        
        # build query
        $SQLQuery = "DELETE FROM VUEMStorefrontSettings WHERE IdItem = $($IdStorefrontSetting)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # BUG IN THIS FUNCTIONALITY!
        # ChangeLog DOES not get updated when you enter a Storefront Settings object in the WEM Administration Console
        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdStorefrontSetting -ChangeType "Delete" -ObjectName $IdStorefrontSetting -ObjectType "Unknown Object" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
