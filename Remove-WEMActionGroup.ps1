<#
    .Synopsis
    Removes a WEM Action Group object from the WEM Database.

    .Description
    Removes a WEM Action Group object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdActionGroup
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMActionGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdActionGroup,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origObject = Get-WEMActionGroup -Connection $Connection -IdActionGroup $IdActionGroup

        # only continue if the action was found
        if (-not $origObject) { 
            Write-Warning "No Action Group Object found for Id $($IdActionGroup)"
            Break
        }
        
        # build query
        $SQLQuery = "DELETE FROM VUEMActionGroups WHERE IdActionGroup = $($IdActionGroup)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdActionGroup -ChangeType "Delete" -ObjectName $origObject.Name -ObjectType "Actions\Action Groups" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
