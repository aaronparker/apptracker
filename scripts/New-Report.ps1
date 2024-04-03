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
    [System.String] $LastUpdateFile = "./json/_lastupdate.txt"
)

$DefaultLayout = @"
---
title: #Title
layout: default
nav_order: 2
last_modified_date: #Date
---
"@

# Install modules
Import-Module -Name "Evergreen" -Force
Import-Module -Name "MarkdownPS" -Force

#region Update the list of supported apps in index.md, sorted alphabetically
$UniqueAppsCount = 0

# Read the file that lists last date applications were updates
if (Test-Path -Path $LastUpdateFile) {
    $LastUpdates = Get-Content -Path $LastUpdateFile | ConvertFrom-Csv
}

foreach ($File in (Get-ChildItem -Path $(Join-Path -Path $JsonPath -ChildPath "*.json"))) {

    $ChildPath = Join-Path -Path $OutputPath -ChildPath $($File.Name.Substring(0, 1).ToLower())
    New-Item -Path $ChildPath -ItemType "Directory" -ErrorAction "SilentlyContinue"

    $App = Find-EvergreenApp | Where-Object { $_.Name -eq $File.BaseName }

    # Convert the date to a long date for readability for all regions
    # "MMM d yyyy 'at' hh:mm tt"
    $LastWriteTime = $LastUpdates | Where-Object { $_.Name -eq $File.Name } | Select-Object -ExpandProperty "LastWriteTime"
    $ConvertedDateTime = [System.DateTime]::ParseExact($LastWriteTime, "d/M/yyyy h:mm:s tt", [System.Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat)

    # Update front matter
    $Markdown = ($DefaultLayout -replace "#Title", $App.Application -replace "#Date", $ConvertedDateTime.ToString("MMM d yyyy 'at' hh:mm tt"))
    $Markdown += "`n`n"
    $Markdown += New-MDHeader -Text "$($App.Application)" -Level 2
    $Markdown += "`n"
    $Markdown += "[Source]($($App.Link))`n`nEvergreen app: ``$($File.BaseName)``"
    $Markdown += "`n`n"

    # Add a table to the markdown for the data from the JSON
    $Table = Get-Content -Path $File.FullName | ConvertFrom-Json | ForEach-Object { $_.URI = "[$($_.URI)]($($_.URI))"; $_ } | New-MDTable
    $Markdown += $Table
    $Markdown | Out-File -FilePath $(Join-Path -Path $ChildPath -ChildPath "$($File.BaseName.ToLower()).md") -Force -Encoding "Utf8" -NoNewline

    $UniqueAppsCount += (Get-Content -Path $File.FullName | ConvertFrom-Json).Count
}
#endregion

#region Update the about page
$About = @"
---
title: About
layout: default
nav_order: 1
---
# Evergreen App Tracker

This site tracks latest application versions via the [Evergreen](https://stealthpuppy.com/evergreen/) PowerShell module.

Updates are posted every 12 hours. Last generated date: ``$(Get-Date -Format "dddd dd/MM/yyyy HH:mm K") $((Get-TimeZone).Id)``.

A project by [@stealthpuppy](https://twitter.com/stealthpuppy).

## Supported Applications

App Tracker is using [Evergreen](https://stealthpuppy.com/evergreen/) to track $((Find-EvergreenApp).Count) applications and $UniqueAppsCount unique application installers:

"@

$Markdown = $About
$Markdown += "`n`n"
$Markdown += Find-EvergreenApp | Select-Object -Property "Application", "Link" | ForEach-Object { $_.Link = "[$($_.Link)]($($_.Link))"; $_ } | New-MDTable
$Markdown | Out-File -FilePath $IndexFile -Force -Encoding "Utf8" -NoNewline
#endregion
