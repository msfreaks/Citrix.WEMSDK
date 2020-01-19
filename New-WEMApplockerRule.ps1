<#
    .Synopsis
    Create a new AppLocker Rule object in the WEM Database.

    .Description
    Create a new AppLocker Rule object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdSite
    ..

    .Parameter Name
    ..

    .Parameter Description
    ..

    .Parameter Type
    ..

    .Parameter Permission
    ..

    .Parameter IdADObjects
    ..

    .Parameter ConditionObject
    ..

    .Parameter ExceptionObjects
    ..

    .Parameter Connection
    ..

    .Example

    .Notes
    Author: Arjan Mensch
#>
function New-WEMAppLockerRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdSite,

        [Parameter(Mandatory=$True)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description = "",
        [Parameter(Mandatory=$True)][ValidateSet("Executable", "Windows Installer", "Scripts", "Packaged", "DLL")]
        [string]$Type,
        [Parameter(Mandatory=$True)][ValidateSet("Allow", "Deny")]
        [string]$Permission,
        [Parameter(Mandatory=$True)]
        [int[]]$IdADObjects,
        [Parameter(Mandatory=$True)]
        [pscustomobject]$ConditionObject,
        [Parameter(Mandatory=$False)]
        [pscustomobject[]]$ExceptionObjects,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # check if there is a configuration for $IdSite
        if (-not (Get-WEMConfiguration -Connection $Connection -IdSite $IdSite)) {
            Write-Error "Configuration not found. Please provide a valid Site Id"
            break
        }

        # check if the conditionobject is actually that
        if (-not ($ConditionObject.pstypenames[0] -like "Citrix.WEMSDK.AppLockerRule*Condition")) {
            Write-Error "ConditionObject is not the correct type. Please provide a valid AppLockerRuleConditionObject"
            break
        }

        # check if exceptions are valid for the type of condition that is requested
        if ($ExceptionObjects) {
            if ($ConditionObject.pstypenames[0] -ne "Citrix.WEMSDK.AppLockerRulePathCondition") {
                Write-Error "ExceptionObject(s) are only valid in combination with a PathCondition type"
                break
            } else {
                # check if the exceptionobjects are actually that
                foreach($ExceptionObject in $ExceptionObjects) {
                    if ($ExceptionObject -and -not ($ExceptionObject.pstypenames[0] -like "Citrix.WEMSDK.AppLockerRule*Condition")) {
                        Write-Error "ExceptionObject is not the correct type. Please provide a valid AppLockerRuleConditionObject"
                        break
                    }
                }
            }
        }
        
        # check if requested type matches with conditionobject
        if ($Type -eq "Executable" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRulePathCondition") {
            if ($ConditionObject.Path.Substring($ConditionObject.Path.Length -2) -ne "\*" -and (@(".exe",".com") -notcontains [System.IO.Path]::GetExtension($ConditionObject.Path.Substring($ConditionObject.Path.LastIndexOf("\") + 1)))) {
                Write-Error "For an Executable rule the Path Condition must be for a .exe or a .com file, or it must be a Path Condition"
                break
            }
        }
        if ($Type -eq "Executable" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRuleHashCondition" -and $ConditionObject.Purpose -ne "Executable") {
            Write-Error "For an Executable rule the Hash Condition purpose must be 'Executable'"
            break
        }
        if ($Type -eq "Windows Installer" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRulePathCondition") {
            if ($ConditionObject.Path.Substring($ConditionObject.Path.Length -2) -ne "\*" -and (@(".msi",".msp",".mst") -notcontains [System.IO.Path]::GetExtension($ConditionObject.Path.Substring($ConditionObject.Path.LastIndexOf("\") + 1)))) {
                Write-Error "For a Windows Installer rule the Path Condition must be for a .msi, a .msp or a .mst file, or it must be a Path Condition"
                break
            }
        }
        if ($Type -eq "Windows Installer" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRuleHashCondition" -and $ConditionObject.Purpose -ne "Windows Installer") {
            Write-Error "For an Windows Installer rule the Hash Condition purpose must be 'Windows Installer'"
            break
        }
        if ($Type -eq "Scripts" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRulePathCondition") {
            if ($ConditionObject.Path.Substring($ConditionObject.Path.Length -2) -ne "\*" -and (@(".ps1",".bat",".cmd",".vbs",".js") -notcontains [System.IO.Path]::GetExtension($ConditionObject.Path.Substring($ConditionObject.Path.LastIndexOf("\") + 1)))) {
                Write-Error "For a Scripts rule the Path Condition must be for a .ps1, a .bat, a .cmd, a .vbs or a .js file, or it must be a Path Condition"
                break
            }
        }
        if ($Type -eq "Scripts" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRuleHashCondition" -and $ConditionObject.Purpose -ne "Scripts") {
            Write-Error "For a Scripts rule the Hash Condition purpose must be 'Scripts'"
            break
        }
        if ($Type -eq "Packaged" -and $ConditionObject.pstypenames[0] -ne "Citrix.WEMSDK.AppLockerRulePublisherCondition") {
            Write-Error "For an Packaged rule only a Publisher Condition is valid"
            break
        }
        if ($Type -eq "DLL" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRulePathCondition") {
            if ($ConditionObject.Path.Substring($ConditionObject.Path.Length -2) -ne "\*" -and (@(".dll",".ocx") -notcontains [System.IO.Path]::GetExtension($ConditionObject.Path.Substring($ConditionObject.Path.LastIndexOf("\") + 1)))) {
                Write-Error "For a DLL rule the Path Condition must be for a .dll or a .ocx file, or it must be a Path Condition"
                break
            }
        }
        if ($Type -eq "DLL" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRuleHashCondition" -and $ConditionObject.Purpose -ne "DLL") {
            Write-Error "For a DLL rule the Hash Condition purpose must be 'DLL'"
            break
        }

        # check if the ADObjects exist in the requested configuration
        foreach($IdADObject in $IdADObjects) {
            $adObject = Get-WEMADUserObject -Connection $Connection -IdSite $IdSite -IdADObject $IdADObject
            if (-not ($adObject)) {
                Write-Error "Could not find an ADUserObject for IdADObject $($IdADObject)"
                break
            }
        }

        # escape possible query breakers
        $Name = ConvertTo-StringEscaped $Name
        $Description = ConvertTo-StringEscaped $Description

        # insert rule
        # build the query to insert the Object
        $ruleGuid = (New-Guid).Guid.ToUpper()
        $SQLQuery = "INSERT INTO AppLockerRules (IdSite, RuleGuid, CollectionType, RuleType, Name, Description, Action, State, RevisionId, Reserved01) VALUES ($($IdSite),'$($ruleGuid)',$($tableVUEMAppLockerCollectionType[$Type]),$($tableVUEMAppLockerRuleType[$ConditionObject.Type]),'$($Name)','$($Description)',0,$($tableVUEMAppLockerRulePermission[$Permission]),1,NULL)"
        $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

        # grab the new Object
        $SQLQuery = "SELECT * FROM AppLockerRules WHERE IdSite = $($IdSite) AND RuleGuid = '$($ruleguid)'"
        $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
        $vuemAppLockerRule = $result.Tables.Rows

        # insert condition
        switch ($ConditionObject.pstypenames[0]) {
            "Citrix.WEMSDK.AppLockerRulePathCondition" { 
                # build the query to insert the Object
                $SQLQuery = "INSERT INTO AppLockerRulePathConditions (IdRule, Path, IsException, RevisionId, Reserved01) VALUES ($($vuemAppLockerRule.IdRule),'$($ConditionObject.Path)',0,0,NULL)"
                $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                
                # insert exceptions
                foreach($ExceptionObject in $ExceptionObjects) {
                    switch ($ExceptionObject.pstypenames[0]) {
                        "Citrix.WEMSDK.AppLockerRulePathCondition" {
                            # build the query to insert the Object
                            $SQLQuery = "INSERT INTO AppLockerRulePathConditions (IdRule, Path, IsException, RevisionId, Reserved01) VALUES ($($vuemAppLockerRule.IdRule),'$($ExceptionObject.Path)',1,0,NULL)"
                            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                        }
                        "Citrix.WEMSDK.AppLockerRulePublisherCondition" {
                            # build the query to insert the Object
                            $SQLQuery = "INSERT INTO AppLockerRulePublisherConditions (IdRule, FilePath, FileName, LowSection, HighSection, Product, Publisher, IsException, RevisionId, Reserved01) VALUES ($($vuemAppLockerRule.IdRule),'$($ExceptionObject.FilePath)','$($ExceptionObject.FileName)','$($ExceptionObject.LowSection)','$($ExceptionObject.HighSection)','$($ExceptionObject.Product)','$($ExceptionObject.Publisher)',1,0,NULL)"
                            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                        }
                        "Citrix.WEMSDK.AppLockerRuleHashCondition" {
                            # build the query to insert the Object
                            $SQLQuery = "INSERT INTO AppLockerRuleHashConditions (IdRule, IsException, RevisionId, Reserved01) VALUES ($($vuemAppLockerRule.IdRule),1,0,NULL)"
                            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

                            # grab the new Object
                            $SQLQuery = "SELECT TOP (1) * FROM AppLockerRuleHashConditions WHERE IdRule = $($vuemAppLockerRule.IdRule) AND IsException = 1 ORDER BY IdCondition DESC"
                            $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                            $vuemAppLockerException = $result.Tables.Rows

                            # process hashes
                            foreach($hash in $ExceptionObject.Hashes) {
                                $SQLQuery = "INSERT INTO AppLockerRuleFileHashes (IdCondition, HashAlgorithm, Hash, FileLength, RevisionId, Reserved01, FileName) VALUES ($($vuemAppLockerException.IdCondition),0,$($hash.Hash),$($hash.FileLength),0,NULL,'$($hash.FileName)')"
                                $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                            }
                        }
                        Default {}
                    }
                }
            }
            "Citrix.WEMSDK.AppLockerRulePublisherCondition" {
                # build the query to insert the Object
                $SQLQuery = "INSERT INTO AppLockerRulePublisherConditions (IdRule, FilePath, FileName, LowSection, HighSection, Product, Publisher, IsException, RevisionId, Reserved01) VALUES ($($vuemAppLockerRule.IdRule),'$($ConditionObject.FilePath)','$($ConditionObject.FileName)','$($ConditionObject.LowSection)','$($ConditionObject.HighSection)','$($ConditionObject.Product)','$($ConditionObject.Publisher)',0,0,NULL)"
                $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
            }
            "Citrix.WEMSDK.AppLockerRuleHashCondition" {
                # build the query to insert the Object
                $SQLQuery = "INSERT INTO AppLockerRuleHashConditions (IdRule, IsException, RevisionId, Reserved01) VALUES ($($vuemAppLockerRule.IdRule),0,0,NULL)"
                $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                
                # grab the new Object
                $SQLQuery = "SELECT TOP (1) * FROM AppLockerRuleHashConditions WHERE IdRule = $($vuemAppLockerRule.IdRule) ORDER BY IdCondition DESC"
                $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                $vuemAppLockerCondition = $result.Tables.Rows

                # process hashes
                foreach($hash in $ConditionObject.Hashes) {
                    $SQLQuery = "INSERT INTO AppLockerRuleFileHashes (IdCondition, HashAlgorithm, Hash, FileLength, RevisionId, Reserved01, FileName) VALUES ($($vuemAppLockerCondition.IdCondition),0,$($hash.Hash),$($hash.FileLength),0,NULL,'$($hash.FileName)')"
                    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                }
            }
            Default {}
        }

        # insert assignment
        # build the query to insert the Object
        foreach($IdADObject in $IdADObjects) {
            $SQLQuery = "INSERT INTO AppLockerRuleAssignments (IdSite, IdAppLockerRule, IdItem, RevisionId, Reserved01) VALUES ($($IdSite),$($vuemAppLockerRule.IdRule),$($IdADObject),1,NULL)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
        }

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $IdSite -IdElement $vuemAppLockerRule.IdRule -ChangeType "Create" -ObjectName $vuemAppLockerRule.Name -ObjectType "AppLocker Rule\$($tableVUEMAppLockerChangeLogType["$($vuemAppLockerRule.CollectionType).$($vuemAppLockerRule.RuleType)"])" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
    }
}
