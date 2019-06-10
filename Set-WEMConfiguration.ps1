<#
    .Synopsis
    Updates a WEM Configuration object in the WEM Database.

    .Description
    Updates a WEM Configuration object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Name
    ..

    .Parameter Description
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False)][ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(Mandatory=$False)][AllowEmptyString()]
        [string]$Description,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    begin {
    }
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # either parameter Name or Description should be present
        if (-not [bool]($MyInvocation.BoundParameters.Keys -match 'name') -and -not [bool]($MyInvocation.BoundParameters.Keys -match 'description')) {
            Write-Error "Provide a value for parameter Name and/or parameter Description"
            Break
        }

        # grab original site
        $origSite = Get-WEMConfiguration -Connection $Connection -IdSite $IdSite

        # only continue if the site was found
        if (-not $origSite) { 
            Write-Warning "No site found with IdSite $($IdSite)"
            Break
        }
        
        # if a new name for the configuration is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name -notlike $origSite.Name) {
            $SQLQuery = "SELECT * FROM VUEMSites WHERE Name LIKE '$($Name)'"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows) {
                # name must be unique
                Write-Error "There's already an application named '$($Name)'"
                Break
            }
    
            Write-Verbose "Name is unique: Continue"
        }
        
        $SQLQuery = "UPDATE VUEMSites SET "
        if ($Name) { 
            $SQLQuery += "Name = '$($Name)'"
            if ([bool]($MyInvocation.BoundParameters.Keys -match 'description')) { $SQLQuery += ", " }
        }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'description')) {
            $SQLQuery += "Description = '$($Description)'"
        }
        $SQLQuery += " WHERE IdSite = $($IdSite)"

        # do not touch IdSite 1 (default site)
        if ($IdSite -gt 1 -and $Name.ToLower() -ne "default site") {
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # grab extra properties
            $SQLQuery = "SELECT Name FROM VUEMSites WHERE IdSite = $($IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
    
            # Updating the ChangeLog
            New-ChangesLogEntry -Connection $Connection -IdSite -1 -IdElement $IdSite -ChangeType "Update" -ObjectName $result.Tables.Rows.Name -ObjectType "Global\Site" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null 

        } else {
            Write-Error "You cannot modify the default site"
        }
    }
    end {
    }
}