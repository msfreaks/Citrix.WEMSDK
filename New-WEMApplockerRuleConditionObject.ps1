<#
    .Synopsis
    Create a new AppLocker Rule Condition object.

    .Description
    Create a new AppLocker Rule Condition object.

    .Link
    https://msfreaks.wordpress.com

    .Parameter Path
    ..

    .Parameter HashCondition
    ..

    .Parameter PathCondition
    ..

    .Parameter PublisherCondition
    ..

    .Parameter Publisher
    ..

    .Parameter Product
    ..

    .Parameter HighSection
    ..

    .Parameter LowSection
    ..

    .Example
    ..

    .Notes
    Author: Arjan Mensch
#>
function New-WEMAppLockerRuleConditionObject {
    [CmdletBinding(DefaultParameterSetName="None")]
    param (
        [Parameter(Mandatory=$True,ParameterSetName="HashCondition")]
        [Parameter(Mandatory=$True,ParameterSetName="PathCondition")]
        [Parameter(Mandatory=$True,ParameterSetName="PublisherCondition")]
        [string]$Path,
        [Parameter(Mandatory=$True,ParameterSetName="HashCondition")]
        [switch]$HashCondition,
        [Parameter(Mandatory=$True,ParameterSetName="HashCondition")][ValidateSet("Executable","Windows Installer","Scripts","DLL")]
        [string]$ConditionPurpose,
        [Parameter(Mandatory=$True,ParameterSetName="PathCondition")]
        [switch]$PathCondition,
        [Parameter(Mandatory=$True,ParameterSetName="PublisherCondition")]
        [switch]$PublisherCondition,
        [Parameter(Mandatory=$False,ParameterSetName="PublisherCondition")]
        [string]$Publisher = "*",
        [Parameter(Mandatory=$False,ParameterSetName="PublisherCondition")]
        [string]$Product = "*",
        [Parameter(Mandatory=$False,ParameterSetName="PublisherCondition")]
        [string]$HighSection = "*",
        [Parameter(Mandatory=$False,ParameterSetName="PublisherCondition")]
        [string]$LowSection = "*"
    )

    process {
        Write-Verbose "Working with database version $($script:databaseVersion)"

        # Abort if path does not exist
        if (-not (Test-Path -Path $Path)) {
            Write-Error "Cannot find '$($Path)'"
            break
        }

        # set variables
        $fileName = $null
        $fileExtension = $null
        if ((Get-Item -Path $Path) -is [System.IO.FileInfo]) {
            $fileExtension = [System.IO.Path]::GetExtension($Path)
            if (@(".exe",".com",".msi",".msp",".mst",".ps1",".bat",".cmd",".vbs",".js",".appx",".dll",".ocx") -notcontains $fileExtension) {
                Write-Error "'$($fileExtension)' is not supported"
                break
            }
            $fileName = [System.IO.Path]::GetFileName($Path)
        }

        # create object
        $vuemObject = [pscustomobject] @{
            'Type'      = $null
            'Version'   = 0
        }

        # modify object based on ParameterSetName
        switch ($PSCmdlet.ParameterSetName) {
            "HashCondition" { 
                Write-Verbose "'HashCondition' requested"
                $vuemObject.Type = "HashCondition"

                # add hashes object
                $vuemObject | Add-Member -MemberType NoteProperty -Name "Hashes" -Value @()

                # add purpose attribute
                $vuemObject | Add-Member -MemberType NoteProperty -Name "Purpose" -Value $ConditionPurpose

                # build files collection to loop through
                $filePath = $Path
                if (-not $filename) { $filePath += "\*" }
                $files = $null
                switch ($ConditionPurpose) {
                    "Executable" {
                        $files = Get-ChildItem -Path $filePath -File -Include "*.exe","*.com"
                    }
                    "Windows Installer" {
                        $files = Get-ChildItem -Path $filePath -File -Include "*.msi","*.msp","*.mst"
                    }
                    "Scripts" {
                        $files = Get-ChildItem -Path $filePath -File -Include "*.ps1","*.bat","*.cmd","*.vbs","*.js"
                    }
                    "DLL" {
                        $files = Get-ChildItem -Path $filePath -File -Include "*.dll","*.ocx"
                    }
                    Default {}
                }
                if (-not $files) {
                    Write-Error "No applicable files were found for this HashCondition purpose ($($ConditionPurpose))"
                    break
                }

                # process files collection
                foreach($file in $files) {
                    $hashObject = [pscustomobject]@{
                        HashAlgorithm = 0
                        # AppLocker module dependency here!
                        Hash = (Get-AppLockerFileInformation -Path $file.VersionInfo.FileName).Hash.HashDataString
                        FileLength = $file.Length
                        FileName = $file.Name
                        Extension = [System.IO.Path]::GetExtension($file.VersionInfo.FileName)
                    }
                    $hashObject | Add-Member scriptmethod ToString { $this.FileName } -Force
                    $hashObject.pstypenames.insert(0, "Citrix.WEMSDK.AppLockerRuleHashObject")

                    $vuemObject.Hashes += $hashObject
                }
            }
            "PathCondition" { 
                Write-Verbose "'PathCondition' requested"
                $vuemObject.Type = "PathCondition"

                $filePath = $Path
                if (-not $filename) {
                    if ($filePath.Substring($filePath.Length -1) -ne "\") { $filePath += "\" } 
                    $filePath += "*"
                }
                $vuemObject | Add-Member -MemberType NoteProperty -Name "Path" -Value (Set-EnvVariablesInPath($filePath))
            }
            "PublisherCondition" { 
                Write-Verbose "'PublisherCondition' requested"
                # publishercondition only works on file not on folder
                if (-not $fileName) {
                    Write-Error "PublisherCondition only works on indiviual files, not on folders ('$($Path)' is a folder)"
                    break
                }
                $vuemObject.Type = "PublisherCondition"
                $vuemObject | Add-Member -MemberType NoteProperty -Name "FilePath" -Value $fileName
                $vuemObject | Add-Member -MemberType NoteProperty -Name "FileName" -Value "*"
                # override properties if extensiontype is .appx
                if ($fileExtension -eq ".appx") {
                    $vuemObject.FileName = "*"
                    $vuemObject.FilePath = "*"
                }

                # set file properties
                $vuemObject | Add-Member -MemberType NoteProperty -Name "Publisher" -Value $Publisher
                $vuemObject | Add-Member -MemberType NoteProperty -Name "Product" -Value $Product
                $vuemObject | Add-Member -MemberType NoteProperty -Name "HighSection" -Value $HighSection
                $vuemObject | Add-Member -MemberType NoteProperty -Name "LowSection" -Value $LowSection
            }
            Default {}
        }
        
        # override the default ToScript() method
        $vuemObject | Add-Member scriptmethod ToString { $this.Type } -Force
        
        # set a custom type to the object
        $vuemObject.pstypenames.insert(0, "Citrix.WEMSDK.AppLockerRule$($PSCmdlet.ParameterSetName)")

        return $vuemObject
    }
}

<#
    Helper function to replace path sections with known environment variables
#>
function Set-EnvVariablesInPath {
    param(
        [string]$Path
    )

    $Path = $Path.ToLower()
    $Path = $Path.Replace($env:windir.ToLower(), "%WINDIR%")
    $Path = $Path.Replace($env:ProgramData.ToLower(), "%PROGRAMDATA%")
    $Path = $Path.Replace($env:ProgramFiles.ToLower(), "%PROGRAMFILES%")
    $Path = $Path.Replace(${env:ProgramFiles(x86)}.ToLower(), "%PROGRAMFILES(X86)%")
    $Path = $Path.Replace($env:SystemDrive.ToLower(), "%OSDRIVE%")

    return $Path
}
