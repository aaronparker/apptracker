<#
    Queries each application in Evergreen and exports the result to JSON
#>
[CmdletBinding(SupportsShouldProcess = $true)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
param(
    [ValidateNotNullOrEmpty()]
    [System.String] $Path
)

# Step through all apps and export result to JSON
Import-Module -Name "Evergreen" -Force

# MozillaFirefox is a special case, so we need to run it separately
foreach ($App in @("MozillaFirefox", "MozillaThunderbird")) {
    Write-Host -Object "Gather: $App"
    $Manifest = Export-EvergreenManifest -Name "$App"
    $params = @{
        Name          = "$App"
        AppParams     = @{ Language = $Manifest.Get.Download.FullLanguageList }
        ErrorAction   = "SilentlyContinue"
        WarningAction = "SilentlyContinue"
    }
    $Output = Get-EvergreenApp @params
    if ($null -eq $Output) {
        Write-Host -Object "Encountered an issue with: $App." -ForegroundColor "Cyan"
    }
    else {
        $Output | `
            Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true }, "Type", "Architecture", "Channel", "Language" -ErrorAction "SilentlyContinue" | `
            ConvertTo-Json | `
            Out-File -FilePath $([System.IO.Path]::Combine($Path, "$App.json")) -NoNewline -Encoding "utf8" -Verbose
        Remove-Variable -Name "Output" -ErrorAction "SilentlyContinue"
    }
}
