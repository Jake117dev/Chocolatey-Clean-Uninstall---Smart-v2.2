<#
.SYNOPSIS
  Smart-Uninstaller v2.2 (locale-safe) – räumt Chocolatey sauber ab, robust ggü. DE/EN Lokalisierung.
.CHANGES
  - takeown: versucht /D Y, dann /D J (deutsche Systeme), sonst ohne /D.
  - icacls: nutzt SID *S-1-5-32-544 (BUILTIN\Administrators) statt lokalisiertem Namen.
  - Kleinere Ausgabe-Fixes; optional UTF-8 Codepage setzen.
#>

[CmdletBinding()]
param([switch]$DryRun)

function Write-Step($msg){ Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)  { Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Bad($msg) { Write-Host "  !! $msg" -ForegroundColor Red }
function Warn2($m)       { Write-Warning $m }
function Do-IfNotDryRun([scriptblock]$Action){ if(-not $DryRun){ & $Action } else { Write-Host "  (DryRun) übersprungen" -ForegroundColor Yellow } }

# Optional: UTF-8 Codepage für saubere Umlaute im Terminal (kein Fehler, wenn chcp fehlt)
try { chcp 65001 > $null } catch {}

# Admin
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
  Write-Bad "Bitte als Administrator ausführen."; exit 1
}
Write-Step "Vorbereitung"
Write-Ok "Admin-Kontext bestätigt"
if($DryRun){ Write-Ok "DryRun aktiv – keine Änderungen" }

# Helpers
$AdminSID = "*S-1-5-32-544"  # BUILTIN\Administrators, sprachunabhängig

