# Flux : Calcul quotidien des statuts documents

## Informations générales

| Champ | Valeur |
|---|---|
| Nom | FRS — Calcul statuts quotidien |
| Déclencheur | Planifié — tous les jours à 08h00 |
| Connecteurs | SharePoint |
| Licence requise | Standard (incluse M365) |

---

## Logique métier

```
Chaque jour à 08h00 :

Pour chaque document dans la liste Documents où :
  EstCourant = Oui
  ET Statut ≠ Obsolète
  ET Statut ≠ Manquant

  Calculer : DiffJours = DateExpiration - Aujourd'hui

  Si DateExpiration est vide → ne rien faire (document sans expiration)

  Si DiffJours < 0        → Statut = "Expiré"
  Si DiffJours <= 7       → Statut = "Expire bientôt"  (si Alerte_J7 = Oui sur le type)
  Si DiffJours <= 30      → Statut = "Expire bientôt"  (si Alerte_J30 = Oui sur le type)
  Si DiffJours <= 90      → Statut = "Expire bientôt"  (si Alerte_J90 = Oui sur le type)
  Sinon                   → Statut = "Valide"
```

---

## Construction dans Power Automate

### Étape 1 — Déclencheur
- Type : **Récurrence**
- Fréquence : **Jour**
- Intervalle : **1**
- Heure : **08:00:00**
- Fuseau horaire : _(fuseau du client)_

### Étape 2 — Obtenir tous les documents actifs
- Action : **Obtenir des éléments** (SharePoint)
- Site : `[URL_SITE]`
- Nom de liste : `Documents`
- Requête de filtre (ODATA) :
  ```
  EstCourant eq 1 and Statut ne 'Obsolète' and Statut ne 'Manquant'
  ```
- Développer les champs : `TypeDocument/AlerteJ90,TypeDocument/AlerteJ30,TypeDocument/AlerteJ7`

### Étape 3 — Boucle sur chaque document
- Action : **Appliquer à chacun** (Apply to each)
- Entrée : résultat de l'étape 2

### Étape 4 (dans la boucle) — Calculer la différence de jours
- Action : **Initialiser une variable** (une seule fois, avant la boucle) → `varDiffJours` (Integer)
- Dans la boucle, action **Définir une variable** :
  ```
  variables('varDiffJours') =
    div(
      sub(
        ticks(items('Apply_to_each')?['DateExpiration']),
        ticks(utcNow())
      ),
      864000000000
    )
  ```
  _(Formule Power Automate : conversion de ticks en jours)_

### Étape 5 (dans la boucle) — Déterminer le nouveau statut
- Action : **Initialiser variable** `varNouveauStatut` (String) = `"Valide"`
- Conditions imbriquées :

```
SI DateExpiration est null ou vide
  → Ne rien faire (Skip)
SINON
  SI varDiffJours < 0
    → varNouveauStatut = "Expiré"
  SINON SI varDiffJours <= 7 ET TypeDocument/AlerteJ7 = true
    → varNouveauStatut = "Expire bientôt"
  SINON SI varDiffJours <= 30 ET TypeDocument/AlerteJ30 = true
    → varNouveauStatut = "Expire bientôt"
  SINON SI varDiffJours <= 90 ET TypeDocument/AlerteJ90 = true
    → varNouveauStatut = "Expire bientôt"
  SINON
    → varNouveauStatut = "Valide"
```

### Étape 6 (dans la boucle) — Mettre à jour si le statut a changé
- Condition : `variables('varNouveauStatut') ne items('Apply_to_each')?['Statut']`
- Si VRAI → Action **Mettre à jour l'élément** (SharePoint) :
  - Liste : `Documents`
  - ID : `items('Apply_to_each')?['ID']`
  - Statut : `variables('varNouveauStatut')`

---

## Notes importantes

- Ne jamais modifier le statut d'un document `Obsolète` ou `Manquant` dans ce flux
- Ce flux doit tourner **avant** le flux d'alertes (décaler l'heure d'alertes à 08h30)
- Tester sur un environnement de développement avant de déployer en production
