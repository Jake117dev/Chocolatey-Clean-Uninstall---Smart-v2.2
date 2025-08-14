# Make-Checksums.ps1
param(
  [string[]]$Files = @(
    "Uninstall-Chocolatey-Smart-v2.2.ps1",
    "RUN-UNINSTALL.cmd",
    "RUN-DRYRUN.cmd"
  )
)

$lines = @()
$md = @()
$md += "| Datei | SHA256 |"
$md += "|---|---|"

foreach ($f in $Files) {
  if (Test-Path $f) {
    $h = (Get-FileHash $f -Algorithm SHA256).Hash
    $lines += "{0}`t{1}" -f $f, $h
    $md += "| $f | `$`{$h`}$ |"
  } else {
    Write-Warning "Datei nicht gefunden: $f"
  }
}

$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"
"Generated: $ts" | Set-Content -Encoding UTF8 CHECKSUMS.txt
$lines | Add-Content -Encoding UTF8 CHECKSUMS.txt

"### 🔐 SHA256-Checksummen (Stand: $ts)" | Set-Content -Encoding UTF8 CHECKSUMS.md
$md | Add-Content -Encoding UTF8 CHECKSUMS.md

Write-Host "Fertig. Dateien erzeugt: CHECKSUMS.txt, CHECKSUMS.md" -ForegroundColor Green
