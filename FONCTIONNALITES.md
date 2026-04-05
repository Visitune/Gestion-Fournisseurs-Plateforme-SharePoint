# Plateforme Gestion Fournisseurs — Spécification Fonctionnelle

> Ce document décrit **ce que fait** la plateforme du point de vue de ses utilisateurs.
> Aucun outil technique n'est mentionné. Ce document est lisible par n'importe qui.

---

## Objet du système

La plateforme permet à une équipe Qualité de **suivre en temps réel la conformité documentaire de ses fournisseurs** : savoir quels documents sont valides, lesquels ont expiré, lesquels manquent, et agir en conséquence sans travail manuel de tri ou de relance.

Elle répond à une contrainte réglementaire des référentiels agroalimentaires (IFS, BRC, FSSC 22000) : toute approbation d'un fournisseur repose sur une liste de documents à jour, avec des durées de validité contrôlées.

---

## Les utilisateurs

| Rôle | Qui | Ce qu'il fait dans la plateforme |
|---|---|---|
| **Responsable Qualité** | Équipe interne | Valide les documents, suit les échéances, pilote les relances |
| **Responsable Achats** | Équipe interne | Consulte les statuts fournisseurs, suit les approbations |
| **Contact Qualité fournisseur** | Externe | Envoie ses documents, reçoit les accusés de réception et les relances |

---

## Les objets gérés

### Le fournisseur

Chaque fournisseur a une fiche avec :
- Son nom, son code interne, son type (producteur, broker, façonnier…)
- Son pays, son email de contact qualité
- Son **statut d'approbation** : en cours, approuvé, suspendu ou disqualifié
- Son **score de conformité** : pourcentage calculé automatiquement selon l'état de ses documents

### La matière première

Chaque matière première achetée a une fiche avec :
- Son nom, son code ressource, sa catégorie, son niveau de criticité

### Le lien Fournisseur × Matière

Quand un fournisseur livre une matière spécifique, un lien est créé entre les deux. Certains documents s'appliquent à ce couple précis (ex : la Fiche Technique d'un ingrédient chez un fournisseur donné).

### Le document

