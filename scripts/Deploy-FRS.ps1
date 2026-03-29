<#
.SYNOPSIS
    Déploie la plateforme Gestion Fournisseurs (FRS) dans SharePoint Online.

.DESCRIPTION
    Crée les listes SharePoint, leurs colonnes, vues filtrées et la bibliothèque
    de documents. Utilise PnP PowerShell v3 (PowerShell 7.4.6+ obligatoire).

    Deux modes de fonctionnement :
    • Sans -ConfigPath : déploiement avec les 8 types de documents par défaut (tous niveaux actifs)
    • Avec -ConfigPath  : déploiement entièrement paramétré depuis le fichier JSON client
      → Types de documents personnalisés (noms, durées, alertes, niveaux)
      → Niveaux actifs (Fournisseur seul OU Fournisseur+Matière)
      Si niveaux_actifs = ["Fournisseur"] uniquement, les listes Matieres_Premieres
      et Liens_Fourn_Mat ne sont pas créées.

    ─── PRÉREQUIS ───────────────────────────────────────────────────────────────
    1. PowerShell 7.4.6 ou supérieur (7.4.x antérieur à .6 peut bloquer sur PnP v3)
       winget install Microsoft.PowerShell   (ou https://github.com/PowerShell/PowerShell)
       ⚠️  Azure Automation (runbooks) est bloqué sur cette version — exécuter en local.

    2. Module PnP PowerShell v3
       Install-Module PnP.PowerShell -Scope CurrentUser

    3. Enregistrer une app Entra ID sur le tenant du client (UNE FOIS PAR TENANT)
       ⚠️  L'ancienne app multi-tenant PnP a été supprimée le 9 sept. 2024.
           Chaque tenant doit avoir sa propre app.

       Register-PnPEntraIDAppForInteractiveLogin `
         -ApplicationName "PnP-FRS" `
         -SharePointDelegatePermissions "AllSites.FullControl" `
         -Tenant "clienttenant.onmicrosoft.com" `
         -Interactive
       → Notez l'AppID retourné, il sera nécessaire pour -ClientId

    ─── UTILISATION STANDARD ────────────────────────────────────────────────────
    ./Deploy-FRS.ps1 `
      -SiteUrl  "https://acmefood.sharepoint.com/sites/GestionFournisseurs" `
      -ClientId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

    ─── UTILISATION AVEC CONFIG CLIENT ─────────────────────────────────────────
    ./Deploy-FRS.ps1 `
      -SiteUrl    "https://acmefood.sharepoint.com/sites/GestionFournisseurs" `
      -ClientId   "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
      -ConfigPath "../../config/exemple_client_A.json"

.PARAMETER SiteUrl
    URL complète du site SharePoint cible. Le site doit déjà exister.

.PARAMETER ClientId
    AppID de l'application Entra ID enregistrée sur ce tenant.

.PARAMETER ConfigPath
    (Optionnel) Chemin vers le fichier JSON de configuration client.
    Si omis, les 8 types de documents par défaut sont chargés et tous les niveaux
    de suivi sont actifs.
#>

param(
    [Parameter(Mandatory, HelpMessage = "URL du site SP (ex: https://contoso.sharepoint.com/sites/GestionFournisseurs)")]
    [string]$SiteUrl,

    [Parameter(Mandatory, HelpMessage = "AppID Entra ID (enregistré via Register-PnPEntraIDAppForInteractiveLogin)")]
    [string]$ClientId,

    [Parameter(HelpMessage = "Chemin vers le fichier JSON de configuration client (optionnel)")]
    [string]$ConfigPath = ""
)

#Requires -Version 7.4.6
#Requires -Modules PnP.PowerShell

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step { param([string]$msg) Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "  ⚠ $msg" -ForegroundColor DarkYellow }
function Write-Skip { param([string]$msg) Write-Host "  ⏭  $msg" -ForegroundColor DarkGray }

# ─── CONNEXION ────────────────────────────────────────────────────────────────
Write-Step "🔌 Connexion à SharePoint..."
Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId
Write-OK "Connecté à : $SiteUrl"


# ═══════════════════════════════════════════════════════════════════════════════
# CHARGEMENT CONFIGURATION CLIENT
# ═══════════════════════════════════════════════════════════════════════════════

# Niveaux actifs par défaut : tous les niveaux
$niveauxActifs = @("Fournisseur", "Matière", "Fournisseur + Matière")
$avecMatieres  = $true

# Types de documents par défaut (utilisés si -ConfigPath n'est pas fourni)
$typesDocs = @(
    @{ Title="Certificat IFS/BRC/FSSC";  DureeValidite=365;  AlerteJ90=$true; AlerteJ30=$true; AlerteJ7=$true;  Obligatoire=$true;  NiveauRattachement="Fournisseur" },
    @{ Title="Fiche Technique";          DureeValidite=730;  AlerteJ90=$true; AlerteJ30=$true; AlerteJ7=$true;  Obligatoire=$true;  NiveauRattachement="Fournisseur + Matière" },
    @{ Title="Cahier des Charges";       DureeValidite=1095; AlerteJ90=$true; AlerteJ30=$true; AlerteJ7=$false; Obligatoire=$true;  NiveauRattachement="Matière" },
    @{ Title="Questionnaire fournisseur";DureeValidite=365;  AlerteJ90=$false;AlerteJ30=$true; AlerteJ7=$false; Obligatoire=$true;  NiveauRattachement="Fournisseur" },
    @{ Title="Déclaration allergènes";   DureeValidite=730;  AlerteJ90=$false;AlerteJ30=$true; AlerteJ7=$false; Obligatoire=$true;  NiveauRattachement="Fournisseur + Matière" },
    @{ Title="Déclaration OGM/Dioxine";  DureeValidite=365;  AlerteJ90=$false;AlerteJ30=$true; AlerteJ7=$false; Obligatoire=$false; NiveauRattachement="Fournisseur + Matière" },
    @{ Title="Analyse laboratoire";      DureeValidite=365;  AlerteJ90=$false;AlerteJ30=$true; AlerteJ7=$false; Obligatoire=$false; NiveauRattachement="Fournisseur + Matière" },
    @{ Title="Déclaration alimentarité"; DureeValidite=1825; AlerteJ90=$true; AlerteJ30=$false;AlerteJ7=$false; Obligatoire=$false; NiveauRattachement="Fournisseur + Matière" }
)

if ($ConfigPath -ne "") {
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Fichier de configuration introuvable : $ConfigPath"
        exit 1
    }
    Write-Step "⚙️  Chargement configuration client : $ConfigPath"
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    # Niveaux actifs — si la clé existe dans la config, on l'utilise
    if ($null -ne $config.PSObject.Properties['niveaux_actifs']) {
        $niveauxActifs = @($config.niveaux_actifs)
    }
    $avecMatieres = ($niveauxActifs -contains "Matière") -or ($niveauxActifs -contains "Fournisseur + Matière")

    # Conversion des types de documents depuis le JSON
    $typesDocs = @()
    foreach ($td in $config.types_documents) {
        # Normalisation du niveau : accepte "Fournisseur+Matière" ou "Fournisseur + Matière"
        $niveau = ($td.niveau -replace '\s*\+\s*', '+') -replace '\+', ' + '
        $typesDocs += @{
            Title              = $td.nom
            DureeValidite      = [int]$td.duree_validite_jours
            AlerteJ90          = [bool]$td.alerte_j90
            AlerteJ30          = [bool]$td.alerte_j30
            AlerteJ7           = [bool]$td.alerte_j7
            Obligatoire        = [bool]$td.obligatoire_approbation
            NiveauRattachement = $niveau.Trim()
        }
    }

    Write-OK "Config chargée : $($typesDocs.Count) types de documents"
    Write-OK "Niveaux de suivi actifs : $($niveauxActifs -join ', ')"
    if (-not $avecMatieres) {
        Write-Warn "Suivi Matière désactivé — Matieres_Premieres et Liens_Fourn_Mat ne seront pas créées"
    }
}


