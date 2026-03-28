# Spécifications Power BI — Phase 5

## Prérequis

| Élément | Détail |
|---|---|
| Licence | Power BI Pro (~10€/user/mois) pour le partage — Power BI Free pour usage personnel |
| Connecteur | SharePoint Online List (inclus, aucun connecteur premium) |
| Actualisation | Planifiée (jusqu'à 8x/jour avec licence Pro) |

---

## Sources de données

Se connecter aux listes SharePoint suivantes via **Obtenir des données → SharePoint Online List** :

| Table Power BI | Source SharePoint |
|---|---|
| `Fournisseurs` | Liste Fournisseurs |
| `Matieres` | Liste Matieres_Premieres |
| `Liens` | Liste Liens_Fournisseur_Matiere |
| `Documents` | Liste Documents |
| `Types_Documents` | Liste Types_Documents |
| `Analyse_Fraude` | Liste Analyse_Fraude |

---

## Modèle de données Power BI (relations)

```
Types_Documents
     │ (1)
     │ TypeDocument [ID]
     │ (*)
Documents ──────────────── Fournisseurs
     │ (*)           (*)        │ (1)
     │                          │
     │ (*)                      │ (*)
Liens ─────────────────── Matieres
     │ (1)
     │ LienID
     │ (1)
Analyse_Fraude
```

**Relations à créer dans Power BI Desktop :**
- `Documents[TypeDocumentId]` → `Types_Documents[ID]`
- `Documents[FournisseurId]` → `Fournisseurs[ID]`
- `Documents[MatiereId]` → `Matieres[ID]`
- `Liens[FournisseurId]` → `Fournisseurs[ID]`
- `Liens[MatiereId]` → `Matieres[ID]`
- `Analyse_Fraude[LienId]` → `Liens[ID]`

---

## Mesures DAX

### KPI de conformité

```dax
-- % Documents valides (parmi les documents courants)
% Conformite =
DIVIDE(
    COUNTROWS(FILTER(Documents, Documents[Statut] = "Valide" && Documents[EstCourant] = TRUE())),
    COUNTROWS(FILTER(Documents, Documents[EstCourant] = TRUE() && Documents[Statut] <> "Obsolète")),
    0
) * 100

-- Nombre de documents expirés
Nb Expirés =
COUNTROWS(
    FILTER(Documents, Documents[Statut] = "Expiré" && Documents[EstCourant] = TRUE())
)

-- Nombre de documents expirant dans 30 jours
Nb Expire Bientôt =
COUNTROWS(
    FILTER(
        Documents,
        Documents[EstCourant] = TRUE() &&
        Documents[DateExpiration] > TODAY() &&
        Documents[DateExpiration] <= TODAY() + 30
    )
)

-- Nombre de documents manquants
Nb Manquants =
COUNTROWS(FILTER(Documents, Documents[Statut] = "Manquant"))

-- Score conformité fournisseur (pour un fournisseur donné)
Score Fournisseur =
VAR docsValides = COUNTROWS(FILTER(Documents, Documents[Statut] = "Valide" && Documents[EstCourant] = TRUE()))
VAR docsTotal   = COUNTROWS(FILTER(Documents, Documents[EstCourant] = TRUE() && Documents[Statut] <> "Obsolète"))
RETURN IF(docsTotal = 0, 0, DIVIDE(docsValides, docsTotal) * 100)

-- Fournisseurs conformes (score > 80%)
Nb Fournisseurs Conformes =
COUNTROWS(
    FILTER(
        SUMMARIZE(Fournisseurs, Fournisseurs[ID], "Score", [Score Fournisseur]),
        [Score] >= 80
    )
)
```

### Suivi temporel

```dax
-- Documents expirés par mois (pour courbe tendance)
Nb Expirés par Mois =
CALCULATE(
    COUNTROWS(Documents),
    Documents[Statut] = "Expiré",
    Documents[EstCourant] = TRUE()
)

-- Délai moyen de renouvellement (jours entre expiration et nouveau document)
Délai Moyen Renouvellement =
AVERAGEX(
    FILTER(Documents, Documents[Statut] = "Valide" && Documents[Version] > 1),
    DATEDIFF(
        RELATED(Documents[DateExpiration]),  -- date d'expiration du précédent
        Documents[DateReception],
        DAY
    )
)
```

---

## Pages du rapport

### Page 1 — Tableau de bord général

**Visuels recommandés :**

| Visuel | Mesure | Description |
|---|---|---|
| Carte | `Nb Expirés` | KPI rouge — documents expirés |
| Carte | `Nb Expire Bientôt` | KPI orange — expirant dans 30j |
| Carte | `Nb Manquants` | KPI violet — documents manquants |
| Carte | `% Conformite` | KPI vert — conformité globale |
| Histogramme | Score par fournisseur | Classement des fournisseurs |
| Anneau | Répartition statuts | Valide / Expire / Expiré / Manquant |
| Tableau | Documents à renouveler | Filtré sur Expiré + Expire bientôt |

---

### Page 2 — Suivi par fournisseur

**Visuels recommandés :**

| Visuel | Description |
|---|---|
| Segment (Slicer) | Filtre par Fournisseur |
| Jauge | Score de conformité du fournisseur sélectionné |
| Tableau | Liste des documents avec statut, date expiration, type |
| Carte (map) | Origine géographique des matières (si pays renseigné) |
| Histogramme | Répartition des statuts pour ce fournisseur |

---

### Page 3 — Suivi par type de document

**Visuels recommandés :**

| Visuel | Description |
|---|---|
| Segment | Filtre par Type de document |
| Courbe | Évolution du nombre de documents expirés dans le temps |
| Matrice | Fournisseur (lignes) × Statut (colonnes) — heatmap conformité |
| Tableau | Calendrier des expirations à venir (30, 60, 90 jours) |

---

### Page 4 — Analyse fraude (accès restreint)

**Visuels recommandés :**

| Visuel | Description |
|---|---|
| Scatter plot | Score fraude (axe X) vs Criticité (axe Y) — bulle = fournisseur |
| Matrice | Matière × Fournisseur → Criticité (couleurs A/B/C) |
| Carte | Carte des origines géographiques par risque |
| Tableau | Top 10 paires Fourn×Mat par note de criticité |
| Segment | Filtre par Probabilité, par Facilité de détection |

**Row-Level Security (RLS) :**
Créer un rôle "Fraude_Accès" dans Power BI pour restreindre la page 4 :
```dax
-- Rôle : Fraude_Accès — filtre sur les tables non sensibles pour les autres rôles
-- Les utilisateurs sans ce rôle ne voient pas la page Analyse Fraude
```

---

### Page 5 — Tendances & historique

**Visuels recommandés :**

| Visuel | Description |
|---|---|
| Courbe | Évolution du taux de conformité global (mensuel) |
| Courbe | Nb de documents renouvelés par mois |
| Histogramme | Délai moyen de renouvellement par type de document |
| Tableau | Historique des changements de statut (si colonne Date_Validation renseignée) |

---

## Configuration de l'actualisation automatique

Dans Power BI Service (app.powerbi.com) :

1. Publier le rapport
2. Aller dans **Paramètres du jeu de données**
3. **Informations d'identification de la source de données** → Se connecter avec le compte M365 du client
4. **Actualisation planifiée** :
   - Activer
   - Fréquence : Quotidienne
   - Heure : 07h30 (avant les alertes Power Automate de 08h30)
   - Fuseau horaire : Europe/Paris

---

## Partage du rapport

### Avec licence Power BI Pro
- Publier dans un Workspace dédié
- Partager avec les utilisateurs par email
- Créer une Application Power BI pour regrouper les pages

### Sans licence Pro (Power BI Free)
- Le rapport est accessible uniquement au créateur
- Alternative : **Publier sur le web** (public — attention aux données sensibles)
- Alternative : **Intégrer dans une page SharePoint** via la web part Power BI
  (nécessite que le rapport soit dans un workspace Premium ou que le client ait une licence Pro)

### Intégration dans la page SharePoint

Pour afficher le dashboard directement sur le site SharePoint client :

1. Dans la page SharePoint → **Modifier** → **Ajouter un composant WebPart**
2. Sélectionner **Power BI**
3. Coller l'URL du rapport
4. Configurer la taille d'affichage

Cette intégration est recommandée pour que le tableau de bord soit accessible
directement depuis le portail Gestion Fournisseurs sans quitter SharePoint.
