<#
    Queries each application in Evergreen and exports the result to JSON
#>
[CmdletBinding(SupportsShouldProcess = $true)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
param(
    [ValidateNotNullOrEmpty()]
    [System.String] $Path
)

# Apps that should be skipped in this run
$SkipApps = @("MozillaFirefox", "MozillaThunderbird")

# Step through all apps and export result to JSON
Import-Module -Name "Evergreen" -Force

# Remove extra files
$Files = Get-ChildItem -Path $Path -Filter "*.json" | Select-Object -ExpandProperty "Basename"
$Apps = Find-EvergreenApp | Select-Object -ExpandProperty "Name"
Compare-Object -ReferenceObject $Files -DifferenceObject $Apps | `
    Select-Object -ExpandProperty "InputObject" | `
    ForEach-Object { Remove-Item -Path $([System.IO.Path]::Combine($Path, "$($_).json")) -ErrorAction "SilentlyContinue" }

# Walk-through each Evergreen app and export data to JSON files
foreach ($App in (Find-EvergreenApp | Where-Object { $_.Name -notin $SkipApps } | Sort-Object { Get-Random } | Select-Object -ExpandProperty "Name")) {

    try {
        $Output = Get-EvergreenApp -Name $App -ErrorAction "SilentlyContinue" -WarningAction "SilentlyContinue"
    }
    catch {
        Write-Host -Object "Encountered an issue with: $App." -ForegroundColor "Cyan"
        Write-Host -Object $_.Exception.Message -ForegroundColor "Cyan"
        $Output = $null
    }

    if ($null -eq $Output) {
        Write-Host -Object "Output from app is null: $App." -ForegroundColor "Cyan"
    }
    elseif ("RateLimited" -in $Output.Version) {
        Write-Host -Object "Skipping. GitHub API rate limited: $App." -ForegroundColor "Cyan"
    }
    else {
        ConvertTo-Json @($Output | Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true }, "Platform", "Type", "Architecture", "Channel", "Release", "Ring", "Language", "Product", "Branch", "JDK", "Title", "Edition" -ErrorAction "SilentlyContinue") | Out-File -FilePath $([System.IO.Path]::Combine($Path, "$App.json")) -NoNewline -Encoding "utf8" -Verbose
        Remove-Variable -Name "Output" -ErrorAction "SilentlyContinue"
    }
}
