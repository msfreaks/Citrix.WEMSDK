<#
    .Synopsis
    Removes a WEM Active Directory object from the WEM Database.

    .Description
    Removes a WEM Active Directory object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdADObject
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMADObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdADObject,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origADObject = Get-WEMADObject -Connection $Connection -IdADObject $IdADObject

        # only continue if the action was found
        if (-not $origADObject) { 
            Write-Warning "No Active Directory Object found for Id $($IdADObject)"
            Break
        }
        
        # don't remove Default Active Directory Objects
        if ($origADObject.Type -like "BUILTIN") {
            Write-Warning "Cannot remove a BUILTIN Active Directory Object"
            Break
        }

        # build query
        $SQLQuery = "DELETE FROM VUEMItems WHERE IdItem = $($IdADObject)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        Write-Verbose "Using Account name: $((Get-ActiveDirectoryName $origADObject.Name).Account)"
        New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdADObject -ChangeType "Delete" -ObjectName (Get-ActiveDirectoryName $origADObject.Name).Account -ObjectType "Users\User" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
