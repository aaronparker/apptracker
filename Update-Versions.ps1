<#
    Queries each application in Evergreen and exports the result to JSON
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateNotNullOrEmpty()]
    [System.String] $Path
)

# Step through all apps and export result to JSON
Find-EvergreenApp | Select-Object -ExpandProperty "Name" | `
    ForEach-Object { Get-EvergreenApp -Name $_ -ErrorAction "Ignore" -WarningAction "Ignore" | `
        ConvertTo-Json | `
        Out-File -FilePath $([System.IO.Path]::Combine($Path, "json", "$_.json")) -NoNewline -Encoding "utf8"
}

<# foreach ($file in (Get-ChildItem -Path "./" -Filter "*.json")) {
    $json = Get-Content -Path $file.FullName | ConvertFrom-Json
    if ($json.Version -match "RateLimited") {
        Get-EvergreenApp -Name $file.BaseName | `
        ConvertTo-Json | `
        Out-File -FilePath $file.FullName -Force
    }
}

foreach ($file in (Get-ChildItem -Path "./" -Filter "*.json")) {
    $json = Get-Content -Path $file.FullName | ConvertFrom-Json
    if ($json.Version -match "RateLimited") {
        Write-Host $file.BaseName
    }
} #>
