<#
    .Synopsis
    Updates a UPM Settings object in the WEM Database.

    .Description
    Updates a UPM Settings object in the WEM Database.

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
    Author: Arjan Mensch
#>
function Set-WEMUPMSettings {
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

        # don't update the Default Configuration
        if ($IdSite -eq 1) {
            Write-Warning "You cannot update settings for the Default Configuration"
            Break
        }

        # only continue if a valid IdSite was passed
        if(-not (Get-WEMConfiguration -Connection $Connection -IdSite $IdSite)) {
            Write-Warning "No site found with IdSite $($IdSite)"
            Break
        }

        # if a Parameters object was passed, set variables and MyInvocation to these values
        $Parameters.Keys | ForEach-Object {
            if ($configurationSettings[$script:databaseSchema].UPMValues -match "'$($_)'") {
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
        $keys = $MyInvocation.BoundParameters.Keys | Where-Object { $configurationSettings[$script:databaseSchema].UPMValues -match "'$($_)'" }

        foreach($key in $keys) {
            # build query for each valid parameter
            $value = (Get-Variable -Name $key).Value
            $SQLQuery = "UPDATE VUEMUPMSettings SET Value = '$($value)', RevisionId = RevisionId + 1 WHERE Name = '$($key)' AND IdSite = $($IdSite)"

            # execute the query
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # grab the updated object
            $SQLQuery = "SELECT * FROM VUEMUPMSettings WHERE IdSite = $($IdSite) AND Name = '$($key)'"
            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # Updating the ChangeLog
            $IdObject = $result.Tables.Rows.IdItem
            New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $IdObject -ChangeType "Update" -ObjectName $key -ObjectType "Policies and Profiles\Citrix UPM Settings" -NewValue $value -ChangeDescription $null -Reserved01 $null 
        }
    }
}

<#
    .Synopsis
    Resets a UPM Settings object in the WEM Database.

    .Description
    Resets a UPM Settings object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function Reset-WEMUPMSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {

        Write-Verbose "Working with database version $($script:databaseVersion)"
        Write-Verbose "Function name '$($MyInvocation.MyCommand.Name)'"

        # create a settings object and fill it using defaults
        $parameterObject = @{}
        foreach($key in $configurationSettings[$script:databaseSchema].UPMValues) {
            $fields = $key.Replace("(","").Replace(")","").Replace(" ","").Split(",")
            $parameterObject.($fields[1].Replace("'","")) = $fields[2].Replace("'","")
        }

        # use the Set- function and pass the complete default settings object
        Set-WEMUPMSettings -Connection $Connection -IdSite $IdSite -Parameters $parameterObject
    }
}
