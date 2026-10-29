# RestorePoint-Manager.ps1 - v2.0 (Matrix Edition)
# Gestione avanzata dei punti di ripristino Windows con GUI Matrix

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Data

# ============================================
# AUTO-ELEVAZIONE ADMIN
# ============================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("Rilancio come Amministratore per gestire i punti di ripristino...", "Richiesta Privilegi", "OK", "Information")
    
    $pwshPath = Join-Path $PSHOME "pwsh.exe"
    if (-not (Test-Path $pwshPath)) { $pwshPath = "pwsh.exe" }
    
    Start-Process $pwshPath -ArgumentList "-NoProfile -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$script:workDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:logFile = Join-Path $script:workDir "RestorePoint_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ============================================
# LOGGING
# ============================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $script:logFile -Value $line -Encoding UTF8
}

"--- RESTOREPOINT MANAGER LOG ---" | Set-Content -Path $script:logFile -Encoding UTF8

# ============================================
# FUNZIONI CORE
# ============================================
function Get-RestorePoints {
    try {
        $rps = Get-ComputerRestorePoint | Select-Object -Property SequenceNumber,
            @{Name='Data Creazione'; Expression={$_.CreationTime.ToString("dd/MM/yyyy HH:mm")}},
            Description,
            @{Name='Tipo Evento'; Expression={
                switch ($_.EventType) {
                    100 {"Installazione applicazione"}
                    101 {"Disinstallazione applicazione"}
                    102 {"Modifica impostazioni"}
                    103 {"Ripristino del sistema"}
                    104 {"Punto di ripristino manuale"}
                    105 {"Aggiornamento di Windows"}
                    default {"Sconosciuto"}
                }
            }},
            @{Name='Tipo Ripristino'; Expression={
                switch ($_.RestorePointType) {
                    0 {"Installazione"}
                    1 {"Modifica"}
                    3 {"Rimozione"}
                    4 {"Ripristino"}
                    5 {"Punto di controllo"}
                    6 {"Punto di ripristino programmato"}
                    7 {"Nuovo disco"}
                    8 {"Modifica del disco"}
                    9 {"Cancella disco"}
                    10 {"Aggiornamento"}
                    11 {"Ripristino automatico"}
                    default {"Sconosciuto"}
                }
            }}
        return $rps
    }
    catch {
        Write-Log "Errore nel recupero: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Refresh-RestorePointsDisplay {
    $dataGridView.DataSource = $null
    $dataGridView.Columns.Clear()

    $restorePoints = Get-RestorePoints
    if ($restorePoints) {
        $dataTable = New-Object System.Data.DataTable
        foreach ($prop in $restorePoints[0].PSObject.Properties) {
            $columnType = [string]
            if ($prop.TypeNameOfValue -eq 'System.Int32') { $columnType = [int] }
            $dataTable.Columns.Add($prop.Name, $columnType)
        }

        foreach ($rp in $restorePoints) {
            $row = $dataTable.NewRow()
            foreach ($prop in $rp.PSObject.Properties) {
                $row[$prop.Name] = $rp.$($prop.Name)
            }
            $dataTable.Rows.Add($row)
        }

        $dataGridView.DataSource = $dataTable
        $dataGridView.AutoResizeColumns([System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::AllCells)
        Write-Log "Caricati $($restorePoints.Count) punti di ripristino." "OK"
    } else {
        $dataGridView.DataSource = $null
        Write-Log "Nessun punto di ripristino trovato." "WARNING"
    }
}

function Test-SystemRestoreStatus {
    # Restituisce $true se il ripristino è attivo, $false se disabilitato
    try {
        # 1. Controlla lo stato del servizio VSS (Volume Shadow Copy)
        $vssService = Get-Service -Name "VSS" -ErrorAction SilentlyContinue
        if ($vssService -and $vssService.Status -eq "Disabled") {
            return @{ Status = $false; Reason = "Il servizio 'Volume Shadow Copy' (VSS) e' DISABILITATO." }
        }

        # 2. Controlla il registro (Group Policy o disabilitazione manuale)
        $srRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore"
        if (Test-Path $srRegPath) {
            $disableSR = (Get-ItemProperty -Path $srRegPath -Name "DisableSR" -ErrorAction SilentlyContinue).DisableSR
            $disableConfig = (Get-ItemProperty -Path $srRegPath -Name "DisableConfig" -ErrorAction SilentlyContinue).DisableConfig
            if ($disableSR -eq 1 -or $disableConfig -eq 1) {
                return @{ Status = $false; Reason = "La creazione dei punti di ripristino e' bloccata dal Registro di sistema (Group Policy)." }
            }
        }

        # 3. Controlla se il disco C: ha la protezione attiva (opzionale, ma utile)
        $srEnabled = (Get-ComputerRestorePoint -ErrorAction SilentlyContinue)
        # Se Get-ComputerRestorePoint fallisce o restituisce un errore, potrebbe essere disabilitato.
        # Ma potrebbero anche esserci semplicemente 0 punti. Usiamo l'assenza di errori come indicatore.
        
        return @{ Status = $true; Reason = "Sistema di ripristino attivo." }
    } catch {
        return @{ Status = $false; Reason = "Impossibile determinare lo stato: $($_.Exception.Message)" }
    }
}

# ============================================
# GUI MATRIX
# ============================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "RESTOREPOINT MANAGER - MATRIX CORE"
$form.Size = New-Object System.Drawing.Size(850, 650)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::Black
$form.ForeColor = [System.Drawing.Color]::Lime
$form.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false

# Titolo
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "RESTOREPOINT MANAGER"
$lblTitle.Font = New-Object System.Drawing.Font("Consolas", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.TextAlign = "MiddleCenter"
$lblTitle.Location = New-Object System.Drawing.Point(20, 10)
$lblTitle.Size = New-Object System.Drawing.Size(790, 30)
$form.Controls.Add($lblTitle)

# DataGridView
$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Location = New-Object System.Drawing.Point(20, 50)
$dataGridView.Size = New-Object System.Drawing.Size(790, 300)
$dataGridView.AllowUserToAddRows = $false
$dataGridView.AllowUserToDeleteRows = $false
$dataGridView.ReadOnly = $true
$dataGridView.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$dataGridView.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
$dataGridView.BackgroundColor = [System.Drawing.Color]::Black
$dataGridView.GridColor = [System.Drawing.Color]::DarkGreen
$dataGridView.DefaultCellStyle.BackColor = [System.Drawing.Color]::Black
$dataGridView.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Lime
$dataGridView.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::DarkGreen
$dataGridView.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
$dataGridView.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
$dataGridView.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::Lime
$form.Controls.Add($dataGridView)

# Pulsante Aggiorna
$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "AGGIORNA ELENCO"
$btnRefresh.Location = New-Object System.Drawing.Point(20, 370)
$btnRefresh.Size = New-Object System.Drawing.Size(150, 35)
$btnRefresh.FlatStyle = "Flat"
$btnRefresh.FlatAppearance.BorderColor = [System.Drawing.Color]::Lime
$btnRefresh.BackColor = "Black"
$btnRefresh.ForeColor = [System.Drawing.Color]::Lime
$form.Controls.Add($btnRefresh)

# --- Label Descrizione ---
$lblNewRP = New-Object System.Windows.Forms.Label
$lblNewRP.Text = "Descrizione nuovo punto:"
$lblNewRP.Location = New-Object System.Drawing.Point(190, 380)
$lblNewRP.AutoSize = $true
$lblNewRP.ForeColor = [System.Drawing.Color]::Lime
$form.Controls.Add($lblNewRP)

# --- TextBox Descrizione ---
$txtDescription = New-Object System.Windows.Forms.TextBox
$txtDescription.Location = New-Object System.Drawing.Point(370, 376)
$txtDescription.Size = New-Object System.Drawing.Size(250, 25)
$txtDescription.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 10)
$txtDescription.ForeColor = [System.Drawing.Color]::Lime
$txtDescription.BorderStyle = "FixedSingle"
# Forza l'ancoraggio a Top-Left per evitare che si allarghi
$txtDescription.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($txtDescription)

# --- Pulsante Crea Punto ---
$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text = "CREA PUNTO"
$btnCreate.Location = New-Object System.Drawing.Point(640, 370)
$btnCreate.Size = New-Object System.Drawing.Size(170, 35)
$btnCreate.FlatStyle = "Flat"
$btnCreate.FlatAppearance.BorderColor = [System.Drawing.Color]::Lime
$btnCreate.BackColor = [System.Drawing.Color]::FromArgb(0, 40, 0)
$btnCreate.ForeColor = [System.Drawing.Color]::Lime
$btnCreate.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnCreate)

# Pulsante Elimina
$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "ELIMINA SELEZIONATO"
$btnDelete.Location = New-Object System.Drawing.Point(20, 430)
$btnDelete.Size = New-Object System.Drawing.Size(220, 35)
$btnDelete.FlatStyle = "Flat"
$btnDelete.FlatAppearance.BorderColor = [System.Drawing.Color]::Red
$btnDelete.BackColor = "Black"
$btnDelete.ForeColor = [System.Drawing.Color]::Red
$form.Controls.Add($btnDelete)

# Pulsante Ripristina
$btnRestore = New-Object System.Windows.Forms.Button
$btnRestore.Text = "AVVIA RIPRISTINO SISTEMA"
$btnRestore.Location = New-Object System.Drawing.Point(260, 430)
$btnRestore.Size = New-Object System.Drawing.Size(250, 35)
$btnRestore.FlatStyle = "Flat"
$btnRestore.FlatAppearance.BorderColor = [System.Drawing.Color]::Orange
$btnRestore.BackColor = [System.Drawing.Color]::FromArgb(40, 20, 0)
$btnRestore.ForeColor = [System.Drawing.Color]::Orange
$btnRestore.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnRestore)

