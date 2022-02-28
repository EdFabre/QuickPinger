<#
.NOTES
    Name: QuickPinger.ps1
    Author: Edge F
    Date created: 02-28-2022
.SYNOPSIS
    Quick and Dirty Script to check is CIDR has pingable objects
.DESCRIPTION
    Quick and Dirty Script to check is CIDR has pingable objects
.PARAMETER ExampleParam
    [PLACEHOLDER]
.INPUTS
    [PLACEHOLDER]
.OUTPUTS
    [PLACEHOLDER]
.EXAMPLE
    [PLACEHOLDER]
#>

# Receives script parameters
param (
    [Parameter(Position = 0, Mandatory = $false)]    
    [String]$ipaddressCIDR
)

# Project Path Variables
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$configPath = "$scriptPath\config"
$installersPath = "$scriptPath\installers"
$utilsPath = "$scriptPath\utils"
$releasesPath = "$scriptPath\releases"

# Imports Powershell Scripts listed in projectInfo.json and located in utils
function LoadAllDeps {
    function TestModActive {
        param (
            [Parameter(Mandatory = $true)]
            [String]$ModuleName,
            [Parameter(Mandatory = $false)]
            [Switch]$Silent
        )
        if ($null -ne (Get-Module $ModuleName)) {
            if ($Silent -ne $true) {
                Write-Host "Dependency: '$ModuleName', Installed"
            }
            return $true
        }
        else {
            if ($Silent -ne $true) {
                Write-Host "Dependency: '$ModuleName', NOT installed"
            }
            return $false
        }
    }

    $depLoadResults = New-Object -TypeName psobject

    $RepoInstallPackages = (ManagePSProject -LoadDeps)
    $RepoInstallPackages | Get-Member -MemberType NoteProperty | ForEach-Object {
        $key = $_.Name
        $modulePath = $($RepoInstallPackages."$key")[0]
        $utilModulePath = $($RepoInstallPackages."$key")[1]
        $zippedGitRepo = $($RepoInstallPackages."$key")[2]
        $RepoURL = $($RepoInstallPackages."$key")[3]
        Import-Module $modulePath -Force
        $repoRes = if ((TestModActive $key -Silent) -eq $true) { "Installed" } else { "Not Installed" }
    
        $depLoadResults | Add-Member -MemberType NoteProperty -Name $key -Value @($repoRes, $RepoURL) -Force
        Remove-Item -Recurse -Force -Path $modulePath -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -Recurse -Force -Path $utilModulePath -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -Recurse -Force -Path $zippedGitRepo -ErrorAction SilentlyContinue | Out-Null
    }

    # Loads Local Scripts in 'utils' folder
    Get-ChildItem -Path $utilsPath -Filter *.ps1 | ForEach-Object {
        Import-Module $_.FullName -Force
        $repoRes = if ((TestModActive $_.BaseName -Silent) -eq $true) { "Installed" } else { "Not Installed" }
    
        $depLoadResults | Add-Member -MemberType NoteProperty -Name $_.BaseName -Value @($repoRes, "$($_.FullName)") -Force
    }

    $formattedDepResults = @()
    $depLoadResults | Get-Member -MemberType NoteProperty | ForEach-Object {
        $key = $_.Name
        $formattedDepResults += [PSCustomObject]@{Dependency = $key; Status = $($depLoadResults."$key")[0]; Source = $($depLoadResults."$key")[1] }
    }
    $formattedDepResults | Format-Table -AutoSize
}

. LoadAllDeps 

Write-Log "Project Path Variables
Script Path: $scriptPath
Config Path: $configPath
Installer Path: $installersPath
Util Path: $utilsPath
Releases Path: $releasesPath" "Debug"

### DO NOT ALTER ABOVE CODE ###
### Insert Code Logic Below ###

