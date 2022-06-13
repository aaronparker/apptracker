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

(Get-Culture).DateTimeFormat
Write-Host ""

# Read the file that list last updated applications
if (Test-Path -Path $UpdateFile) {
    $Updates = Get-Content -Path $UpdateFile
}

# Read the file that lists last date applications were updates
if (Test-Path -Path $LastUpdateFile) {
    $LastUpdates = Get-Content -Path $LastUpdateFile | ConvertFrom-Csv
}

# Walk through each application and update the last update date
foreach ($update in $Updates) {   
    
    # Get the index of the application in the array
    $Index = $LastUpdates.Name.IndexOf($($update -replace "json/", ""))
    
    # If $Index = -1, then the application is new
    if ($Index -eq -1) {
        Write-Host "Add item and date for: $update."
        $NewItem = [PSCustomObject]@{
            Name          = $($update -replace "json/", "")
            LastWriteTime = $(Get-Date -Format "dd/MM/yyyy hh:mm:ss tt")
        }
        $LastUpdates += $NewItem
    }
    else {
        Write-Host "Update date for: $update."
        $LastUpdates[$Index].LastWriteTime = $(Get-Date -Format "dd/MM/yyyy hh:mm:ss tt")
    }
}

# Output the update list back to disk
$LastUpdates | `
    Sort-Object -Property @{ Expression = { [System.DateTime]::ParseExact($($_.LastWriteTime.Trim()), "dd/MM/yyyy hh:mm:ss tt", $null) }; Descending = $true } -Descending | `
    ConvertTo-Csv -Delimiter "," | `
    Out-File -FilePath $LastUpdateFile -Encoding "utf8" -Force
