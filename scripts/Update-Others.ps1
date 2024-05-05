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
foreach ($App in @("MozillaFirefox", "MozillaThunderbird", "FileZilla")) {
    try {
        Write-Host -Object "Gather: $App"
        $Manifest = Export-EvergreenManifest -Name "$App"
        $params = @{
            Name          = $App
            ErrorAction   = "SilentlyContinue"
            WarningAction = "SilentlyContinue"
        }
        if ($App -in @("MozillaFirefox", "MozillaThunderbird")) {
            $params.AppParams = @{ Language = $Manifest.Get.Download.FullLanguageList }
        }
        $Output = Get-EvergreenApp @params
    }
    catch {
        Write-Host -Object "Encountered an issue with: $App." -ForegroundColor "Cyan"
        Write-Host -Object $_.Exception.Message -ForegroundColor "Cyan"
        $_.Exception.Message | Out-File -FilePath $([System.IO.Path]::Combine($Path, "$App.err")) -NoNewline -Encoding "utf8"
        $Output = $null
    }

    if ($null -eq $Output) {
        Write-Host -Object "Encountered an issue with: $App." -ForegroundColor "Cyan"
        if (!(Test-Path -Path $([System.IO.Path]::Combine($Path, "$App.err")))) {
            "Output from last run on PowerShell Core was null." | Out-File -FilePath $([System.IO.Path]::Combine($Path, "$App.err")) -NoNewline -Encoding "utf8"
        }
    }
    else {
        $Output | `
            Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true }, "Type", "Architecture", "Channel", "Language" -ErrorAction "SilentlyContinue" | `
            ConvertTo-Json | `
            Out-File -FilePath $([System.IO.Path]::Combine($Path, "$App.json")) -NoNewline -Encoding "utf8" -Verbose
        Remove-Variable -Name "Output" -ErrorAction "SilentlyContinue"
    }
}
