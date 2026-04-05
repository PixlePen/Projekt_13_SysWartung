#!/bin/bash

# --- 1. ADMIN CHECK ---
# Ohne Root-Rechte brauchen wir gar nicht erst anfangen.
# Da es unter Linux kein direktes "Start-Process -Verb RunAs" gibt, 
# muss der User das Skript einfach mit sudo starten.
if [[ $EUID -ne 0 ]]; then
   echo "Dieses Skript muss als root ausgeführt werden (sudo)." 
   exit 1
fi

# --- 2. LOGGING SETUP (HTML) ---
# Ich ermittle den echten User, damit das Log auch bei sudo im richtigen Home landet.
# Pfad ist jetzt fix auf Dokumente/Logs eingestellt – ordentlich muss es sein.
REAL_USER=$(logname || echo "$USER")
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

BASE_DIR="$REAL_HOME/Dokumente/Logs"
if [ ! -d "$REAL_HOME/Dokumente" ]; then
    BASE_DIR="$REAL_HOME/Documents/Logs"
fi

mkdir -p "$BASE_DIR"
LOG_FILE="$BASE_DIR/Wartung_$(date +%Y-%m-%d_%H-%M).html"
HOSTNAME=$(hostname)

LOGO_SVG="https://nolden.tech/assets/img/branding.svg"

cat <<EOF > "$LOG_FILE"
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
        <h2>Systemwartung Linux: $HOSTNAME</h2>
        <p>Startzeit: $(date)</p>
    </div>
    <img src="$LOGO_SVG" alt="NOLDEN.TECH" class="logo">
</div>
<table>
<tr><th style='width:150px'>Zeit</th><th>Aktion</th><th>Status</th><th>Output / Details</th></tr>
EOF

# Helper-Funktion fürs Logging (ShellCheck-sicher gemacht)
log_html() {
    local message="$1"
    local status="$2"
    local detail_output="$3"
    
    local timestamp
    timestamp=$(date +%H:%M:%S)

    local css_class
    css_class=$(echo "$status" | tr '[:upper:]' '[:lower:]')

    # Konsolenausgabe für das Live-Feeling
    echo "[$timestamp] [$status] $message"

    # HTML-Eintrag für die Ewigkeit
    local detail_block=""
    if [[ -n "$detail_output" ]]; then
        detail_block="<details><summary>Details anzeigen</summary><pre>$detail_output</pre></details>"
    fi

    echo "<tr><td>$timestamp</td><td>$message</td><td class='$css_class'>$status</td><td>$detail_block</td></tr>" >> "$LOG_FILE"
}

# --- 3. START DER ROUTINE ---
log_html "Wartungsskript gestartet" "INFO"

# Hardware Check (Disk Space & S.M.A.R.T)
# Ich prüfe die Root-Partition und die Plattenwerte. Wer will schon Datenverlust?
echo "Prüfe Festplatten..."
FREE_SPACE=$(df / --output=avail -BG | tail -1 | tr -d 'G')
if [ "$FREE_SPACE" -lt 20 ]; then
    log_html "Speicherplatz /" "WARN" "Kritisch: Nur noch ${FREE_SPACE}GB frei!"
else
    log_html "Speicherplatz /" "SUCCESS" "${FREE_SPACE}GB frei (OK)"
fi

if command -v smartctl &> /dev/null; then
    SMART_DATA=$(smartctl -H /dev/sda 2>&1)
    if [[ "$SMART_DATA" == *"PASSED"* ]]; then
        log_html "S.M.A.R.T Check" "SUCCESS" "$SMART_DATA"
    else
        log_html "S.M.A.R.T Check" "ERROR" "$SMART_DATA"
    fi
else
    log_html "S.M.A.R.T Check" "WARN" "smartmontools fehlen."
fi

# Netzwerk: DNS Flush
# Damit der Cache nicht dazwischenfunkt.
echo "Leere DNS Cache..."
if resolvectl flush-caches &> /dev/null || systemd-resolve --flush-caches &> /dev/null; then
    log_html "DNS Cache geleert" "SUCCESS"
else
    log_html "DNS Cache" "WARN" "Konnte Cache nicht leeren."
fi

# System-Updates (APT)
# Das Herzstück: Alles auf den neuesten Stand bringen.
echo "Starte System-Updates..."
log_html "APT Update & Upgrade läuft..." "INFO"
APT_OUT=$(apt-get update && apt-get dist-upgrade -y 2>&1)
log_html "Paketquellen & System-Updates" "SUCCESS" "$APT_OUT"

# --- SICHERHEITS-CHECKUP ---
# Kurzer Check, ob die Schotten dicht sind.
echo "Starte Sicherheits-Checkup..."
log_html "Sicherheits-Checkup gestartet" "INFO"

# Offene Ports (Wer lauscht da?)
OPEN_PORTS=$(ss -tulpn | grep LISTEN)
log_html "Offene Netzwerk-Ports" "INFO" "$OPEN_PORTS"

# SSH Brute-Force Check
FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -n 10)
if [[ -n "$FAILED_LOGINS" ]]; then
    log_html "Fehlgeschlagene Logins (SSH)" "WARN" "$FAILED_LOGINS"
else
    log_html "Fehlgeschlagene Logins (SSH)" "SUCCESS" "Alles sauber."
fi

# Firewall Status
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status)
    if echo "$UFW_STATUS" | grep -iqE "active|aktiv"; then
        log_html "Firewall-Status (UFW)" "SUCCESS" "$UFW_STATUS"
    else
        log_html "Firewall-Status (UFW)" "WARN" "Firewall ist AUS!"
    fi
fi

# Cleanup
# Müll rausbringen: Alte Pakete und Caches löschen.
echo "Bereinigung..."
CLEAN_OUT=$(apt-get autoremove -y && apt-get autoclean -y 2>&1)
log_html "Paket-Bereinigung" "SUCCESS" "$CLEAN_OUT"

# Abschluss
log_html "Wartung beendet." "SUCCESS"
# HTML zumachen und die Rechte wieder an meinen User geben.
echo "</table><br><b>Ende: $(date)</b></body></html>" >> "$LOG_FILE"


echo "----------------------------------------"
echo "Bericht erstellt unter: $LOG_FILE"

# Wichtig: Damit ich die Datei ohne Sudo bearbeiten kann!
chown -R "$REAL_USER":"$REAL_USER" "$BASE_DIR"

# Reboot? Ich entscheide das lieber selbst.
read -rp "Soll ich das System jetzt neu starten? (j/n): " REBOOT
if [[ "$REBOOT" = "j" ]]; then
    echo "Alles klar, bis gleich."
    reboot
else
    echo "Okay, dann später manuell."
fi