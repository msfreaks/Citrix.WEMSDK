<#
    .Synopsis
    Create a new Group Policy Settings Action object in the WEM Database.

    .Description
    Create a new Group Policy Settings Action object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Path
    ..

    .Parameter Overwrite
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function New-WEMGroupPolicyObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [string]$Path,
        [Parameter(Mandatory=$False)]
        [switch]$Overwrite = $false,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # check if path is valid
        if (-not $Path -or -not (Test-Path -Path $Path -ErrorAction SilentlyContinue) -or -not (Test-Path -Path "$($Path)\gpreport.xml" -ErrorAction SilentlyContinue) -or -not (Test-Path -Path "$($Path)\bkupInfo.xml" -ErrorAction SilentlyContinue)) {
            Write-Host "'$($Path)' does not point to a valid GPO backup" -ForegroundColor Red
            Break
        }

        # gpo backup is valid
        $gpoName = ConvertTo-StringEscaped ([xml](Get-Content -Path "$($Path)\bkupInfo.xml")).BackupInst.GPODisplayName."#cdata-section"
        $gpoPols = (Get-ChildItem -Path $Path -Include "*.pol" -Recurse).VersionInfo.FileName
        $gpoRegs = @()
        foreach ($gpoPol in $gpoPols) {
            $gpoScope = ($gpoPol -split "\\")[($gpoPol -split "\\").Length - 2]
            foreach ($gpoReg in (Parse-PolFile -Path $gpoPol)) { 
                $gpoReg | Add-Member -NotePropertyName "Scope" -NotePropertyValue $gpoScope
                $gpoReg | Add-Member -NotePropertyName "Action" -NotePropertyValue "SetValue"
                if ($gpoReg.ValueName -like "*del.*") { 
                    $gpoReg.Action = "DeleteValue"
                    $gpoReg.ValueName = $gpoReg.ValueName.Replace("**del.", "")
                }
                $gpoRegs += $gpoReg
            }
        }

        # abort if no settings are found
        if (-not $gpoRegs) {
            Write-Host "Group Policy object '$($Path)' does not contain any valid registry entries to parse" -ForegroundColor Red
            Break
        }

        # overwrite mode
        Write-Verbose "Overwrite: $($Overwrite)"

        # check if gpo exists 
        $SQLQuery = "SELECT * FROM GroupPolicyObjects WHERE Name = '$($gpoName)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        $IdObject = $null

        if ($result.Tables.Rows.IdObject) {
            Write-Verbose "There's already a Group Policy Settings object named '$($gpoName)' in the Configuration"
            Write-Verbose "Overwrite mode: $(if ($Overwrite) { "enabled" } else { "disabled" })"

            if ($Overwrite) {
                Write-Verbose "Overwrite switch is used. Deleting regvalues for this Group Policy Settings object ($($result.Tables.Rows.IdObject) - $($gpoName)) and updating the Group Policy Settings object"
                # updating the GPO
                $IdObject = $result.Tables.Rows.IdObject
                $SQLQuery = "UPDATE GroupPolicyObjects SET ModifiedTime = '$(Get-Date)', RevisionId = $($result.Tables.Rows.RevisionId + 1) WHERE IdObject = $($IdObject)"
                $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

                # grabbing the updated GPO
                $SQLQuery = "SELECT * FROM GroupPolicyObjects WHERE IdObject = $($IdObject)"
                $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                # writing the update action to the changelog
                New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Update" -ObjectName "$($result.Tables.Rows.Name) ($($result.Tables.Rows.GUID.ToString().ToLower()))" -ObjectType "Group Policy\Object" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

                # deleting GroupPolicyRegOperations for this GPO
                $SQLQuery = "DELETE FROM GroupPolicyRegOperations WHERE IdObject = $($IdObject)"
                $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

                # insert new GroupPolicyRegOperations for this GPO
                foreach ($gpoReg in $gpoRegs) {
                    $gpoRegJData = (@{ "Type" = $gpoReg.ValueType.ToString(); "Data" = $gpoReg.ValueData } | ConvertTo-Json -Depth 9).ToString()
                    $SQLQuery = "INSERT INTO GroupPolicyRegOperations (IdObject,RegAction,Scope,KeyPath,Value,JData,PolicyDefinition,RevisionId,Reserved01) VALUES ($($IdObject),$($tableVUEMRegAction[$gpoReg.Action]),$($tableVUEMRegScope[$gpoReg.Scope]),'$($gpoReg.KeyName)','$($gpoReg.ValueName)',"
                    if ($gpoReg.Action -eq "DeleteValue") { $SQLQuery += "NULL" } else { $SQLQuery += "'$($gpoRegJData)'" }
                    $SQLQuery += ",NULL,1,NULL)"
                    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                }

                # writing the GPO regoperations action to the changelog
                New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Update" -ObjectName "$($result.Tables.Rows.Name) ($($result.Tables.Rows.GUID.ToString().ToLower()))" -ObjectType "Group Policy\Object\Registry Operations" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
            } else {
                Write-Verbose "Overwrite mode is disabled. Skipping update for this Group Policy Settings object"
                return $null
            }
        } else {
            Write-Verbose "Name '$($gpoName)' is unique"
            # insert GroupPolicyObject
            $SQLQuery = "INSERT INTO GroupPolicyObjects (IdSite,GUID,Name,Description,CreatedTime,ModifiedTime,State,RevisionId,Reserved01) VALUES ($($IdSite), '$((New-Guid).Guid.ToString().ToUpper())','$($gpoName)','$($gpoName)','$(Get-Date)','$(Get-Date)',1,1,NULL)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # grab the new GroupPolicyObject
            $SQLQuery = "SELECT * FROM GroupPolicyObjects WHERE Name = '$($gpoName)' AND IdSite = $($IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            $IdObject = $result.Tables.Rows.IdObject

            # writing the create action to the changelog
            New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName "$($result.Tables.Rows.Name) ($($result.Tables.Rows.GUID.ToString().ToLower()))" -ObjectType "Group Policy\Object" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

            # insert new GroupPolicyRegOperations for this GPO
            foreach ($gpoReg in $gpoRegs) {
                $gpoRegJData = (@{ "Type" = $gpoReg.ValueType.ToString(); "Data" = $gpoReg.ValueData } | ConvertTo-Json -Depth 9).ToString()
                $SQLQuery = "INSERT INTO GroupPolicyRegOperations (IdObject,RegAction,Scope,KeyPath,Value,JData,PolicyDefinition,RevisionId,Reserved01) VALUES ($($IdObject),$($tableVUEMRegAction[$gpoReg.Action]),$($tableVUEMRegScope[$gpoReg.Scope]),'$($gpoReg.KeyName)','$($gpoReg.ValueName)',"
                if ($gpoReg.Action -eq "DeleteValue") { $SQLQuery += "NULL" } else { $SQLQuery += "'$($gpoRegJData)'" }
                $SQLQuery += ",NULL,1,NULL)"
                $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
            }

            # writing the GPO regoperations action to the changelog
            New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Update" -ObjectName "$($result.Tables.Rows.Name) ($($result.Tables.Rows.GUID.ToString().ToLower()))" -ObjectType "Group Policy\Object\Registry Operations" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        }

        # return the new GPO object
        return (Get-WEMGroupPolicyObject -Connection $Connection -IdSite $IdSite -IdObject $IdObject)
    }
}
