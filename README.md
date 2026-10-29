# 🛡️ RestorePoint Manager

Gestisci i punti di ripristino di Windows con una GUI Matrix: crea, elimina e avvia il ripristino con un click.

## ✨ Feature

- ✅ **Visualizzazione completa**: elenco di tutti i punti di ripristino con data, descrizione e tipo.
- ✅ **Creazione rapida**: crea un nuovo punto di ripristino inserendo una descrizione.
- ✅ **Eliminazione**: cancella i punti vecchi per liberare spazio.
- ✅ **Avvio Ripristino**: avvia il ripristino del sistema al punto selezionato (con conferma di sicurezza).
- ✅ **Auto-Elevazione Admin**: richiede i privilegi necessari per operare.
- ✅ **Controllo "Smart"**: avvisa se il servizio VSS o la Protezione Sistema sono disabilitati.
- ✅ **Messaggi chiari**: spiega come risolvere i problemi invece di mostrare errori criptici.
- ✅ **Log su file**: traccia tutte le operazioni.

## 📋 Requisiti

- **Windows 10 / 11**
- **PowerShell 7+** (scarica da https://aka.ms/powershell)
- **Privilegi di amministratore** (necessari per gestire i punti di ripristino)

## 🚀 Quick start

```powershell
git clone https://github.com/fabrytoolbox/RestorePoint-Manager.git
cd RestorePoint-Manager
Unblock-File .\RestorePoint-Manager.ps1
.\RestorePoint-Manager.ps1

Oppure doppio click su avvia.bat.

🎯 Casi d'uso
Prima di un aggiornamento o dell'installazione di un driver: crea un punto di sicurezza.

Pulizia del sistema: elimina i punti vecchi che occupano spazio.

Emergenza: avvia un ripristino del sistema con un click (senza navigare nei menu di Windows).

Diagnostica: verifica se il sistema di ripristino è attivo o disabilitato.

⚠️ Attenzione
Il pulsante "Avvia Ripristino Sistema" riavvia il computer e riporta il sistema allo stato del punto selezionato. Assicurati di aver salvato tutti i tuoi lavori prima di procedere.

🐛 Problemi comuni
"Sistema di Ripristino Disabilitato"
Il tool mostra un messaggio con le istruzioni. In breve:

Apri services.msc e avvia "Volume Shadow Copy".

Vai in "Proprietà sistema" → "Protezione sistema" e attiva la protezione per l'unità C:.

"PowerShell 7 non trovato"
Installa PowerShell 7 da https://aka.ms/powershell

📜 Licenza
MIT (vedi LICENSE).

🙏 Crediti
Fabry Toolbox

PowerShell 7 + WinForms

Tema Matrix
