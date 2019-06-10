function Remove-WEMAction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAction,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original action
        $origAction = Get-WEMAction -Connection $Connection -IdAction $IdAction

        # only continue if the action was found
        if (-not $origAction) { 
            Write-Warning "No action found for Id $($IdAction)"
            Break
        }
        


        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origAction.IdSite -IdElement $IdAction -ChangeType "Delete" -ObjectName $Name -ObjectType "Actions\Application" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

    }
}