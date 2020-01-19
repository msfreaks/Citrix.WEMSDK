<#
    .Synopsis
    Updates a AppLocker Rule object in the WEM Database.

    .Description
    Updates a AppLocker Rule object in the WEM Database.

    .Link
    https://msfreaks.wordpress.com

    .Parameter IdRule
    ..

    .Parameter Name
    ..

    .Parameter Description
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
function Set-WEMAppLockerRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdRule,

        [Parameter(Mandatory=$False)]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [string]$Description = "",
        [Parameter(Mandatory=$False)][ValidateSet("Allow", "Deny")]
        [string]$Permission,
        [Parameter(Mandatory=$False)]
        [int[]]$IdADObjects,
        [Parameter(Mandatory=$False)]
        [pscustomobject]$ConditionObject,
        [Parameter(Mandatory=$False)]
        [pscustomobject[]]$ExceptionObjects,

        [Parameter(Mandatory=$True)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    process {

        # grab the orginal rule
        $origObject = Get-WEMAppLockerRule -Connection $Connection -IdRule $IdRule
        $Type = $origObject.CollectionType
        # abort if the rule does not exist
        if (-not $origObject) {
            Write-Error "No rule with id $($IdRule) found in the database"
            break
        }

        # check if the conditionobject parameter is set and has content
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and -not $ConditionObject) {
            Write-Error "A ConditionObject cannot be removed from a rule"
            break
        }

        # check if the conditionobject is actually that
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and -not ($ConditionObject.pstypenames[0] -like "Citrix.WEMSDK.AppLockerRule*Condition")) {
            Write-Error "ConditionObject is not the correct type. Please provide a valid AppLockerRuleConditionObject"
            break
        }

        # check if exceptions are valid for the type of condition that is requested
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ExceptionObjects') -and $ExceptionObjects) {
            if (([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and $ConditionObject.pstypenames[0] -ne "Citrix.WEMSDK.AppLockerRulePathCondition") -or ([bool]($MyInvocation.BoundParameters.Keys -notmatch 'ConditionObject') -and $origObject.RuleType -ne "PathCondition")) {
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
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and $Type -eq "Executable" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRulePathCondition") {
            if ($ConditionObject.Path.Substring($ConditionObject.Path.Length -2) -ne "\*" -and (@(".exe",".com") -notcontains [System.IO.Path]::GetExtension($ConditionObject.Path.Substring($ConditionObject.Path.LastIndexOf("\") + 1)))) {
                Write-Error "For an Executable rule the Path Condition must be for a .exe or a .com file, or it must be a Path Condition"
                break
            }
        }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and $Type -eq "Executable" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRuleHashCondition" -and $ConditionObject.Purpose -ne "Executable") {
            Write-Error "For an Executable rule the Hash Condition purpose must be 'Executable'"
            break
        }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and $Type -eq "Windows Installer" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRulePathCondition") {
            if ($ConditionObject.Path.Substring($ConditionObject.Path.Length -2) -ne "\*" -and (@(".msi",".msp",".mst") -notcontains [System.IO.Path]::GetExtension($ConditionObject.Path.Substring($ConditionObject.Path.LastIndexOf("\") + 1)))) {
                Write-Error "For a Windows Installer rule the Path Condition must be for a .msi, a .msp or a .mst file, or it must be a Path Condition"
                break
            }
        }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and $Type -eq "Windows Installer" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRuleHashCondition" -and $ConditionObject.Purpose -ne "Windows Installer") {
            Write-Error "For an Windows Installer rule the Hash Condition purpose must be 'Windows Installer'"
            break
        }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and $Type -eq "Scripts" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRulePathCondition") {
            if ($ConditionObject.Path.Substring($ConditionObject.Path.Length -2) -ne "\*" -and (@(".ps1",".bat",".cmd",".vbs",".js") -notcontains [System.IO.Path]::GetExtension($ConditionObject.Path.Substring($ConditionObject.Path.LastIndexOf("\") + 1)))) {
                Write-Error "For a Scripts rule the Path Condition must be for a .ps1, a .bat, a .cmd, a .vbs or a .js file, or it must be a Path Condition"
                break
            }
        }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and $Type -eq "Scripts" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRuleHashCondition" -and $ConditionObject.Purpose -ne "Scripts") {
            Write-Error "For a Scripts rule the Hash Condition purpose must be 'Scripts'"
            break
        }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and $Type -eq "Packaged" -and $ConditionObject.pstypenames[0] -ne "Citrix.WEMSDK.AppLockerRulePublisherCondition") {
            Write-Error "For an Packaged rule only a Publisher Condition is valid"
            break
        }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and $Type -eq "DLL" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRulePathCondition") {
            if ($ConditionObject.Path.Substring($ConditionObject.Path.Length -2) -ne "\*" -and (@(".dll",".ocx") -notcontains [System.IO.Path]::GetExtension($ConditionObject.Path.Substring($ConditionObject.Path.LastIndexOf("\") + 1)))) {
                Write-Error "For a DLL rule the Path Condition must be for a .dll or a .ocx file, or it must be a Path Condition"
                break
            }
        }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject') -and $Type -eq "DLL" -and $ConditionObject.pstypenames[0] -eq "Citrix.WEMSDK.AppLockerRuleHashCondition" -and $ConditionObject.Purpose -ne "DLL") {
            Write-Error "For a DLL rule the Hash Condition purpose must be 'DLL'"
            break
        }

        # check if the IdADObjects parameter is set and has content
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idadobjects') -and -not $IdADObjects) {
            Write-Error "You cannot remove all assignments from a rule"
            break
        }

        # check if the ADObjects exist in the requested configuration
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idadobjects')) {
            foreach($IdADObject in $IdADObjects) {
                $adObject = Get-WEMADUserObject -Connection $Connection -IdSite $IdSite -IdADObject $IdADObject
                if (-not ($adObject)) {
                    Write-Error "Could not find an ADUserObject for IdADObject $($IdADObject)"
                    break
                }
            }
        }

        # build the query to update the rule
        $updateFields = @()
        $SQLQuery = "UPDATE AppLockerRules SET "
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'name') -and $origObject.Name -ne (ConvertTo-StringEscaped $Name)) {
            $updateFields += "Name = '$(ConvertTo-StringEscaped $Name)'"
        }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'description') -and $origObject.Description -ne (ConvertTo-StringEscaped $Description)) {
            $updateFields += "Description = '$(ConvertTo-StringEscaped $Description)'"
        }
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'permission') -and $origObject.Permission -ne $Permission) {
            $updateFields += "State = $($tableVUEMApplockerRulePermission[$Permission])"
        }

        # only update if any of the fields were updated
        $isUpdated = $false

        if($updateFields) { 
            $SQLQuery += "{0} " -f ($updateFields -join ", ")
            $SQLQuery += "WHERE IdRule = $($IdRule)"
            Write-Verbose "Query built: $($SQLQuery)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

            # object is updated
            $isUpdated = $true
        } else {
            Write-Verbose "No parameters to update the AppLockerRule were provided, checking ConditionObject, ExceptionObjects, and IdADObjects"
        }

        # checking ConditionObject
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ConditionObject')) {
            Write-Verbose "ConditionObject parameter was found, process ConditionObject"
            # since the object is valid (this was checked earlier) delete the ConditionObject from the database and create the new one

            # insert condition
            switch ($ConditionObject.pstypenames[0]) {
                "Citrix.WEMSDK.AppLockerRulePathCondition" { 
                    # delete the old condition
                    Write-Verbose "Deleting PathCondition"
                    $SQLQuery = "DELETE FROM AppLockerRulePathConditions WHERE IdRule = $($IdRule) AND IsException = 0"
                    $null = Invoke-SQL -Connection $db -Query $SQLQuery
                    # build the query to insert the Object
                    $SQLQuery = "INSERT INTO AppLockerRulePathConditions (IdRule, Path, IsException, RevisionId, Reserved01) VALUES ($($IdRule),'$($ConditionObject.Path)',0,0,NULL)"
                    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery                    
                }
                "Citrix.WEMSDK.AppLockerRulePublisherCondition" {
                    # delete the old condition
                    Write-Verbose "Deleting PpublisherCondition"
                    $SQLQuery = "DELETE FROM AppLockerRulePublisherConditions WHERE IdRule = $($IdRule) AND IsException = 0"
                    $null = Invoke-SQL -Connection $db -Query $SQLQuery
                    # build the query to insert the Object
                    $SQLQuery = "INSERT INTO AppLockerRulePublisherConditions (IdRule, FilePath, FileName, LowSection, HighSection, Product, Publisher, IsException, RevisionId, Reserved01) VALUES ($($IdRule),'$($ConditionObject.FilePath)','$($ConditionObject.FileName)','$($ConditionObject.LowSection)','$($ConditionObject.HighSection)','$($ConditionObject.Product)','$($ConditionObject.Publisher)',0,0,NULL)"
                    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                }
                "Citrix.WEMSDK.AppLockerRuleHashCondition" {
                    # remove hashes from the old condition
                    $SQLQuery = "SELECT TOP (1) * FROM AppLockerRuleHashConditions WHERE IdRule = $($IdRule) AND IsException = 0 ORDER BY IdCondition DESC"
                    $result = Invoke-SQL -Connection $Connection -Query $SQLQuery
                    $vuemAppLockerCondition = $result.Tables.Rows
                    Write-Verbose "Deleting HashCondition hashes"
                    $SQLQuery = "DELETE FROM AppLockerRuleFileHashes WHERE IdCondition = $($vuemAppLockerCondition.IdCondition)"
                    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                    Write-Verbose "Deleting HashCondition"
                    $SQLQuery = "DELETE FROM AppLockerRuleHashConditions WHERE IdRule = $($IdRule) AND IsException = 0"
                    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

                    # build the query to insert the Object
                    $SQLQuery = "INSERT INTO AppLockerRuleHashConditions (IdRule, IsException, RevisionId, Reserved01) VALUES ($($IdRule),0,0,NULL)"
                    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                    
                    # grab the new Object
                    $SQLQuery = "SELECT TOP (1) * FROM AppLockerRuleHashConditions WHERE IdRule = $($IdRule) ORDER BY IdCondition DESC"
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

            # object is updated
            $isUpdated = $true
        }

        # checking ExceptionObjects
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'ExceptionObjects')) {
            Write-Verbose "ExceptionObjects parameter was found, process ExceptionObjects"

            # delete the existing exceptionobjects (this also takes care of $null value)
            Write-Verbose "Deleting PathCondition exceptions and PublisherCondition exceptions"
            $SQLQuery = "DELETE FROM AppLockerRulePathConditions WHERE IdRule = $($IdRule) AND IsException = 1;DELETE FROM AppLockerRulePublisherConditions WHERE IdRule = $($IdRule) AND IsException = 1"
            $null = Invoke-SQL -Connection $db -Query $SQLQuery

            # grab Hash condition exceptions
            $SQLQuery = "SELECT * FROM AppLockerRuleHashConditions WHERE IdRule = $($IdRule) AND IsException = 1"
            $result = Invoke-SQL -Connection $db -Query $SQLQuery
            foreach($row in $result.Tables.rows) {
                Write-Verbose "Deleting Hashes for the HashCondition exception in condition $($row.IdCondition)"
                $SQLQuery = "DELETE FROM AppLockerRuleFileHashes WHERE IdCondition = $($row.IdCondition)"
                Invoke-SQL -Connection $Connection -Query $SQLQuery
            }

            # delete hash condition exceptions (this is now possible because the hashes are also deleted)
            Write-Verbose "Deleting HashCondition exceptions"
            $SQLQuery = "DELETE FROM AppLockerRuleHashConditions WHERE IdRule = $($IdRule) AND IsException = 1"
            $null = Invoke-SQL -Connection $db -Query $SQLQuery

            if ($ExceptionObjects) {
                # create any new exceptionobjects
                # insert exceptions
                foreach($ExceptionObject in $ExceptionObjects) {
                    switch ($ExceptionObject.pstypenames[0]) {
                        "Citrix.WEMSDK.AppLockerRulePathCondition" {
                            # build the query to insert the Object
                            $SQLQuery = "INSERT INTO AppLockerRulePathConditions (IdRule, Path, IsException, RevisionId, Reserved01) VALUES ($($IdRule),'$($ExceptionObject.Path)',1,0,NULL)"
                            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                        }
                        "Citrix.WEMSDK.AppLockerRulePublisherCondition" {
                            # build the query to insert the Object
                            $SQLQuery = "INSERT INTO AppLockerRulePublisherConditions (IdRule, FilePath, FileName, LowSection, HighSection, Product, Publisher, IsException, RevisionId, Reserved01) VALUES ($($IdRule),'$($ExceptionObject.FilePath)','$($ExceptionObject.FileName)','$($ExceptionObject.LowSection)','$($ExceptionObject.HighSection)','$($ExceptionObject.Product)','$($ExceptionObject.Publisher)',1,0,NULL)"
                            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
                        }
                        "Citrix.WEMSDK.AppLockerRuleHashCondition" {
                            # build the query to insert the Object
                            $SQLQuery = "INSERT INTO AppLockerRuleHashConditions (IdRule, IsException, RevisionId, Reserved01) VALUES ($($IdRule),1,0,NULL)"
                            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

                            # grab the new Object
                            $SQLQuery = "SELECT TOP (1) * FROM AppLockerRuleHashConditions WHERE IdRule = $($IdRule) AND IsException = 1 ORDER BY IdCondition DESC"
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

            # object is updated
            $isUpdated = $true
        }

        # checking Assignments
        if ([bool]($MyInvocation.BoundParameters.Keys -match 'idadobjects')) {
            Write-Verbose "IdADObjects parameter was found, process Assignments"

            # adding new assignments
            foreach($IdADObject in $IdADObject) {
                $isAssigned = $false
                foreach($assignment in $origObject.Assignments) {
                    if ($assignment.IdADObject -eq $IdADObject) { $isAssigned = $true }
                }
                if (-not $isAssigned) {
                    # this is a new assignment: add it to the list in the database
                    Write-Verbose "New Assignment detected"
                    $SQLQuery = "INSERT INTO AppLockerRuleAssignments (IdSite, IdAppLockerRule, IdItem, RevisionId, Reserved01) VALUES ($($origObject.IdSite),$($IdRule),$($IdADObject),1,NULL)"
                    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

                    # object is updated
                    $isUpdated = $true
                }
            }
            # removing redundant assignments
            foreach($assignment in $origObject.Assignments) {
                $isRedundant = $True
                foreach($IdADObject in $IdADObjects) {
                    if ($IdADObject -eq $assignment.IdADObject) { $isRedundant = $false }
                }
                if ($isRedundant) {
                    # this assignment is redundant: remove it from the list in the database
                    Write-Verbose "Redundant Assignment detected"
                    $SQLQuery = "DELETE FROM AppLockerRuleAssignments WHERE IdSite = $($origObject.IdSite) AND IdAppLockerRule = $($IdRule) AND IdItem = $($assignment.IdADObject)"
                    $null = Invoke-SQL -Connection $Connection -Query $SQLQuery

                    # object is updated
                    $isUpdated = $true
                }
            }
        }

        if ($isUpdated) {
            # object was updated so increase its version
            $SQLQuery = "UPDATE AppLockerRules SET RevisionId = $($origObject.Version + 1) WHERE IdRule = $($IdRule)"
            $null = Invoke-SQL -Connection $Connection -Query $SQLQuery
        }

        # grab the updated object
        $updatedObject = Get-WEMAppLockerRule -Connection $Connection -IdRule $IdRule

        # Updating the ChangeLog
        New-ChangesLogEntry -Connection $Connection -IdSite $origObject.IdSite -IdElement $IdRule -ChangeType "Update" -ObjectName $updatedObject.Name -ObjectType "AppLocker Rule\$($tableVUEMAppLockerChangeLogType["$($tableVUEMAppLockerCollectionType[$updatedObject.CollectionType]).$($tableVUEMAppLockerRuleType[$updatedObject.RuleType])"])" -NewValue "N/A" -ChangeDescription $null -Reserved01 $null
        
    }
}
