<#
    .Synopsis
    Create a new File System Operation Action object in the WEM Database.

    .Description
    Create a new File System Operation Action object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Name
    ..

    .Parameter Description
    ..

    .Parameter State
    ..

    .Parameter ActionType
    ..

    .Parameter SourcePath
    ..

    .Parameter TargetPath
    ..

    .Parameter TargetOverwrite
    ..

    .Parameter ExecutionOrder
    ..

    .Parameter RunOnce
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function New-WEMFileSystemOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description = "",
        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$False)][ValidateSet("Copy Files / Folders", "Delete Files / Folders", "Rename Files / Folders", "Create Directory Symbolic Link", "Create File Symbolic Link", "Create Directory", "Copy Directory Content", "Delete Directory Content", "Move Directory Content")]
        [string]$ActionType = "Copy Files / Folders",
        [Parameter(Mandatory=$True)]
        [string]$SourcePath,
        [Parameter(Mandatory=$False)]
        [string]$TargetPath,
        [Parameter(Mandatory=$False)]
        [bool]$TargetOverwrite = $True,
        [Parameter(Mandatory=$False)]
        [int]$ExecutionOrder = 0,
        [Parameter(Mandatory=$False)]
        [bool]$RunOnce = $true,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description
        $SourcePath = ConvertTo-StringEscaped $SourcePath
        $TargetPath = ConvertTo-StringEscaped $TargetPath

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMFileSystemOps WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.Action) {
            # name must be unique
            Write-Error "There's already a File System Operation object named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # apply Advanced Option values
        [xml]$actionReserved = $defaultVUEMFileSystemOperationReserved
        ($actionReserved.ArrayOfVUEMActionAdvancedOption.VUEMActionAdvancedOption | Where-Object {$_.Name -like "ExecOrder"}).Value = [string]$ExecutionOrder

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMFileSystemOps (IdSite,Name,Description,State,ActionType,SourcePath,TargetPath,TargetOverwrite,RunOnce,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMFileSystemOpActionType[$ActionType]),'$($SourcePath)','$($TargetPath)',$([int]$TargetOverwrite),'$([int]$RunOnce)',1,'$($actionReserved.OuterXml)')"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT * FROM VUEMFileSystemOps WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdFileSystemOp
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\File System Operation" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return New-VUEMFileSystemOpObject -DataRow $result.Tables.Rows
        #Get-WEMFileSystemOperation -Connection $Connection -IdAction $IdObject
    }
}
New-Alias -Name New-WEMFileSystemOp -Value New-WEMFileSystemOperation