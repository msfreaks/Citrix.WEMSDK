<#
    .Synopsis
    Create a new File Association object in the WEM Database.

    .Description
    Create a new File Association Action object in the WEM Database.

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

    .Parameter FileExtension
    ..

    .Parameter ProgramId
    ..

    .Parameter Action
    ..

    .Parameter IsDefault
    ..

    .Parameter TargetPath
    ..

    .Parameter TargetCommand
    ..

    .Parameter TargetOverwrite
    ..

    .Parameter RunOnce
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMFileAssociation {
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
        [Parameter(Mandatory=$False)][ValidateSet("Create / Set File Association")]
        [string]$ActionType = "Create / Set File Association",
        [Parameter(Mandatory=$True)]
        [string]$FileExtension,
        [Parameter(Mandatory=$True)]
        [string]$ProgramId,
        [Parameter(Mandatory=$True)][ValidateSet("open", "edit", "print")]
        [string]$Action,
        [Parameter(Mandatory=$False)]
        [bool]$IsDefault = $false,
        [Parameter(Mandatory=$True)]
        [string]$TargetPath,
        [Parameter(Mandatory=$True)]
        [string]$TargetCommand,
        [Parameter(Mandatory=$False)]
        [bool]$TargetOverwrite = $false,
        [Parameter(Mandatory=$False)]
        [bool]$RunOnce = $false,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description
        $FileExtension = ConvertTo-StringEscaped $FileExtension
        $ProgramId = ConvertTo-StringEscaped $ProgramId
        $TargetPath = ConvertTo-StringEscaped $TargetPath
        $TargetCommand = ConvertTo-StringEscaped $TargetCommand

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS ObjectCount FROM VUEMFileAssocs WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.ObjectCount) {
            # name must be unique
            Write-Error "There's already a File Association object named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMFileAssocs (IdSite,Name,Description,State,ActionType,FileExt,ProgId,Action,isDefault,TargetPath,TargetCommand,TargetOverwrite,RunOnce,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMFileAssocActionType[$ActionType]),'$($FileExtension)','$($ProgramId)','$($Action)','$([int]$IsDefault)','$($TargetPath)','$($TargetCommand)','$([int]$TargetOverwrite)','$([int]$RunOnce)',1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT * FROM VUEMFileAssocs WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        $IdObject = $result.Tables.Rows.IdFileAssoc
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Create" -ObjectName $Name -ObjectType "Actions\File Association" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return New-VUEMFileAssocObject -DataRow $result.Tables.Rows
        #Get-WEMFileAssociation -Connection $Connection -IdAction $result.Tables.Rows.IdAction
    }
}
New-Alias -Name New-WEMFileAssoc -Value New-WEMFileAssociation