<#
    Queries each application in Evergreen and exports the result to JSON
#>
[CmdletBinding(SupportsShouldProcess = $true)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
param(
    [ValidateNotNullOrEmpty()]
    [System.String] $Path,

    [ValidateNotNullOrEmpty()]
    [System.String] $UpdateFile,

    [ValidateNotNullOrEmpty()]
    [System.String] $AppsFile,

    [ValidateNotNullOrEmpty()]
    [System.String] $AboutFile
)

# Install modules
Import-Module -Name "Evergreen" -Force
Import-Module -Name "MarkdownPS" -Force

#region Update the list of supported apps in APPS.md
$Markdown = New-MDHeader -Text "Application Versions" -Level 1
$Markdown += "`n"
foreach ($File in (Get-ChildItem -Path $Path)) {
    $Markdown += New-MDHeader -Text "$($File.BaseName)" -Level 2
    $Markdown += "`n"

    $Link = Find-EvergreenApp | Where-Object { $_.Name -eq $File.BaseName } | `
        Select-Object -ExpandProperty "Link" -ErrorAction "SilentlyContinue"
    If ($Null -ne $Link) {
        $Markdown += New-MDLink -Text "Link" -Link $Link
        $Markdown += "`n`n"
    }

    $Table = Get-Content -Path $File.FullName | ConvertFrom-Json | New-MDTable
    $Markdown += $Table
    $Markdown += "`n"
}
$Markdown | Out-File -FilePath $UpdateFile -Force -Encoding "Utf8" -NoNewline
#endregion


#region Update the generated date in about.md
$About = @"
# About

This site tracks latest application versions via the [Evergreen](https://stealthpuppy.com/evergreen/) PowerShell module.

Last update: **#DATE** (UTC)
"@
$About -replace "#DATE", (Get-Date -Format "dddd dd/MM/yyyy HH:mm K") | Out-File -FilePath $AboutFile -Force -Encoding "Utf8" -NoNewline
#endregion


#region Update the list of supported apps in APPS.md
$markdown = New-MDHeader -Text "Applications list" -Level 1
$markdown += "`n"
$line = "Evergreen " + '`' + $newVersion + '`' + " supports the following applications:"
$markdown += $line
$markdown += "`n`n"
$markdown += Find-EvergreenApp | New-MDTable
$markdown | Out-File -FilePath $AppsFile -Force -Encoding "Utf8" -NoNewline
#endregion
