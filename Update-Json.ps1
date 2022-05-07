<#
    Queries each application in Evergreen and exports the result to JSON
#>
[CmdletBinding(SupportsShouldProcess = $true)]
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
    Find-EvergreenApp | Select-Object -ExpandProperty "Name" | `
        ForEach-Object { 
        $Output = Get-EvergreenApp -Name $_ -ErrorAction "SilentlyContinue" -WarningAction "SilentlyContinue"
        if ($Null -ne $Output) {
            if ($Output.Version -notin "RateLimited") {
                $Output | Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true }, "Architecture", "Channel", "Release", "Ring", "Language", "Platform", "Product", "Branch", "JDK", "Title", "Edition", "Type" -ErrorAction "SilentlyContinue" | `
                    ConvertTo-Json | `
                    Out-File -FilePath $([System.IO.Path]::Combine($Path, "$_.json")) -NoNewline -Encoding "utf8" -Verbose
            }
        }
        Remove-Variable -Name "Output" -ErrorAction "SilentlyContinue"
    }
}
else {
    Import-Module -Name "DnsClient"
    foreach ($file in (Get-ChildItem -Path $Path -Filter "*.json")) {
        if ($file.Length -eq 0) {
            $Output = Get-EvergreenApp -Name $file.BaseName -ErrorAction "SilentlyContinue" -WarningAction "SilentlyContinue"
            if ($Null -ne $Output) {
                $Output | Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true }, "Architecture", "Channel", "Release", "Ring", "Language", "Platform", "Product", "Branch", "JDK", "Title", "Edition", "Type" -ErrorAction "SilentlyContinue" | `
                    ConvertTo-Json | `
                    Out-File -FilePath $file.FullName -NoNewline -Encoding "utf8" -Force -Verbose
            }
            Remove-Variable -Name "Output" -ErrorAction "SilentlyContinue"
        }
    }
}
