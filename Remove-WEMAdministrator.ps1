<#
    .Synopsis
    Removes a Administrator object from the WEM Database.

    .Description
    Removes a Administrator object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAdministrator
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Remove-WEMAdministrator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAdministrator,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origObject = Get-WEMAdministrator -Connection $Connection -IdAdministrator $IdAdministrator

        # only continue if the action was found
        if (-not $origObject) { 
            Write-Warning "No Administrator found for Id $($IdAdministrator)"
            Break
        }
        
        # build query
        $SQLQuery = "DELETE FROM VUEMAdministrators WHERE IdAdmin = $($IdAdministrator)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        Write-Verbose "Using Object name: $($origObject.Name)"
        New-ChangesLogEntry -Connection $Connection -IdSite -1 -IdElement $IdAdministrator -ChangeType "Delete" -ObjectName $origObject.Name -ObjectType "Administration\Administrators" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
