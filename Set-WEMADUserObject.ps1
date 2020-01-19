<#
    .Synopsis
    Updates a Active Directory object in the WEM Database.

    .Description
    Updates a Active Directory object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdADObject
    ..

    .Parameter Name
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
    Author: Arjan Mensch
#>
function Set-WEMADUserObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdADObject,

        [Parameter(Mandatory=$False)]
        [string]$Name,
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
        $origADObject = Get-WEMADUserObject -Connection $Connection -IdADObject $IdADObject

        # only continue if the object was found
        if (-not $origADObject) { 
            Write-Warning "No Active Directory object found for Id $($IdADObject)"
            Break
        }
        
        # don't update BUILTIN objects
        if ($origADObject.Type -like "BUILTIN") {
            Write-Warning "Cannot update BUILTIN objects"
            Return
        }
        
        # if a new name for the object is entered, check if it's unique
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and (ConvertTo-StringEscaped $Name) -notlike $origADObject.Name ) {
            $SQLQuery = "SELECT COUNT(*) AS ADObject FROM VUEMItems WHERE Name LIKE '$($Name.Replace("'", "''"))' AND IdSite = $($origADObject.IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables.Rows.ADObject) {
                # name must be unique
                Write-Error "There's already an Active Directory object named '$($Name.Replace("'", "''"))' in the Configuration"
                Break
            }

            Write-Verbose "Name is unique: Continue"
        }

        # check Type 
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and [bool]($MyInvocation.BoundParameters.Keys -notmatch 'type')) {
            $ADObject = Get-ActiveDirectoryName -SID "$($Name)"
            if (-not $ADObject) {
                Write-Error "Could not determine Active Directory object type. Please provide the Type manually"
                Break
            }

            $Type = $ADObject.Type

            Write-Verbose "Determined '$($Name)' ($($ADObject.DistinguishedName)) to be of type '$($Type)'"
        }

        # build the query to update the object
        $SQLQuery = "UPDATE VUEMItems SET "
        $updateFields = @()
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "idadobject" }
        foreach ($key in $keys) {
            switch ($key) {
                "Name" {
                    $updateFields += "Name = '$($Name.Replace("'", "''"))'"
                    $updateFields += "Type = $($tableVUEMADObjectType[$Type])"
                    continue
                }
                "Description" {
                    $updateFields += "Description = '$(ConvertTo-StringEscaped $Description)'"
                    continue
                }
                "State" {
                    $updateFields += "State = $($tableVUEMState["$State"])"
                    continue
                }
                "Type" {
                    if (-not $updateFields -match "type") { $updateFields += "Type = $($tableVUEMADObjectType[$Type])" }
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
            $SQLQuery += "RevisionId = $($origADObject.Version + 1) WHERE IdItem = $($IdADObject)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $objectName = $origADObject.Name
            if ($Name) { $objectName = $Name.Replace("'", "''") }
            
            New-ChangesLogEntry -Connection $Connection -IdSite $origADObject.IdSite -IdElement $IdADObject -ChangeType "Update" -ObjectName (Get-ActiveDirectoryName $objectName).Account -ObjectType "Users\User" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
