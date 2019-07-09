<#
    .Synopsis
    Removes a WEM Active Directory Agent or OU object from the WEM Database.

    .Description
    Removes a WEM Active Directory Agent or OU object from the WEM Database.

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
function Remove-WEMADAgentObject {
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
        $origObject = Get-WEMADAgentObject -Connection $Connection -IdADObject $IdADObject

        # only continue if the action was found
        if (-not $origObject) { 
            Write-Warning "No Active Directory Object found for Id $($IdADObject)"
            Break
        }
        
        # don't remove Default Active Directory Objects
        if ($origObject.Type -notlike "Computer" -and $origObject.Type -notlike "Organizational Unit") {
            Write-Warning "You can not delete this type of object ($($origObject.Type))"
            Break
        }

        # build query
        $SQLQuery = "DELETE FROM VUEMADObjects WHERE IdAdObject = $($IdADObject)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        Write-Verbose "Using Account name: $($origObject.Name)"
        New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdADObject -ChangeType "Delete" -ObjectName $origObject.Name -ObjectType "Active Directory Object\$($origObject.Type)" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
