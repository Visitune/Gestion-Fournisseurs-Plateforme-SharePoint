# Flux : Relance fournisseur manuelle

## Informations générales

| Champ | Valeur |
|---|---|
| Nom | FRS — Relance fournisseur |
| Déclencheur | Manuel — depuis une fiche Fournisseur SharePoint |
| Connecteurs | SharePoint, Office 365 Outlook |
| Licence requise | Standard (incluse M365) |

---

## Logique métier

```
Déclenchement : clic sur bouton "Relancer ce fournisseur"
  dans la vue Fournisseurs (SharePoint)

1. Récupérer l'ID du fournisseur sélectionné
2. Récupérer les infos du fournisseur (nom, email contact qualité)
3. Rechercher tous les documents actifs de ce fournisseur
   où Statut = "Expiré" OU Statut = "Manquant" OU Statut = "Expire bientôt"
4. Construire un tableau HTML avec la liste des documents
5. Envoyer email au fournisseur (et en copie à Qualité + Achats)
6. Créer un enregistrement de relance dans la liste Relances
```

---

## Construction dans Power Automate

### Déclencheur
- Type : **Flux de bouton** ou **Déclencher un flux pour un élément sélectionné**
- Liste source : `Fournisseurs`
- Paramètre d'entrée : ID de l'élément sélectionné

> **Comment déclencher depuis SharePoint** :
> Dans la vue Fournisseurs → Sélectionner un fournisseur → Menu **Automatiser**
> → le flux apparaît dans la liste des actions disponibles.

### Étape 1 — Obtenir la fiche fournisseur
- Action : **Obtenir un élément** (SharePoint)
- Liste : `Fournisseurs`, ID : `triggerBody()?['entity']?['ID']`

### Étape 2 — Obtenir les documents à renouveler de ce fournisseur
- Action : **Obtenir des éléments** (SharePoint) — Liste `Documents`
- Filtre ODATA :
  ```
  FournisseurLookupId eq [ID_Fournisseur]
  and EstCourant eq 1
  and (Statut eq 'Expiré' or Statut eq 'Manquant' or Statut eq 'Expire bientôt')
  ```
- Développer : `TypeDocument/Title,TypeDocument/DureeValiditeJours,Matiere/Title`

### Étape 3 — Construire le tableau HTML
- Action : **Créer une table HTML** à partir du résultat
- Colonnes à afficher :
  ```
  Type de document  → items()?['TypeDocument/Title']
  Matière           → items()?['Matiere/Title']
  Statut            → items()?['Statut']
  Expiration        → formatDateTime(items()?['DateExpiration'], 'dd/MM/yyyy')
  ```

### Étape 4 — Envoyer l'email
- Action : **Envoyer un e-mail (V2)** — Office 365 Outlook
- À : `outputs('Get_Fournisseur')?['body/EmailQualite']`
- CC : `[EMAIL_QUALITE_INTERNE]` ; `[EMAIL_ACHATS_INTERNE]`
- Sujet :
  ```
  [ACTION REQUISE] Documents à mettre à jour — @{outputs('Get_Fournisseur')?['body/Title']}
  ```
- Corps : voir template `relance_fournisseur.html`
- Inclure le tableau HTML de l'étape 3

### Étape 5 — Enregistrer la relance (optionnel)
Créer une liste SharePoint `Relances` (simple) pour tracer les relances envoyées :
```
- ID_Fournisseur (lookup)
- Date_Relance
- Envoyé_Par
- Nb_Documents_Concernés
- Commentaire
```

---

## Flux complémentaire : flow_nouveau_document.md

À chaque nouvel upload de document dans la liste `Documents` :

```
Déclencheur : Création d'un élément dans la liste Documents

1. Récupérer TypeDocument + Fournisseur + Matiere + LienFournMat du nouveau document
2. Rechercher l'ancien document courant de même type pour la même entité :
   Filtre : TypeDocument = [même] ET [même entité] ET EstCourant = 1 ET ID ≠ [nouveau]
3. Si trouvé :
   → Mettre à jour l'ancien : EstCourant = Non, Statut = "Obsolète"
   → Incrémenter Version du nouveau = ancien.Version + 1
4. Notifier Qualité : "Nouveau document reçu — en attente de validation"
```
