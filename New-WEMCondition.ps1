<#
    .Synopsis
    Create a new Condition object in the WEM Database.

    .Description
    Create a new Condition object in the WEM Database.

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

    .Parameter Type
    ..

    .Parameter TestValue
    ..

    .Parameter TestResult
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author:  Arjan Mensch
    Version: 0.9.0
#>
function New-WEMCondition {
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
        [Parameter(Mandatory=$True)][ValidateSet("Active Directory Attribute Match","Active Directory Group Match","Active Directory Path Match","Active Directory Site Match","Client IP Address Match","Client OS","Client Remote OS Match","ClientName Match","ComputerName Match","Connection State","DateTime Match","Dynamic Value Match","Environment Variable Match","File Version Match","File/Folder does not exist","File/Folder exists","IP Address Match","Name is in List","Name is not in List","Name or Value is in List","Name or Value is not in List","Network Connection State","No Active Directory Attribute Match","No Active Directory Group Match","No Active Directory Path Match","No Active Directory Site Match","No Client IP Address Match","No Client OS Match","No Client Remote OS Match","No ClientName Match","No ComputerName Match","No DateTime Match","No Dynamic Value Match","No Environment Variable Match","No File Version Match","No IP Address Match","No Registry Value Match","No User Country Match","No User UI Language Match","No WMI Query result Match","No XenApp Farm Name Match","No XenApp Version Match","No XenApp Zone Name Match","No XenDesktop Desktop Group Name Match","No XenDesktop Farm Name Match","OS Platform Type","Provisioning Services Image Mode","Published Resource Name","Registry Value Match","Scheduling","Transformer Mode State","User Country Match","User SBC Resource Type","User UI Language Match","WMI Query result Match","XenApp Farm Name Match","XenApp Version Match","XenApp Zone Name Match","XenDesktop Desktop Group Name Match","XenDesktop Farm Name Match")]
        [string]$Type,
        [Parameter(Mandatory=$False)]
        [string]$TestValue = "",
        [Parameter(Mandatory=$True)]
        [string]$TestResult,
        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description
        $TestValue = ConvertTo-StringEscaped $TestValue
        $TestResult = ConvertTo-StringEscaped $TestResult

        # name is unique if it's not yet used in the same Action Type in the site 
        $SQLQuery = "SELECT COUNT(*) AS Condition FROM VUEMFiltersConditions WHERE Name LIKE '$($Name)' AND IdSite = $($IdSite)"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        if ($result.Tables.Rows.Condition -or $Name -like "always true") {
            # name must be unique
            Write-Error "There's already an Condition object named '$($Name)' in the Configuration"
            Break
        }

        Write-Verbose "Name is unique: Continue"

        # build optional values
        $requiredTestValue = -not $tableVUEMFiltersConditionType[$tableVUEMFiltersConditionType[$Type]].UseName
        $validatedTestResult = ($null -ne $tableVUEMFiltersConditionType[$tableVUEMFiltersConditionType[$Type]].TestedResult)

        if ($requiredTestValue -and [bool]($MyInvocation.BoundParameters.Keys -notcontains 'testvalue')) {
            Write-Error "If you define a condition of type '$($Type)', you must provide a value for 'TestValue'"
            Break
        }
        if (-not $requiredTestValue) { $TestValue = $Type }
        if ($validatedTestResult -and [bool]($tableVUEMFiltersConditionType[$tableVUEMFiltersConditionType[$Type]].TestedResult -notcontains $TestResult)) {
            Write-Error "If you define a condition of type '$($Type)', you must provide a value for 'TestResult' matching one of [$($tableVUEMFiltersConditionType[$tableVUEMFiltersConditionType[$Type]].TestedResult -join ", ")]"
            Break
        }

        # build the query to update the action
        $SQLQuery = "INSERT INTO VUEMFiltersConditions (IdSite,Name,Description,State,Type,TestValue,TestResult,RevisionId,Reserved01) VALUES ($($IdSite),'$($Name)','$($Description)',$($tableVUEMState[$State]),$($tableVUEMFiltersConditionType[$Type]),'$($TestValue)','$($TestResult)',1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new action
        $SQLQuery = "SELECT IdFilterCondition AS IdCondition FROM VUEMFiltersConditions WHERE IdSite = $($IdSite) AND Name = '$($Name)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $result.Tables.Rows.IdADObject -ChangeType "Create" -ObjectName $Name -ObjectType "Filters\Filter Condition" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null

        # Return the new object
        Get-WEMCondition -Connection $Connection -IdCondition $result.Tables.Rows.IdCondition
    }
}
