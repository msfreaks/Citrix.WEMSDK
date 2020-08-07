<#
    .Synopsis
    Removes a Citrix Optimizer Configuration object from the WEM Database.

    .Description
    Removes a Citrix Optimizer Configuration object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdTemplate
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Remove-WEMCitrixOptimizerConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdTemplate,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # only continue if the WEM version supports it
        if ($script:databaseSchema -lt 2003) {
            Write-Error "WEM $($script:databaseSchema) does not support Citrix Optimizer Configurations"
            Break
        }

        # only continue if a valid IdSite was passed
        if (-not (Get-WEMConfiguration -Connection $Connection -IdSite $IdSite)) {
            Write-Warning "No site found with IdSite $($IdSite)"
            Break
        }
        
        # grab original object
        $origObject = Get-WEMCitrixOptimizerConfiguration -Connection $Connection -IdSite $IdSite -IdTemplate $IdTemplate -Verbose

        # only continue if the object was found
        if (-not $origObject) { 
            Write-Warning "No Citrix Optimizer Configuration object found for Id $($IdTemplate)"
            Break
        }
                
        # don't remove Default Active Directory Objects
        if ($origObject.IsDefaultTemplate) {
            Write-Warning "Cannot remove a Default Citrix Optimizer Configuration Object"
            Break
        }

        # build query
        $SQLQuery = "DELETE FROM VUEMCitrixOptimizerConfigurations WHERE IdTemplate = $($IdTemplate)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # check if the template content can be deleted
        $SQLQuery = "SELECT * FROM VUEMCitrixOptimizerConfigurations WHERE IdContent = $($origObject.IdContent)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        if (-not $result.Tables) {
            # no other configs use the referenced template -> delete it
            Write-Verbose "No other configurations reference the Optimizer Template. Deleting template and its hash."

            $SQLQuery = "DELETE FROM VUEMCitrixOptimizerTemplatesHash WHERE IdContent = $($origObject.IdContent)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
            $SQLQuery = "DELETE FROM VUEMCitrixOptimizerTemplatesContent WHERE IdContent = $($origObject.IdContent)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
        }

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdTemplate -ChangeType "Delete" -ObjectName $origObject.Name -ObjectType "Citrix Optimizer\Configurations" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
