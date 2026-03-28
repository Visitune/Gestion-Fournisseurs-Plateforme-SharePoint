# Flux : Portail fournisseur — Dépôt de documents par email

## Contexte

Ce flux implémente l'**Option A** du portail fournisseur (Phase 1) :
- Le fournisseur reçoit un email avec un lien sécurisé
- Il dépose son document via un formulaire SharePoint (sans créer de compte)
- Le service Qualité est notifié à réception

---

## Architecture du portail (sans Power Apps, sans licence premium)

```
[Liste SharePoint : Demandes_Documents]
    ↓
    ├── ID unique par demande
    ├── Fournisseur, Matière, Type document
    ├── Lien de dépôt (URL unique)
    └── Statut : En attente / Reçu / Validé

[Bibliothèque : Depot_Fournisseurs]
    ├── Dossier par fournisseur
    └── Documents déposés (en attente de traitement)

[Flux 1 : Envoi de la demande]
    Déclencheur : Manuel (depuis la fiche fournisseur)
    Action : Créer une Demande, envoyer email avec lien

[Flux 2 : Réception du document]
    Déclencheur : Nouveau fichier dans Depot_Fournisseurs
    Action : Notifier Qualité, créer entrée en attente dans Documents
```

---

## FLUX 1 : Envoi de la demande de dépôt

### Déclencheur
- Type : **Pour un élément sélectionné** (SharePoint)
- Liste : `Fournisseurs`

### Étape 1 — Créer la demande dans la liste `Demandes_Documents`

> Créer d'abord la liste `Demandes_Documents` dans SharePoint avec les colonnes :
>
> | Colonne | Type |
> |---|---|
> | Title | Texte (ID unique = GUID généré) |
> | Fournisseur | Lookup → Fournisseurs |
> | TypeDocument | Lookup → Types_Documents |
> | Matiere | Lookup → Matieres_Premieres (optionnel) |
> | StatutDemande | Choix : En attente / Reçu / Annulé |
> | DateDemande | DateTime |
> | LienDepot | URL |
> | Commentaire | Note |

```
Action : Ajouter un élément (SharePoint)
Liste  : Demandes_Documents
Valeurs :
  Title         = guid()   ← expression Power Automate
  Fournisseur   = ID du fournisseur sélectionné
  StatutDemande = "En attente"
  DateDemande   = utcNow()
```

### Étape 2 — Générer le lien de dépôt

Le lien pointe vers un formulaire SharePoint de la liste `Demandes_Documents`
en mode "Nouveau formulaire" pré-rempli :

```
URL_DEPOT = https://[TENANT].sharepoint.com/sites/[SITE]/Lists/Demandes_Documents/
            NewForm.aspx?ID=[ID_DEMANDE]&Source=[URL_RETOUR]
```

Pour une sécurité renforcée, utiliser un lien partagé avec expiration :
```
Action : Créer un lien de partage (SharePoint)
→ Type : Modification anonyme
→ Expiration : 30 jours
→ Pointer vers le dossier fournisseur dans Depot_Fournisseurs
```

### Étape 3 — Envoyer l'email au fournisseur

```
Action : Envoyer un e-mail (V2) — Outlook
À      : [Email contact qualité du fournisseur]
CC     : [Email Qualité interne] ; [Email Achats interne]
Sujet  : [ACTION REQUISE] Documents qualité à déposer — [Nom Fournisseur]
Corps  : Template relance_fournisseur.html
         (injecter le lien de dépôt généré à l'étape 2)
```

---

## FLUX 2 : Réception d'un document déposé par le fournisseur

### Déclencheur
- Type : **Lorsqu'un fichier est créé** (SharePoint)
- Bibliothèque : `Depot_Fournisseurs`
- Dossier : _(tous les sous-dossiers)_

### Étape 1 — Notifier le service Qualité

```
Action : Envoyer un e-mail
À      : [Email Qualité interne]
Sujet  : [NOUVEAU DÉPÔT] Document reçu de [Nom dossier] — [Nom fichier]
Corps  :
  Un document a été déposé par le fournisseur.
  Fichier   : [Nom fichier]
  Fournisseur : [Nom du dossier parent]
  Déposé le : [Date]
  [Lien direct vers le fichier dans SharePoint]

  → Aller dans la liste Documents pour créer l'entrée et valider.
```

### Étape 2 — Créer une entrée "En attente de validation" dans la liste Documents

```
Action : Ajouter un élément (SharePoint)
Liste  : Documents
Valeurs :
  Title            = Nom du fichier
  Statut           = "En attente de validation"
  Source           = "Envoi fournisseur"
  URLFichier       = URL du fichier déposé
  DateReception    = utcNow()
  EstCourant       = true
  Version          = 1
```

### Étape 3 — Mettre à jour la demande associée (optionnel)

Si le fichier est lié à une demande tracée dans `Demandes_Documents` :
```
Action : Mettre à jour un élément
Liste  : Demandes_Documents
Valeur : StatutDemande = "Reçu"
```

---

## OPTION B (Phase 2) : Portail guest SharePoint

Pour les clients qui souhaitent un vrai portail en temps réel :

### Configuration Azure AD B2B

1. Dans le portail Azure → **Azure Active Directory** → **External Identities**
2. Activer les invitations guest
3. Configurer les domaines autorisés (optionnel — liste blanche des domaines fournisseurs)

### Inviter un fournisseur

```powershell
# Via PowerShell ou dans le portail Azure
New-AzureADMSInvitation `
    -InvitedUserEmailAddress "contact@fournisseur.com" `
    -InviteRedirectUrl "https://TENANT.sharepoint.com/sites/SITE/SitePages/Portail-Fournisseur.aspx" `
    -SendInvitationMessage $true
```

### Permissions à configurer

Le compte guest doit avoir accès **uniquement** à :
- La vue filtrée sur son propre code fournisseur (SharePoint audience targeting)
- Son dossier dans la bibliothèque `Depot_Fournisseurs`

**Important** : ne jamais donner accès "Lecture" sur toute la liste Fournisseurs
sans filtrage — utiliser les groupes SharePoint et les permissions au niveau de l'élément.

### Filtrage de la vue par l'identité du guest

Dans la page portail fournisseur, utiliser une web part Liste SharePoint
avec filtre dynamique :
```
Filtre : EmailQualite = [Me]
```
ou passer par une Power App (Phase 2) qui filtre par l'email de l'utilisateur connecté.
