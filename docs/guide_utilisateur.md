# Guide utilisateur — Plateforme Gestion Fournisseurs SharePoint

## À qui s'adresse ce guide ?

Ce guide est destiné aux équipes **Qualité** et **Achats** utilisant la plateforme
de gestion fournisseurs déployée sur SharePoint.

---

## 1. ACCÉDER À LA PLATEFORME

1. Ouvrir votre navigateur (Edge ou Chrome recommandé)
2. Aller sur le site SharePoint communiqué par votre administrateur
3. Se connecter avec votre compte Microsoft 365 habituel

La page d'accueil affiche immédiatement :
- Le nombre de documents expirés (rouge)
- Le nombre de documents expirant dans 30 jours (orange)
- Le nombre d'approbations en attente
- Les dernières alertes

---

## 2. CONSULTER UN FOURNISSEUR

### Depuis le menu "Fournisseurs"

1. Cliquer sur **Fournisseurs** dans le menu de navigation
2. La liste affiche tous les fournisseurs avec leur statut de conformité
3. Cliquer sur un fournisseur pour ouvrir sa fiche

### Ce que vous voyez dans la fiche fournisseur

- Informations générales (code, type, pays, contacts)
- Statut d'approbation
- Score de conformité
- Onglet **Documents** : tous ses documents avec statuts et dates
- Onglet **Matières** : toutes les matières liées à ce fournisseur
- Onglet **Historique** : documents obsolètes consultables
- Bouton **Relancer ce fournisseur** (envoi automatique d'email)

---

## 3. AJOUTER UN NOUVEAU FOURNISSEUR

> Prérequis : avoir le rôle Qualité ou Achats

1. Dans la liste **Fournisseurs**, cliquer sur **+ Nouveau**
2. Renseigner les informations obligatoires :
   - Nom du fournisseur
   - Code fournisseur (unique)
   - Type de fournisseur
   - Contact qualité (email)
3. Cliquer **Enregistrer** — le fournisseur est créé avec le statut **"En cours"**
4. La plateforme génère automatiquement la liste des documents obligatoires à fournir
5. Uploader chaque document requis (voir section 5)
6. Quand tous les documents obligatoires sont validés → changer le statut en **"Approuvé"**

> ⚠ Un fournisseur ne peut pas être utilisé (lié à des matières) tant qu'il n'est pas **Approuvé**

---

## 4. AJOUTER UNE NOUVELLE MATIÈRE / INGRÉDIENT / EMBALLAGE

1. Dans la liste **Matières Premières**, cliquer sur **+ Nouveau**
2. Renseigner :
   - Code ressource (ex: 02145)
   - Nom (ex: EXTRAIT FLEUR D'ORANGER)
   - Catégorie (Ingrédient / Emballage / etc.)
   - Criticité
3. Dans la liste **Liens Fournisseur-Matière**, créer le lien :
   - Sélectionner le fournisseur (doit être Approuvé)
   - Sélectionner la matière
   - Statut : "En approbation"
4. Uploader les documents spécifiques à cette source (FT, CDC...)
5. Après validation → changer le statut du lien en **"Actif"**

---

## 5. UPLOADER UN DOCUMENT

### Méthode 1 — Depuis la liste Documents

1. Aller dans **Documents** → cliquer **+ Nouveau**
2. Renseigner :
   - **Type de document** (choisir dans la liste)
   - **Fournisseur** et/ou **Matière** selon le niveau du type
   - **Date de réception**
   - **Référence document** (numéro ou code du document)
   - **Date d'expiration** (si connue) — sinon elle sera calculée automatiquement
3. Dans le champ **URL Fichier** : uploader d'abord le fichier dans la bibliothèque
   **Documents_Fichiers**, puis coller l'URL
4. Cliquer **Enregistrer** — le document est en statut **"En attente de validation"**

### Méthode 2 — Upload direct dans la bibliothèque

1. Aller dans **Documents_Fichiers**
2. Naviguer dans le dossier du fournisseur concerné
3. Glisser-déposer le fichier
4. Renseigner les métadonnées (Fournisseur, Matière, Type, Date expiration)
5. Créer manuellement l'entrée correspondante dans la liste **Documents**

> 💡 **Conseil** : utiliser la méthode 1 pour avoir un suivi complet automatique.

---

## 6. VALIDER UN DOCUMENT

Seul le rôle **Qualité** peut valider un document.

1. Dans la liste **Documents**, filtrer sur **"En attente de validation"**
2. Ouvrir le document à valider
3. Cliquer sur l'URL pour vérifier le contenu du fichier
4. Si le document est conforme :
   - Changer **Statut** → **"Valide"**
   - Renseigner **Date de validation** (aujourd'hui)
   - Renseigner **Validé par** (votre nom)
5. Enregistrer

> ⚠ Si un document du même type existait déjà pour ce fournisseur/matière,
> l'ancien bascule automatiquement en **"Obsolète"**.

---

## 7. GÉRER LES DOCUMENTS EXPIRÉS

### Tableau de bord quotidien

Chaque matin, consulter la vue **"À renouveler"** dans la liste Documents.
Elle affiche tous les documents expirés + expirant bientôt, triés par date.

### Relancer un fournisseur

1. Dans la liste **Fournisseurs**, sélectionner le fournisseur concerné
2. Cliquer sur **Automatiser** → **Relancer ce fournisseur**
3. Un email est envoyé automatiquement au contact qualité du fournisseur
   avec la liste des documents manquants/expirés
4. Un enregistrement est créé dans la liste **Relances** pour traçabilité

### Quand le fournisseur renvoie un document

1. Uploader le nouveau document (voir section 5)
2. Le valider (voir section 6)
3. L'ancien document bascule automatiquement en **"Obsolète"**

---

## 8. CONSULTER L'HISTORIQUE D'UN DOCUMENT

1. Dans la liste **Documents**, sélectionner la vue **"Historique"**
2. Cette vue affiche tous les documents obsolètes
3. Filtrer par Fournisseur ou Matière pour retrouver l'évolution d'un document dans le temps
4. Cliquer sur l'URL pour consulter un ancien document

---

## 9. ANALYSE FRAUDE

L'espace Analyse Fraude est accessible séparément (lien dans le menu).

1. Sélectionner la paire **Fournisseur + Matière** à analyser
2. Renseigner les scores (Historique, Marché, Origine, Produit)
3. La criticité est calculée automatiquement selon la grille configurée
4. Renseigner les mesures de détection et les certifications
5. Enregistrer — l'analyse est tracée avec la date et l'analyste

> Ces données sont confidentielles — accès restreint à l'équipe Qualité + Achats

---

## 10. ALERTES EMAIL AUTOMATIQUES

Les alertes suivantes sont envoyées automatiquement :

| Délai | Destinataires | Condition |
|---|---|---|
| J-90 avant expiration | Qualité + Achats | Si activé sur le type de document |
| J-30 avant expiration | Qualité + Achats + Fournisseur | Si activé sur le type de document |
| J-7 avant expiration | Qualité + Achats + Fournisseur | Si activé sur le type de document |
| Jour J (expiration) | Qualité + Achats | Automatique |

Vous n'avez rien à faire — ces alertes sont générées chaque matin à 08h30.

---

## 11. QUESTIONS FRÉQUENTES

**Q : Je ne vois pas le bouton "Relancer ce fournisseur"**
R : Ce bouton n'apparaît que si vous avez le rôle Qualité ou Achats.
Vérifier avec votre administrateur SharePoint.

**Q : Le statut d'un document ne s'est pas mis à jour**
R : Le calcul des statuts tourne chaque matin à 08h00.
Si urgent, contacter l'administrateur pour lancer le flux manuellement.

**Q : J'ai uploadé un document mais il n'apparaît pas dans la liste**
R : L'upload dans la bibliothèque ne crée pas automatiquement l'entrée dans la liste Documents.
Il faut créer manuellement l'entrée (voir section 5).

**Q : Comment voir les documents d'un fournisseur inactif ?**
R : Dans la liste Liens Fournisseur-Matière, filtrer sur Statut = "Inactif".
Cliquer sur le lien → accéder aux documents associés dans la vue "Historique".

---

## 12. CONTACTS SUPPORT

Pour toute question technique sur la plateforme, contacter :
_(À renseigner lors du déploiement client)_
