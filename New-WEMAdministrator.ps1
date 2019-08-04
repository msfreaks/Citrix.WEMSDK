<#
    .Synopsis
    Create a new Administrator object in the WEM Database.

    .Description
    Create a new Administrator object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter Id
    ..

    .Parameter Description
    ..

    .Parameter Type
    ..

    .Parameter State
    ..

    .Parameter Permission
    ..

    .Parameter IdSite
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMAdministrator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [string]$Id,
        [Parameter(Mandatory=$False)]
        [string]$Description = "",
        [Parameter(Mandatory=$False)][ValidateSet("Group","User")]
        [string]$Type,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State = "Disabled",
        [Parameter(Mandatory=$False)][ValidateSet("Full Access","Read Only","Actions Creator","Actions Manager","Filters Manager","Assigments Manager","System Utilities Manager","System Monitoring Manager","Policies and Profiles Manager","Configured User Manager","Transformer Manager","Advanced Settings Manager","Security Manager")]
        [string]$Permission = "",
        [Parameter(Mandatory=$False)]
        [int]$IdSite = 0,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # define regexes
        $regExSID = "^S-\d-(\d+-){1,14}\d+$"

        # escape possible query breakers
        $Id = ConvertTo-StringEscaped $Id
        $Description = ConvertTo-StringEscaped $Description

        # Id must match SID
        if ($Id -notmatch $regExSID) {
            Write-Error "Please privide a valid object SID."
            Break
        }

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMAdministrators WHERE Name LIKE '$($Id)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already an Administrator object named '$($Id)' in the Configuration"
            Break
        }

        Write-Verbose "Id is unique: Continue"

        # check IdSite if one was provided
        if($IdSite -ge 1) {
            if(-not (Get-WEMConfiguration -Connection $Connection -IdSite $IdSite)) {
                Write-Error "Configuration not found. Please provide a valid Site Id"
                Break
            }
        }

        # check permissions
        $xmlPermission = [xml]$defaultVUEMAdministratorPermissions
        if ($Permission) { $xmlPermission.ArrayOfVUEMAdminPermission.VUEMAdminPermission.AuthorizationLevel = $tableVUEMAdminPermissions[$Permission] }
        $xmlPermission.ArrayOfVUEMAdminPermission.VUEMAdminPermission.idSite = [string]$IdSite

        # build optional values
        if ([bool]($MyInvocation.BoundParameters.Keys -notmatch 'type')) { 
            $ADObject = Get-ActiveDirectoryName -SID "$($Id)"
            if (-not $ADObject) {
                Write-Error "Could not determine Active Directory object type. Please provide the Type manually"
                Break
            }

            $Type = $ADObject.Type

            Write-Verbose "Determined '$($Name)' ($($ADObject.DistinguishedName)) to be of type '$($Type)'"
        }    

        # build the query to insert the Object
        $SQLQuery = "INSERT INTO VUEMAdministrators (Name,Description,State,Type,Permissions,RevisionId,Reserved01) VALUES ('$($Id)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMADObjectType[$Type]),'$($xmlPermission.InnerXml)',1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new Object
        $vuemAdministratorObject = Get-WEMAdministrator -Connection $Connection -Name $id

        # Updating the ChangeLog
        Write-Verbose "Using Object name: $($Id)"
        $IdObject = $vuemAdministratorObject.IdAdministrator
        New-ChangesLogEntry -Connection $Connection -IdSite -1 -IdElement $IdObject -ChangeType "Create" -ObjectName (Get-ActiveDirectoryName $Id).Account -ObjectType "Administration\Administrators" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return $vuemAdministratorObject
    }
}
