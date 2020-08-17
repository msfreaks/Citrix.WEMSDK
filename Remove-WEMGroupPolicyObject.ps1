<#
    .Synopsis
    Removes a Group Policy Settings Action object from the WEM Database.

    .Description
    Removes a Group Policy Settings Action object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdObject
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Remove-WEMGroupPolicyObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdObject,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # grab original object
        $origObject = Get-WEMGroupPolicyObject -Connection $Connection -IdObject $IdObject

        # only continue if the action was found
        if (-not $origObject) { 
            Write-Warning "No Group Policy Settings Action object found for Id $($IdObject)"
            Break
        }
        
        # build query
        $SQLQuery = "DELETE FROM GroupPolicyObjects WHERE IdObject = $($IdObject)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # deleting individual registry operations from GroupPolicyRegOperations is not needed. DB triggers handle this!
        
        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdObject -ChangeType "Delete" -ObjectName "$($origObject.Name) ($($origObject.Guid.ToString().ToLower()))" -ObjectType "Group Policy\Object" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
