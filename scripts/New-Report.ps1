<#
    Queries each application in Evergreen and exports the result to JSON
#>
[CmdletBinding(SupportsShouldProcess = $true)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
param(
    [ValidateNotNullOrEmpty()]
    [System.String] $Path,

    [ValidateNotNullOrEmpty()]
    [System.String] $OutFile
)

# $Path = "./docs/json/*.json"
# $OutFile = "./docs/index.md"

Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.208"
If (Get-PSRepository -Name "PSGallery" | Where-Object { $_.InstallationPolicy -ne "Trusted" }) {
    Write-Host "Trust repository: PSGallery." -ForegroundColor "Cyan"
    Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
}
$Modules = @("MarkdownPS")
ForEach ($Module in $Modules) {
    If ([System.Version]((Find-Module -Name $Module).Version) -gt (Get-Module -Name $Module -ListAvailable).Version) {
        Write-Host "Checking module $Module." -ForegroundColor "Cyan"
        Install-Module -Name $Module -SkipPublisherCheck -Force
        Import-Module -Name $Module -Force
    }
}

# Update the list of supported apps in APPS.md
$Markdown = New-MDHeader -Text "Application Versions" -Level 1
$Markdown += "`n"
foreach ($File in (Get-ChildItem -Path $Path)) {
    $Markdown += New-MDHeader -Text "$($File.BaseName)" -Level 2
    $Markdown += "`n"
    $Table = Get-Content -Path $File.FullName | ConvertFrom-Json | New-MDTable
    $Markdown += $Table
    $Markdown += "`n"
}
($Markdown.TrimEnd("`n")) | Out-File -FilePath $OutFile -Force -Encoding "Utf8"
