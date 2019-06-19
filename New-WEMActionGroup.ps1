<#
    .Synopsis
    Create a new Action Group object in the WEM Database.

    .Description
    Create a new Action Group object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Name
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
function New-WEMActionGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [string]$Name,
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
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMActionGroups WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already an Action Group object named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # build the query to update the object
        $SQLQuery = "INSERT INTO VUEMActionGroups (IdSite,Name,Description,State,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new object
        $SQLQuery = "SELECT * FROM VUEMActionGroups WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdActionGroup
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\Action Groups" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return New-VUEMActionGroupObject -Connection $Connection -DataRow $result.Tables.Rows
    }
}
