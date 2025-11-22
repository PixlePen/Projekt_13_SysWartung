# 🛠️ SysWartung - Automatisiertes Windows-Pflegeskript

> **Version:** 3.0 (Final) | **Author:** [PixlePen]

Ein "Fire-and-Forget" PowerShell-Skript für Systemadministratoren und Power-User. Es automatisiert die komplette Wartungskette von Windows-Clients: Diagnose, Reparatur, Updates und Bereinigung – inklusive detailliertem HTML-Reporting.

---

## 📸 Vorschau

**1. Der Prozess (Live-Ansicht in der Konsole)**
Das Skript visualisiert Updates und Checks mit Fortschrittsbalken.
![Console Output](<img width="1313" height="343" alt="repscript_screenshot" src="https://github.com/user-attachments/assets/9a29419f-3e51-4d62-9535-bb7a3a31c0f9" />
)

**2. Das Ergebnis (HTML-Log)**
Nach Abschluss wird automatisch ein browserbasierter Bericht im Dark-Mode generiert.
![HTML Report](<img width="1276" height="837" alt="image_1c1aa0" src="https://github.com/user-attachments/assets/cdd708c9-9921-4d62-ad9e-965f2d55a334" />
)

---

## 🚀 Features

Dieses Skript nutzt ausschließlich Windows-Bordmittel und offizielle Module.

* **🛡️ Auto-Elevation:** Prüft auf Administrator-Rechte und startet sich bei Bedarf selbst neu.
* **🩺 Hardware-Diagnose:** Checkt S.M.A.R.T-Status aller Laufwerke und Speicherplatz auf `C:`.
* **🔙 Sicherheit:** Erstellt automatisch einen **Systemwiederherstellungspunkt** vor Änderungen.
* **🌐 Netzwerk (Remote-Safe):** Leert den DNS-Cache (`FlushDNS`), führt aber **keinen** Winsock-Reset durch, um VPN/RDP-Verbindungen nicht zu trennen.
* **🔧 Systemreparatur:**
    * `DISM /RestoreHealth` (Image-Prüfung)
    * `SFC /scannow` (Dateisystem-Integrität)
* **📦 Update-Management:**
    * **Software:** Aktualisiert alle Pakete via `Winget`.
    * **Windows:** Installiert fehlende Patches via `PSWindowsUpdate` (installiert das Modul automatisch nach, falls es fehlt).
* **🧹 Bereinigung:** Löscht temporäre Dateien (`%TEMP%`).
* **📄 Reporting:** Erstellt einen übersichtlichen HTML-Bericht unter `$env:USERPROFILE\Desktop\Logs`.

---

## 📥 Installation & Nutzung

### Download
Lade dir einfach die Datei [`RepScript.ps1`]() aus diesem Repository herunter.

### Ausführung
Da PowerShell-Skripte standardmäßig blockiert sein können, starte das Skript am besten so:

1.  Rechtsklick auf die Datei ➔ **"Mit PowerShell ausführen"**
2.  Oder via Terminal (als Admin):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\RepScript.ps1
