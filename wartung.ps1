# --- 1. ADMIN CHECK ---
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Dieses Skript muss als Administrator ausgeführt werden!"
    Pause
    exit
}

# --- 2. LOGGING SETUP ---
$LogDir = "$HOME\Documents\Logs"
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory }

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$LogFile = "$LogDir\Wartung_$($env:COMPUTERNAME)_$Timestamp.html"
$LogoUrl = "https://nolden.tech/assets/img/branding.svg"

# HTML Header
$Header = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
    body { font-family: 'Segoe UI', sans-serif; background-color: #1e1e1e; color: #d4d4d4; padding: 20px; }
    h2 { border-bottom: 1px solid #555; padding-bottom: 10px; color: #fff; margin: 0; }
    table { width: 100%; border-collapse: collapse; margin-top: 20px; }
    th, td { border: 1px solid #333; padding: 10px; text-align: left; vertical-align: top; }
    th { background-color: #252526; color: #fff; }
    tr:nth-child(even) { background-color: #2d2d2d; }
    .success { color: #4caf50; font-weight: bold; }
    .error { color: #f44336; font-weight: bold; }
    .warn { color: #ff9800; font-weight: bold; }
    .info { color: #00bcd4; font-weight: bold; }
    details { margin-top: 5px; color: #888; cursor: pointer; }
    pre { background: #111; padding: 10px; overflow-x: auto; white-space: pre-wrap; color: #ccc; font-family: monospace; }
    .header-flex { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #555; padding-bottom: 15px; }
    .logo { max-height: 100px; }
</style>
</head>
<body>
<div class="header-flex">
    <div>
        <h2>Systemwartung Windows: $($env:COMPUTERNAME)</h2>
        <p>Startzeit: $(Get-Date)</p>
    </div>
    <img src="$LogoUrl" alt="NOLDEN.TECH" class="logo">
</div>
<table>
<tr><th style='width:150px'>Zeit</th><th>Aktion</th><th>Status</th><th>Output / Details</th></tr>
"@
$Header | Out-File $LogFile -Encoding UTF8

function Log-Html {
    param($Message, $Status, $Details)
    $Time = Get-Date -Format "HH:mm:ss"
    $Class = $Status.ToLower()
    $DetailBlock = if ($Details) { "<details><summary>Details anzeigen</summary><pre>$Details</pre></details>" } else { "" }
    
    Write-Host "[$Time] [$Status] $Message"
    "<tr><td>$Time</td><td>$Message</td><td class='$Class'>$Status</td><td>$DetailBlock</td></tr>" | Out-File $LogFile -Append -Encoding UTF8
}

# --- 3. ROUTINE ---
Log-Html "Wartungsskript gestartet" "INFO"

# Disk Check
$Drive = Get-PSDrive C
$FreeGB = [math]::Round($Drive.Free / 1GB, 2)
if ($FreeGB -lt 20) {
    Log-Html "Speicherplatz C:" "WARN" "Nur noch $($FreeGB)GB frei!"
} else {
    Log-Html "Speicherplatz C:" "SUCCESS" "$($FreeGB)GB frei (OK)"
}

# DNS Flush
Write-Host "Leere DNS Cache..."
ipconfig /flushdns | Out-Null
Log-Html "DNS Cache geleert" "SUCCESS"

# Windows Updates (Suche)
Log-Html "Suche nach Windows Updates..." "INFO"
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
$SearchResult = $UpdateSearcher.Search("IsInstalled=0")
Log-Html "Windows Updates" "SUCCESS" "Gefundene Updates: $($SearchResult.Updates.Count)"

# Firewall Status
$FW = Get-NetFirewallProfile -Name Domain,Public,Private
if ($FW.Enabled -contains $true) {
    Log-Html "Firewall-Status" "SUCCESS" "Aktiv (Domain/Public/Private)"
} else {
    Log-Html "Firewall-Status" "WARN" "Firewall ist teilweise DEAKTIVIERT!"
}

# Abschluss
Log-Html "Wartung beendet." "SUCCESS"
"</table><br><b>Ende: $(Get-Date)</b></body></html>" | Out-File $LogFile -Append -Encoding UTF8

Write-Host "`nBericht erstellt: $LogFile"
$Choice = Read-Host "Soll das System neu gestartet werden? (j/n)"
if ($Choice -eq "j") { Restart-Computer }
