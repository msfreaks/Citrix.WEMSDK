<#
    .Synopsis
    Updates a Citrix Optimizer Configuration object in the WEM Database.

    .Description
    Updates a Citrix Optimizer Configuration object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter IdTemplate
    ..

    .Parameter State
    ..

    .Parameter Groups
    ..

    .Parameter Targets
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Set-WEMCitrixOptimizerConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdTemplate,

        [Parameter(Mandatory=$False)][ValidateSet("Enabled","Disabled")]
        [string]$State,
        [Parameter(Mandatory=$False)]
        [string[]]$Groups,
        [Parameter(Mandatory=$False)]
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
        
        # grab original object
        $origObject = Get-WEMCitrixOptimizerConfiguration -Connection $Connection -IdSite $IdSite -IdTemplate $IdTemplate -Verbose

        # only continue if the object was found
        if (-not $origObject) { 
            Write-Warning "No Citrix Optimizer Configuration object found for Id $($IdTemplate)"
            Break
        }
        
        # determine targets
        $newtargets = 0
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'targets')) {
            foreach($target in $Targets) {
                if ($configurationSettings."$($script:databaseSchema)".VUEMCitrixOptimizerTargets.GetEnumerator() | Where-Object {$_.Value -eq $target}) {
                    $newtargets += [int]($configurationSettings."$($script:databaseSchema)".VUEMCitrixOptimizerTargets.GetEnumerator() | Where-Object {$_.Value -eq $target}).Name
                } else {
                    Write-Host "Cannot apply Targets parameter.`n'$($target)' does not exist in WEM $($script:databaseSchema)" -ForegroundColor Red
                    Break
                }
            }

            Write-Verbose "Determined Targets are valid"
        }

        # check State (only 1 Target OS template may be enabled at any time) 
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'state') -and $State -eq "Enabled") {
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

        $selectedGroups = @()
        $unselectedGroups = @()
        $availableGroups = $origObject.TemplateXml.Root.Group.DisplayName

        # check Groups (only 1 Target OS template may be enabled at any time) 
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'groups')) {
            if (@($Groups | Where-Object { $availableGroups -notcontains $_ } | Select-Object -first 1).Count) {
                Write-Host "One or more of the requested groups are not available in the template." -ForegroundColor Red
                Break
            }

            $selectedGroups = $Groups
            $unselectedGroups = @($availableGroups | Where-Object { $_ -notin $selectedGroups })
        }

        # build the query to update the object
        $SQLQuery = "UPDATE VUEMCitrixOptimizerConfigurations SET "
        $updateFields = @()
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $_ -notmatch "connection" -and $_ -notmatch "idtemplate" -and $_ -notmatch "idsite" }
        foreach ($key in $keys) {
            switch ($key) {
                "State" {
                    $updateFields += "State = $($tableVUEMState["$($State)"])"
                    continue
                }
                "Groups" {
                    $updateFields += "SelectedGroups = '$($selectedGroups -join ",")'"
                    $updateFields += "UnselectedGroups = '$($unselectedGroups -join ",")'"
                    continue
                }
                "Targets" {
                    $updateFields += "Targets = $($newtargets)"
                    continue
                }
                Default {}
            }
        }

        # if anything needs to be updated, update the object
        if($updateFields) { 
            $SQLQuery += "{0}, " -f ($updateFields -join ", ")
            $SQLQuery += "RevisionId = $($origObject.Version + 1) WHERE IdTemplate = $($IdTemplate)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdTemplate -ChangeType "Update" -ObjectName $origObject.Name -ObjectType "Citrix Optimizer\Configurations" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        } else {
            Write-Warning "No parameters to update were provided"
        }
    }
}
