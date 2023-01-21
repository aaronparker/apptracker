<#
    Saves a list of when the application was list updated
#>
[CmdletBinding(SupportsShouldProcess = $false)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
param(
    [System.String] $Path,

    [ValidateNotNullOrEmpty()]
    [System.String] $UpdateFile = "./json/_update-pwsh.txt",

    [ValidateNotNullOrEmpty()]
    [System.String] $LastUpdateFile = "./json/_lastupdate.txt"
)

# Get the current list of application data files
# Get-ChildItem -Path "$Path/*.json" | `
#     Select-Object -Property "Name", "LastWriteTime" | `
#     Sort-Object -Property "LastWriteTime" -Descending | `
#     ConvertTo-Csv -Delimiter "," | `
#     Out-File -FilePath $LastUpdateFile -Encoding "utf8" -Force

#region Functions
Function Test-PSCore {
    <#
        .SYNOPSIS
            Returns True if running on PowerShell Core.
    #>
    [CmdletBinding(SupportsShouldProcess = $false)]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Version = '6.0.0'
    )

    # Check whether current PowerShell environment matches or is higher than $Version
    If (($PSVersionTable.PSVersion -ge [Version]::Parse($Version)) -and ($PSVersionTable.PSEdition -eq "Core")) {
        Write-Output -InputObject $true
    }
    Else {
        Write-Output -InputObject $false
    }
}
#endregion

# Date/Time format
$Format = "d/M/yyyy h:mm:s tt"

# Read the file that list last updated applications
if (Test-Path -Path $UpdateFile) {
    $Updates = Get-Content -Path $UpdateFile

    # Read the file that lists last date applications were updates
    if (Test-Path -Path $LastUpdateFile) {
        $LastUpdates = Get-Content -Path $LastUpdateFile | ConvertFrom-Csv

        # Walk through each application and update the last update date
        foreach ($update in $Updates) {   
    
            # Get the index of the application in the array
            $Index = $LastUpdates.Name.IndexOf($($update -replace "json/", ""))
    
            # If $Index = -1, then the application is new
            if ($Index -eq -1) {
                Write-Host "Add item and date for: $update."
                $NewItem = [PSCustomObject]@{
                    Name          = $($update -replace "json/", "")
                    LastWriteTime = $(Get-Date -Format $Format)
                }
                $LastUpdates += $NewItem
            }
            else {
                Write-Host "Update date for: $update."
                $LastUpdates[$Index].LastWriteTime = $(Get-Date -Format $Format)
            }
        }

        # Output the update list back to disk
        if (Test-PSCore) {
            $LastUpdates | `
                Sort-Object -Property @{ Expression = { [System.DateTime]::ParseExact($($_.LastWriteTime.Trim()), $Format, $null) }; Descending = $true } -Descending | `
                ConvertTo-Csv -Delimiter "," | `
                Out-File -FilePath $LastUpdateFile -Encoding "utf8" -Force
        }
        else {
            $LastUpdates | `
                Sort-Object -Property @{ Expression = { [System.DateTime]::ParseExact($($_.LastWriteTime.Trim()), $Format, $null) }; Descending = $true } -Descending | `
                ConvertTo-Csv -Delimiter "," -NoTypeInformation | `
                Out-File -FilePath $LastUpdateFile -Encoding "utf8" -Force
        }
    }
}
