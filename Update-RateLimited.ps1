<#
    Queries each application in Evergreen and exports the result to JSON
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateNotNullOrEmpty()]
    [System.String] $Path
)

foreach ($file in (Get-ChildItem -Path $Path -Filter "*.json")) {
    $json = Get-Content -Path $file.FullName | ConvertFrom-Json
    if ($json.Version -match "RateLimited") {
        Get-EvergreenApp -Name $file.BaseName | `
        ConvertTo-Json | `
        Out-File -FilePath $file.FullName -Force
    }
}
