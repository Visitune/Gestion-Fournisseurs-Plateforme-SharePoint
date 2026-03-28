# Spécifications Power Apps — Phase 2

## Prérequis

| Élément | Détail |
|---|---|
| Licence | Power Apps per user (~20€/user/mois) ou per app (~5€/user/app) |
| Plateforme | Canvas App (flexibilité maximale) |
| Sources de données | Listes SharePoint provisionnées en Phase 0 |
| Compatibilité | Web + Tablette + Mobile |

---

## Écrans de l'application

### 1. Écran Accueil — Dashboard

```
┌─────────────────────────────────────────────────────┐
│  🏠 Gestion Fournisseurs              [NomUtilisateur]│
├─────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │    12    │  │    5     │  │    3     │           │
│  │ Expirés  │  │ J-30     │  │ En attente│           │
│  │ 🔴       │  │ 🟠       │  │ validation│           │
│  └──────────┘  └──────────┘  └──────────┘           │
│                                                      │
│  Documents à traiter aujourd'hui                     │
│  ┌────────────────────────────────────────────┐     │
│  │ [Type] [Fournisseur] [Matière] [Date exp.] │     │
│  │ [Type] [Fournisseur] [Matière] [Date exp.] │     │
│  └────────────────────────────────────────────┘     │
│                                                      │
│  [📋 Fournisseurs] [📦 Matières] [📄 Documents]     │
└─────────────────────────────────────────────────────┘
```

**Connexions Power Apps :**
```
// Compter les documents expirés
CountIf(
    Documents,
    Statut = "Expiré" && EstCourant = true
)

// Compter les documents J-30
CountIf(
    Documents,
    DateExpiration <= DateAdd(Today(), 30, TimeUnit.Days) &&
    DateExpiration > Today() &&
    EstCourant = true
)
```

---

### 2. Écran Fournisseurs — Liste

```
┌─────────────────────────────────────────────────────┐
│  ← Fournisseurs                    🔍 [Recherche...] │
├─────────────────────────────────────────────────────┤
│  ● NACTIS (Aralco)          ████░ 85%  ✅ Approuvé  │
│  ● Bardinet Gastronomie     ██░░░ 42%  ⚠️ Alerte    │
│  ● Louis Saveur             ░░░░░  0%  🔴 Expiré    │
│                                                      │
│                            [+ Nouveau fournisseur]  │
└─────────────────────────────────────────────────────┘
```

**Formule barre de conformité :**
```
// Score de conformité (% documents valides parmi les obligatoires)
Set(
    varScoreConformite,
    If(
        CountIf(docsObligatoires, Statut = "Valide") = 0,
        0,
        CountIf(docsObligatoires, Statut = "Valide") /
        CountRows(docsObligatoires) * 100
    )
)
```

---

### 3. Écran Fiche Fournisseur

