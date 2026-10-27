# Regenerate PNGs from .mmd sources (requires Node.js).
# Usage: cd ansible/docs/diagrams && ./render.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$npx = Get-Command npx -ErrorAction SilentlyContinue
if (-not $npx) {
  Write-Error "npx not found. Install Node.js, then run: npx -y @mermaid-js/mermaid-cli -V"
}

Get-ChildItem -Filter "*.mmd" | ForEach-Object {
  $png = [System.IO.Path]::ChangeExtension($_.FullName, ".png")
  Write-Host "Rendering $($_.Name) -> $([System.IO.Path]::GetFileName($png))"
  npx -y @mermaid-js/mermaid-cli -i $_.FullName -o $png -b transparent -s 2
}

Write-Host "Done."
