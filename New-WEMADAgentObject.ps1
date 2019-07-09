<#
    .Synopsis
    Create a new Active Directory Agent or OU object in the WEM Database.

    .Description
    Create a new Active Directory Agent or OU object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Id
    ..

    .Parameter Description
    ..

    .Parameter Type
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
function New-WEMADAgentObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [string]$Id,
        [Parameter(Mandatory=$False)]
        [string]$Description = "",
        [Parameter(Mandatory=$False)][ValidateSet("Computer","Organizational Unit", $null)]
        [string]$Type = $null,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$False)]
        [int]$Priority = 100,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # define regexes
        $regExSID = "^S-\d-(\d+-){1,14}\d+$"
        $regExGUID = "^([0-9A-Fa-f]{8}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{12})$"

        # escape possible query breakers
        $Id = ConvertTo-StringEscaped $Id
        $Description = ConvertTo-StringEscaped $Description

        # Id must match SID or GUID
        if ($Id -notmatch $regExSID -and $Id -notmatch $regExGUID) {
            Write-Error "Please privide a valid object GUID or SID."
            Break
        }

        # if type is Computer, Id must match SID
        if ($Type -like "Computer" -and $Id -notmatch $regExSID) {
            Write-Error "Please privide a valid object SID if you want to add an Agent Computer Object"
            Break
        }

        # if type is Organizational Unit, Id must match GUID
        if ($Type -like "Organizational Unit" -and $Id -notmatch $regExGUID) {
            Write-Error "Please privide a valid object GUID if you want to add an Agent Organizational Unit Object"
            Break
        }
        
        # determine type if it was ommited
        if (-not $Type -and $Id -match $regExSID) { $Type = "Computer" }
        if (-not $Type -and $Id -match $regExGUID) { $Type = "Organizational Unit" }

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMADObjects WHERE ADObjectId LIKE '$($Id)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already a Computer or Organizational Unit Object with Id '$($Id)' in the Configuration"
            Break
        }

        Write-Verbose "Id is unique: Continue"

        # build optional values
        $ldapObject = $null
        $ldapObject = Get-ActiveDirectoryName -SID $Id -GUID $Id -Type $tableVUEMADObjectType[$Type]

        if (-not $ldapObject) {
            # something went wrong in AD lookup
            Write-Error "Failed to retrieve required attributes for '$($Id)' from the Active Directory"
            Break
        }

        # grab Name from DistinguishedName
        $Name = $ldapObject.DistinguishedName.Split(",")[0].Replace("OU=","").Replace("CN=","")

        # build the query to insert the Object
        $SQLQuery = "INSERT INTO VUEMADObjects (IdSite,ADObjectId,Name,Description,State,Type,Priority,RevisionId,Reserved01) VALUES ($($IdSite),'$($Id)','$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMADObjectType[$Type]),$($Priority),1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new Object
        $vuemADAgentObject = Get-WEMADAgentObject -Connection $Connection -IdSite $IdSite -ADObjectId $Id

        # Updating the ChangeLog
        Write-Verbose "Using Object name: $($Name)"
        $IdObject = $vuemADAgentObject.IdADObject
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName "$($Name) ($($Id))" -ObjectType "Active Directory Object\$($Type)" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return $vuemADAgentObject
    }
}
