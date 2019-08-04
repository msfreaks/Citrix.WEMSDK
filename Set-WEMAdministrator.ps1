<#
    .Synopsis
    Updates a WEM Administrator object in the WEM Database.

    .Description
    Updates a WEM Administrator object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAdministrator
    ..

    .Parameter Name
    ..

    .Parameter Description
    ..

    .Parameter State
    ..

    .Parameter Permissions
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMAdministrator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAdministrator,
        [Parameter(Mandatory=$False)]
        [string]$Description,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State,
        [Parameter(Mandatory=$False)]
        [pscustomobject[]]$Permissions,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origObject = Get-WEMAdministrator -Connection $Connection -IdAdministrator $IdAdministrator

        # only continue if the object was found
        if (-not $origObject) { 
            Write-Warning "No Administrator object found for Id $($IdAdministrator)"
            Break
        }
        
        # check permissions object
        if ($Permissions) {
            foreach($permission in $Permissions){ 
                if ($permission.PSObject.TypeNames[0] -ne "Citrix.WEMSDK.AdminPermission") {
                    Write-Warning "Invalid permission object entered. Please provide valid Administrator Permission objects."
                    Break
                }
            } 
        }
        # build the query to update the object
        $SQLQuery = "UPDATE VUEMAdministrators SET "
        $updateFields = @()
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "idadobject" }
        foreach ($key in $keys) {
            switch ($key) {
                "Description" {
                    $updateFields += "Description = '$(ConvertTo-StringEscaped $Description)'"
                    continue
                }
                "State" {
                    $updateFields += "State = $($tableVUEMState["$State"])"
                    continue
                }
                "Permissions" {
                    $permissionXML = '<?xml version="1.0" encoding="utf-8"?><ArrayOfVUEMAdminPermission xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
                    foreach($permission in $Permissions) {
                        Write-Debug "Adding permission '$($tableVUEMAdminPermissions[$permission.Permission])'"
                        $permissionXML += "<VUEMAdminPermission><idSite>$($permission.IdSite)</idSite><AuthorizationLevel>$($tableVUEMAdminPermissions[$permission.Permission])</AuthorizationLevel></VUEMAdminPermission>" 
                    }
                    $permissionXML += '</ArrayOfVUEMAdminPermission>'
                    $updateFields += "Permissions = '$($permissionXML)'"
                    continue
                }
                Default {}
            }
        }

        # if anything needs to be updated, update the object
        if($updateFields) { 
            $SQLQuery += "{0}, " -f ($updateFields -join ", ")
            $SQLQuery += "RevisionId = $($origObject.Version + 1) WHERE IdAdmin = $($IdAdministrator)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectId = $origObject.Name
            
            New-ChangesLogEntry -Connection $Connection -IdSite -1 -IdElement $IdAdministrator -ChangeType "Update" -ObjectName (Get-ActiveDirectoryName $objectId).Account -ObjectType "Administration\Administrators" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}