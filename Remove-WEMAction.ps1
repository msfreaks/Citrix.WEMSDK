<#
    .Synopsis
    Removes a WEM Action object from the WEM Database.

    .Description
    Removes a WEM Action object from the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdAction
    ..

    .Parameter Category
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Remove-WEMAction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [string]$Category,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original action
        $origAction = Get-WEMAction -Connection $Connection -IdAction $IdAction -Category $Category

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No action found for Id $($IdAction)"
            Break
        }
        
        # build query
        $SQLQuery = "DELETE FROM VUEM$($tableVUEMActionCategory[$origAction.Category]) WHERE $($tableVUEMActionCategoryId[$origAction.Category]) = $($IdAction)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdAction -ChangeType "Delete" -ObjectName $origAction.Name -ObjectType "Actions\$($origAction.Category)" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}