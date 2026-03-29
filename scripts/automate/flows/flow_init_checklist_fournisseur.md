# Flux 6 — Initialisation checklist documentaire (nouveau fournisseur)

## Informations générales

| Champ | Valeur |
|---|---|
| Nom | FRS — Init checklist fournisseur |
| Déclencheur | Automatique — création d'un item dans `Fournisseurs` |
| Connecteurs | SharePoint |
| Licence requise | Standard (incluse M365) |
| Flux complémentaire | Flux 7 — Init checklist lien Fourn×Mat |

---

## Rôle métier

Ce flux matérialise la promesse "la plateforme génère automatiquement la liste des documents attendus" décrite dans le guide utilisateur section 3.

À chaque nouveau fournisseur, il crée immédiatement les items `Statut = Manquant` dans la liste `Documents` pour tous les types de documents obligatoires de niveau **Fournisseur**. L'équipe Qualité voit directement ce qui est attendu sans avoir à le créer manuellement.

---

## Logique métier

```
Déclenchement : création d'un item dans Fournisseurs

1. Récupérer tous les Types_Documents où :
   NiveauRattachement = "Fournisseur" ET Obligatoire = Oui

2. Pour chaque type :
   Vérifier si un document courant existe déjà
   (FournisseurId = nouveau fournisseur, TypeDocumentId = ce type, DocumentCourant = true)

3. Si absent → créer item Documents :
   - Title   = "[TypeDocument] — [NomFournisseur]"
   - Statut  = "Manquant"
   - TypeDocumentId   = ID du type
   - FournisseurId    = ID du nouveau fournisseur
   - DocumentCourant  = true
   - Version          = 0
   - Conformite       = "En attente"
```

La vérification d'existence (étape 2) rend le flux idempotent : si le flux tourne deux fois ou si un document existe déjà (migration), il ne crée pas de doublon.

---

## Construction dans Power Automate

### Déclencheur
- Type : **Quand un élément est créé** (`GetOnNewItems`) — polling toutes les minutes
- Liste : `Fournisseurs`

### Étape 1 — Obtenir les types de niveau Fournisseur
- Action : **Obtenir des éléments** (SharePoint) — Liste `Types_Documents`
- Filtre ODATA :
  ```
  NiveauRattachement eq 'Fournisseur' and Obligatoire eq 1
  ```
- Sélectionner : `ID,Title,DureeValidite,NiveauRattachement`

### Étape 2 — Boucle sur chaque type
- Action : **Appliquer à chacun** (`Foreach`)

### Étape 3 (dans la boucle) — Vérifier l'existence
- Action : **Obtenir des éléments** — Liste `Documents`
- Filtre :
  ```
  FournisseurId eq @{triggerBody()?['ID']}
  and TypeDocumentId eq @{items('Pour_chaque_type_fournisseur')?['ID']}
  and DocumentCourant eq 1
  ```
- `$top` : 1

### Étape 4 (dans la boucle) — Créer si absent
- Condition : `length(résultat étape 3) equals 0`
- Si VRAI → **Créer un élément** — Liste `Documents` avec les champs décrits ci-dessus

---

## Configuration requise après import

| Paramètre | Valeur |
|---|---|
| `VOTRE_SITE_URL` | URL du site SharePoint |
| `LIST_GUID_FOURNISSEURS` | ID liste Fournisseurs |
| `LIST_GUID_DOCUMENTS` | ID liste Documents |
| `LIST_GUID_TYPES_DOCUMENTS` | ID liste Types_Documents |

---

## Note sur les types de documents par défaut

Les 8 types chargés par `Deploy-FRS.ps1` ont les niveaux suivants :

| Type | Niveau | Obligatoire |
|---|---|---|
| Certificat IFS/BRC/FSSC | Fournisseur | Oui → **créé par ce flux** |
| Questionnaire fournisseur | Fournisseur | Oui → **créé par ce flux** |
| Fiche Technique | Fournisseur + Matière | Oui → créé par Flux 7 |
| Cahier des Charges | Matière | Oui → créé par Flux 7 |
| Déclaration allergènes | Fournisseur + Matière | Oui → créé par Flux 7 |
| Déclaration OGM/Dioxine | Fournisseur + Matière | Non |
| Analyse laboratoire | Fournisseur + Matière | Non |
| Déclaration alimentarité | Fournisseur + Matière | Non |
