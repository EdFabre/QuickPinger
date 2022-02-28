$projectDirName = Split-Path (Split-Path (Split-Path $MyInvocation.MyCommand.Definition -Parent)) -Leaf
$ScriptName = (Get-Item $MyInvocation.PSCommandPath).Basename
$ScriptLogsDirName = "ScriptLogs"


function Write-Log {
    <#
    .NOTES
        Name: Write-Log.ps1
        Author: Edge Fabre
        Date created: 02-12-2019
    .SYNOPSIS
        Writes a custom log object to disk
    .DESCRIPTION
        This is a custom commandlette which assists in writing detailed logs for
        a powershell project
    .PARAMETER ProjectName
        String which specifies the name of the project
    .INPUTS
        System.String. Single Word Project Name
    .OUTPUTS
        CSV. Writes a CSV File to the Temp folder
    .EXAMPLE
        // Writes to log file with the severity of "Information"
        Write-Log.ps1 -Message "This script rocks!" -Severity "Information"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Debug', 'Information', 'Warning', 'Error')]
        [string]$Severity = 'Information'
    )

    Write-Host "$(Get-Date -f g) - $Severity : $Message"

    New-Item -Path "$env:HOMEDRIVE\Temp" -Name $ScriptLogsDirName -ItemType "directory" -Force | Out-Null
    New-Item -Path "$env:HOMEDRIVE\Temp\$ScriptLogsDirName" -Name $projectDirName -ItemType "directory" -Force | Out-Null

    [pscustomobject]@{
        Time       = (Get-Date -f g)
        Message    = $Message
        Severity   = $Severity
        ScriptName = $ScriptName
        Host       = $env:computername
    } | Export-Csv -Path "$env:HOMEDRIVE\Temp\$ScriptLogsDirName\$projectDirName\$($ScriptName)_LogFile.csv" -Append -NoTypeInformation -Force
    Set-ItemProperty -Path "$env:HOMEDRIVE\Temp\$ScriptLogsDirName\$projectDirName\$($ScriptName)_LogFile.csv" -Name IsReadOnly -Value $true
}