# ═══════════════════════════════════════════════════════════════════════════════
# LISTE 1 — Types_Documents
# Configuration des types de documents (durée, alertes, obligatoire…)
# ═══════════════════════════════════════════════════════════════════════════════
Write-Step "📋 [1/7] Création liste Types_Documents..."

New-PnPList -Title "Types_Documents" -Template GenericList -OnQuickLaunch | Out-Null

$colonnesTD = @(
    @{ DisplayName = "Durée validité (jours)";          InternalName = "DureeValidite";       Type = "Number"   },
    @{ DisplayName = "Niveau rattachement";              InternalName = "NiveauRattachement";   Type = "Choice";
       Choices = @("Fournisseur","Matière","Fournisseur + Matière") },
    @{ DisplayName = "Alerte J-90";                     InternalName = "AlerteJ90";            Type = "Boolean"  },
    @{ DisplayName = "Alerte J-30";                     InternalName = "AlerteJ30";            Type = "Boolean"  },
    @{ DisplayName = "Alerte J-7";                      InternalName = "AlerteJ7";             Type = "Boolean"  },
    @{ DisplayName = "Obligatoire pour approbation";    InternalName = "Obligatoire";          Type = "Boolean"  }
)
foreach ($col in $colonnesTD) {
    if ($col.Type -eq "Choice") {
        Add-PnPField -List "Types_Documents" -DisplayName $col.DisplayName `
            -InternalName $col.InternalName -Type Choice -Choices $col.Choices `
            -AddToDefaultView | Out-Null
    } else {
        Add-PnPField -List "Types_Documents" -DisplayName $col.DisplayName `
            -InternalName $col.InternalName -Type $col.Type `
            -AddToDefaultView | Out-Null
    }
}

