<#
    .Synopsis
    Create a new Citrix Optimizer Configuration object in the WEM Database.

    .Description
    Create a new Citrix Optimizer Configuration object in the WEM Database.

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

    .Parameter Priority
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function New-WEMCitrixOptimizerConfiguration {
    [CmdletBinding(DefaultParameterSetName="byName")]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True, ParameterSetName="byName")]
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True, ParameterSetName="byFile")]
        [int]$IdSite,

        [Parameter(Mandatory=$True, ParameterSetName="byName")]
        [string]$Name,
        [Parameter(Mandatory=$True, ParameterSetName="byFile")]
        [string]$TemplateXmlFile,

        [Parameter(Mandatory=$False, ParameterSetName="byName")]
        [Parameter(Mandatory=$False, ParameterSetName="byFile")]
        [string[]]$Groups = @(""),
        [Parameter(Mandatory=$True, ParameterSetName="byName")]
        [Parameter(Mandatory=$True, ParameterSetName="byFile")]
        [string[]]$Targets,
        [Parameter(Mandatory=$False, ParameterSetName="byName")][ValidateSet("Enabled","Disabled")]
        [Parameter(Mandatory=$False, ParameterSetName="byFile")][ValidateSet("Enabled","Disabled")]
        [string]$State = "Enabled",

        [Parameter(Mandatory=$True, ParameterSetName="byName")]
        [Parameter(Mandatory=$True, ParameterSetName="byFile")]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # only continue if the WEM version supports it
        if ($script:databaseSchema -lt 2003) {
            Write-Error "WEM $($script:databaseSchema) does not support Citrix Optimizer Configurations"
            Break
        }

        # only continue if a valid IdSite was passed
        if (-not (Get-WEMConfiguration -Connection $Connection -IdSite $IdSite)) {
            Write-Warning "No site found with IdSite $($IdSite)"
            Break
        }

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name

        # for byName set, only continue of the templatename actually exists and is not already being used
        $contentId = $null
        if ($PsCmdlet.ParameterSetName -eq "byName") {
            # build query to check if there is a template with that name
            $SQLQuery = "SELECT IdContent FROM VUEMCitrixOptimizerTemplatesContent WHERE TemplateContent LIKE '%<displayname>$($Name)</displayname>%'"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables) {
                $contentId = $result.Tables.Rows.IdContent
            } else {
                Write-Host "There is no template in the database named '$($Name)'.`nName parameter should match the DisplayName tag in the template" -ForegroundColor Red
                Break
            }

            # build query to check if there is a configuration with that contentId
            $SQLQuery = "SELECT * FROM VUEMCitrixOptimizerConfigurations WHERE IdContent = $($contentId) AND IdSite = $($IdSite)"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables) {
                Write-Host "There is already a Citrix Optimizer Configuration in this site referencing '$($Name)'" -ForegroundColor Red
                Break
            }
        }

        # for byFile set, only continue of the templatefile can be found and is a Citrix Optimizer xml file
        $content = $null

        if ($PsCmdlet.ParameterSetName -eq "byFile") {
            # check if the file exists
            if (-not (Test-Path -Path $TemplateXmlFile -Include "*.xml" -ErrorAction SilentlyContinue)) {
                Write-Host "'$($TemplateXmlFile)' was not found" -ForegroundColor Red
                Break
            }

            # load the file and check if it's a Citrix Optimizer file
            try {
                $content = [xml](Get-Content -Path $TemplateXmlFile)
            }
            catch {
                Write-Host "Error loading '$($TemplateXmlFile)'" -ForegroundColor Red
                Break                
            }

            if (-not ($content.root) -or -not ($content.root.metadata) -or -not ($content.root.group) -or -not ($content.root.metadata.category -eq "OS Optimizations")) {
                Write-Host "'$($TemplateXmlFile)' was loaded but does not appear to be a Citrix Optimizer template file"
                Break
            }

            # calculate hash
            #
            # NOTE:
            # 2020-08-05 hash method unknown. Closest I get is MD5 the content, then Base64 that MD5 hash
            #
            $contenthash = ""
            $SQLQuery = "SELECT * FROM VUEMCitrixOptimizerTemplatesHash WHERE TemplateHash = '$($contenthash)'"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
            if ($result.Tables) {
                Write-Host "This template is already in the database" -ForegroundColor Red
                Break
            }

            # insert the template into the database

            # insert the template-hash into the database

        }

        # check the other parameters

        # insert everything into the CitrixOptimizerConfigurations table
        # build the query to insert the Object
        $SQLQuery = "INSERT INTO .."
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new Object
        $vuemObject = Get-WEMCitrixOptimizerConfiguration -Connection $Connection -IdSite $IdSite -Name "$($Name)"

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $vuemObject.IdTemplate -ChangeType "Create" -ObjectName $vuemObject.Name -ObjectType "Citrix Optimizer\Configurations" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return $vuemObject
    }
}
