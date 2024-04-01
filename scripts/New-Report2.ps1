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
---
"@

# Install modules
Import-Module -Name "Evergreen" -Force
Import-Module -Name "MarkdownPS" -Force

#region Update the list of supported apps in index.md, sorted alphabetically
$UniqueAppsCount = 0
# $Markdown = New-MDHeader -Text "Updates by name" -Level 1
# $Markdown += "`n"

foreach ($File in (Get-ChildItem -Path $(Join-Path -Path $JsonPath -ChildPath "*.json"))) {

    # Get the first letter of the file name
    #$File.Name.Substring(0, 1)
    $ChildPath = Join-Path -Path $OutputPath -ChildPath $File.Name.Substring(0, 1)
    New-Item -Path $ChildPath -ItemType "Directory" -ErrorAction "SilentlyContinue"

    $App = Find-EvergreenApp | Where-Object { $_.Name -eq $File.BaseName }

    $Markdown = ($DefaultLayout -replace "#Title", $App.Application)
    $Markdown += "`n`n"
    $Markdown += New-MDHeader -Text "$($File.BaseName)" -Level 2
    $Markdown += "`n"
    if ($null -ne $App.Link) {
        $Markdown += New-MDLink -Text "Link" -Link $App.Link
        $Markdown += "`n`n"
    }

    $Table = Get-Content -Path $File.FullName | ConvertFrom-Json | New-MDTable
    $Markdown += $Table
    #$Markdown += "`n"
    $Markdown | Out-File -FilePath $(Join-Path -Path $ChildPath -ChildPath "$($File.BaseName).md") -Force -Encoding "Utf8" -NoNewline

    $UniqueAppsCount += (Get-Content -Path $File.FullName | ConvertFrom-Json).Count
}
#endregion

#region Update the generated date
$About = @"
---
title: About
layout: default
nav_order: 1
---
This site tracks latest application versions via the [Evergreen](https://stealthpuppy.com/evergreen/) PowerShell module.

Updates are posted every 12 hours. Last update: $(Get-Date -Format "dddd dd/MM/yyyy HH:mm K") $((Get-TimeZone).Id).

A project by [@stealthpuppy](https://twitter.com/stealthpuppy).
"@
#endregion

#region Update the list of supported apps
$markdown = $About
$markdown += "`n"
$markdown += New-MDHeader -Text "Supported Applications" -Level 1
$markdown += "`n"
$line = "App Tracker is using [Evergreen](https://stealthpuppy.com/evergreen/) to track $((Find-EvergreenApp).Count) applications and $UniqueAppsCount unique application installers:"
$markdown += $line
$markdown += "`n`n"
$markdown += Find-EvergreenApp | Select-Object -Property "Application", "Link" | New-MDTable
$markdown | Out-File -FilePath $IndexFile -Force -Encoding "Utf8" -NoNewline
#endregion
