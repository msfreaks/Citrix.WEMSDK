<#
    .Synopsis
    Removes a Active Directory User or Group object from the WEM Database.

    .Description
    Removes a Active Directory User or Group object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdADObject
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Remove-WEMADUserObject {
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
        $origObject = Get-WEMADUserObject -Connection $Connection -IdADObject $IdADObject

        # only continue if the action was found
        if (-not $origObject) { 
            Write-Warning "No Active Directory Object found for Id $($IdADObject)"
            Break
        }
        
        # don't remove Default Active Directory Objects
        if ($origObject.Type -like "BUILTIN") {
            Write-Warning "Cannot remove a BUILTIN Active Directory Object"
            Break
        }

        # build query
        $SQLQuery = "DELETE FROM VUEMItems WHERE IdItem = $($IdADObject)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        Write-Verbose "Using Account name: $((Get-ActiveDirectoryName $origObject.Name).Account)"
        New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdADObject -ChangeType "Delete" -ObjectName (Get-ActiveDirectoryName $origObject.Name).Account -ObjectType "Users\User" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
