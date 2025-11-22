<#
.SYNOPSIS
    Systemwartung & Reparatur - Version 3.0 (Final)
.DESCRIPTION
    Automatisiertes Wartungsskript.
    Features: HTML-Reporting, Auto-Update (Winget & WU), S.M.A.R.T Check, Bereinigung.
    Safety: Kein Winsock-Reset (Remote-Safe).
#>

# --- 1. ADMIN CHECK ---
# Ohne Admin-Rechte brauchen wir gar nicht erst anfangen. 
# Falls wir keine haben, starte ich das Skript selbstständig neu als Admin.
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- 2. LOGGING SETUP (HTML) ---
# Ich schreibe das Log in HTML. Plaintext ist mir zu unübersichtlich.
# Hier definiere ich das CSS für den Dark Mode – sieht besser aus und schont die Augen.
$LogPath = "$env:USERPROFILE\Desktop\Logs"
if (!(Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory | Out-Null }
$LogFile = "$LogPath\Wartung_$(Get-Date -Format yyyy-MM-dd_HH-mm).html"

$HtmlHeader = @"
<!DOCTYPE html>
<html>
<head>
<style>
    body { font-family: 'Segoe UI', sans-serif; background-color: #1e1e1e; color: #d4d4d4; padding: 20px; }
    h2 { border-bottom: 1px solid #555; padding-bottom: 10px; color: #fff; }
    table { width: 100%; border-collapse: collapse; margin-top: 20px; }
    th, td { border: 1px solid #333; padding: 10px; text-align: left; vertical-align: top; }
    th { background-color: #252526; color: #fff; }
    tr:nth-child(even) { background-color: #2d2d2d; }
    .success { color: #4caf50; font-weight: bold; }
    .error { color: #f44336; font-weight: bold; }
    .warn { color: #ff9800; font-weight: bold; }
    details { margin-top: 5px; color: #888; cursor: pointer; }
    pre { background: #111; padding: 10px; overflow-x: auto; white-space: pre-wrap; color: #ccc; font-family: consolas; }
</style>
</head>
<body>
<h2>Systemwartung: $env:COMPUTERNAME</h2>
<p>Startzeit: $(Get-Date)</p>
<table>
<tr><th style='width:150px'>Zeit</th><th>Aktion</th><th>Status</th><th>Output / Details</th></tr>
"@

$HtmlHeader | Out-File $LogFile -Encoding UTF8

# Helper-Funktion fürs Logging
function Log-Html {
    param([string]$Message, [string]$Status="INFO", [string]$DetailOutput=$null)
    $TimeStamp = (Get-Date).ToString('HH:mm:ss')
    
    # Konsolenausgabe (für direktes Feedback)
    $ConsoleColor = switch ($Status) { "SUCCESS" {"Green"} "ERROR" {"Red"} "WARN" {"Yellow"} Default {"Cyan"} }
    Write-Host "[$TimeStamp] [$Status] $Message" -ForegroundColor $ConsoleColor
    
    # HTML-Ausgabe (für die Dokumentation)
    $DetailBlock = if ($DetailOutput) { "<details><summary>Details anzeigen</summary><pre>$DetailOutput</pre></details>" } else { "" }
    $CssClass = $Status.ToLower()
    "<tr><td>$TimeStamp</td><td>$Message</td><td class='$CssClass'>$Status</td><td>$DetailBlock</td></tr>" | Out-File $LogFile -Append -Encoding UTF8
}

# Fortschrittsbalken aktualisieren
function Update-Progress {
    param([int]$Percent, [string]$Activity)
    Write-Progress -Activity "Systemwartung läuft..." -Status $Activity -PercentComplete $Percent
}

# --- 3. START DER ROUTINE ---

Update-Progress 5 "Initialisiere..."
Log-Html "Wartungsskript gestartet" "INFO"

# Hardware Check
# Ich prüfe S.M.A.R.T Status und ob C: noch genug Luft hat (< 20 GB gibt Warnung).
Update-Progress 10 "Hardware-Diagnose..."
try {
    $Disks = Get-CimInstance -ClassName Win32_DiskDrive | Select-Object Model, Status
    foreach ($D in $Disks) {
        if ($D.Status -eq "OK") { Log-Html "S.M.A.R.T Check: $($D.Model)" "SUCCESS" "Status: OK" }
        else { Log-Html "S.M.A.R.T Check: $($D.Model)" "ERROR" "Status: $($D.Status)" }
    }
    
    $LogicalDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $FreeGB = [math]::Round($LogicalDisk.FreeSpace / 1GB, 2)
    if ($FreeGB -lt 20) { Log-Html "Speicherplatz C:" "WARN" "Kritisch: Nur noch $FreeGB GB frei!" }
    else { Log-Html "Speicherplatz C:" "SUCCESS" "$FreeGB GB frei (OK)" }
} catch { Log-Html "Hardware-Check fehlgeschlagen" "ERROR" $_.Exception.Message }

# Sicherungspunkt
# Bevor ich Änderungen mache, ziehe ich einen Restore Point. Sicher ist sicher.
Update-Progress 20 "Erstelle Wiederherstellungspunkt..."
try {
    Checkpoint-Computer -Description "Wartung_Script_Auto" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Log-Html "Systemwiederherstellungspunkt erstellt" "SUCCESS"
} catch { Log-Html "Kein Wiederherstellungspunkt" "WARN" "Funktion evtl. deaktiviert oder nicht erlaubt." }

# Netzwerk
# Ich flushe nur den DNS. Winsock Reset lasse ich weg, damit meine VPN/Remote-Session nicht stirbt!
Update-Progress 30 "Netzwerk-Cache..."
try {
    $dns = cmd.exe /c "ipconfig /flushdns" 2>&1 | Out-String
    Log-Html "DNS Cache geleert" "SUCCESS" $dns
} catch { Log-Html "DNS Flush Fehler" "ERROR" $_ }

# Systemreparatur
# Standard-Prozedur: Erst Image prüfen (DISM), dann Filesystem (SFC).
Update-Progress 50 "Systemreparatur (SFC & DISM)..."
Log-Html "DISM RestoreHealth läuft..." "INFO"
$dismOut = DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
Log-Html "DISM abgeschlossen" "SUCCESS" $dismOut

Log-Html "SFC Scan läuft..." "INFO"
$sfcOut = sfc /scannow 2>&1 | Out-String
if ($sfcOut -match "corrupt files") { Log-Html "SFC hat Reparaturen durchgeführt" "WARN" $sfcOut }
else { Log-Html "SFC: Systemdateien integer" "SUCCESS" $sfcOut }

# Software Updates (Winget)
# Alles aktualisieren, was Winget finden kann. Auch ohne Store-Anbindung.
Update-Progress 70 "Software Updates (Winget)..."
try {
    $wgOut = winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements --disable-interactivity 2>&1 | Out-String
    Log-Html "Winget Update-Lauf" "SUCCESS" $wgOut
} catch { Log-Html "Winget Fehler" "ERROR" $_.Exception.Message }

# Windows Updates
# Ich prüfe auf das PSWindowsUpdate Modul. Wenn es fehlt, installiere ich es nach.
Update-Progress 85 "Windows Updates..."
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Log-Html "Modul PSWindowsUpdate fehlt. Installiere es nach..." "WARN"
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction SilentlyContinue
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Scope AllUsers -ErrorAction Stop
        Log-Html "Modul erfolgreich installiert" "SUCCESS"
    } catch { Log-Html "Modul-Installation fehlgeschlagen" "ERROR" "Internet prüfen! $($_.Exception.Message)" }
}

if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
    try {
        Import-Module PSWindowsUpdate
        Log-Html "Suche und installiere Windows Updates..." "INFO"
        # WICHTIG: -IgnoreReboot, damit das Skript nicht mittendrin abbricht.
        $wuOut = Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot 2>&1 | Out-String
        Log-Html "Windows Update abgeschlossen" "SUCCESS" $wuOut
    } catch { Log-Html "Windows Update Fehler" "ERROR" $_.Exception.Message }
}

# Cleanup
Update-Progress 95 "Aufräumen..."
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Log-Html "Temporäre Dateien bereinigt" "SUCCESS"

# Abschluss
Update-Progress 100 "Fertig!"
"</table><br><b>Ende: $(Get-Date)</b></body></html>" | Out-File $LogFile -Append -Encoding UTF8
Log-Html "Wartung beendet. Öffne Bericht..." "SUCCESS"
Invoke-Item $LogFile

# Reboot Frage
# Ich entscheide selbst, wann ich neustarte.
Write-Host "`n----------------------------------------" -ForegroundColor Cyan
$Reboot = Read-Host "Soll ich das System jetzt neu starten? (j/n)"
if ($Reboot -eq "j") { 
    Write-Host "Alles klar, wir sehen uns auf der anderen Seite." -ForegroundColor Green
    Restart-Computer -Force 
} else {
    Write-Host "Okay, Neustart später manuell durchführen." -ForegroundColor Yellow
}