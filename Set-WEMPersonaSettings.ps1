<#
    .Synopsis
    Updates a WEM Persona Settings object in the WEM Database.

    .Description
    Updates a WEM Persona Settings object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Parameters
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function Set-WEMPersonaSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [pscustomobject]$Parameters,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {

        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # only continue if a valid IdSite was passed
        if(-not (Get-WEMConfiguration -Connection $Connection -IdSite $IdSite)) {
            Write-Warning "No site found with IdSite $($IdSite)"
            Break
        }

        # if a Parameters object was passed, set variables and MyInvocation to these values
        $Parameters.Keys | ForEach-Object {
            if ($configurationSettings[$script:databaseSchema].PersonaValues -match "'$($_)'") {
                if(Get-Variable -Name $_ -ErrorAction SilentlyContinue) { 
                    Write-Verbose "Setting $($_) variable using $($_) value from parameter object to override single parameter"
                    Set-Variable -Name $_ -Value $Parameters.$_
                } else {
                    Write-Verbose "Creating $($_) variable using $($_) value from parameter object"
                    New-Variable -Name $_ -Value $Parameters.$_
                }
                $MyInvocation.BoundParameters.$_ = $Parameters.$_
            } else {
                Write-Warning "Unknown parameter found in parameter object ('$($_)')"
            }
        }

        # process all parameters
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $configurationSettings[$script:databaseSchema].PersonaValues -match "'$($_)'" }

        foreach($key in $keys) {
            # build query for each valid parameter
            $SQLQuery = "UPDATE VUEMPersonaSettings SET Value = '"
            $value = (Get-Variable -Name $key).Value
            $sqlValue = $value
            switch($value) {
                ("True" -or "False") {
                    $SQLQuery += "$([int][bool]$value)"
                    $sqlValue = [string][int][bool]$value
                }
                default {
                    $SQLQuery += "$($value)"
                }
            }
            $SQLQuery += "', RevisionId = RevisionId + 1 WHERE Name = '$($key)' AND IdSite = $($IdSite)"

            # execute the query
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # grab the updated object
            $SQLQuery = "SELECT * FROM VUEMPersonaSettings WHERE IdSite = $($IdSite) AND Name = '$($key)'"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $IdObject = $result.Tables.Rows.IdItem
            New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Update" -ObjectName $key -ObjectType "Policies and Profiles\VMware Persona Settings" -NewValue $sqlValue -ChangeDescription $null -Reserved01 $null 
        }
    }
}
