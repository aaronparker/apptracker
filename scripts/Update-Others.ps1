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
    if ($Null -eq $Output) {
        Write-Host -Object "Encountered an issue with: $App." -ForegroundColor "Cyan"
    }
    else {
        $Output | Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true }, "Architecture", "Channel", "Language", "Type" -ErrorAction "SilentlyContinue" | `
            ConvertTo-Json | Out-File -FilePath $([System.IO.Path]::Combine($Path, "$App.json")) -NoNewline -Encoding "utf8" -Verbose
        Remove-Variable -Name "Output" -ErrorAction "SilentlyContinue"
    }
}
