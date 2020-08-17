<#
    .Synopsis
    Create a new Citrix Optimizer Configuration object in the WEM Database.

    .Description
    Create a new Citrix Optimizer Configuration object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [string]$TemplateXmlFile,

        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State = "Enabled",
        [Parameter(Mandatory=$False)]
        [string[]]$Groups = @(),
        [Parameter(Mandatory=$True)]
        [string[]]$Targets,

        [Parameter(Mandatory=$True)]
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

        # for byFile set, only continue of the templatefile can be found and is a Citrix Optimizer xml file
        $content = $null
        $contentId = $null
        $xmlContent = $null

        # check if the file exists
        if (-not (Test-Path -Path $TemplateXmlFile -Include "*.xml" -ErrorAction SilentlyContinue)) {
            Write-Host "'$($TemplateXmlFile)' was not found" -ForegroundColor Red
            Break
        }

        # load the file and check if it's a Citrix Optimizer file
        try {
            $content = Get-Content -Path $TemplateXmlFile -Encoding UTF8 -Raw
        }
        catch {
            Write-Host "Error loading '$($TemplateXmlFile)'" -ForegroundColor Red
            Break                
        }

        $xmlContent = [xml]$content
        if (-not ($xmlContent.root) -or -not ($xmlContent.root.metadata) -or -not ($xmlContent.root.group) -or -not ($xmlContent.root.metadata.category -eq "OS Optimizations")) {
            Write-Host "'$($TemplateXmlFile)' was loaded but does not appear to be a Citrix Optimizer template file" -ForegroundColor Red
            Break
        }

        # calculate hash (Thanks Wayne!)
        $mySHA256 = [System.Security.Cryptography.SHA256]::Create()
        $contenthash = [System.Convert]::ToBase64String($mySHA256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($content)))
        
        $SQLQuery = "SELECT IdContent FROM VUEMCitrixOptimizerTemplatesHash WHERE TemplateHash = '$($contenthash)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.IdContent) {
            Write-Host "This template is already in the database" -ForegroundColor Red
            Break
        }

        # get the name from the XmlFile
        $Name = ConvertTo-StringEscaped $xmlContent.root.metadata.displayname

        # insert the template-hash into the database
        $SQLQuery = "INSERT INTO VUEMCitrixOptimizerTemplatesHash (TemplateHash) VALUES ('$($contenthash)')"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
        # grab the contentId
        $SQLQuery = "SELECT IdContent FROM VUEMCitrixOptimizerTemplatesHash WHERE TemplateHash = '$($ContentHash)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        $contentId = $result.Tables.Rows.IdContent

        # insert the template into the database
        $content = ConvertTo-StringEscaped $content
        $SQLQuery = "INSERT INTO VUEMCitrixOptimizerTemplatesContent (IdContent, TemplateContent) VALUES ($($contentId), '$($content)')"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # paritally build query
        $SQLQuery = "INSERT INTO VUEMCitrixOptimizerConfigurations (IdSite, Name, State, Targets, SelectedGroups, UnselectedGroups, IsDefaultTemplate, IdContent, RevisionId, Reserved01) VALUES ($($IdSite), '$($Name)', "

        # check the other parameters
        # check State (only 1 Target OS template may be enabled at any time) 
        if ($State -eq "Enabled") {
            $configurations = Get-WEMCitrixOptimizerConfiguration -Connection $Connection -IdSite $IdSite -State Enabled

            # check Target OSs
            foreach ($configuration in $configurations) {
                $conftargets = 0
                foreach ($target in $configuration.Targets) {
                    $conftargets += [int]($configurationSettings."$($script:databaseSchema)".VUEMCitrixOptimizerTargets.GetEnumerator() | Where-Object {$_.Value -eq $target}).Name
                }
                if($newtargets -band $conftargets) {
                    Write-Host "Cannot Enable this Citrix Optimizer Configuration.`nOnly one Target OS Template may be enabled at any time.`n'$($configuration.Name)' is already enabled for one or more of the requested target OSs." -ForegroundColor Red
                    Break
                }
            }

            Write-Verbose "Determined State can indeed be Enabled"
        }

        $SQLQuery += "$($tableVUEMState["$($State)"]), "

        # determine targets
        $newtargets = 0
        foreach($target in $Targets) {
            if ($configurationSettings."$($script:databaseSchema)".VUEMCitrixOptimizerTargets.GetEnumerator() | Where-Object {$_.Value -eq $target}) {
                $newtargets += [int]($configurationSettings."$($script:databaseSchema)".VUEMCitrixOptimizerTargets.GetEnumerator() | Where-Object {$_.Value -eq $target}).Name
            } else {
                Write-Host "Cannot apply Targets parameter.`n'$($target)' does not exist in WEM $($script:databaseSchema)" -ForegroundColor Red
                Break
            }
        }

        Write-Verbose "Determined Targets are valid"

        $SQLQuery += "$($newtargets), "

        # determine groups
        $selectedGroups = @()
        $unselectedGroups = @()
        $availableGroups = $xmlContent.root.group.displayname

        # check Groups 
        if (@($Groups | Where-Object { $availableGroups -notcontains $_ } | Select-Object -first 1).Count) {
            Write-Host "One or more of the requested groups are not available in the template." -ForegroundColor Red
            Break
        }

        $selectedGroups = $Groups
        $unselectedGroups = @($availableGroups | Where-Object { $_ -notin $selectedGroups })

        $SQLQuery += "'$($selectedGroups -join ",")', '$($unselectedGroups -join ",")', "
        
        # insert everything into the CitrixOptimizerConfigurations table
        $SQLQuery += "0, $($contentId), 1, NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new Object
        $vuemObject = Get-WEMCitrixOptimizerConfiguration -Connection $Connection -IdSite $IdSite -Name "$($Name)"

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $vuemObject.IdTemplate -ChangeType "Create" -ObjectName $vuemObject.Name -ObjectType "Citrix Optimizer\Configurations" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        return $vuemObject
    }
}
