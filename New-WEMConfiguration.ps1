<#
    .Synopsis
    Create a new WEM Configuration object in the WEM Database.

    .Description
    Create a new WEM Configuration object in the WEM Database.

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
    Author:  Arjan Mensch
    Version: 0.9.0
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
    ### TODO
    ### create new config based on template config?

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description

        # check if there's already a configuration with that name
        $SQLQuery = "SELECT COUNT(*) AS Site FROM VUEMSites WHERE Name LIKE '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.Site) {
            # name must be unique
            Write-Error "There's already a configuration named '$($Name)'"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # build and execute Insert query
        $SQLQuery = "INSERT INTO VUEMSites (Name, Description, State, RevisionId) VALUES ('$($Name)', '$($Description)', 1, 1)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the ID from the newly created record
        $SQLQuery = "SELECT * FROM VUEMSites WHERE Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        $IdSite = $result.Tables.Rows.IdSite

        # fill other tables with defaults after adding the Site record
        # VUEMParameters
        $SQLQuery = ("INSERT INTO VUEMParameters (IdSite, Name, Value, State, RevisionId) VALUES {0}" -f ($defaultVUEMParameters -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMAgentSettings
        $SQLQuery = ("INSERT INTO VUEMAgentSettings (IdSite,Name,Value,State,RevisionId) VALUES {0}" -f ($defaultVUEMAgentSettings -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMSystemUtilities
        $SQLQuery = ("INSERT INTO VUEMSystemUtilities (IdSite,Name,Type,Value,State,RevisionId) VALUES {0}" -f ($defaultVUEMUtilities -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMEnvironmentalSettings
        $SQLQuery = ("INSERT INTO VUEMEnvironmentalSettings (IdSite,Name,Type,Value,State,RevisionId) VALUES {0}" -f ($defaultVUEMEnvironmentalSettings -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMUPMSettings
        $SQLQuery = ("INSERT INTO VUEMUPMSettings (IdSite,Name,Value,State,RevisionId) VALUES {0}" -f ($defaultVUEMUPMSettings -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMPersonaSettings
        $SQLQuery = ("INSERT INTO VUEMPersonaSettings (IdSite,Name,Value,State,RevisionId) VALUES {0}" -f ($defaultVUEMPersonaSettings -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMUSVSettings
        $SQLQuery = ("INSERT INTO VUEMUSVSettings (IdSite,Name,Type,Value,State,RevisionId) VALUES {0}" -f ($defaultVUEMUSVSettings -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMKioskSettings
        $SQLQuery = ("INSERT INTO VUEMKioskSettings (IdSite,Name,Type,Value,State,RevisionId) VALUES {0}" -f ($defaultVUEMKioskSettings -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # VUEMSystemMonitoringSettings
        $SQLQuery = ("INSERT INTO VUEMSystemMonitoringSettings (IdSite,Name,Value,State,RevisionId) VALUES {0}" -f ($defaultVUEMSystemMonitoringSettings -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # AppLockerSettings
        $SQLQuery = ("INSERT INTO AppLockerSettings (IdSite, State, RevisionId, Value, Setting) VALUES {0}" -f ($defaultApplockerSettings -join ", ")) -f $IdSite
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # 1903 version!
        # GroupPolicyGlobalSettings
        if ($script:databaseVersion -like "1903.*") {
            $SQLQuery = "INSERT INTO GroupPolicyGlobalSettings (IdSite, Name, Value) VALUES ($($IdSite), 'EnableGroupPolicyEnforcement', '0')"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
        }
        
        # VUEMItems
        if ($script:databaseVersion -like "1903.*") {
            $SQLQuery = ("INSERT INTO VUEMItems (IdSite, Name, DistinguishedName, Description, State, Type, Priority, RevisionId) VALUES {0}" -f ($defaultVUEMItems -join ", ")) -f $IdSite
        } else {
            $SQLQuery = ("INSERT INTO VUEMItems (IdSite, Name, Description, State, Type, Priority, RevisionId) VALUES {0}" -f ($defaultVUEMItemsLegacy -join ", ")) -f $IdSite
        }
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite -1 -IdElement $IdSite -ChangeType "Create" -ObjectName $Name -ObjectType "Global\Site" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        Get-WEMConfiguration -Connection $Connection -IdSite $IdSite

    }
}
