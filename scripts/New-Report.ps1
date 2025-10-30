<#
    Queries each application in Evergreen and exports the result to JSON
#>
[CmdletBinding(SupportsShouldProcess = $true)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
param(
    [ValidateNotNullOrEmpty()]
    [System.String] $JsonPath = "./json",

    [ValidateNotNullOrEmpty()]
    [System.String] $OutputPath = "./docs/_apps",

    [ValidateNotNullOrEmpty()]
    [System.String] $IndexFile = "./docs/index.md",

    [ValidateNotNullOrEmpty()]
    [System.String[]] $ChangedFiles
)

$DefaultLayout = @"
---
title: #Title
layout: default
nav_order: 2
parent: #ParentTitle
last_modified_date: #Date
---
"@

$AppIndex = @"
---
title: #ParentTitle
layout: default
nav_exclude: false
has_children: true
---
# #ParentTitle
"@

# Install modules
Import-Module -Name "Evergreen" -Force
Import-Module -Name "MarkdownPS" -Force

#region Update the list of supported apps in index.md, sorted alphabetically
$UniqueAppsCount = 0

# Get update information - prefer ChangedFiles parameter over LastUpdateFile
if ($ChangedFiles) {
    Write-Host "Using provided changed files list: $($ChangedFiles.Count) files" -ForegroundColor "Yellow"
    # Create a hashtable for quick lookup of changed files with their timestamps
    $UpdatedFilesLookup = @{}
    foreach ($File in $ChangedFiles) {
        $FileName = [System.IO.Path]::GetFileName($File)
        $FullPath = Join-Path -Path $JsonPath -ChildPath $FileName
        if (Test-Path -Path $FullPath) {
            $UpdatedFilesLookup[$FileName] = (Get-Item -Path $FullPath).LastWriteTime
        }
    }
}

# Remove the _apps folder, so that we get clean content
Remove-Item -Path $OutputPath -Recurse -Force -ErrorAction "Continue"
New-Item -Path $OutputPath -ItemType "Directory" -ErrorAction "SilentlyContinue"

foreach ($File in (Get-ChildItem -Path $(Join-Path -Path $JsonPath -ChildPath "*.json"))) {

    # Creates a new directory for a report and generates an index file inside the directory
    # The index file is named "index.md" and its content is based on the first letter of the file name.
    $ChildPath = Join-Path -Path $OutputPath -ChildPath $($File.Name.Substring(0, 1).ToLower())
    New-Item -Path $ChildPath -ItemType "Directory" -ErrorAction "SilentlyContinue" | Out-Null
    Set-Content -Path (Join-Path -Path $ChildPath -ChildPath "index.md") -Value ($AppIndex -replace "#ParentTitle", $File.Name.Substring(0, 1).ToUpper()) -Force -Encoding "Utf8" -NoNewline

    # Output the file being processed
    Write-Host "Processing $($File.FullName)" -ForegroundColor "Green"

    # Get the Evergreen app object
    $App = Find-EvergreenApp | Where-Object { $_.Name -eq $File.BaseName }

    # Update front matter
    $Markdown = ($DefaultLayout -replace "#Title", $App.Application -replace "#Date", $($File.LastWriteTime.ToString("dd/MM/yyyy h:mm:ss tt"))) -replace "#ParentTitle", $File.Name.Substring(0, 1).ToUpper()

    # Get details of the app from the saved JSON; Update the count of unique apps
    $AppObject = Get-Content -Path $File.FullName | ConvertFrom-Json
    $UniqueAppsCount += $AppObject.Count

    # Update page details
    $Markdown += "`n`n"
    $Markdown += New-MDHeader -Text "$($App.Application)" -Level 2
    $Markdown += "`n"
    $Markdown += "[Source]($($App.Link))"
    $Markdown += "`n`n"
    $Markdown += "Evergreen app: ``$($File.BaseName)``. Found **$($AppObject.Count)** installer$(if ($AppObject.Count -gt 1) { "s" })."
    $Markdown += "`n`n"

    # Add details of previous check
    $ErrFile = $([System.IO.Path]::Combine($JsonPath, "$($App.Name).err"))
    if (Test-Path -Path $ErrFile) {
        $Err = Get-Content -Path $ErrFile
        $Markdown += "Last check: 🔴`n"
        $Markdown += '```'
        $Markdown += "`n$Err`n"
        $Markdown += '```'
        $Markdown += "`n`n"
    }
    else {
        $Markdown += "Last check: 🟢"
        $Markdown += "`n`n"
    }

    # Add a table to the markdown for the data from the JSON
    $Table = $AppObject | ForEach-Object { $_.URI = "[$($_.URI)]($($_.URI))"; $_ } | New-MDTable
    $Markdown += $Table
    $Markdown | Out-File -FilePath $(Join-Path -Path $ChildPath -ChildPath "$($File.BaseName.ToLower()).md") -Force -Encoding "Utf8" -NoNewline
}
#endregion

#region Update the about page
$About = @"
---
title: Home
layout: default
nav_order: 1
---
# Evergreen App Tracker

This site tracks latest application versions via the [Evergreen](https://stealthpuppy.com/evergreen/) PowerShell module. To view details of the latest release, choose an application from the List of Apps tree on the left.

{: .important }
> Updates are posted every 12 hours. Last generated: ``$(Get-Date -Format "dddd dd/MM/yyyy HH:mm K") $((Get-TimeZone).Id)``.

## Supported Applications

App Tracker is using [Evergreen](https://www.powershellgallery.com/packages/Evergreen/) to track **$((Find-EvergreenApp).Count)** applications and **$UniqueAppsCount** unique application installers.

{: .highlight }
> **Note:** The status of the application is based on the last update run. Validate the status of an application by running ``Get-EvergreenApp`` locally.
"@

# Create a table for supported applications with a last update status
$SupportedApps = Find-EvergreenApp | ForEach-Object { $_.Link = "[view]($("https://stealthpuppy.com/apptracker/apps/$($_.Name.Substring(0, 1))/$($_.Name)/"))".ToLower(); $_ } | `
    ForEach-Object {
    $Name = $_.Name
    $JsonFileName = "$Name.json"
    
    # Get last update time - prefer UpdatedFilesLookup over LastUpdates
    $LastUpdateTime = if ($UpdatedFilesLookup -and $UpdatedFilesLookup.ContainsKey($JsonFileName)) {
        $UpdatedFilesLookup[$JsonFileName].ToString("yyyy-MM-dd")
    }
    elseif ($LastUpdates) {
        ($LastUpdates | Where-Object { $_.Name -eq $JsonFileName } | Select-Object -ExpandProperty "LastWriteTime" -First 1) -split " " | Select-Object -First 1
    }
    else {
        # Fallback to file system timestamp
        $JsonFile = [System.IO.Path]::Combine($JsonPath, $JsonFileName)
        if (Test-Path -Path $JsonFile) {
            (Get-Item -Path $JsonFile).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        }
        else {
            "Unknown"
        }
    }
    
    [PSCustomObject] @{
        Application = $_.Application
        LastUpdate  = "``$LastUpdateTime``"
        Status      = $(if (Test-Path -Path $([System.IO.Path]::Combine($JsonPath, "$Name.err"))) { "🔴" } else { "🟢" })
        Details     = $_.Link
    }
}
$Markdown = $About
$Markdown += "`n`n"
$Markdown += $SupportedApps | New-MDTable -Columns ([Ordered]@{Application = "left"; LastUpdate = "left"; Status = "left"; Details = "left" })
$Markdown | Out-File -FilePath $IndexFile -Force -Encoding "Utf8" -NoNewline

# Remove .err files from the JSON path
Remove-Item -Path $([System.IO.Path]::Combine($JsonPath, "*.err")) -Force -ErrorAction "SilentlyContinue"
#endregion
