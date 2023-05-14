<#
    Queries each application in Evergreen and exports the result to JSON
#>
[CmdletBinding(SupportsShouldProcess = $true)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
param(
    [ValidateNotNullOrEmpty()]
    [System.String] $Path
)

#region Functions
Function Test-PSCore {
    <#
        .SYNOPSIS
            Returns True if running on PowerShell Core.
    #>
    [CmdletBinding(SupportsShouldProcess = $false)]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Version = '6.0.0'
    )

    # Check whether current PowerShell environment matches or is higher than $Version
    If (($PSVersionTable.PSVersion -ge [Version]::Parse($Version)) -and ($PSVersionTable.PSEdition -eq "Core")) {
        Write-Output -InputObject $true
    }
    Else {
        Write-Output -InputObject $false
    }
}
#endregion

# Apps that should be skipped in this run
$SkipApps = @("MozillaFirefox", "MozillaThunderbird")

# Step through all apps and export result to JSON
Import-Module -Name "Evergreen" -Force
if (Test-PSCore) {

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
            Write-Host -Object "Output from apps is null: $App." -ForegroundColor "Cyan"
        }
        elseif ("RateLimited" -in $Output.Version) {
            Write-Host -Object "Skipping. GitHub API rate limited: $App." -ForegroundColor "Cyan"
        }
        else {
            $Output | Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true }, "Platform", "Type", "Architecture", "Channel", "Release", "Ring", "Language", "Product", "Branch", "JDK", "Title", "Edition" -ErrorAction "SilentlyContinue" | `
                ConvertTo-Json | Out-File -FilePath $([System.IO.Path]::Combine($Path, "$App.json")) -NoNewline -Encoding "utf8" -Verbose
            Remove-Variable -Name "Output" -ErrorAction "SilentlyContinue"
        }
    }
}
else {

    # Walk-through each JSON file and validate it, update contents if required
    foreach ($file in (Get-ChildItem -Path $Path -Filter "*.json")) {
        if (($file.Length -eq 0) -or ((Get-Content -Path $file.FullName) -match "RateLimited")) {

            Write-Host -Object "Update: $($file.BaseName)." -ForegroundColor "Cyan"
            $params = @{
                Name          = $file.BaseName
                ErrorAction   = "SilentlyContinue"
                WarningAction = "SilentlyContinue"
                Verbose       = $true
            }
            $Output = Get-EvergreenApp @params

            if ($null -eq $Output) {
                Write-Host -Object "Encountered an issue with: $($file.BaseName)." -ForegroundColor "Cyan"
            }
            elseif ($Output[0].Version -eq "RateLimited") {
                Write-Host -Object "Skipping. GitHub API rate limited: $($file.BaseName)." -ForegroundColor "Cyan"
            }
            else {
                $Output | `
                    Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true }, "Platform", "Type", "Architecture", "Channel", "Release", "Ring", "Language", "Product", "Branch", "JDK", "Title", "Edition" -ErrorAction "SilentlyContinue" | `
                    ConvertTo-Json | `
                    Out-File -FilePath $file.FullName -NoNewline -Encoding "utf8" -Verbose
                Remove-Variable -Name "Output" -ErrorAction "SilentlyContinue"
            }
        }
    }

    # Find output that doesn't exist for an application in Evergreen
    foreach ($App in (Find-EvergreenApp | Where-Object { $_.Name -notin $SkipApps } | Sort-Object { Get-Random } | Select-Object -ExpandProperty "Name")) {
        if (-not (Test-Path -Path $([System.IO.Path]::Combine($Path, "$App.json")) -ErrorAction "SilentlyContinue")) {

            Write-Host -Object "Update: $App." -ForegroundColor "Cyan"
            $params = @{
                Name          = $App
                ErrorAction   = "SilentlyContinue"
                WarningAction = "SilentlyContinue"
                Verbose       = $true
            }
            $Output = Get-EvergreenApp @params

            if ($null -eq $Output) {
                Write-Host -Object "Encountered an issue with: $App." -ForegroundColor "Cyan"
            }
            elseif ("RateLimited" -in $Output.Version) {
                Write-Host -Object "Skipping. GitHub API rate limited: $App." -ForegroundColor "Cyan"
            }
            else {
                $Output | `
                    Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true }, "Platform", "Type", "Architecture", "Channel", "Release", "Ring", "Language", "Product", "Branch", "JDK", "Title", "Edition" -ErrorAction "SilentlyContinue" | `
                    ConvertTo-Json | `
                    Out-File -FilePath $([System.IO.Path]::Combine($Path, "$App.json")) -NoNewline -Encoding "utf8" -Verbose
                Remove-Variable -Name "Output" -ErrorAction "SilentlyContinue"
            }
        }
    }
}
