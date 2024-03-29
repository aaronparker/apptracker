<#
    Queries each application in Evergreen and exports the result to JSON
#>
[CmdletBinding(SupportsShouldProcess = $true)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
param(
    [ValidateNotNullOrEmpty()]
    [System.String] $Path,

    [ValidateNotNullOrEmpty()]
    [System.String] $UpdatesAlpha,

    [ValidateNotNullOrEmpty()]
    [System.String] $UpdatesDate,

    [ValidateNotNullOrEmpty()]
    [System.String] $AppsFile,

    [ValidateNotNullOrEmpty()]
    [System.String] $AboutFile,

    [ValidateNotNullOrEmpty()]
    [System.String] $LastUpdateFile = "./json/_lastupdate.txt"
)

# Install modules
Import-Module -Name "Evergreen" -Force
Import-Module -Name "MarkdownPS" -Force

#region Update the list of supported apps in index.md, sorted alphabetically
$UniqueAppsCount = 0
$Markdown = New-MDHeader -Text "Updates by name" -Level 1
$Markdown += "`n"
foreach ($File in (Get-ChildItem -Path $(Join-Path -Path $Path -ChildPath "*.json"))) {
    $Markdown += New-MDHeader -Text "$($File.BaseName)" -Level 2
    $Markdown += "`n"

    $Link = Find-EvergreenApp | Where-Object { $_.Name -eq $File.BaseName } | `
        Select-Object -ExpandProperty "Link" -ErrorAction "SilentlyContinue"
    if ($null -ne $Link) {
        $Markdown += New-MDLink -Text "Link" -Link $Link
        $Markdown += "`n`n"
    }

    $Table = Get-Content -Path $File.FullName | ConvertFrom-Json | New-MDTable
    $Markdown += $Table
    $Markdown += "`n"

    $UniqueAppsCount += (Get-Content -Path $File.FullName | ConvertFrom-Json).Count
}
$Markdown | Out-File -FilePath $UpdatesAlpha -Force -Encoding "Utf8" -NoNewline
#endregion


#region Update the list of supported apps in date.md, sorted alphabetically
# Read the file that lists last date applications were updates
if (Test-Path -Path $LastUpdateFile) {
    $LastUpdates = Get-Content -Path $LastUpdateFile | ConvertFrom-Csv
}

$Markdown = New-MDHeader -Text "Updates by date" -Level 1
$Markdown += "`n"
foreach ($File in $LastUpdates) {
    $Markdown += New-MDHeader -Text $($File.Name -replace ".json", "") -Level 2
    $Markdown += "`n"

    $Link = Find-EvergreenApp | Where-Object { $_.Name -eq $($File.Name -replace ".json", "") } | `
        Select-Object -ExpandProperty "Link" -ErrorAction "SilentlyContinue"
    if ($null -ne $Link) {
        $Markdown += "$(New-MDLink -Text "Link" -Link $Link)"
        $Markdown += "`n`n"

        # Convert the date to a long date for readability for all regions
        $ConvertedDateTime = [System.DateTime]::ParseExact($File.LastWriteTime, "d/M/yyyy h:mm:s tt", [System.Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat)
        $LastUpdate = "$($ConvertedDateTime.ToLongDateString()) $($ConvertedDateTime.ToLongTimeString())"

        $Markdown += "**Last update**: $LastUpdate $((Get-TimeZone).Id)"
        $Markdown += "`n`n"
    }

    $Table = Get-Content -Path $(Join-Path -Path $Path -ChildPath $File.Name) | ConvertFrom-Json | New-MDTable
    $Markdown += $Table
    $Markdown += "`n"
}
$Markdown | Out-File -FilePath $UpdatesDate -Force -Encoding "Utf8" -NoNewline
#endregion


#region Update the generated date in about.md
$About = @"
---
hide:
  - navigation
  - toc
---
# About

This site tracks latest application versions via the [Evergreen](https://stealthpuppy.com/evergreen/) PowerShell module.

Updates are posted every 8 hours. Last update: $(Get-Date -Format "dddd dd/MM/yyyy HH:mm K") $((Get-TimeZone).Id).

A project by [@stealthpuppy](https://twitter.com/stealthpuppy).
"@
$About | Out-File -FilePath $AboutFile -Force -Encoding "Utf8" -NoNewline
#endregion


#region Update the list of supported apps in APPS.md
$markdown = "---`n"
$markdown += "hide:`n"
$markdown += "  - navigation`n"
$markdown += "  - toc`n"
$markdown += "---`n`n"
$markdown += New-MDHeader -Text "Supported Applications" -Level 1
$markdown += "`n"
$line = "App Version Tracker is using Evergreen to track $((Find-EvergreenApp).Count) applications and $UniqueAppsCount unique application installers:"
$markdown += $line
$markdown += "`n`n"
$markdown += Find-EvergreenApp | Select-Object -Property "Application", "Link" | New-MDTable
$markdown | Out-File -FilePath $AppsFile -Force -Encoding "Utf8" -NoNewline
#endregion
