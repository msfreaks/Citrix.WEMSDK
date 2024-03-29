<#
    .Synopsis
    Sets up a database connection.

    .Description
    Sets up a database connection.

    .Link
    https://msfreaks.wordpress.com

    .Parameter Server
    ..

    .Parameter Database
    ..
    
    .Parameter Credential
    ..
    
    .Example

    .Notes
    Author: Arjan Mensch
#>
function New-WEMDatabaseConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)][string]$Server,
        [Parameter(Mandatory=$True)][string]$Database,
        [Parameter(Mandatory=$False)][PSCredential]$Credential = [PSCredential]::Empty
    )

    $ConnectionString = $null
    if ($Credential -ne [PSCredential]::Empty) {
        Write-Verbose "Credential provided. Setting up connection using credentials."
        $ConnectionString = "Server=$Server;Database=$Database;User Id=$($Credential.UserName);Password=$($Credential.GetNetworkCredential().password);"
    } else {
        Write-Verbose "No credential provided. Setting up connection using Integrated Security."
        $ConnectionString = "Server=$($Server);Database=$($Database);Trusted_Connection=True"
        #$ConnectionString = "Data Source=$Server; Integrated Security=SSPI; Initial Catalog=$Database"
    }

    Write-Verbose "Connection string: $($ConnectionString)"

    $connection = New-Object -TypeName "System.Data.SqlClient.SqlConnection" $ConnectionString

    # grab database version
    $SQLQuery = "SELECT value FROM VUEMParameters WHERE IdSite = 1 AND Name = 'VersionInfo'"
    $result = Invoke-SQL -Connection $connection -Query $SQLQuery
    $script:databaseVersion = $result.Tables.Rows.value
    $script:databaseSchema = $script:databaseVersion.Substring(0, $script:databaseVersion.IndexOf("."))

    # 1903.0.1.1, 1906.0.1.1, 1909.1.0.1, 1912.1.0.1
    Write-Verbose "Database version $($script:databaseVersion) detected (schema $($script:databaseSchema))"
    if (-not $configurationSettings[$script:databaseSchema]) {
        Write-Warning "Connected to a database version with unsupported schema: $($script:databaseVersion) (schema $($script:databaseSchema))`nLatest supported schema version for this module: $($configurationSettings.Keys | Sort-Object -Descending | Select-Object -First 1)`n`nFull functionality is not guaranteed`nFalling back to latest supported schema version"
        $script:databaseSchema = ($configurationSettings.Keys | Sort-Object -Descending | Select-Object -First 1)
    }
    return $connection
}
