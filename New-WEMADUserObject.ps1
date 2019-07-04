<#
    .Synopsis
    Create a new Active Directory User or Group object in the WEM Database.

    .Description
    Create a new Active Directory User or Group object in the WEM Database.

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

    .Parameter Priority
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMADUserObject {
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
        [Parameter(Mandatory=$False)][ValidateSet("User","Group",$null)]
        [string]$Type = $null,
        [Parameter(Mandatory=$False)]
        [int]$Priority = 100,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMItems WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already an Active Directory object named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # build optional values
        if ([bool]($MyInvocation.BoundParameters.Keys -notmatch 'type')) { 
            $ADObject = Get-ActiveDirectoryName -SID "$($Name)"
            if (-not $ADObject) {
                Write-Error "Could not determine Active Directory object type. Please provide the Type manually"
                Break
            }

            $Type = $ADObject.Type

            Write-Verbose "Determined '$($Name)' ($($ADObject.DistinguishedName)) to be of type '$($Type)'"
        }    

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMItems (IdSite,Name,DistinguishedName,Description,State,Type,Priority,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)',NULL,'$($Description)',$($tableVUEMState[$State]),$($tableVUEMADObjectType[$Type]),$($Priority),1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT * FROM VUEMItems WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        Write-Verbose "Using Account name: $((Get-ActiveDirectoryName $Name).Account)"
        $IdObject = $result.Tables.Rows.IdItem
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName (Get-ActiveDirectoryName $Name).Account -ObjectType "Users\User" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return New-VUEMADUserObject -DataRow $result.Tables.Rows
    }
}
