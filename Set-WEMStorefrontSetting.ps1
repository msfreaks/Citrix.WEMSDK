<#
    .Synopsis
    Updates a Storefront Setting object in the WEM Database.

    .Description
    Updates a Storefront Setting object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdItem
    ..

    .Parameter Url
    ..

    .Parameter Description
    ..

    .Parameter State
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMStorefrontSetting {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdStorefrontSetting,

        [Parameter(Mandatory=$False)]
        [string]$StorefrontUrl,
        [Parameter(Mandatory=$False)]
        [string]$Description,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original item
        $origStorefrontSetting = Get-WEMStorefrontSetting -Connection $Connection -IdStorefrontSetting $IdStorefrontSetting

        # only continue if the condition was found
        if (-not $origStorefrontSetting) { 
            Write-Warning "No Condition object found for Id $($IdStorefrontSetting)"
            Break
        }
        
        # if a new url for the Storefront Setting is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'storefronturl') -and $StorefrontUrl.Replace("'", "''") -notlike $origStorefrontSetting.Url ) {
            $SQLQuery = "SELECT COUNT(*) AS StorefrontSetting FROM VUEMStorefrontSettings WHERE Url LIKE '$($StorefrontUrl.Replace("'", "''"))' AND IdSite = $($origStorefrontSetting.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.StorefrontSetting) {
                # name must be unique
                Write-Error "There's already a Storefront Settings object for '$($StorefrontUrl)' in the Configuration"
                Break
            }

            Write-Verbose "Storefront Url is unique: Continue"
        }

        # build the query to update the action
        $SQLQuery = "UPDATE VUEMStorefrontSettings SET "
        $updateFields = @()
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "idstorefrontsetting" }
        foreach ($key in $keys) {
            switch ($key) {
                "StorefrontUrl" {
                    $updateFields += "Url = '$($StorefrontUrl.Replace("'", "''"))'"
                    continue
                }
                "Description" {
                    $updateFields += "Description = '$($Description.Replace("'", "''"))'"
                    continue
                }
                "State" {
                    $updateFields += "State = $($tableVUEMState["$State"])"
                    continue
                }
                Default {}
            }
        }

        # if anything needs to be updated, update the action
        if($updateFields) { 
            $SQLQuery += "{0}, " -f ($updateFields -join ", ")
            $SQLQuery += "RevisionId = $($origStorefrontSetting.Version + 1) WHERE IdItem = $($IdStorefrontSetting)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # BUG IN THIS FUNCTIONALITY!
            # ChangeLog DOES not get updated when you enter a Storefront Settings object in the WEM Administration Console
            # Updating the ChangeLog
            #$objectUrl = $origStorefrontSetting.Url
            #if ($StorefrontUrl) { $objectUrl = $StorefrontUrl.Replace("'", "''") }
            
            #New-ChangesLogEntry -Connection $Connection -IdSite $origStorefrontSetting.IdSite -IdElement $IdStorefrontSetting -ChangeType "Update" -ObjectName $IdStorefrontSetting -ObjectType "Unknown Object" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
