# Importa il Gantt di Stand up nel GitHub Project "ARCADE Milano 2026 | Piano di lavoro".
#
# Uso, da PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\scripts\importa-gantt.ps1            (prova: stampa il piano, non crea niente)
#   powershell -ExecutionPolicy Bypass -File .\scripts\importa-gantt.ps1 -Esegui    (crea davvero etichette, milestone, issue e schede)
#
# Si può rilanciare senza rischi: le issue con lo stesso titolo non vengono duplicate.
# Il rilancio riporta Status a Todo: per non toccarlo aggiungi -SenzaStatus.

param([switch]$Esegui, [switch]$SenzaStatus)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = New-Object System.Text.UTF8Encoding $false

$Org      = "stand-up-arcade-milan"
$Repo     = "$Org/Standup-platform"
$ProjNum  = 1
$ProjId   = "PVT_kwDOFHx1_c4BnaIw"

# Esegue gh e riprova fino a 3 volte, per gli errori passeggeri di GitHub
function GhRun {
    for ($tent = 1; $tent -le 3; $tent++) {
        $out = & gh.exe @args
        if ($LASTEXITCODE -eq 0) { return $out }
        if ($tent -lt 3) { Start-Sleep -Seconds 3 }
    }
    throw "gh ha fallito: gh $($args -join ' ')"
}
function GhJson {
    $out = GhRun @args | Out-String
    return $out | ConvertFrom-Json
}
# Imposta i campi delle issue (date, Area) con l'API REST dei campi issue
function ImpostaCampiIssue($numero, $valori) {
    $json = @{ issue_field_values = @($valori) } | ConvertTo-Json -Depth 6 -Compress
    for ($tent = 1; $tent -le 3; $tent++) {
        $out = $json | & gh.exe api --method PUT -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2026-03-10" "repos/$Repo/issues/$numero/issue-field-values" --input - | Out-String
        if ($LASTEXITCODE -eq 0) { return }
        if ($tent -lt 3) { Start-Sleep -Seconds 3 }
    }
    throw "impossibile impostare i campi della issue $numero"
}
# Una sola esecuzione, senza ripetere: serve per creare le issue, per non rischiare doppioni
function GhOnceJson {
    $out = & gh.exe @args | Out-String
    if ($LASTEXITCODE -ne 0) { throw "gh ha fallito: gh $($args -join ' ')" }
    return $out | ConvertFrom-Json
}

# Fasi del Gantt: nome della milestone e scadenza
$Fasi = [ordered]@{
    0 = @{ Nome = "Fase 0: Avvio";                    Fine = "2026-10-29"; Desc = "Kickoff, ruoli, esplorazione dei dati e bozza dei KPI." }
    1 = @{ Nome = "Fase 1: Analisi e progettazione";  Fine = "2026-10-30"; Desc = "Processo commerciale, schema dati, contratto API e mockup. Chiude con il SAL 1." }
    2 = @{ Nome = "Fase 2: Fondamenta";               Fine = "2026-11-13"; Desc = "Database con le edizioni 2024 e 2025, API base, back office e flusso del contratto. Chiude con il SAL 2." }
    3 = @{ Nome = "Fase 3: Sviluppo in autonomia";    Fine = "2026-12-01"; Desc = "Tornelli e scanner, cruscotti, report, sicurezza, portale espositori e rinnovi." }
    4 = @{ Nome = "Fase 4: Chiusura e consegna";      Fine = "2026-12-04"; Desc = "Test end-to-end, documentazione, prove della demo e presentazione finale." }
}

# Etichette per filone
$Etichette = @(
    @{ Nome = "BID";       Colore = "2c6bd3"; Desc = "Dati e codice" },
    @{ Nome = "BAD";       Colore = "7b42cf"; Desc = "Power Platform e Business Intelligence" },
    @{ Nome = "Comune";    Colore = "0e8f83"; Desc = "Lavoro condiviso tra BID e BAD" },
    @{ Nome = "Gestione";  Colore = "b8720f"; Desc = "Coordinamento, Git e documentazione" },
    @{ Nome = "milestone"; Colore = "cf2f4a"; Desc = "Data di controllo con il cliente o di consegna" }
)

