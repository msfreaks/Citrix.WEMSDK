<#
    .Synopsis
    Create a new Configuration object in the WEM Database.

    .Description
    Create a new Configuration object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter Name
    ..

    .Parameter Description
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function New-WEMConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False)][AllowEmptyString()]
        [string]$Description,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description

        # check if there's already a configuration with that name
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMSites WHERE Name LIKE '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already a Configuration object named '$($Name)'"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # build and execute Insert query
        $SQLQuery = "INSERT INTO VUEMSites ({0}) VALUES ({1})" -f $configurationSettings[$script:databaseSchema].SiteFields, ($configurationSettings[$script:databaseSchema].SiteValues -f $Name, $Description)
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the ID from the newly created record
        $objectSite = Get-WEMConfiguration -Connection $Connection -Name "$($Name)"
        $IdSite = $objectSite.IdSite

        # fill other tables with defaults after adding the Site record
        # VUEMParameters
        $SQLQuery = ("INSERT INTO VUEMParameters ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].ParametersFields, ($configurationSettings[$script:databaseSchema].ParametersValues -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMAgentSettings
        $SQLQuery = ("INSERT INTO VUEMAgentSettings ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].AgentSettingsFields, ($configurationSettings[$script:databaseSchema].AgentSettingsValues -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMSystemUtilities
        $SQLQuery = ("INSERT INTO VUEMSystemUtilities ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].SystemUtilitiesFields, ($configurationSettings[$script:databaseSchema].SystemUtilitiesValues -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMEnvironmentalSettings
        $SQLQuery = ("INSERT INTO VUEMEnvironmentalSettings ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].EnvironmentalFields, ($configurationSettings[$script:databaseSchema].EnvironmentalValues -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMUPMSettings
        $SQLQuery = ("INSERT INTO VUEMUPMSettings ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].UPMFields, ($configurationSettings[$script:databaseSchema].UPMValues -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMPersonaSettings
        $SQLQuery = ("INSERT INTO VUEMPersonaSettings ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].PersonaFields, ($configurationSettings[$script:databaseSchema].PersonaValues -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMUSVSettings
        $SQLQuery = ("INSERT INTO VUEMUSVSettings ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].USVFields, ($configurationSettings[$script:databaseSchema].USVValues -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMKioskSettings
        $SQLQuery = ("INSERT INTO VUEMKioskSettings ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].KioskFields, ($configurationSettings[$script:databaseSchema].KioskValues -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMSystemMonitoringSettings
        $SQLQuery = ("INSERT INTO VUEMSystemMonitoringSettings ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].SystemMonitoringFields, ($configurationSettings[$script:databaseSchema].SystemMonitoringValues -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # AppLockerSettings
        if ($configurationSettings[$script:databaseSchema].AppLockerFields) {
            $SQLQuery = ("INSERT INTO AppLockerSettings ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].AppLockerFields, ($configurationSettings[$script:databaseSchema].AppLockerValues -join ", ")) -f $IdSite
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
        }

        # GroupPolicyGlobalSettings
        if ($configurationSettings[$script:databaseSchema].GroupPolicyGlobalSettingsFields) {
            $SQLQuery = ("INSERT INTO GroupPolicyGlobalSettings ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].GroupPolicyGlobalSettingsFields, ($configurationSettings[$script:databaseSchema].GroupPolicyGlobalSettingsValues -join ", ")) -f $IdSite
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
        }
        
        # CitrixOptimizerConfigurations
        if ($configurationSettings[$script:databaseSchema].CitrixOptimizerConfigurationsFields) {
            $SQLQuery = ("INSERT INTO VUEMCitrixOptimizerConfigurations ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].CitrixOptimizerConfigurationsFields, ($configurationSettings[$script:databaseSchema].CitrixOptimizerConfigurationsValues -join ", ")) -f $IdSite
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
        }

        # VUEMItems
        $SQLQuery = ("INSERT INTO VUEMItems ({0}) VALUES {1}" -f $configurationSettings[$script:databaseSchema].ItemsFields, ($configurationSettings[$script:databaseSchema].ItemsValues -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite -1 -IdElement $IdSite -ChangeType "Create" -ObjectName $Name -ObjectType "Global\Site" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        Get-WEMConfiguration -Connection $Connection -IdSite $IdSite

    }
}