# Pulsante Esci
$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "TERMINATE"
$btnExit.Location = New-Object System.Drawing.Point(690, 550)
$btnExit.Size = New-Object System.Drawing.Size(120, 35)
$btnExit.FlatStyle = "Flat"
$btnExit.FlatAppearance.BorderColor = [System.Drawing.Color]::DarkGray
$btnExit.ForeColor = [System.Drawing.Color]::DarkGray
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# ============================================
# EVENTI
# ============================================
$btnRefresh.Add_Click({ Refresh-RestorePointsDisplay })

$btnCreate.Add_Click({
    $description = $txtDescription.Text.Trim()
    if ([string]::IsNullOrEmpty($description)) {
        [System.Windows.Forms.MessageBox]::Show("Inserisci una descrizione per il nuovo punto di ripristino.", "Descrizione Mancante", "OK", "Information")
        return
    }

    try {
        Write-Log "Creazione punto di ripristino: $description" "INFO"
        
        # Tentiamo la creazione
        Checkpoint-Computer -Description $description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        
        [System.Windows.Forms.MessageBox]::Show("Punto di ripristino creato con successo!", "Successo", "OK", "Information")
        Write-Log "Punto creato con successo." "OK"
        Refresh-RestorePointsDisplay
        $txtDescription.Text = ""
    }
    catch {
        # Se l'errore è quello del servizio disabilitato, mostriamo un messaggio "umano"
        if ($_.Exception.Message -match "disabilitato|disabilitato o non è associato|disabled") {
            $errMsg = "Impossibile creare il punto di ripristino.`n`n" +
                      "Il servizio 'Volume Shadow Copy' (VSS) o la Protezione del Sistema sono DISABILITATI su questo PC.`n`n" +
                      "Per risolvere:`n" +
                      "1. Apri 'Servizi' (services.msc).`n" +
                      "2. Trova 'Volume Shadow Copy' e avvialo.`n" +
                      "3. Vai in 'Proprietà sistema' -> 'Protezione sistema' e attiva la protezione per l'unità C:."
            [System.Windows.Forms.MessageBox]::Show($errMsg, "Sistema di Ripristino Disabilitato", "OK", "Warning")
            Write-Log "Tentativo fallito: Sistema di ripristino disabilitato." "WARNING"
        } else {
            # Errore generico
            [System.Windows.Forms.MessageBox]::Show("Errore durante la creazione: $($_.Exception.Message)", "Errore", "OK", "Error")
            Write-Log "Errore creazione: $($_.Exception.Message)" "ERROR"
        }
    }
})
$btnDelete.Add_Click({
    if ($dataGridView.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Seleziona un punto di ripristino da eliminare.", "Nessuna Selezione", "OK", "Information")
        return
    }

    $selectedRow = $dataGridView.SelectedRows[0]
    $sequenceNumber = $selectedRow.Cells["SequenceNumber"].Value
    $description = $selectedRow.Cells["Description"].Value
    $creationTime = $selectedRow.Cells["Data Creazione"].Value

    $confirmResult = [System.Windows.Forms.MessageBox]::Show("Sei sicuro di voler eliminare il punto di ripristino:`n`nDescrizione: '$description'`nData: '$creationTime'`n`nQuesta azione è irreversibile.", "Conferma Eliminazione", "YesNo", "Warning")

    if ($confirmResult -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            Remove-ComputerRestorePoint -RestorePoint $sequenceNumber -ErrorAction Stop
            [System.Windows.Forms.MessageBox]::Show("Punto di ripristino eliminato con successo!", "Successo", "OK", "Information")
            Write-Log "Punto $sequenceNumber eliminato." "OK"
            Refresh-RestorePointsDisplay
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Errore durante l'eliminazione: $($_.Exception.Message)", "Errore", "OK", "Error")
            Write-Log "Errore eliminazione: $($_.Exception.Message)" "ERROR"
        }
    }
})

