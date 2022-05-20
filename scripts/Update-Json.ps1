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
    [CmdletBinding(SupportsShouldProcess = $False)]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $False, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Version = '6.0.0'
    )

    # Check whether current PowerShell environment matches or is higher than $Version
    If (($PSVersionTable.PSVersion -ge [Version]::Parse($Version)) -and ($PSVersionTable.PSEdition -eq "Core")) {
        Write-Output -InputObject $True
    }
    Else {
        Write-Output -InputObject $False
    }
}
#endregion

# Step through all apps and export result to JSON
if (Test-PSCore) {

    # Remove extra files
    $Files = Get-ChildItem -Path $Path -Filter "*.json" | Select-Object -ExpandProperty "Basename"
    $Apps = Find-EvergreenApp | Select-Object -ExpandProperty "Name"
    Compare-Object -ReferenceObject $Files -DifferenceObject $Apps | `
        Select-Object -ExpandProperty "InputObject" | `
        ForEach-Object { Remove-Item -Path $([System.IO.Path]::Combine($Path, "$($_).json")) }

    foreach ($App in (Find-EvergreenApp | Sort-Object { Get-Random } | Select-Object -ExpandProperty "Name")) {

        $Output = Get-EvergreenApp -Name $App -ErrorAction "SilentlyContinue" -WarningAction "SilentlyContinue"
        if ($Null -eq $Output) {
            Write-Host -Object "Encountered an issue with: $App." -ForegroundColor "Cyan"
        }
        elseif ("RateLimited" -in $Output.Version) {
            Write-Host -Object "Skipping. GitHub API rate limited: $App." -ForegroundColor "Cyan"
        }
        else {
            $Output | Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true }, "Architecture", "Channel", "Release", "Ring", "Language", "Platform", "Product", "Branch", "JDK", "Title", "Edition", "Type" -ErrorAction "SilentlyContinue" | `
                ConvertTo-Json | Out-File -FilePath $([System.IO.Path]::Combine($Path, "$App.json")) -NoNewline -Encoding "utf8" -Verbose
            Remove-Variable -Name "Output" -ErrorAction "SilentlyContinue"
        }
    }
}
else {
    foreach ($file in (Get-ChildItem -Path $Path -Filter "*.json")) {
        
        if (($file.Length -eq 0) -or ((Get-Content -Path $file.FullName) -match "RateLimited")) {
            Write-Host -Object "Update: $($file.BaseName)." -ForegroundColor "Cyan"

            $Output = Get-EvergreenApp -Name $file.BaseName -ErrorAction "SilentlyContinue" -WarningAction "SilentlyContinue"
            if ($Null -eq $Output) {
                Write-Host -Object "Encountered an issue with: $($file.BaseName)." -ForegroundColor "Cyan"
            }
            elseif ($Output[0].Version -eq "RateLimited") {
                Write-Host -Object "Skipping. GitHub API rate limited: $($file.BaseName)." -ForegroundColor "Cyan"
            }
            else {
                $Output | Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true }, "Architecture", "Channel", "Release", "Ring", "Language", "Platform", "Product", "Branch", "JDK", "Title", "Edition", "Type" -ErrorAction "SilentlyContinue" | `
                    ConvertTo-Json | Out-File -FilePath $file.FullName -NoNewline -Encoding "utf8" -Verbose
                Remove-Variable -Name "Output" -ErrorAction "SilentlyContinue"
            }
        }
    }
}