function Take-Own-Recursive([string]$Path){
  if(-not (Test-Path $Path)){ return }
  $cmds = @(
    "takeown /f `"$Path`" /r /d Y",
    "takeown /f `"$Path`" /r /d J",
    "takeown /f `"$Path`" /r"
  )
  foreach($c in $cmds){
    try{
      cmd.exe /c $c | Out-Null
      return $true
    } catch { continue }
  }
  return $false
}

function Icacls-Grant-Admins([string]$Path){
  if(-not (Test-Path $Path)){ return }
  try{
    cmd.exe /c "icacls `"$Path`" /grant $AdminSID`:F /T /C" | Out-Null
    return $true
  } catch { return $false }
}

# Stop processes
Write-Step "Prozesse beenden (choco.exe)"
Do-IfNotDryRun {
  Stop-Process -Name choco -Force -ErrorAction SilentlyContinue
  Write-Ok "Prozesse beendet (sofern vorhanden)"
}

# Collect packages via lib or choco list -l
$libRoot = "C:\ProgramData\chocolatey\lib"
$packages = @()
if(Test-Path $libRoot){
  try{ $packages = Get-ChildItem -Path $libRoot -Directory -EA SilentlyContinue | Select-Object -Expand Name } catch { Warn2 $_ }
}
if(-not $packages -or $packages.Count -eq 0){
  try{
    $raw = choco list -l 2>$null
    if($raw){ foreach($line in $raw){ if($line -match "\|"){ $n = ($line -split "\|")[0].Trim(); if($n){ $packages += $n } } } }
  } catch { Warn2 "CLI-Auflistung fehlgeschlagen: $($_.Exception.Message)" }
}
$packages = $packages | Sort-Object -Unique
Write-Step ("Gefundene Pakete: " + ($(if($packages){ ($packages -join ', ') } else { '<keine>' })))

# Uninstall all except 'chocolatey'
$toRemove = $packages | Where-Object { $_ -ne 'chocolatey' }
if($toRemove.Count -gt 0){
  Write-Step "Pakete deinstallieren (ohne 'chocolatey')"
  foreach($p in $toRemove){
    Write-Host "  - uninstall $p"
    Do-IfNotDryRun { 
      try { choco uninstall $p -y --remove-dependencies --skip-autouninstaller | Out-Null; Write-Ok "$p deinstalliert (oder bereits entfernt)" }
      catch { Warn2 ("Fehler bei $($p): $($_.Exception.Message)") }
    }
  }
}else{
  Write-Ok "Keine abhängigen Pakete gefunden"
}

# Try uninstall chocolatey
Write-Step "Chocolatey deinstallieren (versuche regulär)"
$chocoRoot = "C:\ProgramData\chocolatey"
$chocoBin  = Join-Path $chocoRoot "bin\choco.exe"

Do-IfNotDryRun {
  $uninstalled = $false
  try{
    choco uninstall chocolatey -y --skip-autouninstaller | Out-Null
    $uninstalled = $true
    Write-Ok "Chocolatey-Paket deinstalliert (oder bereits nicht vorhanden)"
  } catch {
    Warn2 "Reguläre Deinstallation meldete Fehler: $($_.Exception.Message)"
  }

  if(-not $uninstalled -and (Test-Path $chocoBin)){
    Write-Step "Zugriff/Locks auf choco.exe beheben"
    try{
      attrib -r -s -h $chocoBin 2>$null | Out-Null
      Take-Own-Recursive (Split-Path $chocoBin -Parent) | Out-Null
      Icacls-Grant-Admins (Split-Path $chocoBin -Parent)    | Out-Null
      $ren = "$chocoBin.removed"
      if(Test-Path $ren){ Remove-Item -Force $ren -EA SilentlyContinue }
      Rename-Item $chocoBin $ren -EA SilentlyContinue
      Write-Ok "Lock/ACL auf choco.exe beseitigt"
    } catch { Warn2 "ACL/Lock-Behebung fehlgeschlagen: $($_.Exception.Message)" }
  }
}

# Scheduled tasks & optional service
Write-Step "Geplante Tasks/Dienste bereinigen"
Do-IfNotDryRun {
  try{
    $tasks = Get-ScheduledTask -EA SilentlyContinue | Where-Object { $_.TaskName -match 'Chocolatey' -or $_.TaskPath -match 'Chocolatey' }
    foreach($t in $tasks){ try{ Unregister-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Confirm:$false } catch{} }
    Write-Ok "Scheduled Tasks entfernt (falls vorhanden)"
  } catch { }
  try{
    $svc = Get-Service -Name "ChocolateyAgent" -EA SilentlyContinue
    if($svc){ Stop-Service $svc -Force -EA SilentlyContinue; sc.exe delete ChocolateyAgent | Out-Null; Write-Ok "Dienst 'ChocolateyAgent' entfernt" }
  } catch { }
}

# Directory cleanup
Write-Step "Verzeichnisse entfernen"
$paths = @(
  "C:\ProgramData\chocolatey",
  "C:\ProgramData\ChocolateyHttpCache",
  "C:\Chocolatey"
)
foreach($p in $paths){
  Write-Host "  - $p"
  Do-IfNotDryRun {
    try{
      if(Test-Path $p){
        Take-Own-Recursive $p | Out-Null
        Icacls-Grant-Admins $p | Out-Null
        Remove-Item -Recurse -Force $p -EA SilentlyContinue
      }
      Write-Ok "Entfernt (oder nicht vorhanden)"
    } catch { Warn2 "Konnte $p nicht löschen: $($_.Exception.Message)" }
  }
}

# PATH & env vars
function Remove-ChocoFromPath([string]$scope){
  try{
    $path = [Environment]::GetEnvironmentVariable("PATH",$scope)
    if([string]::IsNullOrEmpty($path)){ return }
    $parts = $path -split ';' | Where-Object { $_ -and ($_ -notmatch "(?i)\\chocolatey(\\|$)") }
    $new = ($parts -join ';').TrimEnd(';')
    if($new -ne $path){ Do-IfNotDryRun { [Environment]::SetEnvironmentVariable("PATH",$new,$scope) }; Write-Ok "PATH ($scope) bereinigt" }
    else { Write-Ok "PATH ($scope) unverändert" }
  } catch { Warn2 "PATH-Bereinigung ($scope) fehlgeschlagen: $($_.Exception.Message)" }
}
Write-Step "PATH/Env-Vars/Registry bereinigen"
Remove-ChocoFromPath -scope "Machine"
Remove-ChocoFromPath -scope "User"

function Remove-ChocoEnvVars([string]$scope){
  $vars = @("CHOCOLATEYINSTALL","ChocolateyInstall","ChocolateyToolsLocation","ChocolateyLastPathUpdate")
  foreach ($v in $vars){
    Do-IfNotDryRun { try{ [Environment]::SetEnvironmentVariable($v,$null,$scope); Write-Ok "$v ($scope) entfernt" } catch { Warn2 "Konnte $v ($scope) nicht entfernen: $($_.Exception.Message)" } }
  }
}
Remove-ChocoEnvVars -scope "Machine"
Remove-ChocoEnvVars -scope "User"

$regPaths = @("HKLM:\Software\Chocolatey","HKCU:\Software\Chocolatey")
foreach($rp in $regPaths){
  Write-Host "  - $rp"
  Do-IfNotDryRun { try{ if(Test-Path $rp){ Remove-Item -Recurse -Force $rp } ; Write-Ok "Registry-Schlüssel entfernt (oder nicht vorhanden)" } catch { Warn2 "Konnte $rp nicht entfernen: $($_.Exception.Message)" } }
}

# Final verification
Write-Step "Abschluss-Check"
$existsDir = Test-Path "C:\ProgramData\chocolatey"
$existsExe = Test-Path "C:\ProgramData\chocolatey\bin\choco.exe"
$inPathM   = ([Environment]::GetEnvironmentVariable("PATH","Machine") -match "(?i)\\chocolatey")
$inPathU   = ([Environment]::GetEnvironmentVariable("PATH","User") -match "(?i)\\chocolatey")
$cmd = Get-Command choco -EA SilentlyContinue

if(-not $existsDir -and -not $existsExe -and -not $inPathM -and -not $inPathU -and -not $cmd){
  Write-Host "✅ Chocolatey ist vollständig entfernt." -ForegroundColor Green
} else {
  Write-Host "⚠️ Reste erkannt:" -ForegroundColor Yellow
  Write-Host ("  Dir: " + $(if($existsDir){"JA"}else{"nein"}))
  Write-Host ("  choco.exe: " + $(if($existsExe){"JA"}else{"nein"}))
  Write-Host ("  PATH(Machine/User): " + $(if($inPathM){"JA"}else{"nein"}) + "/" + $(if($inPathU){"JA"}else{"nein"}))
  Write-Host ("  Get-Command choco: " + $(if($cmd){"JA"}else{"nein"}))
  Write-Host "  → Ein Neustart kann PATH/Handles final bereinigen. Danach erneut prüfen."
}