Function Get-SubnetAddresses {
    Param ([IPAddress]$IP, [ValidateRange(0, 32)][int]$maskbits)
    
    # Convert the mask to type [IPAddress]:
    $mask = ([Math]::Pow(2, $MaskBits) - 1) * [Math]::Pow(2, (32 - $MaskBits))
    $maskbytes = [BitConverter]::GetBytes([UInt32] $mask)
    $DottedMask = [IPAddress]((3..0 | ForEach-Object { [String] $maskbytes[$_] }) -join '.')
      
    # bitwise AND them together, and you've got the subnet ID
    $lower = [IPAddress] ( $ip.Address -band $DottedMask.Address )
    
    # We can do a similar operation for the broadcast address
    # subnet mask bytes need to be inverted and reversed before adding
    $LowerBytes = [BitConverter]::GetBytes([UInt32] $lower.Address)
    [IPAddress]$upper = (0..3 | % { $LowerBytes[$_] + ($maskbytes[(3 - $_)] -bxor 255) }) -join '.'
    
    # Make an object for use elsewhere
    Return [pscustomobject][ordered]@{
        Lower = $lower
        Upper = $upper
    }
}

Function Get-IPRange {
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName)][IPAddress]$lower,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName)][IPAddress]$upper
    )
    # use lists for speed
    $IPList = [Collections.ArrayList]::new()
    $null = $IPList.Add($lower)
    $i = $lower
        
    # increment ip until reaching $upper in range
    while ( $i -ne $upper ) { 
        # IP octet values are built back-to-front, so reverse the octet order
        $iBytes = [BitConverter]::GetBytes([UInt32] $i.Address)
        [Array]::Reverse($iBytes)
        
        # Then we can +1 the int value and reverse again
        $nextBytes = [BitConverter]::GetBytes([UInt32]([bitconverter]::ToUInt32($iBytes, 0) + 1))
        [Array]::Reverse($nextBytes)
        
        # Convert to IP and add to list
        $i = [IPAddress]$nextBytes
        $null = $IPList.Add($i)
    }
        
    return $IPList
}

function GenerateReportTemplate {
    # This section creates the reports table, identifier name and some counters
    $resultsTable = @()
    $identifierName = "IPAddress"
    $countEnabled = 0
    $countDisabled = 0

    # This section imports collection that will be used
    if ($ipaddressCIDR -eq "") {
        $ipaddressCIDR = Read-Host "CIDR (NNN.NNN.NNN.NNN/NN)?"
    }
    $ipaddressRange = (Get-SubnetAddresses $ipaddressCIDR.split("/")[0] $ipaddressCIDR.split("/")[1])
    $ipAddressesCol = Get-IPRange $ipaddressRange.Lower $ipaddressRange.Upper

    # Loop through the ipAddressesCol and generates the report based on what needs to be done
    foreach ($item in $ipAddressesCol) {
        
        # Create the temporary Object to hold this instances data and set fields to null
        $tempObjTemplate = [PSCustomObject]@{
            "$($identifierName)" = $item.IPAddressToString
            'isActive'           = 'null'
        }

        $testIsActive = Test-Connection -ComputerName $item.IPAddressToString -Count 1 -Quiet

        # Modify Example Member Field 'ItemA' within the temporary Object
        if ($testIsActive) {
            $tempObjTemplate | Add-Member -MemberType NoteProperty -Name 'isActive' -Value 'True' -Force
            $countEnabled++
        }
        else {
            $tempObjTemplate | Add-Member -MemberType NoteProperty -Name 'isActive' -Value 'False' -Force
            $countDisabled++
        }

        # Add temporary object to resultsTable
        $resultsTable += $tempObjTemplate
    }
    
    # Write some logging metrics using counters
    Write-Log -Message "You have $countDisabled items disabled" -Severity Warning
    Write-Log -Message "You have $countEnabled items enabled" -Severity Information

    # Save to file
    $csvOutPath = (Join-Path $scriptPath "results_$(Get-Date -Format FileDateTime).csv" )
    $resultsTable | ft -AutoSize
    $resultsTable | Export-Csv -Path $csvOutPath -NoTypeInformation
    Write-Log -Message "Saved CSV Output to '$csvOutPath'" -Severity Information
}

GenerateReportTemplate