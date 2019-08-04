<#
    .Synopsis
    Updates a WEM Active Directory Agent or OU object in the WEM Database.

    .Description
    Updates a WEM Active Directory Agent or OU object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdADObject
    ..

    .Parameter Description
    ..

    .Parameter State
    ..

    .Parameter Priority
    ..

    .Parameter Connection
    ..
    
    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMADAgentObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdADObject,
        [Parameter(Mandatory=$False)]
        [string]$Description,
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State,
        [Parameter(Mandatory=$False)][ValidateSet("User","Group")]
        [string]$Type,
        [Parameter(Mandatory=$False)]
        [int]$Priority,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # grab original object
        $origADObject = Get-WEMADAgentObject -Connection $Connection -IdADObject $IdADObject

        # only continue if the object was found
        if (-not $origADObject) { 
            Write-Warning "No Active Directory object found for Id $($IdADObject)"
            Break
        }
        
        # build the query to update the object
        $SQLQuery = "UPDATE VUEMADObjects SET "
        $updateFields = @()
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "idadobject" }
        foreach ($key in $keys) {
            switch ($key) {
                "Description" {
                    $updateFields += "Description = '$(ConvertTo-StringEscaped $Description)'"
                    continue
                }
                "State" {
                    $updateFields += "State = $($tableVUEMState["$State"])"
                    continue
                }
                "Priority" {
                    $updateFields += "Priority = $([string]$Priority)"
                    continue
                }
                Default {}
            }
        }

        # if anything needs to be updated, update the object
        if($updateFields) { 
            $SQLQuery += "{0}, " -f ($updateFields -join ", ")
            $SQLQuery += "RevisionId = $($origADObject.Version + 1) WHERE IdADObject = $($IdADObject)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origADObject.Name
            
            New-ChangesLogEntry -Connection $Connection -IdSite $origADObject.IdSite -IdElement $IdADObject -ChangeType "Update" -ObjectName "$($objectName) ($($origADObject.ADObjectId))" -ObjectType "Active Directory Object\$($origADObject.Type.Replace(' ',''))" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}