foreach ($td in $typesDocs) {
    Add-PnPListItem -List "Types_Documents" -Values @{
        Title               = $td.Title
        DureeValidite       = $td.DureeValidite
        AlerteJ90           = $td.AlerteJ90
        AlerteJ30           = $td.AlerteJ30
        AlerteJ7            = $td.AlerteJ7
        Obligatoire         = $td.Obligatoire
        NiveauRattachement  = $td.NiveauRattachement
    } | Out-Null
}
Write-OK "Types_Documents créée + $($typesDocs.Count) types de documents chargés"


# ═══════════════════════════════════════════════════════════════════════════════
# LISTE 2 — Fournisseurs
# ═══════════════════════════════════════════════════════════════════════════════
Write-Step "🏢 [2/7] Création liste Fournisseurs..."

New-PnPList -Title "Fournisseurs" -Template GenericList -OnQuickLaunch | Out-Null

Add-PnPField -List "Fournisseurs" -DisplayName "Code fournisseur"       -InternalName "CodeFournisseur"     -Type Text    -AddToDefaultView | Out-Null
Add-PnPField -List "Fournisseurs" -DisplayName "Type"                   -InternalName "TypeFournisseur"     -Type Choice  -AddToDefaultView `
    -Choices @("Producteur","Broker","Négoce","Façonnier","Distributeur") | Out-Null
Add-PnPField -List "Fournisseurs" -DisplayName "Statut approbation"     -InternalName "StatutApprobation"   -Type Choice  -AddToDefaultView `
    -Choices @("En cours d'approbation","Approuvé","Suspendu","Disqualifié") | Out-Null
Add-PnPField -List "Fournisseurs" -DisplayName "Email contact qualité"  -InternalName "EmailContactQualite" -Type Text    -AddToDefaultView | Out-Null
Add-PnPField -List "Fournisseurs" -DisplayName "Score conformité (%)"   -InternalName "ScoreConformite"     -Type Number  -AddToDefaultView | Out-Null
Add-PnPField -List "Fournisseurs" -DisplayName "Pays"                   -InternalName "Pays"                -Type Text    | Out-Null
Add-PnPField -List "Fournisseurs" -DisplayName "Commentaires"           -InternalName "Commentaires"        -Type Note    | Out-Null

Write-OK "Fournisseurs créée"


# ═══════════════════════════════════════════════════════════════════════════════
# LISTE 3 — Matieres_Premieres  (créée uniquement si suivi Matière actif)
# ═══════════════════════════════════════════════════════════════════════════════
if ($avecMatieres) {
    Write-Step "📦 [3/7] Création liste Matieres_Premieres..."

    New-PnPList -Title "Matieres_Premieres" -Template GenericList -OnQuickLaunch | Out-Null

    Add-PnPField -List "Matieres_Premieres" -DisplayName "Code ressource"  -InternalName "CodeRessource" -Type Text   -AddToDefaultView | Out-Null
    Add-PnPField -List "Matieres_Premieres" -DisplayName "Catégorie"       -InternalName "Categorie"     -Type Choice -AddToDefaultView `
        -Choices @("Ingrédient","Emballage","Auxiliaire technologique","Arôme","Additif","Autre") | Out-Null
    Add-PnPField -List "Matieres_Premieres" -DisplayName "Criticité"       -InternalName "Criticite"     -Type Choice -AddToDefaultView `
        -Choices @("Haute","Moyenne","Faible") | Out-Null

    Write-OK "Matieres_Premieres créée"
} else {
    Write-Step "⏭  [3/7] Matieres_Premieres — ignorée (niveaux_actifs : Fournisseur uniquement)"
    Write-Skip "Suivi par matière désactivé pour ce client"
}


