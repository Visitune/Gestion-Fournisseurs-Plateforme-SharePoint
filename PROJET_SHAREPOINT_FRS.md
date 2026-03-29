# SHAREPOINT SUPPLIER MANAGEMENT PLATFORM
## Document de référence projet — v0.1
### Date : 2026-03-28

---

## TABLE DES MATIÈRES

1. [Contexte & Problématique](#1-contexte--problématique)
2. [Objectifs du projet](#2-objectifs-du-projet)
3. [Modèle de déploiement](#3-modèle-de-déploiement)
4. [Architecture globale](#4-architecture-globale)
5. [Modèle de données](#5-modèle-de-données)
6. [Cycle de vie documentaire](#6-cycle-de-vie-documentaire)
7. [Workflow d'approbation](#7-workflow-dapprobation)
8. [Alertes & Relances](#8-alertes--relances)
9. [Accès fournisseurs externes](#9-accès-fournisseurs-externes)
10. [Analyse fraude — espace dédié](#10-analyse-fraude--espace-dédié)
11. [Licences Microsoft 365](#11-licences-microsoft-365)
12. [Migration initiale](#12-migration-initiale)
13. [Roadmap](#13-roadmap)
14. [Décisions prises](#14-décisions-prises)
15. [Questions ouvertes](#15-questions-ouvertes)

---

## 1. CONTEXTE & PROBLÉMATIQUE

### 1.1 Situation actuelle chez les clients (AS-IS)

Les clients cibles sont des entreprises industrielles (agroalimentaire, pharma, emballage)
qui gèrent leurs fournisseurs via :

- **Un serveur de fichiers local** avec une arborescence type :
  ```
  Serveur/Fournisseurs/
  ├── FOURNISSEUR_A/
  │   ├── Fiches Techniques/
  │   ├── Certificats/
  │   ├── Cahiers des Charges/
  │   ├── Questionnaires/
  │   └── Archives/
  ├── FOURNISSEUR_B/
  └── ...
  ```

- **Un ou plusieurs fichiers Excel** mélangeant dans un même tableau :
  - Suivi de validité des documents (FT, CDC, certificats, déclarations)
  - Résultats des questionnaires fournisseurs (EN.ACHAT.001, .006, .007, etc.)
  - Analyse de risque fraude (scores historique, marché, origine, criticité)
  - Évaluation fournisseur globale
  - Statuts de conformité

### 1.2 Problèmes identifiés

| Problème | Impact |
|---|---|
| Fichiers non structurés, nommage incohérent | Impossible de retrouver un document |
| Versions multiples non contrôlées | Risque de travailler sur un document obsolète |
| Pas de suivi automatique des expiration | Découverte tardive des non-conformités |
| Pas de lien entre documents, fournisseurs et matières | Pas de vision globale |
| Excel surchargé (documents + fraude + questionnaires mélangés) | Erreurs, lourdeur, non maintenable |
| Pas de traçabilité fiable | Risque en audit GFSI / IFS / BRC |
| Processus de relance manuel | Perte de temps, oublis fréquents |

### 1.3 Exemple de données réelles (structure Excel existante)

Les colonnes typiques d'un Excel client couvrent en un seul tableau :

```
Statut | Code ressource | Nom | Fournisseur
Date réception FT | Ref FT | Date validation qualité | Date CDC
EN.ACHAT.001 (date) | EN.ACHAT.006 | EN.ACHAT.007 | EN.ACHAT.008 |
EN.ACHAT.010 | EN.ACHAT.011 | EN.ACHAT.013 | EN.ACHAT.017 | EN.ACHAT.021
Tout valide ? | Langue | REF OA
FT (OUI/NON) | CDC (OUI/NON) | EN.ACHAT.001 (OUI/NON) | ...
nb Oui | nb Non | PJ FT | PJ CDC | PJ 001 | ...
Evaluation fournisseur N-1 | Type fournisseur
Origine matière | Origine transformation
Paramètre falsifiable | Historique fraude | Coût/rareté marché
Complexité chaîne appro | Facilité fraude | Notion identité
Score total | Probabilité | Mesures détection | Facilité détection
Note criticité | Certificat GFSI | Nom certificat | Certification matière
Note criticité pondérée | Facteurs atténuation | Méthodes détection
Commentaire
```

Ce tableau mélange au moins 5 domaines conceptuels distincts qui doivent être séparés.

---

## 2. OBJECTIFS DU PROJET

### Objectif principal
Transformer un système de fichiers + Excel en une **plateforme intelligente de gestion
fournisseurs** reposant sur Microsoft 365, déployable et reproductible chez plusieurs
clients industriels.

### Objectifs détaillés

| Objectif | Description |
|---|---|
| **Centralisation** | Tous les documents dans SharePoint |
| **Structuration** | Données relationnelles (fournisseur → matière → document) |
| **Traçabilité** | Historique complet, documents obsolètes conservés et consultables |
| **Automatisation** | Statuts calculés, alertes expiration, relances fournisseurs |
| **Approbation** | Workflow validation documentaire avant activation |
| **Multi-client** | Architecture reproductible, paramétrable par client |
| **Portail fournisseur** | Accès externe limité pour dépôt de documents |
| **Analyse fraude** | Module dédié, séparé, collaboratif |

---

## 3. MODÈLE DE DÉPLOIEMENT

```
[Nous - prestataire]
    │
    ├── Déploiement d'un SharePoint par client industriel
    │    (script de provisioning automatique)
    │
    ├── Migration initiale des données existantes
    │    (prestation : reprise serveur fichiers + Excel)
    │
    └── Maintenance / évolution

[Client industriel - ex: Entreprise A]
    │
    ├── Utilise le SharePoint déployé
    ├── Gère ses propres fournisseurs
    └── Ses fournisseurs ont un accès externe limité
```

**Important** : 1 client industriel = 1 déploiement SharePoint indépendant.
Les données de chaque client sont isolées. Pas de mutualisation des données clients.

---

## 4. ARCHITECTURE GLOBALE

### 4.1 Vue d'ensemble des 3 espaces

```
┌─────────────────────────────────────────────────────────────────┐
│              SITE SHAREPOINT CLIENT (ex: Entreprise A)           │
│                                                                   │
│  ┌───────────────────────┐    ┌──────────────────────────────┐   │
│  │   ESPACE INTERNE       │    │    ESPACE FOURNISSEUR         │   │
│  │   Qualité + Achats     │    │    (accès guest/email)        │   │
│  │                        │    │                              │   │
│  │  • Dashboard alertes   │◄───┤  • Voir ses propres docs     │   │
│  │  • Fournisseurs        │    │  • Voir documents manquants  │   │
│  │  • Matières premières  │    │  • Uploader documents        │   │
│  │  • Documents & statuts │    │    demandés                  │   │
│  │  • Workflow validation │    │                              │   │
│  │  • Relances            │    └──────────────────────────────┘   │
│  └───────────────────────┘                                        │
│              │                                                     │
│              │ (lookup — données partagées)                       │
│              ▼                                                     │
│  ┌─────────────────────────────────────────────────────────┐      │
│  │              ESPACE ANALYSE FRAUDE                       │      │
│  │              (accès interne restreint)                   │      │
│  │                                                          │      │
│  │  • Évaluation risque par Fournisseur + Matière           │      │
│  │  • Rempli en équipe (Qualité + Achats)                   │      │
│  │  • Scores paramétrables, criticité, mesures détection    │      │
│  │  • Référence les mêmes Fournisseurs & Matières           │      │
│  └─────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Stack technique

| Couche | Outil | Licence requise |
|---|---|---|
| Stockage documents | Bibliothèque SharePoint | M365 standard |
| Base de données | Microsoft Lists (SharePoint) | M365 standard |
| Logique métier & alertes | Power Automate (connecteurs standard) | M365 standard |
| Interface Phase 1 | Pages SharePoint natives | M365 standard |
| Interface Phase 2 | Power Apps Canvas App | Licence dédiée requise |
| Analytics | Power BI | Licence dédiée ou Power BI free |

### 4.3 Flux de données

```
[Bibliothèque SharePoint]     [Listes SharePoint]
   Documents physiques    ◄──► Métadonnées & statuts
   (PDF, XLSX, DOCX...)         │
                                ▼
                         [Power Automate]
                         Calcul statuts
                         Envoi alertes
                         Relances email
                                │
                                ▼
                         [Pages SharePoint]
                         Dashboard, vues filtrées
                         Indicateurs visuels
```

---

## 5. MODÈLE DE DONNÉES

### 5.1 Principe de rattachement des documents

Un document peut être rattaché à 3 niveaux :

```
Niveau FOURNISSEUR
└── Certificat IFS, Questionnaire fournisseur, Évaluation annuelle

Niveau MATIÈRE
└── Fiche Technique générique, CDC générique

Niveau FOURNISSEUR + MATIÈRE  (le plus fréquent)
└── FT spécifique à cette source, Déclaration alimentarité,
    Analyse laboratoire, CDC spécifique
```

### 5.2 Table de configuration — Types_Documents

> Table paramétrable par client — définit tous les types de documents gérés

| Colonne | Type | Description |
|---|---|---|
| `Nom` | Texte | Ex: "Fiche Technique", "Certificat IFS", "Déclaration alimentarité" |
| `Niveau_Rattachement` | Choix | Fournisseur / Matière / Fournisseur+Matière |
| `Durée_Validité_Defaut` | Nombre (jours) | Ex: FT=730, Cert=365, Décl.alim=1825 |
| `Alerte_J90` | Oui/Non | Déclencher alerte 90j avant expiration |
| `Alerte_J30` | Oui/Non | Déclencher alerte 30j avant expiration |
| `Alerte_J7` | Oui/Non | Déclencher alerte 7j avant expiration |
| `Obligatoire_Approbation` | Oui/Non | Bloque l'approbation si absent |
| `Extensions_Acceptées` | Texte | pdf, xlsx, docx... |
| `Commentaire` | Texte long | Notes de configuration |

**Exemples de valeurs typiques :**

| Type document | Niveau | Durée validité | Obligatoire |
|---|---|---|---|
| Fiche Technique | Fourn+Matière | 730 jours (2 ans) | Oui |
| Cahier des Charges | Fourn+Matière | 1095 jours (3 ans) | Oui |
| Certificat IFS/BRC/FSSC | Fournisseur | 365 jours (1 an) | Oui |
| Questionnaire fournisseur | Fournisseur | 365 jours (1 an) | Oui |
| Déclaration alimentarité | Fourn+Matière | 1825 jours (5 ans) | Selon client |
| Analyse laboratoire | Fourn+Matière | 365 jours (1 an) | Non |
| Évaluation fournisseur | Fournisseur | 365 jours (1 an) | Non |

### 5.3 Table Fournisseurs

| Colonne | Type | Description |
|---|---|---|
| `Code_Fournisseur` | Texte (clé) | Code unique |
| `Nom` | Texte | Raison sociale |
| `Type` | Choix | Producteur direct / Broker / Négoce / Distributeur |
| `Pays` | Texte | Pays siège social |
| `Contact_Qualite` | Personne/email | Interlocuteur qualité |
| `Contact_Achats` | Personne/email | Interlocuteur achats |
| `Statut_Approbation` | Choix | En cours / Approuvé / Suspendu / Archivé |
| `Date_Approbation` | Date | Date de première approbation |
| `Score_Conformite` | Nombre | Calculé (paramétrable) |
| `Commentaire` | Texte long | |

### 5.4 Table Matieres_Premieres

| Colonne | Type | Description |
|---|---|---|
| `Code_Ressource` | Texte (clé) | Code unique (ex: 02145) |
| `Nom` | Texte | Ex: EXTRAIT FLEUR D'ORANGER |
| `Catégorie` | Choix | Ingrédient / Emballage / Auxiliaire technologique / Autre |
| `Criticité` | Choix | Haute / Moyenne / Faible |
| `Commentaire` | Texte long | |

### 5.5 Table Liens_Fourn_Mat

> Table pivot — un fournisseur peut avoir plusieurs matières, une matière peut venir de plusieurs fournisseurs

| Colonne | Type | Description |
|---|---|---|
| `ID_Lien` | Clé auto | |
| `Fournisseur` | Lookup → Fournisseurs | |
| `Matiere` | Lookup → Matieres_Premieres | |
| `Statut` | Choix | Actif / Inactif / En approbation |
| `Date_Activation` | Date | |
| `Date_Desactivation` | Date | Quand ce fournisseur a cessé pour cette matière |
| `REF_OA` | Texte | Référence ordre d'achat / référence interne |
| `Langue_FT` | Choix | FR / EN / Autre |
| `Commentaire` | Texte long | Ex: "Passé chez autre fournisseur en déc 2022" |

### 5.6 Table Documents — TABLE CENTRALE

| Colonne | Type | Description |
|---|---|---|
| `ID_Document` | Clé auto | |
| `Type_Document` | Lookup → Types_Documents | |
| `Fournisseur` | Lookup → Fournisseurs | Renseigné si niveau Fournisseur |
| `Matiere` | Lookup → Matieres_Premieres | Renseigné si niveau Matière |
| `Lien_Fourn_Mat` | Lookup → Liens_Fourn_Mat | Renseigné si niveau Fourn+Matière |
| `Date_Reception` | Date | Date de réception du document |
| `Reference_Document` | Texte | Référence interne du document (ex: ACN0004709) |
| `Date_Expiration` | Date | Saisie manuelle OU calculée auto |
| `Statut` | Choix | Valide / Expire_Bientôt / Expiré / Manquant / Obsolète |
| `Est_Courant` | Oui/Non | Un seul document courant par type par entité |
| `Version` | Nombre | Auto-incrémenté à chaque nouveau document du même type |
| `URL_Fichier` | Lien hypertexte | Lien vers le fichier dans la bibliothèque SharePoint |
| `Date_Validation` | Date | Date de validation par Qualité |
| `Validé_Par` | Personne | Compte SharePoint du validateur |
| `Source` | Choix | Migration / Upload manuel / Envoi fournisseur |
| `Commentaire` | Texte long | |

### 5.7 Table Analyse_Fraude — MODULE SÉPARÉ

> Espace d'accès restreint, rempli en équipe Qualité + Achats

| Colonne | Type | Description |
|---|---|---|
| `Lien_Fourn_Mat` | Lookup → Liens_Fourn_Mat | |
| `Parametre_Falsifiable` | Texte | Ex: oxyde d'éthylène, appellation Porto |
| `Score_Historique` | Nombre (0-5) | Historique fraudes connues (RASFF, publications) |
| `Score_Marché` | Nombre (0-5) | Coût, rareté, saisonnalité, taille marché |
| `Score_Origine` | Nombre (0-5) | Complexité chaîne appro, origine, ponctualité |
| `Score_Produit` | Nombre (0-5) | Facilité fraude, état physique de la matière |
| `Score_Total` | Calculé | Somme des 4 scores |
| `Probabilité` | Choix | Improbable / Possible / Probable |
| `Mesures_Detection` | Texte long | Mesures internes (BL, étiquetage, physico-chimie...) |
| `Facilite_Detection` | Choix | Impossible / Difficile / Possible / Facile |
| `Note_Criticité` | Texte | Calculé selon grille (A/B/C) |
| `Certif_GFSI` | Oui/Non | Le fournisseur est-il certifié GFSI ? |
| `Nom_Certif_GFSI` | Texte | Ex: FSSC 22000, IFS, BRC |
| `Autres_Certifs` | Texte | ISO 9001, Bio, VPF... |
| `Certif_Matiere` | Oui/Non | Certification spécifique à la matière |
| `Note_Certif` | Texte | Note selon certifications (A/B/C) |
| `Note_Criticité_Pondérée` | Texte | Criticité ajustée par certifications |
| `Facteurs_Attenuation` | Texte long | |
| `Necessaire_Approfondir` | Oui/Non | |
| `Methodes_Analyse` | Texte long | Visuel, documentaire, physico-chimie, ADN... |
| `Date_Analyse` | Date | |
| `Analyste` | Personne | |
| `Commentaire` | Texte long | |

---

## 6. CYCLE DE VIE DOCUMENTAIRE

### 6.1 Statuts et transitions

```
MANQUANT
    │
    │ Upload du document par l'utilisateur ou le fournisseur
    ▼
EN ATTENTE DE VALIDATION
    │
    │ Validation par la personne habilitée (Qualité)
    ▼
VALIDE ◄──────────────────────────────────────────────────────┐
    │                                                          │
    │ J-90 → Alerte email Qualité + Achats                    │
    │ J-30 → Alerte email + fournisseur                       │
    │ J-7  → Alerte urgente                                   │
    ▼                                                          │
EXPIRE BIENTÔT                                                 │
    │                                                          │
    │ Date dépassée                                            │
    ▼                                                          │
EXPIRÉ                                                         │
    │                                                          │
    │ Nouveau document du même type uploadé + validé           │
    ▼                                                          │
OBSOLÈTE ─────── conservé, consultable dans l'historique ─────┘
```

### 6.2 Règle de version

- Quand un nouveau document du **même type** est validé pour la **même entité**
  (même paire Fournisseur+Matière, ou même Fournisseur) :
  - L'ancien passe en `Statut = Obsolète` et `Est_Courant = Non`
  - Le nouveau passe en `Statut = Valide` et `Est_Courant = Oui`
  - La version s'incrémente automatiquement
- L'historique complet est conservé et consultable (FT v1, v2, v3...)

### 6.3 Types de fichiers acceptés

PDF, XLSX, XLS, DOCX, DOC, et tout format paramétrable dans `Types_Documents`.

---

## 7. WORKFLOW D'APPROBATION

### 7.1 Nouveau fournisseur

```
1. Création de la fiche Fournisseur (Statut: En cours)
2. Le système génère automatiquement la checklist documentaire
   → Flux 6 (flow_init_checklist_fournisseur) crée un item "Manquant" pour chaque
     TypeDocument où NiveauRattachement = "Fournisseur" et Obligatoire = Oui
3. Upload des documents requis (par Qualité/Achats ou via portail fournisseur)
4. Validation de chaque document par la personne habilitée (Qualité)
5. Quand tous les documents obligatoires sont Valides → Statut Fournisseur → Approuvé

⛔ Règle : impossible d'approuver un fournisseur si un document obligatoire
          est manquant ou expiré
```

### 7.2 Nouvelle matière / ingrédient / emballage

```
1. La matière ne peut être créée qu'en étant liée à un Fournisseur Approuvé
2. Création du Lien_Fournisseur_Matiere (Statut: En approbation)
3. Le système génère la checklist documentaire
   (Types_Documents Obligatoires de niveau Matière + Fournisseur+Matière)
4. Upload + validation par Qualité
5. Quand tous les documents obligatoires sont Valides → Lien → Statut Actif

⛔ Règle : impossible d'activer un lien Fournisseur+Matière si un document
          obligatoire est manquant ou expiré
```

---

## 8. ALERTES & RELANCES

### 8.1 Alertes automatiques (Power Automate — flux quotidien)

```
Tous les jours à 8h00 :
  Parcourir tous les Documents où :
    Est_Courant = Oui
    ET Statut ≠ Obsolète
    ET Statut ≠ Manquant

  Pour chaque document :
    Si Date_Expiration = Aujourd'hui + 90j
      ET Alerte_J90 = Oui sur le Type_Document
      → Email à Qualité + Achats
        Objet : [ALERTE J-90] Document expirant le [date]
        Corps : Fournisseur, Matière, Type document, Date expiration

    Si Date_Expiration = Aujourd'hui + 30j
      ET Alerte_J30 = Oui
      → Email à Qualité + Achats + Contact_Qualite Fournisseur

    Si Date_Expiration = Aujourd'hui + 7j
      ET Alerte_J7 = Oui
      → Email urgent multi-destinataires

    Si Date_Expiration < Aujourd'hui
      → Mettre à jour Statut = Expiré
```

### 8.2 Relance manuelle

- Bouton "Relancer ce fournisseur" dans la fiche fournisseur
- Power Automate génère un email avec :
  - Liste des documents manquants
  - Liste des documents expirés
  - Lien vers le portail de dépôt (si activé)

---

## 9. ACCÈS FOURNISSEURS EXTERNES

### Option A — Email + lien de dépôt (Phase 1 recommandée)

```
Power Automate envoie email au fournisseur :
  "Documents à mettre à jour pour [Matière X]"
  Liste des documents manquants/expirés
  Lien direct → formulaire SharePoint de dépôt

Le fournisseur dépose le fichier sans créer de compte
Power Automate notifie Qualité à réception
Le document passe en "En attente de validation"
```

- Avantages : zéro friction, aucun compte fournisseur à gérer
- Limites : pas de vue en temps réel pour le fournisseur, moins sécurisé

### Option B — Portail Guest SharePoint (Phase 2)

```
Fournisseur reçoit invitation email (Azure AD B2B Guest)
Crée un compte Microsoft gratuit ou reçoit un code unique
Accède à une page SharePoint filtrée sur son propre code fournisseur
Voit :
  - Ses documents actifs et leurs dates d'expiration
  - La liste de ce qui manque ou est expiré
  - Un bouton pour déposer un document
Ne peut pas voir les données des autres fournisseurs
```

- Avantages : portail en temps réel, sécurisé, traçable
- Prérequis : configuration Azure AD B2B, acceptation par le service IT client

**Décision actuelle** : Option A en Phase 1. Option B étudiée pour Phase 2.

---

## 10. ANALYSE FRAUDE — ESPACE DÉDIÉ

### 10.1 Positionnement

- Module distinct de la gestion documentaire courante
- Accès restreint : Qualité + Achats uniquement
- Rempli collaborativement lors des sessions d'évaluation d'équipe
- Référence les mêmes entités (Fournisseurs, Matières, Liens) sans dupliquer les données

### 10.2 Logique d'évaluation

L'analyse fraude est menée par paire **Fournisseur + Matière** selon 2 axes :

**Axe Fournisseur :**
- Type (producteur direct vs broker — niveau de risque différent)
- Certifications GFSI (FSSC 22000, IFS, BRC) — facteur d'atténuation
- Autres certifications (ISO 9001, Bio, Halal, VPF...)
- Historique relationnel

**Axe Matière :**
- État physique (poudre, liquide, restructuré = plus facilement fraudable)
- Historique RASFF / publications scientifiques
- Fluctuation marché / rareté / saisonnalité
- Complexité chaîne d'approvisionnement
- Paramètres précis pouvant être falsifiés (ex: oxyde d'éthylène, appellation)

### 10.3 Grille de scoring (exemple — paramétrable)

| Critère | Échelle | Description |
|---|---|---|
| Historique | 0-5 | Fraudes documentées sur cette matière |
| Marché | 0-5 | Pression économique à frauder |
| Origine | 0-5 | Complexité de la traçabilité géographique |
| Produit | 0-5 | Facilité technique de la fraude |
| **Total** | 0-20 | Somme |
| Probabilité | Seuils | Improbable (<8) / Possible (8-14) / Probable (>14) |
| Détection | A/B/C | A=Impossible, B=Difficile, C=Facile |
| Criticité | Matrice | Croisement Probabilité × Détection |

Les seuils et la grille sont **entièrement paramétrables** selon le référentiel utilisé par le client.

---

## 11. LICENCES MICROSOFT 365

### 11.1 Ce qui est inclus dans les licences M365 standards

| Fonctionnalité | Business Basic | Business Standard | E1 | E3 |
|---|---|---|---|---|
| SharePoint | ✅ | ✅ | ✅ | ✅ |
| Microsoft Lists | ✅ | ✅ | ✅ | ✅ |
| Power Automate (connecteurs standard) | ✅ | ✅ | ✅ | ✅ |
| Power Apps (basique) | ❌ | ✅ limité | ❌ | ✅ limité |
| Guest Access (Azure AD B2B) | ✅ | ✅ | ✅ | ✅ |
| Power BI (version gratuite) | ✅ | ✅ | ✅ | ✅ |

### 11.2 Ce qui nécessite une licence supplémentaire

| Fonctionnalité | Coût indicatif | Quand utile |
|---|---|---|
| Power Automate Premium | ~15€/user/mois | Connecteurs HTTP, appels API externes |
| Power Apps per user | ~20€/user/mois | Application mobile riche, Phase 2 |
| Power Apps per app | ~5€/user/app/mois | Limité à 1 application |
| Power BI Pro | ~10€/user/mois | Partage de rapports entre utilisateurs |

### 11.3 Stratégie licences recommandée

- **Phase 1** : 100% sur licences M365 existantes (SharePoint + Lists + Power Automate standard)
- **Phase 2** : évaluer Power Apps uniquement si le client a le budget et le besoin réel
- **Alternative Power Apps** : SharePoint moderne + pages personnalisées couvrent 80% des besoins sans licence supplémentaire

---

## 12. MIGRATION INITIALE

### 12.1 Périmètre de la prestation

La migration depuis les serveurs de fichiers + Excel vers SharePoint est une **prestation accompagnée**. Les clients ne le feront pas seuls.

### 12.2 Étapes de migration

```
PHASE AUDIT
1. Inventaire du dossier serveur (arborescence, volumes, types fichiers)
2. Analyse du fichier Excel existant (colonnes, qualité données, doublons)
3. Cartographie Fournisseurs × Matières identifiées

PHASE PRÉPARATION
4. Déploiement du site SharePoint client (script de provisioning)
5. Configuration des Types_Documents selon le client
6. Import des fournisseurs et matières dans les listes

PHASE INGESTION DOCUMENTS
7. Script d'ingestion (PowerShell/Python) :
   a. Scan de l'arborescence locale
   b. Détection fournisseur par nom de dossier / règles nommage
   c. Détection type document par règles nommage / sous-dossier
   d. Attribution statut (Valide / Expiré / Obsolète) selon date
   e. Renommage normalisé
   f. Upload dans bibliothèque SharePoint
   g. Création ligne dans liste Documents

PHASE REPRISE DONNÉES
8. Reprise données Excel → listes SharePoint
   (Dates, statuts questionnaires, données fraude)

PHASE VALIDATION
9. Contrôle qualité avec le client
10. Formation utilisateurs
```

### 12.3 Gestion des documents historiques

- Les anciens documents (FT v1, certificats expirés) sont **conservés** dans SharePoint
- Ils sont uploadés avec `Statut = Obsolète` et `Est_Courant = Non`
- Ils sont visibles dans l'onglet "Historique" de chaque fiche
- Ils ne génèrent pas d'alertes

---

## 13. ROADMAP

```
PHASE 0 — FONDATIONS (à faire maintenant)
├── Définir le fichier de configuration client (template JSON ou CSV)
├── Créer le script de provisioning SharePoint
│   (crée automatiquement toute la structure pour un nouveau client)
└── Documenter l'architecture des listes et leurs colonnes exactes

PHASE 1 — SHAREPOINT NATIF FONCTIONNEL
├── Pages SharePoint dashboard
├── Vues conditionnelles (rouge/orange/vert selon statut)
├── Power Automate : calcul statuts quotidien
├── Power Automate : alertes J-90 / J-30 / J-7
├── Power Automate : relance fournisseur par email
└── Guide utilisateur Qualité + Achats

PHASE 2 — MIGRATION INITIALE (prestation)
├── Script d'ingestion fichiers (serveur → SharePoint)
├── Script de reprise données Excel
└── Process de validation avec client

PHASE 3 — PORTAIL FOURNISSEUR
├── Option A : email + lien dépôt (sans compte)
└── Option B : guest access SharePoint (avec compte)

PHASE 4 — POWER APPS (si licences disponibles)
├── Formulaires d'approbation guidés
├── Interface mobile optimisée
└── Workflow validation multi-étapes

PHASE 5 — ANALYTICS
├── Power BI connecté aux listes SharePoint
├── Dashboard conformité fournisseurs
├── KPI : % documents valides, score fournisseur, alertes actives
└── Rapport analyse fraude
```

---

## 14. DÉCISIONS PRISES

| # | Sujet | Décision |
|---|---|---|
| 1 | Validation documents | 1 seule personne Qualité — pas de multi-validation |
| 2 | Analyse fraude | Espace séparé, accès interne restreint, rempli en équipe |
| 3 | Questionnaires | Phase 1 = PDF upload uniquement |
| 4 | Accès fournisseurs | Phase 1 = email + lien dépôt, Phase 2 = portail guest |
| 5 | Architecture multi-client | 1 client = 1 site SharePoint indépendant |
| 6 | Score conformité | Entièrement paramétrable par client |
| 7 | Historique documents | Conservé, obsolètes consultables mais sans alerte |
| 8 | Migration | Prestation accompagnée, pas en autonomie client |
| 9 | Power Apps | Phase 2 conditionnelle aux licences disponibles |
| 10 | Phase 1 | 100% sur licences M365 existantes |

---

## 15. QUESTIONS OUVERTES

| # | Question | Impact | Priorité |
|---|---|---|---|
| Q1 | Score conformité : formule de calcul ? (% docs valides pondéré par criticité ?) | KPI dashboard | Moyen |
| Q2 | Portail fournisseur Phase 1 : le formulaire de dépôt peut-il être une liste SharePoint partagée anonymement ? | Faisabilité technique | Haut |
| Q3 | Analyse fraude : grille de scoring identique pour tous les clients ou paramétrable ? | Complexité config | Moyen |
| Q4 | Questionnaires numériques (Phase 2) : Microsoft Forms ou Power Apps Form ? | Architecture Phase 2 | Bas |
| Q5 | Nombre d'utilisateurs internes typiques chez un client ? | Dimensionnement | Bas |
| Q6 | Faut-il gérer les notifications vers les achats séparément de la qualité ? | Workflow alertes | Moyen |
| Q7 | Le script de provisioning doit-il gérer la création du site SharePoint lui-même, ou seulement les listes sur un site existant ? | Périmètre script | Haut |

---

## ANNEXE — Exemple de données réelles (client référence)

### Matières gérées (extrait)

| Statut | Code | Nom | Fournisseur | FT | Certificat |
|---|---|---|---|---|---|
| Actif | 02145 | EXTRAIT FLEUR D'ORANGER | NACTIS (Aralco) | 20/10/2025 | FSSC 22000 |
| Inactif | 02145 | EXTRAIT FLEUR D'ORANGER | NACTIS (Aralco) | 06/04/2020 | FSSC 22000 |
| Actif | 02174 | PORTO 19% S sans arôme poivre | Bardinet Gastronomie | 29/04/2025 | IFS + BRC |
| Inactif | 02174 | PORTO 19% S/P | Bardinet Gastronomie | 02/04/2020 | IFS + BRC |
| Inactif | 03868 | APERITIF BASE DE VIN | Bardinet Gastronomie | 02/04/2020 | IFS + BRC |

### Questionnaires utilisés (client référence)

| Code | Intitulé |
|---|---|
| EN.ACHAT.001 | Questionnaire fournisseur général |
| EN.ACHAT.006 | OGM, dioxine, nano |
| EN.ACHAT.007 | Allergènes |
| EN.ACHAT.008 | Éthique et malveillance |
| EN.ACHAT.010 | Prévention risques corps étrangers et risques chimiques |
| EN.ACHAT.011 | Plan de contrôle contaminants |
| EN.ACHAT.013 | Gestion de crise |
| EN.ACHAT.017 | Composition ingrédients |
| EN.ACHAT.021 | Protocole de sécurité |

---

*Document vivant — à mettre à jour au fil des décisions et évolutions du projet.*
*Version 0.1 — 2026-03-28*
