# Flux 7 — Initialisation checklist documentaire (nouveau lien Fournisseur×Matière)

## Informations générales

| Champ | Valeur |
|---|---|
| Nom | FRS — Init checklist lien Fourn×Mat |
| Déclencheur | Automatique — création d'un item dans `Liens_Fourn_Mat` |
| Connecteurs | SharePoint |
| Licence requise | Standard (incluse M365) |
| Flux complémentaire | Flux 6 — Init checklist fournisseur |

---

## Rôle métier

Quand une nouvelle source d'approvisionnement est créée (un fournisseur est associé à une matière première), ce flux génère automatiquement les items `Statut = Manquant` pour tous les types de documents obligatoires de niveau **Matière** ou **Fournisseur + Matière**.

---

## Logique métier

```
Déclenchement : création d'un item dans Liens_Fourn_Mat

1. Récupérer tous les Types_Documents où :
   (NiveauRattachement = "Matière" OU NiveauRattachement = "Fournisseur + Matière")
   ET Obligatoire = Oui

2. Pour chaque type :
   Vérifier si un document courant existe déjà
   (FournisseurId + MatierePremiereId + TypeDocumentId + DocumentCourant = true)

3. Si absent → créer item Documents :
   - Title             = "[TypeDocument] — [Fournisseur] / [Matière]"
   - Statut            = "Manquant"
   - TypeDocumentId    = ID du type
   - FournisseurId     = FournisseurId du lien
   - MatierePremiereId = MatierePremiereId du lien
   - LienFournMatId    = ID du lien (pour traçabilité)
   - DocumentCourant   = true
   - Version           = 0
   - Conformite        = "En attente"
```

---

## Construction dans Power Automate

### Déclencheur
- Type : **Quand un élément est créé** (`GetOnNewItems`) — polling toutes les minutes
- Liste : `Liens_Fourn_Mat`

### Étape 1 — Obtenir les types de niveau Matière / Fourn+Mat
- Action : **Obtenir des éléments** — Liste `Types_Documents`
- Filtre ODATA :
  ```
  (NiveauRattachement eq 'Matière' or NiveauRattachement eq 'Fournisseur + Matière')
  and Obligatoire eq 1
  ```
- Sélectionner : `ID,Title,DureeValidite,NiveauRattachement`

### Étape 2 — Boucle sur chaque type

### Étape 3 (dans la boucle) — Vérifier l'existence
- Filtre :
  ```
  FournisseurId eq @{triggerBody()?['FournisseurId']}
  and MatierePremiereId eq @{triggerBody()?['MatierePremiereId']}
  and TypeDocumentId eq @{items('Pour_chaque_type_matiere')?['ID']}
  and DocumentCourant eq 1
  ```

### Étape 4 (dans la boucle) — Créer si absent
- Condition : `length(résultat étape 3) equals 0`
- Si VRAI → créer l'item Manquant avec FournisseurId, MatierePremiereId, LienFournMatId

---

## Configuration requise après import

| Paramètre | Valeur |
|---|---|
| `VOTRE_SITE_URL` | URL du site SharePoint |
| `LIST_GUID_LIENS_FOURN_MAT` | ID liste Liens_Fourn_Mat |
| `LIST_GUID_DOCUMENTS` | ID liste Documents |
| `LIST_GUID_TYPES_DOCUMENTS` | ID liste Types_Documents |
