# 🛡️ Toolkit Supplier Management & HACCP 2026
> **Solution de Gestion Documentaire Fournisseurs & Plan de Maîtrise Sanitaire (PMS)**

[![Netlify Status](https://api.netlify.com/api/v1/badges/your-id/deploy-status)](https://votre-url-netlify.app)
*(Bouton indicatif - à configurer après déploiement)*

Ce dépôt contient une solution complète et modulaire pour la gestion de la conformité fournisseurs (IFS/BRC/FSSC) et l'automatisation du plan HACCP sur Microsoft 365.

### 🌐 Démo Client Interactive
Le fichier `NAVIGATEUR.html` sert de guide visuel et d'interface de démonstration. 
**Pour les clients** : Déployé sur Netlify pour une consultation instantanée sans configuration.
**Pour les collègues** : Guide complet des flux SharePoint et des structures de données.

---

---

## Structure du projet

```
├── NAVIGATEUR.html                       ← Présentation interactive + démo visuelle
├── PROJET_SHAREPOINT_FRS.md              ← Document de référence complet
│
├── scripts/
│   ├── Deploy-FRS.ps1                    ← Script PnP déploiement (Phase 0) — REQUIS
│   └── automate/
│       └── flows/
│           ├── flow_calcul_statuts.json       ← Flux 1 — Calcul statuts quotidien
│           ├── flow_alertes_expiration.json   ← Flux 2 — Alertes J-90/J-30/J-7
│           ├── flow_relance_fournisseur.json  ← Flux 3 — Relance manuelle fournisseur
│           ├── flow_nouveau_document.json     ← Flux 4 — Archivage + versioning auto
│           └── flow_portail_fournisseur.json  ← Flux 5 — Portail Microsoft Forms
│
├── GenerateurBaseFournisseur.ps1         ← Script optionnel migration fichiers serveur
│
├── config/
│   ├── client_config_template.json       ← Template à copier pour chaque client
│   └── exemple_client_A.json             ← Exemple client agroalimentaire
│
├── docs/
│   ├── guide_utilisateur.md              ← Guide équipes Qualité + Achats
│   └── guide_migration.md               ← Guide migration initiale (Phase 2)
│
└── templates/
    └── email/
        ├── alerte_expiration.html         ← Template email alerte
        └── relance_fournisseur.html       ← Template email relance
```

---

## Déploiement — Nouveau client (Phase 0)

### Prérequis

- PowerShell **7.4.6+** (pas 7.4.0–7.4.5)
- Module PnP.PowerShell v3

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
```

- Site SharePoint déjà créé sur le tenant du client

### Étape 1 — Enregistrer l'app Entra ID (une fois par tenant)

> ⚠️ L'ancienne app multi-tenant PnP a été supprimée le 9 sept. 2024.
> Chaque tenant doit avoir sa propre app.

```powershell
Register-PnPEntraIDAppForInteractiveLogin `
  -ApplicationName "PnP-FRS" `
  -SharePointDelegatePermissions "AllSites.FullControl" `
  -Tenant "client.onmicrosoft.com" `
  -Interactive
# → Notez l'AppID retourné
```

### Étape 2 — Lancer le script de déploiement

```powershell
./scripts/Deploy-FRS.ps1 `
  -SiteUrl  "https://client.sharepoint.com/sites/GestionFournisseurs" `
  -ClientId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

Durée : 3 à 5 minutes. Crée les 6 listes + bibliothèque + 8 types de documents par défaut.

### Étape 3 — Importer les 5 flux Power Automate

Dans Power Automate → **Importer un package** → sélectionner chaque fichier JSON.

Après import, remplacer dans chaque flux :
| Paramètre | Valeur |
|---|---|
| `VOTRE_SITE_URL` | URL du site SP |
| `LIST_GUID_DOCUMENTS` | ID de la liste Documents (visible dans l'URL des paramètres de liste) |
| `EMAIL_QUALITE` | Email équipe Qualité |
| `EMAIL_ACHATS` | Email équipe Achats |
| `VOTRE_FORM_ID` | ID du formulaire Microsoft Forms (Flux 5 uniquement) |

> **Alternative ALM** : pour un déploiement multi-environnements (dev → prod) avec versioning Git,
> utiliser PAC CLI : `pac solution import --path ./solution.zip`

---

## Prérequis clients (licences)

| Outil | Usage | Coût |
|---|---|---|
| SharePoint Online | Stockage + données | Inclus M365 |
| Power Automate | 5 flux automatisés | Inclus M365 Standard |
| Microsoft Forms | Portail fournisseur | Inclus M365 |
| Excel Online | Reporting | Inclus M365 |
| PnP.PowerShell | Script déploiement | Gratuit open source |

**Aucune licence supplémentaire requise.** Fonctionne sur M365 Business Basic, Standard, et E3/E5.

---

## Points d'attention déploiement

- Le trigger `GetOnNewItems` (Flux 4) est marqué *deprecated* par Microsoft — fonctionnel mais migration vers webhooks SP recommandée à moyen terme
- Les connexions SharePoint dans Power Automate **expirent après 90 jours d'inactivité** → re-auth manuelle dans PA → Connexions
- Azure Automation ne supporte pas PS 7.4.6 — exécuter `Deploy-FRS.ps1` en local

---

## 🚀 Déploiement sur Netlify (Guide Interactif)

Pour partager le guide visuel `NAVIGATEUR.html` avec vos clients :

1.  **Méthode Automatique (GitHub)** : Connectez ce dépôt (privé) à Netlify. Le fichier `netlify.toml` redirigera automatiquement `/` vers `/NAVIGATEUR.html`.
2.  **Méthode Manuelle (Drag & Drop)** : Glissez-déposez l'intégralité du dossier du projet sur [Netlify Drop](https://app.netlify.com/drop).

> [!TIP]
> Le `netlify.toml` inclut une directive `noindex` pour éviter que les moteurs de recherche ne référencent la version démo de votre client.

---

## 🏗️ Roadmap de Développement (Lots 2026)

Le projet évolue actuellement selon les axes prioritaires suivants (Phase "Expert Tooling") :

| Lot | Feature | Priorité | Statut | Techno |
|---|---|---|---|---|
| **Lot 2** | Gestion Justifications Documentaires | **Haute** | ⏳ Prévu | IndexedDB |
| **Lot 3** | Plan de Maîtrise (Étapes HACCP 8-12) | **Moyenne** | ⏳ Prévu | Vanilla JS |
| **Lot 4** | Reporting Experts & Export PDF | **Optimisation** | ⏳ Prévu | jsPDF |

**Notes pour les collègues :**
- Les fichiers de configuration dans `/config` servent de templates. Ne poussez pas de données clients réelles sur le repo GitHub (utilisez des variables de déploiement si besoin).
- Pour modifier les icônes, utilisez la bibliothèque **Lucide** déjà intégrée via CDN dans le HTML.

---

## Authors & License
- **Auteur :** Mounir (Expert Qualité & Digital)
- **Repo Privé :** usage réservé aux collaborateurs internes.