```
┌─────────────────────────────────────────────────────┐
│  ← NACTIS (Aralco)                [✉ Relancer]      │
├──────────────────────┬──────────────────────────────┤
│  Code    : 1107      │  Score     : 85%             │
│  Type    : Producteur│  Statut    : Approuvé ✅     │
│  Pays    : France    │  Certif.   : FSSC 22000      │
│  Contact : ...       │  Depuis    : 01/01/2022      │
├──────────────────────┴──────────────────────────────┤
│  [Documents]  [Matières]  [Historique]  [Fraude]   │
├─────────────────────────────────────────────────────┤
│  DOCUMENTS                                           │
│  ┌─────────────────────────────────────────────┐   │
│  │ 🟢 Certificat GFSI    exp: 15/03/2026       │   │
│  │ 🟠 Questionnaire 001  exp: 01/04/2026 J-4  │   │
│  │ 🔴 EN.ACHAT.006       exp: 12/01/2026 EXPIRÉ│   │
│  │ [+ Ajouter un document]                     │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

**Couleur statut dynamique :**
```
// Couleur badge selon statut
Switch(
    ThisItem.Statut,
    "Valide",           RGBA(46, 125, 50, 1),    // vert
    "Expire bientôt",   RGBA(230, 81, 0, 1),     // orange
    "Expiré",           RGBA(183, 28, 28, 1),    // rouge
    "Manquant",         RGBA(106, 27, 154, 1),   // violet
    "Obsolète",         RGBA(158, 158, 158, 1),  // gris
    RGBA(0, 0, 0, 1)
)
```

---

### 4. Écran Ajout / Validation document

```
┌─────────────────────────────────────────────────────┐
│  ← Nouveau document                                  │
├─────────────────────────────────────────────────────┤
│  Type de document *                                  │
│  [▼ Sélectionner...]                                │
│                                                      │
│  Fournisseur *                                       │
│  [▼ NACTIS (Aralco)]                               │
│                                                      │
│  Matière (si applicable)                             │
│  [▼ EXTRAIT FLEUR D'ORANGER]                        │
│                                                      │
│  Date de réception *    Date d'expiration            │
│  [📅 28/03/2026]        [📅 Calculée auto]          │
│                                                      │
│  Référence document                                  │
│  [ACN0004709/ANL009669]                             │
│                                                      │
│  Fichier *                                           │
│  [📎 Joindre ou glisser-déposer]                   │
│                                                      │
│  Commentaire                                         │
│  [________________________________]                  │
│                                                      │
│  [Annuler]                    [Enregistrer →]       │
└─────────────────────────────────────────────────────┘
```

**Calcul automatique de la date d'expiration :**
```
// Calculer la date d'expiration à partir du type de document
Set(
    varDateExpCalculee,
    If(
        !IsBlank(drpTypeDocument.Selected.DureeValiditeJours),
        DateAdd(
            dpDateReception.SelectedDate,
            drpTypeDocument.Selected.DureeValiditeJours,
            TimeUnit.Days
        ),
        Blank()
    )
)
```

---

### 5. Écran Analyse Fraude

```
┌─────────────────────────────────────────────────────┐
│  ← Analyse fraude — NACTIS × EXTRAIT FL. D'ORANGER  │
├─────────────────────────────────────────────────────┤
│  Paramètre falsifiable                               │
│  [Oxyde d'éthylène                                  ]│
│                                                      │
│  Origine matière          Origine transformation     │
│  [USA, Pays-Bas, Inde...] [France (Yssingeaux)    ] │
│                                                      │
│  SCORES (0 à 5)                                      │
│  Historique  ○○●○○  2     Marché  ○○○○○  0          │
│  Origine     ○○○○○  0     Produit  ○○○○○  0          │
│                                                      │
│  Score total : 2 / 20                               │
│  Probabilité : [▼ Improbable]                       │
│                                                      │
│  Mesures de détection                                │
│  [Vérification BL et étiquetage               ]    │
│                                                      │
│  Facilité détection : [▼ Impossible]               │
│  Criticité           : [A]  ← calculée auto        │
│                                                      │
│  Fournisseur certifié GFSI  [✅ Oui]               │
│  Certification : [FSSC 22000                       ] │
│                                                      │
│  Criticité pondérée : [A]   Approfondir : [Non]    │
│                                                      │
│  [Annuler]                    [Enregistrer →]       │
└─────────────────────────────────────────────────────┘
```

**Calcul criticité automatique :**
```
// Matrice Probabilité × Détection → Criticité
Set(
    varCriticite,
    If(
        drpProbabilite.Selected.Value = "Improbable" && drpDetection.Selected.Value = "Impossible", "A",
        If(
            drpProbabilite.Selected.Value = "Improbable" && drpDetection.Selected.Value = "Difficile", "A",
            If(
                drpProbabilite.Selected.Value = "Improbable" && drpDetection.Selected.Value = "Possible", "B",
                If(
                    drpProbabilite.Selected.Value = "Probable",  "C",
                    "B"
                )
            )
        )
    )
)
```

---

## Rôles et permissions dans Power Apps

```
Rôle Qualité :
  - Accès complet à tous les écrans
  - Peut valider les documents
  - Peut approuver les fournisseurs
  - Peut accéder à l'analyse fraude

Rôle Achats :
  - Accès Fournisseurs, Matières, Documents (lecture + upload)
  - Peut déclencher des relances
  - Pas d'accès à l'analyse fraude

Rôle Lecture :
  - Consultation uniquement
  - Pas d'accès à l'analyse fraude

Fournisseur (guest) :
  - Accès uniquement à son propre portail de dépôt
  - Pas d'accès aux données internes
```

**Filtrage par rôle :**
```
// Dans OnStart de l'application
Set(
    varUserRole,
    If(
        User().Email in ["qualite@client.fr", "responsable@client.fr"],
        "Qualite",
        If(
            User().Email in ["achats@client.fr"],
            "Achats",
            "Lecture"
        )
    )
)
```

---

## Déploiement

1. Créer l'application dans Power Apps Studio (make.powerapps.com)
2. Connecter les sources de données SharePoint (toutes les listes)
3. Construire les écrans dans l'ordre : Accueil → Fournisseurs → Fiche → Document → Fraude
4. Tester sur tablette et mobile
5. Publier et partager avec les utilisateurs concernés
6. Optionnel : créer un raccourci sur l'écran d'accueil mobile (PWA)
