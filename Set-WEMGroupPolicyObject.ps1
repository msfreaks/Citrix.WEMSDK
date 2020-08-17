<#
    .Synopsis
    Updates a Group Policy Settings Action object in the WEM Database.

    .Description
    Updates a Group Policy Settings Action object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdObject
    ..

    .Parameter Name
    ..

    .Parameter Description
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMGroupPolicyObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdObject,

        [Parameter(Mandatory=$False)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # grab original action
        $origObject = Get-WEMGroupPolicyObject -Connection $Connection -IdObject $IdObject

        # only continue if the action was found
        if (-not $origObject) { 
            Write-Warning "No Group Policy Settings action found for Id $($IdObject)"
            Break
        }
        
        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description

        # if a new name for the object is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $Name -notlike $origObject.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS Action FROM GroupPolicyObjects WHERE Name LIKE '$($Name)' AND IdSite = $($origObject.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.Action) {
                # name must be unique
                Write-Error "There's already a Group Policy Settings action named '$($Name)' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"

        }

        # build the query to update the action
        $SQLQuery = "UPDATE GroupPolicyObjects SET "
        $updateFields = @()
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "IdAction" }
        foreach ($key in $keys) {
            switch ($key) {
                "Name" {
                    $updateFields += "Name = '$($Name)'"
                    continue
                }
                "Description" {
                    $updateFields += "Description = '$($Description)'"
                    continue
                }
                Default {}
            }
        }

        # if anything needs to be updated, update the action
        if($updateFields) { 
            if ($updateFields) { $SQLQuery += "{0}, " -f ($updateFields -join ", ") }
            $SQLQuery += "RevisionId = $($origAction.Version + 1) WHERE IdObject = $($IdObject)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origObject.Name
            New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdObject -ChangeType "Update" -ObjectName "$($objectName) ($($origObject.Guid.ToString().ToLower()))" -ObjectType "Group Policy\Object" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
            if ($Name) { $objectName = $Name }
            New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdObject -ChangeType "Update" -ObjectName "$($objectName) ($($origObject.Guid.ToString().ToLower()))" -ObjectType "Group Policy\Object\Registry Operations" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
