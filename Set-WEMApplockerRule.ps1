function Set-WEMAppLockerRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [int]$IdAppLockerRule,

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
        $rule = Get-WEMAppLockerRule -Connection $Connection -IdAppLockerRule $IdAppLockerRule

        # abort if the rule does not exist
        if (-not $rule) {
            Write-Error "No rule with id $($IdAppLockerRule) found in the database"
            break
        }

        
    }
}