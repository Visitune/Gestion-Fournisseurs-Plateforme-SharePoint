# Flux : Portail fournisseur — Dépôt via Microsoft Forms

## Informations générales

| Champ | Valeur |
|---|---|
| Nom | FRS — Portail fournisseur (Forms) |
| Déclencheur | Microsoft Forms — à chaque nouvelle réponse |
| Connecteurs | Microsoft Forms, OneDrive Entreprise, SharePoint, Office 365 Outlook |
| Licence requise | Standard (incluse M365) |

---

## Architecture (Phase 1 — sans compte fournisseur)

```
[Microsoft Forms — Formulaire de dépôt]
    ↓ trigger : nouvelle réponse
[Flux Power Automate]
    ├── 1. Récupère les détails de la réponse Forms
    ├── 2. Extrait le fichier joint (OneDrive du créateur du form)
    ├── 3. Résout les IDs SharePoint : Fournisseur, TypeDocument, MatierePremiere
    ├── 4. Copie le fichier → Documents_Fichiers/<TypeDocument>/<nomFichier>
    ├── 5. Crée un item Documents (Statut = "En attente de validation")
    │       → déclenche automatiquement le Flux 4 (versioning + notification Qualité)
    └── 6. Envoie un email de confirmation au fournisseur
```

---

## Formulaire Microsoft Forms à créer

| Question | Type | Variable |
|---|---|---|
| Q1 — Code fournisseur | Texte court (obligatoire) | `answers/0/answer` |
| Q2 — Type de document | Liste déroulante (obligatoire) | `answers/1/answer` |
| Q3 — Matière première concernée | Texte court (optionnel) | `answers/2/answer` |
| Q4 — Date d'émission du document | Date (obligatoire) | `answers/3/answer` |
| Q5 — Fichier à déposer | Upload de fichier (obligatoire) | `answers/4/answer/name` |

---

## Construction dans Power Automate

### Déclencheur
- Type : **Quand une réponse est soumise** (Microsoft Forms)
- Paramètre : ID du formulaire (`VOTRE_FORM_ID`)

### Étape 1 — Obtenir les détails de la réponse
- Action : **Obtenir les détails de la réponse** (Microsoft Forms)
- Form ID : `VOTRE_FORM_ID`
- Response ID : `triggerBody()?['resourceData/responseId']`

### Étape 2 — Extraire le contenu du fichier (OneDrive)
- Action : **Obtenir le contenu d'un fichier** (OneDrive Entreprise)
- Path : `outputs('Obtenir_details_reponse')?['body/answers/4/answer/id']`

### Étape 3 — Résoudre les IDs (3 appels SharePoint parallèles)

**Chercher_fournisseur** — GetItems sur `Fournisseurs` :
```
$filter = CodeFournisseur eq '[answers/0/answer]'
```

**Chercher_type_document** — GetItems sur `Types_Documents` :
```
$filter = Title eq '[answers/1/answer]'
```

**Chercher_matiere** — GetItems sur `Matieres_Premieres` :
```
$filter = Title eq '[answers/2/answer]'
```

### Étape 4 — Construire le nom de fichier (variable `nomFichier`)
```
[TypeDoc]_[Matière]_[DateEmission]_[NomFichierOriginal]
= answers/1/answer _ answers/2/answer _ answers/3/answer _ answers/4/answer/name
```

### Étape 5 — Copier le fichier dans Documents_Fichiers
- Destination : `LIBRARY_NAME/[TypeDocument]/[nomFichier]`

### Étape 6 — Créer l'item dans la liste Documents
| Champ | Valeur |
|---|---|
| Title | `@variables('nomFichier')` |
| Statut | `En attente de validation` |
| DateEmission | `answers/3/answer` |
| DateReception | `utcNow()` |
| DocumentCourant | `true` |
| FournisseurId | `first(Chercher_fournisseur.body.value).ID` |
| TypeDocumentId | `first(Chercher_type_document.body.value).ID` |
| MatierePremiereId | `first(Chercher_matiere.body.value).ID` (null si non trouvée) |
| LienFichier | URL du fichier copié |
| Commentaires | `Déposé via portail le [date] par [email répondant]` |

> **Note** : la création de cet item déclenche automatiquement le Flux 4 (archivage des versions précédentes + notification Qualité).

### Étape 7 — Confirmer au fournisseur
- Action : **Envoyer un e-mail (V2)** — Office 365 Outlook
- À : `responderEmailAddress` (email du répondant Forms)
- CC : `EMAIL_QUALITE`
- Confirmation de réception avec récapitulatif code fournisseur / type / fichier

---

## Configuration requise après import

| Paramètre | Où le trouver |
|---|---|
| `VOTRE_FORM_ID` | URL du formulaire Forms → après `/forms/` |
| `VOTRE_SITE_URL` | URL du site SharePoint |
| `LIST_GUID_DOCUMENTS` | SP → Paramètres liste Documents → URL |
| `LIST_GUID_FOURNISSEURS` | SP → Paramètres liste Fournisseurs → URL |
| `LIST_GUID_TYPES_DOCUMENTS` | SP → Paramètres liste Types_Documents → URL |
| `LIST_GUID_MATIERES_PREMIERES` | SP → Paramètres liste Matieres_Premieres → URL |
| `LIBRARY_NAME` | `Documents_Fichiers` |
| `EMAIL_QUALITE` | Email équipe Qualité interne |

---

## Option B — Phase 2 : portail guest Azure AD B2B

Si le client veut un portail temps réel avec authentification fournisseur :
1. Activer les invitations guest dans Azure Active Directory → External Identities
2. Inviter chaque fournisseur avec `New-AzureADMSInvitation`
3. Créer une page SharePoint "Portail Fournisseur" avec audience targeting (filtre sur `EmailContactQualite eq [Me]`)
4. Donner accès uniquement au dossier fournisseur dans `Documents_Fichiers`