# ═══════════════════════════════════════════════════════════════════════════════
# LISTE 4 — Liens_Fourn_Mat  (créée uniquement si suivi Matière actif)
# Table de jonction Fournisseur × Matière
# ═══════════════════════════════════════════════════════════════════════════════
if ($avecMatieres) {
    Write-Step "🔗 [4/7] Création liste Liens_Fourn_Mat..."

    New-PnPList -Title "Liens_Fourn_Mat" -Template GenericList -OnQuickLaunch | Out-Null

    Add-PnPField -List "Liens_Fourn_Mat" -DisplayName "Fournisseur"      -InternalName "Fournisseur"    -Type Lookup `
        -LookupList "Fournisseurs" -LookupField "Title" -AddToDefaultView | Out-Null
    Add-PnPField -List "Liens_Fourn_Mat" -DisplayName "Matière première" -InternalName "MatierePremiere" -Type Lookup `
        -LookupList "Matieres_Premieres" -LookupField "Title" -AddToDefaultView | Out-Null
    Add-PnPField -List "Liens_Fourn_Mat" -DisplayName "Statut du lien"   -InternalName "StatutLien"     -Type Choice -AddToDefaultView `
        -Choices @("En approbation","Actif","Inactif","Suspendu") | Out-Null
    Add-PnPField -List "Liens_Fourn_Mat" -DisplayName "Référence OA"     -InternalName "RefOA"          -Type Text   | Out-Null

    Write-OK "Liens_Fourn_Mat créée"
} else {
    Write-Step "⏭  [4/7] Liens_Fourn_Mat — ignorée (niveaux_actifs : Fournisseur uniquement)"
    Write-Skip "Suivi par source Fournisseur×Matière désactivé pour ce client"
}


# ═══════════════════════════════════════════════════════════════════════════════
# LISTE 5 — Documents  (table centrale)
# ═══════════════════════════════════════════════════════════════════════════════
Write-Step "📄 [5/7] Création liste Documents (table centrale)..."

New-PnPList -Title "Documents" -Template GenericList -OnQuickLaunch | Out-Null
Set-PnPList -Identity "Documents" -EnableVersioning $true -MajorVersions 50 | Out-Null

# Colonnes lookup — Fournisseur et Type de document toujours présents
Add-PnPField -List "Documents" -DisplayName "Type de document" -InternalName "TypeDocument"  -Type Lookup -LookupList "Types_Documents" -LookupField "Title" -AddToDefaultView | Out-Null
Add-PnPField -List "Documents" -DisplayName "Fournisseur"      -InternalName "Fournisseur"   -Type Lookup -LookupList "Fournisseurs"     -LookupField "Title" -AddToDefaultView | Out-Null

# Colonnes lookup Matière — uniquement si suivi Matière actif
if ($avecMatieres) {
    Add-PnPField -List "Documents" -DisplayName "Matière première" -InternalName "MatierePremiere" -Type Lookup -LookupList "Matieres_Premieres" -LookupField "Title" | Out-Null
    Add-PnPField -List "Documents" -DisplayName "Lien Fourn×Mat"   -InternalName "LienFournMat"    -Type Lookup -LookupList "Liens_Fourn_Mat"    -LookupField "Title" | Out-Null
}

# Colonnes statut / dates
Add-PnPField -List "Documents" -DisplayName "Statut" -InternalName "Statut" -Type Choice -AddToDefaultView `
    -Choices @("Manquant","En attente de validation","Valide","Expire bientôt","Expiré","Obsolète") | Out-Null

Add-PnPField -List "Documents" -DisplayName "Date d'émission"     -InternalName "DateEmission"    -Type DateTime -AddToDefaultView | Out-Null
Add-PnPField -List "Documents" -DisplayName "Date d'expiration"   -InternalName "DateExpiration"  -Type DateTime -AddToDefaultView | Out-Null
Add-PnPField -List "Documents" -DisplayName "Date de réception"   -InternalName "DateReception"   -Type DateTime | Out-Null
Add-PnPField -List "Documents" -DisplayName "Date de validation"  -InternalName "DateValidation"  -Type DateTime | Out-Null
Add-PnPField -List "Documents" -DisplayName "Validé par"          -InternalName "ValidePar"       -Type User     | Out-Null
Add-PnPField -List "Documents" -DisplayName "Conformité"          -InternalName "Conformite"      -Type Choice -AddToDefaultView `
    -Choices @("Conforme","Non conforme","En attente") | Out-Null

# Colonnes versioning
Add-PnPField -List "Documents" -DisplayName "Version"             -InternalName "Version"         -Type Number  -AddToDefaultView | Out-Null
Add-PnPField -List "Documents" -DisplayName "Document courant"    -InternalName "DocumentCourant" -Type Boolean -AddToDefaultView | Out-Null
Add-PnPField -List "Documents" -DisplayName "Lien vers fichier"   -InternalName "LienFichier"     -Type URL     | Out-Null
Add-PnPField -List "Documents" -DisplayName "Commentaires"        -InternalName "Commentaires"    -Type Note    | Out-Null

# ─── Vues filtrées ────────────────────────────────────────────────────────────
$vueExpires = @"
<View><Query><Where><And>
  <Eq><FieldRef Name='DocumentCourant'/><Value Type='Boolean'>1</Value></Eq>
  <Eq><FieldRef Name='Statut'/><Value Type='Choice'>Expiré</Value></Eq>
</And></Where><OrderBy><FieldRef Name='DateExpiration'/></OrderBy></Query></View>
"@

$vueSoon = @"
<View><Query><Where><And>
  <Eq><FieldRef Name='DocumentCourant'/><Value Type='Boolean'>1</Value></Eq>
  <Eq><FieldRef Name='Statut'/><Value Type='Choice'>Expire bientôt</Value></Eq>
</And></Where><OrderBy><FieldRef Name='DateExpiration'/></OrderBy></Query></View>
"@

$vuePending = @"
<View><Query><Where>
  <Eq><FieldRef Name='Statut'/><Value Type='Choice'>En attente de validation</Value></Eq>
</Where><OrderBy><FieldRef Name='DateReception' Ascending='FALSE'/></OrderBy></Query></View>
"@

Add-PnPView -List "Documents" -Title "Expirés"              -Query $vueExpires `
    -Fields @("Title","Fournisseur","TypeDocument","DateExpiration","Statut","Conformite") | Out-Null
Add-PnPView -List "Documents" -Title "Expire bientôt"       -Query $vueSoon `
    -Fields @("Title","Fournisseur","TypeDocument","DateExpiration","Statut") | Out-Null
Add-PnPView -List "Documents" -Title "En attente validation" -Query $vuePending `
    -Fields @("Title","Fournisseur","TypeDocument","DateReception","LienFichier") | Out-Null

Write-OK "Documents créée (colonnes + 3 vues filtrées)"


# ═══════════════════════════════════════════════════════════════════════════════
# LISTE 6 — Analyse_Fraude  (accès restreint)
# ═══════════════════════════════════════════════════════════════════════════════
Write-Step "🔒 [6/7] Création liste Analyse_Fraude (accès restreint)..."

New-PnPList -Title "Analyse_Fraude" -Template GenericList | Out-Null
# Pas sur QuickLaunch — liste confidentielle

# Lien de rattachement : Fourn×Mat si disponible, sinon Fournisseur seul
if ($avecMatieres) {
    Add-PnPField -List "Analyse_Fraude" -DisplayName "Lien Fourn×Mat" -InternalName "LienFournMat" -Type Lookup `
        -LookupList "Liens_Fourn_Mat" -LookupField "Title" -AddToDefaultView | Out-Null
} else {
    Add-PnPField -List "Analyse_Fraude" -DisplayName "Fournisseur" -InternalName "Fournisseur" -Type Lookup `
        -LookupList "Fournisseurs" -LookupField "Title" -AddToDefaultView | Out-Null
}

Add-PnPField -List "Analyse_Fraude" -DisplayName "Paramètre analysé"      -InternalName "ParametreAnalyse"  -Type Text   -AddToDefaultView | Out-Null
Add-PnPField -List "Analyse_Fraude" -DisplayName "Score historique (0-5)" -InternalName "ScoreHistorique"   -Type Number -AddToDefaultView | Out-Null
Add-PnPField -List "Analyse_Fraude" -DisplayName "Score marché (0-5)"     -InternalName "ScoreMarche"       -Type Number -AddToDefaultView | Out-Null
Add-PnPField -List "Analyse_Fraude" -DisplayName "Score origine (0-5)"    -InternalName "ScoreOrigine"      -Type Number -AddToDefaultView | Out-Null
Add-PnPField -List "Analyse_Fraude" -DisplayName "Score produit (0-5)"    -InternalName "ScoreProduit"      -Type Number -AddToDefaultView | Out-Null
Add-PnPField -List "Analyse_Fraude" -DisplayName "Probabilité fraude"     -InternalName "ProbabiliteFraude" -Type Choice -AddToDefaultView `
    -Choices @("Improbable","Possible","Probable") | Out-Null
Add-PnPField -List "Analyse_Fraude" -DisplayName "Note criticité"         -InternalName "NoteCriticite"     -Type Choice -AddToDefaultView `
    -Choices @("A - Prioritaire","B - Surveillance","C - Standard") | Out-Null
Add-PnPField -List "Analyse_Fraude" -DisplayName "Commentaires"           -InternalName "Commentaires"      -Type Note   | Out-Null

# Couper l'héritage — plus personne n'a accès par défaut
Set-PnPList -Identity "Analyse_Fraude" -BreakRoleInheritance -ClearSubscopes | Out-Null

Write-OK "Analyse_Fraude créée (permissions héritées coupées)"
Write-Warn "Ajoutez manuellement les groupes Qualité/Achats dans Paramètres > Autorisations"


# ═══════════════════════════════════════════════════════════════════════════════
# BIBLIOTHÈQUE — Documents_Fichiers
# Stockage physique des fichiers (PDF, Word, Excel…)
# ═══════════════════════════════════════════════════════════════════════════════
Write-Step "📁 [7/7] Création bibliothèque Documents_Fichiers..."

New-PnPList -Title "Documents_Fichiers" -Template DocumentLibrary -OnQuickLaunch | Out-Null
Set-PnPList -Identity "Documents_Fichiers" -EnableVersioning $true -MajorVersions 50 | Out-Null

Write-OK "Documents_Fichiers créée (versioning 50 versions actif)"


# ═══════════════════════════════════════════════════════════════════════════════
# RÉCAPITULATIF
# ═══════════════════════════════════════════════════════════════════════════════
$listesCreees = "Types_Documents · Fournisseurs"
if ($avecMatieres) { $listesCreees += " · Matieres_Premieres · Liens_Fourn_Mat" }
$listesCreees += " · Documents · Analyse_Fraude"

$niveauxLabel = $niveauxActifs -join ' · '

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host " ✅  Déploiement FRS terminé avec succès !" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host " Site       : $SiteUrl" -ForegroundColor White
Write-Host " Listes     : $listesCreees" -ForegroundColor White
Write-Host " Biblio     : Documents_Fichiers" -ForegroundColor White
Write-Host " Vues       : 3 vues filtrées dans Documents" -ForegroundColor White
Write-Host " Types docs : $($typesDocs.Count) types chargés" -ForegroundColor White
Write-Host " Niveaux    : $niveauxLabel" -ForegroundColor White
if ($ConfigPath -ne "") {
Write-Host " Config     : $ConfigPath" -ForegroundColor White
}
Write-Host ""
Write-Host " ⚠️  Étapes manuelles restantes :" -ForegroundColor Yellow
Write-Host "    1. Configurer les permissions de la liste Analyse_Fraude" -ForegroundColor Yellow
Write-Host "    2. Importer les 7 flux Power Automate (dossier scripts/automate/flows/)" -ForegroundColor Yellow
if (-not $avecMatieres) {
Write-Host "       → Flux 7 (Init checklist lien) non nécessaire — suivi Matière inactif" -ForegroundColor DarkYellow
}
Write-Host "    3. Charger les données Fournisseurs et Matières (depuis l'Excel client)" -ForegroundColor Yellow
Write-Host "    4. Personnaliser les alertes email (adresses destinataires dans les flows)" -ForegroundColor Yellow
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green

Disconnect-PnPOnline
