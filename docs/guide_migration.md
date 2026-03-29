# Guide de migration — Serveur fichiers + Excel → SharePoint

## Vue d'ensemble

La migration se déroule en 4 étapes :

```
ÉTAPE 1 : Audit & préparation
ÉTAPE 2 : Déploiement SharePoint (script Deploy-FRS.ps1)
ÉTAPE 3 : Migration des documents physiques (script GenerateurBaseFournisseur.ps1)
ÉTAPE 4 : Import des données dans SharePoint (via PnP PowerShell + CSV généré)
```

Durée estimée : 1 à 3 jours selon le volume documentaire.

---

## ÉTAPE 1 — AUDIT & PRÉPARATION

### 1.1 Inventaire du dossier serveur

Exécuter depuis PowerShell pour obtenir un inventaire :

```powershell
# Compter les fichiers par extension
Get-ChildItem "C:\Chemin\Serveur\Fournisseurs" -Recurse -File |
    Group-Object Extension |
    Sort-Object Count -Descending |
    Select-Object Name, Count |
    Format-Table

# Compter les fichiers par sous-dossier (niveau 1)
Get-ChildItem "C:\Chemin\Serveur\Fournisseurs" -Directory |
    ForEach-Object {
        [PSCustomObject]@{
            Fournisseur  = $_.Name
            NbFichiers   = (Get-ChildItem $_.FullName -Recurse -File).Count
            TailleTotal  = "{0:N1} Mo" -f ((Get-ChildItem $_.FullName -Recurse -File |
                Measure-Object -Property Length -Sum).Sum / 1MB)
        }
    } | Format-Table
```

### 1.2 Analyse du fichier Excel

Vérifier et nettoyer l'Excel avant conversion en CSV :

1. **Supprimer** les lignes d'en-tête multiples ou les lignes de titre fusionnées
2. **Normaliser** les dates : toutes au format `dd/MM/yyyy` (éviter les textes "N/A" ou tirets)
3. **Vérifier** le format fournisseur : doit être `CODE : NOM` (ex: `1107 : NACTIS`)
4. **Identifier** les colonnes présentes vs les champs de la liste Documents dans SharePoint
5. **Adapter** la règle `$DetectionRules` dans `GenerateurBaseFournisseur.ps1` si les patterns de nommage diffèrent

### 1.3 Conversion Excel → CSV

Dans Excel :
1. **Fichier** → **Enregistrer sous**
2. Type : **CSV UTF-8 (délimité par des virgules)**
   > `GenerateurBaseFournisseur.ps1` produit un CSV avec ";" comme séparateur (compatible Excel français)
3. Enregistrer dans le dossier de travail sous `suivi_fournisseurs.csv`

### 1.4 Exporter les listes SharePoint de référence

Si le SharePoint est déjà partiellement peuplé :

1. Sur SharePoint → liste **Fournisseurs** → **Exporter** → CSV → sauver `Fournisseurs.csv`
2. Sur SharePoint → liste **Matieres_Premieres** → **Exporter** → CSV → sauver `Matieres_Premieres.csv`

---

## ÉTAPE 2 — DÉPLOIEMENT SHAREPOINT

### Prérequis

```powershell
# Installer PnP PowerShell (une seule fois par machine)
Install-Module PnP.PowerShell -Scope CurrentUser -Force

# Vérifier l'installation
Get-Module PnP.PowerShell -ListAvailable | Select-Object Name, Version
```

### Adapter la configuration client

1. Copier `config\client_config_template.json` → `config\CLIENT_NOM.json`
2. Renseigner :
   - `client.sharepoint_url` : URL exacte du site SharePoint
   - `client.nom` et `client.code`
   - `alertes.email_qualite` et `alertes.email_achats`
   - `types_documents` : adapter selon les documents utilisés par ce client

### Exécuter le provisioning

```powershell
cd "C:\...\PROJET SHAREPOINT FRS\scripts"

# Exécution réelle
.\Deploy-FRS.ps1 -SiteUrl "https://TENANT.sharepoint.com/sites/NOM_SITE" -ClientId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Vérification post-déploiement

Après le script, vérifier dans SharePoint :
- [ ] Liste `Types_Documents` créée et peuplée avec les types configurés
- [ ] Liste `Fournisseurs` créée avec toutes les colonnes
- [ ] Liste `Matieres_Premieres` créée
- [ ] Liste `Liens_Fourn_Mat` créée avec les lookups
- [ ] Liste `Documents` créée avec les lookups
- [ ] Liste `Analyse_Fraude` créée
- [ ] Bibliothèque `Documents_Fichiers` créée

---

## ÉTAPE 3 — MIGRATION DOCUMENTS PHYSIQUES

### Principe

Le script `GenerateurBaseFournisseur.ps1` traite un fournisseur à la fois.
Répéter l'opération pour chaque fournisseur.

### Exécution par fournisseur

```powershell
cd "C:\...\PROJET SHAREPOINT FRS"