$btnRestore.Add_Click({
    if ($dataGridView.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Seleziona un punto di ripristino per avviare il ripristino.", "Nessuna Selezione", "OK", "Information")
        return
    }

    $selectedRow = $dataGridView.SelectedRows[0]
    $sequenceNumber = $selectedRow.Cells["SequenceNumber"].Value
    $description = $selectedRow.Cells["Description"].Value
    $creationTime = $selectedRow.Cells["Data Creazione"].Value

    $confirmResult = [System.Windows.Forms.MessageBox]::Show("ATTENZIONE: Stai per avviare un ripristino del sistema!`n`nIl computer si riavvierà immediatamente e cercherà di tornare allo stato di:`n`nDescrizione: '$description'`nData: '$creationTime'`n`nAssicurati di aver salvato tutti i tuoi lavori. Sei sicuro di voler procedere?", "Conferma Ripristino Sistema", "YesNo", "Stop")

    if ($confirmResult -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            Write-Log "Avvio ripristino sistema al punto $sequenceNumber" "WARNING"
            Restore-Computer -RestorePoint $sequenceNumber -ErrorAction Stop
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Errore durante l'avvio del ripristino: $($_.Exception.Message)", "Errore", "OK", "Error")
            Write-Log "Errore ripristino: $($_.Exception.Message)" "ERROR"
        }
    }
})

# ============================================
# AVVIO
# ============================================
$form.Add_Shown({
    Write-Log "RestorePoint Manager avviato." "INFO"
    Refresh-RestorePointsDisplay
})

$form.ShowDialog() | Out-Null