# Attività, una per riga: Titolo, Responsabile (ruolo), Filone, Inizio, Fine, Fase, Tipo (att = attività, ms = milestone), separati da barre verticali
$Attivita = @'
Kickoff, consegna dati e intervista requisiti|Tutti|Comune|2026-10-16|2026-10-16|0|att
Ruoli, repository Git unico e convenzioni|Team Leader, Git|Gestione|2026-10-17|2026-10-21|0|att
Esplorazione dati 2024 e 2025 e catalogo anomalie|Data Engineer, Power BI|Comune|2026-10-19|2026-10-27|0|att
Bozza definizione KPI da validare col cliente|Power BI|BAD|2026-10-19|2026-10-29|0|att
Analisi processo commerciale, dal preventivo al contratto|Power Apps, Power Automate|BAD|2026-10-19|2026-10-28|1|att
Schema dati condiviso su PostgreSQL|Data Architect e BAD|Comune|2026-10-21|2026-10-29|1|att
Contratto API (specifica OpenAPI)|Backend|BID|2026-10-22|2026-10-29|1|att
Privacy by design e modello di sicurezza: espositori e minori|Sicurezza, Data Architect|Comune|2026-10-23|2026-10-29|1|att
Mockup back office, cruscotto e portale|Power Apps, Frontend|Comune|2026-10-23|2026-10-29|1|att
Preparazione presentazione SAL 1|Team Leader|Gestione|2026-10-28|2026-10-29|1|att
SAL 1: schema e API congelati|Tutti, cliente|Gestione|2026-10-30|2026-10-30|1|ms
Creazione database e caricamento edizione 2024|Data Engineer, Data Architect|BID|2026-10-31|2026-11-05|2|att
Caricamento edizione 2025 e gestione anomalie|Data Engineer|BID|2026-11-05|2026-11-12|2|att
API base: espositori, spazi, contratti|Backend|BID|2026-11-02|2026-11-12|2|att
Back office Power Apps: listino e planimetria|Power Apps|BAD|2026-11-02|2026-11-10|2|att
Flusso commerciale semplificato: pratica, offerta, contratto e acconto|Power Automate, Power Apps|BAD|2026-11-03|2026-11-12|2|att
Dati commerciali nel modello condiviso|Power Automate, Data Architect|Comune|2026-11-05|2026-11-12|2|att
Briefing intermedio|Tutti, cliente|Gestione|2026-11-06|2026-11-06|2|ms
Prima versione report Power BI sui KPI|Power BI|BAD|2026-11-06|2026-11-12|2|att
Prova integrata della demo SAL 2|Git e QA, Team Leader|Gestione|2026-11-11|2026-11-12|2|att
SAL 2: due edizioni e contratto 2026|Tutti|Gestione|2026-11-13|2026-11-13|2|ms
Acquisizione tornelli e scanner in tempo reale|Data Engineer, Backend|BID|2026-11-16|2026-11-24|3|att
App di scansione allo stand|Power Apps|BAD|2026-11-16|2026-11-25|3|att
Cruscotto staff: affluenza e picco nei padiglioni|Frontend, Backend|BID|2026-11-16|2026-11-27|3|att
Stima delle presenze dal peso su dati simulati|Data Engineer, Backend|BID|2026-11-18|2026-11-26|3|att
Report direzione: confronto edizioni, ricavo per m2, costo per contatto|Power BI|BAD|2026-11-16|2026-11-27|3|att
Implementazione RLS e tutela dati minori|Sicurezza, Power BI, Backend|Comune|2026-11-17|2026-11-28|3|att
Stato settimanale al cliente 20/11|Team Leader|Gestione|2026-11-20|2026-11-20|3|ms
Portale espositori con riepilogo post-fiera|Frontend, Backend|BID|2026-11-20|2026-12-01|3|att
Rinnovo espositori generato dal contratto precedente|Power Automate|BAD|2026-11-23|2026-11-28|3|att
Riconciliazione numeri tra tutte le viste|Power BI, Data Engineer|Comune|2026-11-25|2026-12-01|3|att
Stato settimanale al cliente 27/11|Team Leader|Gestione|2026-11-27|2026-11-27|3|ms
Test end-to-end delle tre fasi della fiera|Git e QA, Tutti|Comune|2026-11-30|2026-12-02|4|att
README, specifica API e pulizia repository|Git, Backend|Gestione|2026-11-30|2026-12-03|4|att
Slide e prove della demo dal vivo|Team Leader, Tutti|Gestione|2026-12-01|2026-12-03|4|att
Stato settimanale al cliente 03/12|Team Leader|Gestione|2026-12-03|2026-12-03|4|ms
Presentazione finale e consegna|Tutti, cliente|Gestione|2026-12-04|2026-12-04|4|ms
'@

$righe = $Attivita -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
$piano = foreach ($r in $righe) {
    $c = $r.Split("|")
    [pscustomobject]@{ Titolo = $c[0]; Resp = $c[1]; Filone = $c[2]; Inizio = $c[3]; Fine = $c[4]; Fase = [int]$c[5]; Tipo = $c[6] }
}

if (-not $Esegui) {
    Write-Host "PROVA: non viene creato niente." -ForegroundColor Yellow
    Write-Host "Attività da creare: $($piano.Count)"
    $piano | Format-Table Titolo, Filone, Inizio, Fine, Fase, Tipo -AutoSize
    Write-Host "Per creare davvero, rilancia con -Esegui" -ForegroundColor Yellow
    return
}

# 1. Etichette
Write-Host "Etichette..." -ForegroundColor Cyan
foreach ($e in $Etichette) {
    GhRun label create $e.Nome --color $e.Colore --description $e.Desc --force -R $Repo | Out-Null
}

# 2. Milestone (le fasi)
Write-Host "Milestone..." -ForegroundColor Cyan
$esistenti = GhJson api "repos/$Repo/milestones?state=all&per_page=100"
foreach ($k in $Fasi.Keys) {
    $f = $Fasi[$k]
    if (-not ($esistenti | Where-Object { $_.title -eq $f.Nome })) {
        GhRun api "repos/$Repo/milestones" -f "title=$($f.Nome)" -f "due_on=$($f.Fine)T23:59:59Z" -f "description=$($f.Desc)" | Out-Null
        Write-Host "  creata: $($f.Nome)"
    }
}

