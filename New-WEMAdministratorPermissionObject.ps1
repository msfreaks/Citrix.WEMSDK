<#
    .Synopsis
    Create a new Administrator Permission object.

    .Description
    Create a new Administrator Permission object.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Permission
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMAdministratorPermissionObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)][ValidateSet("Full Access","Read Only","Actions Creator","Actions Manager","Filters Manager","Assigments Manager","System Utilities Manager","System Monitoring Manager","Policies and Profiles Manager","Configured User Manager","Transformer Manager","Advanced Settings Manager","Security Manager")]
        [string]$Permission,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        # check IdSite if one was provided
        if($IdSite -ge 1) {
            if(-not (Get-WEMConfiguration -Connection $Connection -IdSite $IdSite)) {
                Write-Error "Configuration not found. Please provide a valid Site Id"
                Break
            }
        }

        if ($IdSite -ge 1) {
            $vuemObject = [pscustomobject] @{
                'IdSite'      = [int]$IdSite
                'Name'        = (Get-WEMConfiguration -Connection $Connection -IdSite $IdSite).Name
                'Permission'  = $Permission
            }
        } else {
            $vuemObject = [pscustomobject] @{
                'IdSite'      = 0
                'Name'        = "Global Admin"
                'Permission'  = $Permission
            }
        }

        # override the default ToScript() method
        $vuemObject | Add-Member ScriptMethod ToString { "$($this.Name) ($($this.Permission))" } -Force
        # set a custom type to the object
        $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.AdminPermission")
        
        # Return the new object
        return $vuemObject
    }
}