La fiche centrale. Pour chaque document géré, la plateforme enregistre :
- Le fournisseur concerné (et éventuellement la matière première)
- Le type de document (Fiche Technique, Certificat, CDC…)
- Le statut : Manquant, En attente de validation, Valide, Expire bientôt, Expiré, Obsolète
- Les dates d'émission, d'expiration, de réception, de validation
- Qui l'a validé
- La version (la plateforme conserve l'historique des versions précédentes)
- Un lien vers le fichier lui-même
- Un indicateur "document actif" : une seule version est active à la fois

### Le type de document

Chaque type a ses propres règles, définies par le client :
- À qui il s'applique : au fournisseur seul, à la matière seule, ou au couple fournisseur × matière
- Sa durée de validité (en jours)
- S'il est obligatoire pour qu'un fournisseur soit approuvé
- À quel horizon envoyer des alertes (90 jours avant, 30 jours, 7 jours)

---

## Ce que le système fait automatiquement

### Calcul des statuts (chaque matin)

Chaque matin, la plateforme passe en revue tous les documents actifs. Elle compare la date d'expiration à la date du jour et met à jour le statut :

| Situation | Statut attribué |
|---|---|
| Document absent de la checklist | Manquant |
| Document déposé, pas encore validé | En attente de validation |
| Date d'expiration > aujourd'hui + 30 jours | Valide |
| Date d'expiration dans moins de 90 jours | Expire bientôt |
| Date d'expiration dans moins de 30 jours | Expire bientôt (urgence) |
| Date d'expiration dans moins de 7 jours | Expire bientôt (critique) |
| Date d'expiration dépassée | Expiré |
| Remplacé par une version plus récente | Obsolète |

### Alertes automatiques par email

En même temps que le calcul des statuts, des emails partent automatiquement :
- À l'équipe Qualité : la liste des documents qui expirent dans les horizons définis
- Au fournisseur concerné (si configuré) : un rappel à J-30 et J-7 avec les documents à renouveler

Les horizons d'alerte (90 / 30 / 7 jours) sont configurables par type de document.

### Réception d'un document envoyé par un fournisseur

Quand un fournisseur envoie un document :
- Le fichier est rangé automatiquement au bon endroit
- Une fiche document est créée avec les bonnes informations (fournisseur, type, date de réception)
- L'ancienne version est archivée (conservée mais marquée comme obsolète)
- L'équipe Qualité est notifiée par email
- Le fournisseur reçoit un accusé de réception avec le numéro de dossier

### Génération de la checklist à la création d'un fournisseur

Quand un nouveau fournisseur est ajouté, la plateforme crée automatiquement les fiches "Manquant" pour chaque document obligatoire qui lui correspond. L'équipe Qualité voit immédiatement ce qui manque sans avoir à le saisir manuellement.

---

## Ce que l'équipe Qualité fait manuellement

### Valider ou rejeter un document

Quand un document est en statut "En attente de validation", le responsable :
1. Consulte le fichier
2. Saisit la date d'émission du document
3. Change le statut sur "Valide" (ou "Non conforme" avec un commentaire)
4. La date d'expiration est calculée automatiquement selon la durée de validité du type

### Relancer un fournisseur

Depuis la liste des fournisseurs, le responsable peut déclencher une relance en un clic. Un email personnalisé est envoyé au fournisseur avec :
- La liste de ses documents manquants ou expirés
- Les délais concernés
- L'adresse d'envoi pour y remédier

### Approuver ou suspendre un fournisseur

Le responsable change manuellement le statut d'approbation d'un fournisseur. Cela n'a pas d'effet automatique sur les documents — c'est une décision humaine.

---

## Ce que le fournisseur fait (externe)

Le fournisseur n'a accès à aucune interface interne. Son seul point d'interaction est l'envoi de documents.

### Envoyer un document

Il envoie un email à l'adresse dédiée de son client, en respectant une convention simple dans l'objet de l'email (son code fournisseur + le code du type de document).

Il peut envoyer depuis n'importe quelle boîte email. Il n'a pas besoin de créer de compte ni d'accéder à un portail.

### Recevoir un accusé de réception

Dans les secondes qui suivent, il reçoit un email confirmant :
- Quel document a été reçu
- Son numéro de dossier interne
- Le statut : en attente de validation

### Recevoir une relance

Quand des documents arrivent à expiration, il peut recevoir un email de relance automatique ou manuel, listant ce qu'il doit fournir.

---

## Les vues de l'équipe Qualité

La plateforme propose plusieurs vues filtrées, accessibles directement sans manipulation :

| Vue | Ce qu'elle montre | Utilisation |
|---|---|---|
| **Expirés** | Tous les documents courants dont la date est dépassée | Priorisation des actions urgentes |
| **Expire bientôt** | Documents courants qui expirent dans les 90 prochains jours | Anticipation des relances |
| **En attente de validation** | Documents reçus mais pas encore traités | File de travail quotidienne |
| **Tous les documents courants** | Vue complète de l'état actuel, un document par ligne | Audit global |
| **Par fournisseur** | Filtrage sur un fournisseur pour voir toute sa conformité | Revue fournisseur |

---

## La vue simplifiée du responsable Qualité — ce qu'il voit chaque jour

**Le matin** : il reçoit un email récapitulatif avec trois chiffres : combien de documents expirés, combien expirent bientôt, combien attendent sa validation.

**En cours de journée** :
- Il ouvre la vue "En attente de validation" et traite les documents reçus la veille
- Il consulte la vue "Expirés" et relance les fournisseurs concernés en un clic
- Il peut rechercher n'importe quel fournisseur et voir instantanément l'état de tous ses documents

**Ce qu'il ne fait plus manuellement** :
- Aller chercher les emails des fournisseurs et les ranger
- Calculer les dates d'expiration
- Générer les listes de documents manquants
- Rédiger les emails de relance
- Mettre à jour les tableaux Excel de suivi

---

## Paramétrage par client

Chaque client configure la plateforme selon ses pratiques avant le démarrage :

**Les types de documents** : les équipes définissent exactement quels documents elles gèrent, avec pour chacun :
- Son nom tel qu'il apparaît dans leurs processus
- Sa durée de validité
- S'il est obligatoire pour l'approbation
- À quel(s) niveau il s'applique (fournisseur seul / matière première / couple fournisseur+matière)
- Quand envoyer les alertes

**Le niveau de suivi** : certains clients suivent les documents uniquement par fournisseur (simple). D'autres les suivent par source d'approvisionnement, c'est-à-dire par couple fournisseur × matière (plus précis, requis pour certaines certifications).

**Les destinataires des alertes** : qui reçoit les alertes J-90, J-30, J-7 (email Qualité, email Achats, fournisseur).

**Le calcul du score de conformité** : quels documents comptent dans le score et avec quel poids.

---

## Ce que la plateforme ne fait pas

- Elle ne remplace pas le jugement humain pour la validation des documents
- Elle n'évalue pas la qualité du contenu d'un document (c'est le rôle du responsable qui valide)
- Elle ne génère pas les documents elle-même
- Elle ne communique pas directement avec les systèmes ERP ou de certification tiers
- Elle ne gère pas les audits ni les non-conformités produit (périmètre distinct)

---

## Résumé — La valeur pour l'équipe Qualité

Avant la plateforme, le suivi documentaire fournisseurs repose typiquement sur :
- Un ou plusieurs fichiers Excel tenus manuellement
- Des rappels calendrier pour les relances
- Des dossiers partagés sans convention de nommage stable
- Des emails éparpillés entre plusieurs boîtes

Avec la plateforme :
- Un seul endroit pour voir l'état de tous les fournisseurs et tous leurs documents
- Les alertes arrivent automatiquement, sans rien paramétrer au quotidien
- Les relances partent en un clic, personnalisées et complètes
- L'historique des versions est conservé et consultable
- Le score de conformité est calculé en temps réel pour chaque fournisseur
- Un fournisseur peut envoyer ses documents depuis n'importe quelle boîte email, sans compte à créer
