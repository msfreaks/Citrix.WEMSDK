<#
    .Synopsis
    Returns a Citrix Optimizer Configuration object from the WEM Database.

    .Description
    Returns a Citrix Optimizer Configuration object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdTemplate
    ..

    .Parameter Name
    ..

    .Parameter State
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Get-WEMCitrixOptimizerConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdTemplate,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State,
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

        # build query
        $SQLQuery = "SELECT * FROM VUEMCitrixOptimizerConfigurations"
        if ($IdSite -or $Name -or $IdTemplate -or $State) {
            $SQLQuery += " WHERE "
            if ($IdSite) { 
                $SQLQuery += "IdSite = $($IdSite)"
                if ($Name -or $IdTemplate -or $State) { $SQLQuery += " AND " }
            }
            if ($IdTemplate) { 
                $SQLQuery += "IdTemplate = $($IdTemplate)"
                if ($Name -or $State) { $SQLQuery += " AND " }
            }
            if ($Name) {
                $SQLQuery += "Name LIKE '$($Name.Replace("*","%"))'"
                if ($State) { $SQLQuery += " AND " }
            }
            if ($State) { $SQLQuery += "State LIKE $($tableVUEMState["$($State)"])" }
        }
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        $vuemCitrixOptimizerConfigurations = @()
        foreach ($row in $result.Tables.Rows) { $vuemCitrixOptimizerConfigurations += New-VUEMCitrixOptimizerConfigurationObject -DataRow $row }
    
        # return the final object
        return $vuemCitrixOptimizerConfigurations 
    }
}