# 3. Campi del Project e campi delle issue
Write-Host "Campi..." -ForegroundColor Cyan
$campi = (GhJson project field-list $ProjNum --owner $Org --format json).fields
$fStatus = $campi | Where-Object { $_.name -eq "Status" }
function OpzioneId($campo, $nome) { return ($campo.options | Where-Object { $_.name -eq $nome }).id }

# Start date, Target date e Area sono campi delle issue a livello di organizzazione
$campiIssue = GhOnceJson api "orgs/$Org/issue-fields" -H "X-GitHub-Api-Version: 2026-03-10"
Write-Host ("  Campi delle issue: " + (($campiIssue | ForEach-Object { $_.name + " (" + $_.data_type + ")" }) -join ", "))
$cStart  = $campiIssue | Where-Object { $_.name -eq "Start date" }
$cTarget = $campiIssue | Where-Object { $_.name -eq "Target date" }
$cArea   = $campiIssue | Where-Object { $_.name -eq "Area" }
if (-not $cStart -or -not $cTarget) { throw "Non trovo i campi Start date e Target date tra i campi delle issue." }
if ($cArea -and $cArea.options) {
    Write-Host ("  Area, valori: " + (($cArea.options | ForEach-Object { $_.name }) -join ", "))
} else {
    Write-Host "  Area senza valori leggibili: la salto, restano le etichette." -ForegroundColor Yellow
    $cArea = $null
}

# 4. Issue + schede del Project
Write-Host "Issue e schede..." -ForegroundColor Cyan
$numMilestone = @{}
foreach ($m in (GhJson api "repos/$Repo/milestones?state=all&per_page=100")) { $numMilestone[$m.title] = $m.number }
$esistenti = @{}
foreach ($i in (GhJson issue list -R $Repo --state all --limit 500 --json "title,url,number")) { $esistenti[$i.title] = $i }

$creati = 0; $giaEsistenti = 0; $errori = @()
foreach ($a in $piano) {
    try {
        $fase = $Fasi[$a.Fase]
        $nuova = $false
        if ($esistenti.ContainsKey($a.Titolo)) {
            $url = $esistenti[$a.Titolo].url
            $numero = $esistenti[$a.Titolo].number
            $giaEsistenti++
        } else {
            $periodo = if ($a.Inizio -eq $a.Fine) { $a.Inizio } else { "$($a.Inizio) / $($a.Fine)" }
            $corpo = "Responsabile (ruolo): $($a.Resp)`nFilone: $($a.Filone)`nFase: $($fase.Nome)`nPeriodo: $periodo`n`nNomi e assegnazione da definire quando la divisione BID e BAD è concordata."
            $parametri = @("api", "repos/$Repo/issues", "-f", "title=$($a.Titolo)", "-f", "body=$corpo", "-f", "labels[]=$($a.Filone)", "-F", "milestone=$($numMilestone[$fase.Nome])")
            if ($a.Tipo -eq "ms") { $parametri += @("-f", "labels[]=milestone") }
            $risp = GhOnceJson @parametri
            $url = $risp.html_url
            $numero = $risp.number
            $nuova = $true
            $creati++
        }
        # date e Area, come campi della issue
        $valori = @(
            @{ field_id = [int64]$cStart.id;  value = $a.Inizio },
            @{ field_id = [int64]$cTarget.id; value = $a.Fine }
        )
        if ($cArea) {
            $opz = $cArea.options | Where-Object { $_.name -ieq $a.Filone }
            if ($opz) { $valori += @{ field_id = [int64]$cArea.id; value = $opz.name } }
        }
        ImpostaCampiIssue $numero $valori
        # scheda nel Project e Status
        $item = GhJson project item-add $ProjNum --owner $Org --url $url --format json
        if (-not $SenzaStatus) {
            $stato = if ($a.Titolo -like "Kickoff*") { "Done" } else { "Todo" }
            GhRun project item-edit --id $item.id --project-id $ProjId --field-id $fStatus.id --single-select-option-id (OpzioneId $fStatus $stato) | Out-Null
        }
        Write-Host ("  " + $(if ($nuova) { "creata" } else { "aggiornata" }) + ": " + $a.Titolo)
    } catch {
        $errori += $a.Titolo
        Write-Host "  ERRORE su: $($a.Titolo)" -ForegroundColor Red
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 800
}
Write-Host ""
Write-Host "Fatto. Create: $creati, già esistenti e aggiornate: $giaEsistenti, errori: $($errori.Count)." -ForegroundColor Green
if ($errori.Count -gt 0) {
    Write-Host "Attività con errore (rilancia lo script per riprovarle):" -ForegroundColor Yellow
    $errori | ForEach-Object { Write-Host "  - $_" }
}
Write-Host "Apri il Project: https://github.com/orgs/$Org/projects/$ProjNum"