# Migration réelle
.\GenerateurBaseFournisseur.ps1 `
    -SupplierRoot "C:\Serveur\Fournisseurs\NACTIS" `
    -SupplierCode "1107" `
    -MasterFourn ".\Fournisseurs.csv" `
    -MasterMat ".\Matieres_Premieres.csv" `
    -SharePointBase "https://TENANT.sharepoint.com/sites/NOM_SITE/Documents_Fichiers" `
    -OutputDir ".\"
```

### Résultats générés

Le script crée un dossier `Export_1107` contenant :

```
Export_1107/
├── FT/
│   └── 1107_NACTIS_FT_02145_20260101_FicheTech_OrFleur.pdf
├── CERTIFICATS/
│   └── 1107_NACTIS_CERT_GFSI_20260101_FSSC22000.pdf
├── QUESTIONNAIRES/
│   ├── 1107_NACTIS_EN_ACHAT_001_20260101_QuestFourn.pdf
│   └── ...
├── DIVERS/
│   └── (fichiers non classifiés — à vérifier)
└── Rapport_1107.txt
```

### Traitement des fichiers non classifiés

Les fichiers dans le dossier `DIVERS/` n'ont pas été reconnus automatiquement.
Options :
1. **Les renommer** en incluant un mot-clé reconnu (FT, CERT, CDC, etc.)
2. **Les reclasser manuellement** dans le bon sous-dossier
3. **Ajouter une règle** dans `$DetectionRules` du script si le pattern est récurrent

### Compléter les dates d'expiration manquantes

Ouvrir le fichier `Base_<SupplierCode>.csv` généré et compléter la colonne `Date_Validite` pour les documents où elle n'a pas pu être calculée (colonne vide = document sans date connue).

---

## ÉTAPE 4 — IMPORT DONNÉES EXCEL

### Test préalable (DryRun)

```powershell
# Vérifier d'abord le contenu du CSV de rapport généré par GenerateurBaseFournisseur.ps1
# (fichier Base_<SupplierCode>.csv dans le dossier de sortie)
Import-Csv ".\Base_1107.csv" | Format-Table -AutoSize | Out-Host -Paging
```

Vérifier le fichier `Base_<SupplierCode>.csv` généré :
- [ ] Noms fournisseurs corrects
- [ ] Codes matières corrects
- [ ] Dates parsées correctement (pas de "null" là où une date est attendue)
- [ ] Types de documents détectés

### Adapter le mapping si nécessaire

Si les noms de colonnes du CSV client diffèrent, modifier `$DetectionRules` dans `GenerateurBaseFournisseur.ps1`.

### Import réel

```powershell
# Upload des fichiers physiques et CSV vers SharePoint via PnP PowerShell
# (les fichiers ont déjà été organisés par GenerateurBaseFournisseur.ps1 dans Export_<SupplierCode>/)
Add-PnPFile -Path ".\Export_1107\*.pdf" `
    -Folder "Documents_Fichiers" `
    -Connection (Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId -ReturnConnection)
```

---

## ÉTAPE 5 — VALIDATION POST-MIGRATION

### Checklist de contrôle

Avec le client, vérifier un échantillon de fournisseurs :

- [ ] Le nombre de fournisseurs dans SharePoint correspond à l'Excel
- [ ] Le nombre de matières correspond
- [ ] Les documents physiques sont bien uploadés dans la bibliothèque
- [ ] Les URLs dans la liste Documents pointent vers les bons fichiers
- [ ] Les statuts (Valide / Expiré / Obsolète) sont cohérents avec les dates
- [ ] Les données fraude sont présentes pour les paires Fourn×Mat concernées

### Mise à jour des URLs

Après upload des fichiers dans la bibliothèque, mettre à jour le champ `URLFichier`
dans la liste Documents pour chaque document migré.

Option rapide : utiliser la vue grille (Edit in grid view) dans SharePoint pour
coller les URLs en masse.

### Formation utilisateurs

Organiser une session de 1h-2h avec le client :
1. Présentation du tableau de bord
2. Ajout d'un nouveau document (démo)
3. Validation d'un document (démo)
4. Relance d'un fournisseur (démo)
5. Consultation de l'historique
6. Remettre le guide utilisateur

---

## TROUBLESHOOTING

### "Accès refusé" lors du provisioning
→ Vérifier que le compte utilisé est **Administrateur de site** sur le site SharePoint cible.

### Dates mal parsées dans l'import Excel
→ Vérifier le format des dates dans le CSV. Certaines versions Excel exportent `01/01/2025`,
d'autres `1/1/2025`. Ajouter le format manquant dans la fonction `Parse-Date`.

### Lookup non créé dans la liste Documents
→ Les lookups nécessitent que la liste cible soit créée d'abord.
Vérifier que `Deploy-FRS.ps1` a bien créé toutes les listes dans le bon ordre.

### Upload échoue pour un fichier
→ Vérifier que le nom de fichier ne contient pas de caractères spéciaux (`#`, `%`, `&`).
Le script de migration normalise les noms — relancer sur le fichier problématique.

### Module PnP.PowerShell non trouvé
```powershell
Install-Module PnP.PowerShell -Scope CurrentUser -Force -AllowClobber
Import-Module PnP.PowerShell
```
