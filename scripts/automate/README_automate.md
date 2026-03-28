# Flux Power Automate — FRS Platform

Ce dossier contient les spécifications et templates des flux Power Automate à créer
pour chaque déploiement client.

---

## Vue d'ensemble des flux

| Flux | Déclencheur | Description |
|---|---|---|
| `flow_calcul_statuts` | Quotidien (08h00) | Recalcule les statuts de tous les documents |
| `flow_alertes_expiration` | Quotidien (08h00) | Envoie les alertes J-90 / J-30 / J-7 |
| `flow_relance_fournisseur` | Manuel (bouton) | Email de relance avec liste documents manquants |
| `flow_nouveau_document` | Création item (Documents) | Marque l'ancien document comme Obsolète |
| `flow_depot_fournisseur` | Création fichier (dossier depot) | Notifie Qualité d'un nouveau dépôt fournisseur |

---

## Prérequis

- Licence Power Automate **standard** (incluse dans M365 Business Basic/Standard/E1/E3)
- Connecteurs utilisés : SharePoint (standard), Office 365 Outlook (standard)
- Aucun connecteur premium requis pour Phase 1

---

## Instructions de création

Chaque flux se crée dans Power Automate (make.powerautomate.com) :

1. Aller sur https://make.powerautomate.com
2. Cliquer **+ Nouveau flux** → **Flux de cloud planifié** (pour les flux quotidiens)
   ou **Flux de cloud automatisé** (pour les flux déclenchés par événement)
3. Suivre les spécifications détaillées dans chaque fichier de flux

---

## Paramètres globaux à configurer

Avant de créer les flux, noter les informations suivantes du site SharePoint client :

```
URL_SITE          = https://TENANT.sharepoint.com/sites/NOM_SITE
LISTE_DOCUMENTS   = Documents
LISTE_FOURNISSEURS= Fournisseurs
LISTE_TYPES_DOCS  = Types_Documents
EMAIL_QUALITE     = qualite@client.fr
EMAIL_ACHATS      = achats@client.fr
```

Ces valeurs sont à reporter dans chaque flux lors de la configuration des actions SharePoint.
