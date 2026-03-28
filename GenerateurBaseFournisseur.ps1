param(
    [string]$SupplierRoot = ".\Fuseau 2081",
    [string]$OutputDir = ".\",
    [string]$SharePointBase = "https://bahierfr.sharepoint.com/sites/NonConformiteQualite/Docs_Fournisseurs",
    [string]$SupplierCode = "2081",
    [string]$MasterFourn = ".\Fournisseurs.csv",
    [string]$MasterMat = ".\Matieres_Premieres.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== GENERATEUR BASE DOCUMENTAIRE V3 (MASTER DATA) ===" -ForegroundColor Cyan

# ─── CHARGEMENT DES DONNÉES MASTER ───────────────────────────────────────────
$SupplierName = "Fournisseur Inconnu"
if (Test-Path $MasterFourn) {
    Write-Host "[1/6] Chargement CSV Fournisseurs..." -ForegroundColor Yellow
    $csvF = Import-Csv $MasterFourn -Delimiter "," -Encoding UTF8
    $fournMatch = $csvF | Where-Object { $_.ID_Fournisseur -eq $SupplierCode }
    if ($fournMatch) {
        $SupplierName = $fournMatch.Nom_Fournisseur
        Write-Host "   -> Fournisseur detecte : $SupplierName ($SupplierCode)" -ForegroundColor Green
    }
    else {
        Write-Host "   -> AVERTISSEMENT : Fournisseur $SupplierCode introuvable dans le Master." -ForegroundColor Yellow
    }
}
else {
    Write-Host "   -> Master Fournisseurs introuvable, utilisation du code : $SupplierCode" -ForegroundColor Yellow
}

$IngredientMap = @{}
if (Test-Path $MasterMat) {
    Write-Host "[2/6] Chargement CSV Matieres Premieres..." -ForegroundColor Yellow
    $csvM = Import-Csv $MasterMat -Delimiter "," -Encoding UTF8
    $matCount = 0
    foreach ($row in $csvM) {
        if (-not [string]::IsNullOrWhiteSpace($row.Code_Ressource)) {
            $code = $row.Code_Ressource.Trim()
            $nom = ""
            if ($row.psobject.properties.match('Nom_Ressouces').Count -gt 0) { $nom = $row.Nom_Ressouces }
            elseif ($row.psobject.properties.match('Nom_Ressource').Count -gt 0) { $nom = $row.Nom_Ressource }
            
            $IngredientMap[$code] = @{
                CodeId = $row.id
                Nom    = $nom
            }
            $matCount++
        }
    }
    Write-Host "   -> $matCount matieres references chargees." -ForegroundColor Green
}
else {
    Write-Host "   -> Master Matieres introuvable. Les codes articles devront etre resolus manuellement." -ForegroundColor Yellow
}

# ─── FONCTIONS CLASSIFICATION ────────────────────────────────────────────────
function Get-DocType {
    param([string]$FileName, [string]$FolderPath, [string]$Extension)
    $name = $FileName.ToUpper()
    $folder = $FolderPath.ToUpper()
    if ($Extension -eq ".msg") { return "COURRIER" }
    if ($folder -match "\\CDC\\?" -or $name -match "CDC|CAHIER.DES.CHARGES") { return "CDC" }
    if ($name -match "CRISE|ALERTE|RECALL|GESTION.CRISE" -or $folder -match "CRISE") { return "GESTION_CRISE" }
    if ($name -match "PROTOCOLE|PROTOCOL|SECURITE") { return "PROTOCOLE" }
    if ($name -match "CERTIFICAT|CERTIF|IFS|FSSC|ISO.9001|HACCP|BIO" -or $folder -match "CERTIFICAT") { return "CERTIFICAT" }
    if ($folder -match "\\ANALYSE" -or $name -match "ANALYSE|AR-\d|R2[0-9]{7}") { return "ANALYSE" }
    if ($name -match "QUESTIONNAIRE|OGM|ALLERGEN|COMPOSITION|EN\.ACHAT\.(006|007|010|011|013|017)|ETHIQUE|MALVEILLANCE|CONTAMINANT|PLAN.DE.CONTROLE") { return "QUESTIONNAIRE" }
    if ($name -match "^\d{5}|FICHE.TECHNIQUE|FT[\.\-_ ]|\.FT\.") { return "FT" }
    return "AUTRE"
}

function Get-DateFromFilename {
    param([string]$FileName)
    if ($FileName -match "(\d{4})[-_](\d{2})[-_](\d{2})") {
        try { return [datetime]::ParseExact("$($Matches[1])-$($Matches[2])-$($Matches[3])", "yyyy-MM-dd", $null) } catch {}
    }
    if ($FileName -match "(\d{2})[/\.\-](\d{2})[/\.\-](\d{4})") {
        try { return [datetime]::ParseExact("$($Matches[1])/$($Matches[2])/$($Matches[3])", "dd/MM/yyyy", $null) } catch {}
    }
    $moisFr = @{ "janvier" = 1; "fevrier" = 2; "mars" = 3; "avril" = 4; "mai" = 5; "juin" = 6; "juillet" = 7; "aout" = 8; "septembre" = 9; "octobre" = 10; "novembre" = 11; "decembre" = 12 }
    $fnLow = $FileName.ToLower()
    foreach ($mois in $moisFr.Keys) {
        if ($fnLow -match "(\d{1,2})\s*$mois\s*(\d{4})") {
            try { return [datetime]::new([int]$Matches[2], $moisFr[$mois], [int]$Matches[1]) } catch {}
        }
    }
    if ($FileName -match "(20[12]\d)") {
        try { return [datetime]::new([int]$Matches[1], 1, 1) } catch {}
    }
    return $null
}

function Resolve-Ingredient {
    param([string]$FilePath)
    # Cherche un code a 4 ou 5 chiffres dans le nom de dossier ou de fichier
    if ($FilePath -match "(\\0?(\d{4,5})[^\\]*\\)|(^0?(\d{4,5}))") {
        $code = if ($Matches[2]) { $Matches[2] } else { $Matches[4] }
        if ($IngredientMap.ContainsKey($code)) { 
            return @{ Code = "ING_" + $IngredientMap[$code].CodeId; Nom = $IngredientMap[$code].Nom; BaseCode = $code }
        }
    }
    
    # Fallback si mots cles (pour retro-compatibilite ou doc mal nomme)
    $pl = $FilePath.ToLower()
    if ($pl -match "amande") { return @{ Code = "ING_UNK"; Nom = "Amandes"; BaseCode = "UNK" } }
    if ($pl -match "tournesol") { return @{ Code = "ING_UNK"; Nom = "Huile tournesol"; BaseCode = "UNK" } }
    if ($pl -match "olive") { return @{ Code = "ING_UNK"; Nom = "Huile olive"; BaseCode = "UNK" } }
    if ($pl -match "raisin") { return @{ Code = "ING_UNK"; Nom = "Raisins secs"; BaseCode = "UNK" } }
    if ($pl -match "sucre") { return @{ Code = "ING_UNK"; Nom = "Sucre"; BaseCode = "UNK" } }
    if ($pl -match "moutarde") { return @{ Code = "ING_UNK"; Nom = "Moutarde"; BaseCode = "UNK" } }
    if ($pl -match "oeuf") { return @{ Code = "ING_UNK"; Nom = "Oeuf"; BaseCode = "UNK" } }
    if ($pl -match "figue") { return @{ Code = "ING_UNK"; Nom = "Figue"; BaseCode = "UNK" } }
    if ($pl -match "cranberr") { return @{ Code = "ING_UNK"; Nom = "Cranberries"; BaseCode = "UNK" } }
    
    return @{ Code = "ING_GENERAL"; Nom = "Generique / Tous produits"; BaseCode = "ALL" }
}

function Sanitize-Name {
    param([string]$Name, [int]$MaxLen = 60)
    $clean = $Name -replace '[^a-zA-Z0-9\.\-]', '_' -replace '_+', '_' -replace '^_|_$', ''
    if ($clean.Length -gt $MaxLen) { $clean = $clean.Substring(0, $MaxLen) }
    return $clean
}

function Clean-Field {
    param([string]$Value, [int]$MaxLen = 255)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    $v = $Value.Trim() -replace '"', "'"
    if ($v.Length -gt $MaxLen) { $v = $v.Substring(0, $MaxLen) }
    return $v
}

function Quote-CSV {
    param([string]$Value)
    if ($Value -match '[;"\r\n]') { return '"' + ($Value -replace '"', '""') + '"' }
    return $Value
}

# ─── PREPARATION EXPORT ──────────────────────────────────────────────────────
if (-not (Test-Path $SupplierRoot)) {
    Write-Error "Dossier source introuvable : $SupplierRoot"
    exit 1
}

$ExportFolder = [System.IO.Path]::Combine($OutputDir, ("Export_" + $SupplierCode))
$OutputCSV = [System.IO.Path]::Combine($OutputDir, ("Base_" + $SupplierCode + ".csv"))
$ReportPath = [System.IO.Path]::Combine($OutputDir, ("Rapport_" + $SupplierCode + ".txt"))

if (Test-Path $ExportFolder) { Remove-Item $ExportFolder -Recurse -Force }
New-Item -ItemType Directory -Path $ExportFolder | Out-Null
Write-Host "[3/6] Dossier Export reinitialise : Export_$SupplierCode" -ForegroundColor Yellow

# ─── SCAN DES FICHIERS ───────────────────────────────────────────────────────
Write-Host "[4/6] Scan du dossier source..." -ForegroundColor Yellow
$SupportedExt = @(".pdf", ".doc", ".docx", ".xls", ".xlsx", ".msg", ".txt")
$ExcludePatterns = @("Thumbs.db", ".DS_Store", "desktop.ini")

$AllFiles = Get-ChildItem -Path $SupplierRoot -Recurse -File |
Where-Object { $SupportedExt -contains $_.Extension.ToLower() -and $ExcludePatterns -notcontains $_.Name } |
Sort-Object FullName

Write-Host ("   -> " + $AllFiles.Count + " fichiers a traiter") -ForegroundColor Green

# ─── CLASSIFICATION ──────────────────────────────────────────────────────────
Write-Host "[5/6] Extraction, renommage et copie en cours..." -ForegroundColor Yellow
$records = [System.Collections.Generic.List[PSCustomObject]]::new()
$docIndex = 1
$today = [datetime]::Today
$copyCount = 0

foreach ($file in $AllFiles) {
    $ext = $file.Extension.ToLower()
    $basename = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $folder = $file.DirectoryName
    
    # ─── EXTRACTION DES MÉTADONNÉES ──────────────────────────────────────────
    $docType = Get-DocType -FileName $file.Name -FolderPath $folder -Extension $ext
    $ing = Resolve-Ingredient -FilePath $file.FullName
    $emDate = Get-DateFromFilename -FileName $file.Name

    <# 
    ---------------------------------------------------------------------------
    PROJET : FUTURE EVOLUTION OCR (Python / Project PDFANALYZE)
    ---------------------------------------------------------------------------
    C'est ici que s'insérera l'appel au script Python pour analyser le CONTENU.
    Logique cible : 
    1. Si $emDate ou $docType sont incertains (ou 'AUTRE'), appeler module 'PDFANALYZE'.
    2. Récupérer les données structurées du corps du PDF via OCR.
    3. Mettre à jour $emDate et $docType avec les données du corps du fichier.
    ---------------------------------------------------------------------------
    #>

    if ($null -eq $emDate) {
        $pf = [System.IO.Path]::GetFileName($folder)
        if ($pf -match "^(20[12]\d)$") { $emDate = [datetime]::new([int]$pf, 1, 1) }
    }
    
    $annee = ""; $datVal = ""; $statut = "En attente"
    if ($null -ne $emDate) {
        $annee = $emDate.Year.ToString()
        $expiry = $emDate.AddYears(3)
        $datVal = $expiry.ToString("dd/MM/yyyy")
        $statut = if ($expiry -lt $today) { "Expire" } else { "Valide" }
    }
    
    $docID = "DOC_{0:D3}" -f $docIndex; $docIndex++
    $safeBase = Sanitize-Name -Name $basename -MaxLen 60
    $newBasename = ($docType + "_" + $ing.BaseCode + "_" + $docID + "_" + $safeBase)
    $newFilename = $newBasename + $ext
    
    $typeFolder = [System.IO.Path]::Combine($ExportFolder, $docType)
    if (-not (Test-Path $typeFolder)) { New-Item -ItemType Directory -Path $typeFolder | Out-Null }
    
    $destPath = [System.IO.Path]::Combine($typeFolder, $newFilename)
    Copy-Item -Path $file.FullName -Destination $destPath -Force
    $copyCount++
    
    $spFilename = $newFilename -replace ' ', '%20'
    $spURL = $SharePointBase + "/" + $SupplierCode + "/" + $docType + "/" + $spFilename
    $titleRaw = $docType + "_" + $ing.BaseCode + "_" + $docID
    $title = Clean-Field -Value $titleRaw -MaxLen 100
    
    $row = [PSCustomObject]@{
        Title             = Quote-CSV (Clean-Field $title)
        ID_Fournisseur    = $SupplierCode
        Nom_Fournisseur   = Quote-CSV (Clean-Field $SupplierName)
        Code_Ingredient   = $ing.BaseCode
        ID_Ingredient     = $ing.Code
        Nom_Ingredient    = Quote-CSV (Clean-Field $ing.Nom)
        ID_Document       = $docID
        Nom_Document      = Quote-CSV (Clean-Field $newBasename -MaxLen 255)
        Extension         = $ext
        Type_Document     = $docType
        Annee_Emission    = $annee
        Date_Validite     = $datVal
        Statut            = $statut
        Chemin_SharePoint = Quote-CSV ("/Docs_Fournisseurs/" + $SupplierCode + "/" + $docType + "/")
        Nom_Fichier       = Quote-CSV (Clean-Field $newFilename -MaxLen 255)
        URL_SharePoint    = Quote-CSV (Clean-Field $spURL -MaxLen 500)
    }
    $records.Add($row)
}

# ─── GENERATION CSV & RAPPORT ────────────────────────────────────────────────
Write-Host "[6/6] Creation des livrables finaux..." -ForegroundColor Yellow

# CSV Export (Format Semicolon for French Excel)
$header = "Title;ID_Fournisseur;Nom_Fournisseur;Code_Ingredient;ID_Ingredient;Nom_Ingredient;ID_Document;Nom_Document;Extension;Type_Document;Annee_Emission;Date_Validite;Statut;Chemin_SharePoint;Nom_Fichier;URL_SharePoint"
$csvLines = [System.Collections.Generic.List[string]]::new()
$csvLines.Add($header)
foreach ($r in $records) {
    $line = ($r.Title + ";" + $r.ID_Fournisseur + ";" + $r.Nom_Fournisseur + ";" + $r.Code_Ingredient + ";" + $r.ID_Ingredient + ";" + $r.Nom_Ingredient + ";" + $r.ID_Document + ";" + $r.Nom_Document + ";" + $r.Extension + ";" + $r.Type_Document + ";" + $r.Annee_Emission + ";" + $r.Date_Validite + ";" + $r.Statut + ";" + $r.Chemin_SharePoint + ";" + $r.Nom_Fichier + ";" + $r.URL_SharePoint)
    $csvLines.Add($line)
}
$utf8WithBom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllLines($OutputCSV, $csvLines, $utf8WithBom)

# Rapport Textuel
$byType = $records | Group-Object Type_Document  | Sort-Object Count -Descending
$byIng = $records | Group-Object Nom_Ingredient | Sort-Object Count -Descending
$byStatut = $records | Group-Object Statut         | Sort-Object Count -Descending

$rpt = [System.Collections.Generic.List[string]]::new()
$rpt.Add("=== RAPPORT EXPORT $SupplierName ($SupplierCode) ===")
$rpt.Add("Date           : " + (Get-Date -Format "dd/MM/yyyy HH:mm"))
$rpt.Add("TOTAL FILES    : " + $records.Count)
$rpt.Add("")
$rpt.Add("--- STATUTS ---")
foreach ($s in $byStatut) { $rpt.Add(("  {0,-15}: {1,3}" -f $s.Name, $s.Count)) }
$rpt.Add("")
$rpt.Add("--- TYPES ---")
foreach ($t in $byType) { $rpt.Add(("  {0,-15}: {1,3}" -f $t.Name, $t.Count)) }
$rpt.Add("")
$rpt.Add("--- INGREDIENTS DETECTES (Via Base Master) ---")
foreach ($i in $byIng) { $rpt.Add(("  {0,-40}: {1,3}" -f $i.Name, $i.Count)) }
[System.IO.File]::WriteAllLines($ReportPath, $rpt, $utf8WithBom)

Write-Host "   -> CSV et Rapport generes avec succes dans $OutputDir" -ForegroundColor Green
Write-Host ""
Write-Host "=== TERMINE ===" -ForegroundColor Cyan
Write-Host "Copiez le dossier Export_$SupplierCode sur SharePoint." -ForegroundColor White
Write-Host "Copiez-Collez le contenu de Base_$SupplierCode.csv dans votre Liste." -ForegroundColor White
