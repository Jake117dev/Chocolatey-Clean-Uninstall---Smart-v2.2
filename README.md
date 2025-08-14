# 🧹 Chocolatey Clean Uninstall – Smart v2.2

[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue)](#)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-lightgrey)](#)
[![Maintenance](https://img.shields.io/badge/Maintenance-Cleanup-success)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Zweck:** Dieses Skript entfernt **Chocolatey vollständig** – inkl. aller Choco-Pakete (zuerst), Registry-Reste, PATH-Einträge, geplanten Tasks/Agent und gesperrten Dateien.  
**Robust:** Locale-safe (DE/EN), ACL-Fix, Handle-Break, UTF-8-Ausgabe, idempotent.  
**Sicher:** Erst **Dry-Run**, dann Live.

---

## 📂 Struktur 

Chocolatey-Clean/

├─ Uninstall-Chocolatey-Smart-v2.2.ps1 # Hauptskript

├─ RUN-UNINSTALL.cmd # Live-Run (Doppelklick)

├─ RUN-DRYRUN.cmd # Test-Run (Doppelklick)

└─ README.md

---

## ⚡ Quickstart

### A) Von USB-Stick (empfohlen für Helpdesk/Offline)

1. USB-Stick einstecken → Ordner öffnen → **`RUN-DRYRUN.cmd`** (Rechtsklick → *Als Admin ausführen*).
2. Wenn okay → **`RUN-UNINSTALL.cmd`** (ebenfalls als Admin).
3. **Neustart** empfehlen, falls noch „Reste erkannt“ gemeldet wurden.

### B) Aus Downloads (PowerShell – Admin)

cd $env:USERPROFILE\Downloads

Unblock-File .\Uninstall-Chocolatey-Smart-v2.2.ps1

Set-ExecutionPolicy Bypass -Scope Process -Force

powershell -ExecutionPolicy Bypass -File .\Uninstall-Chocolatey-Smart-v2.2.ps1 -DryRun

(wenn gut:)

powershell -ExecutionPolicy Bypass -File .\Uninstall-Chocolatey-Smart-v2.2.ps1

Erfolg prüfen:

Get-Command choco -EA SilentlyContinue   # -> nichts

Test-Path "C:\ProgramData\chocolatey"    # -> False

## 🧪 Was das Skript tut (Kurzfassung)

Pakete ermitteln (primär C:\ProgramData\chocolatey\lib, fallback choco list -l).

Alle Pakete außer chocolatey deinstallieren (inkl. --remove-dependencies).

Chocolatey entfernen, Locks/ACLs lösen (takeown, icacls, Rename-Fallback).

Ordner/Cache/Tasks/Dienst löschen (ChocolateyAgent, geplante Tasks).

PATH/Env/Registry bereinigen (sprachunabhängig via SID).

Abschluss-Check: „✅ vollständig entfernt“ oder „⚠️ Reste erkannt“.

💡 Bei gesperrten Dateien hilft das Skript selbst (Besitzübernahme & Rechte). AV kurz pausieren kann zusätzlich helfen.

## 🔧 Optional: EXE selbst bauen (ps2exe)

Für Umgebungen, die gern eine „klickbare“ EXE sehen. Hinweis: EXE triggert eher AV/SmartScreen als PS1+CMD.

Auf einer Builder-Kiste:

Install-Module ps2exe -Scope CurrentUser

Build:

Invoke-ps2exe `
  -InputFile  .\Uninstall-Chocolatey-Smart-v2.2.ps1 `
  -OutputFile .\Chocolatey-Clean-Uninstall.exe `
  -noConsole -requireAdmin `
  -title "Chocolatey Clean Uninstall" `
  -description "Smart, locale-safe uninstaller for Chocolatey"

Signieren (empfohlen):

$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=ChocolateyClean" -CertStoreLocation Cert:\CurrentUser\My

Set-AuthenticodeSignature -FilePath .\Uninstall-Chocolatey-Smart-v2.2.ps1 -Certificate $cert

(Für EXE:) 

signtool.exe /fd sha256 /a /tr http://timestamp.digicert.com /td sha256 /v Chocolatey-Clean-Uninstall.exe

## 🧰 Troubleshooting

„Datei nicht gefunden“ → In den richtigen Ordner wechseln (cd …) / USB-Laufwerksbuchstaben prüfen.

„Zugriff verweigert“ → Skript löst ACL/Locks automatisch; ggf. AV kurz pausieren.

Umlaute/Sonderzeichen komisch → Konsole ≠ UTF-8; Skript setzt chcp 65001 intern.

„choco nicht gefunden“ im Log → gut! Dann ist die CLI bereits weg; Skript putzt nur Reste.

### 📜 Lizenz
MIT – ohne Gewähr, Nutzung auf eigene Verantwortung.
© 2025 – Contributions welcome.
