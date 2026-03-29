# Flux : Alertes d'expiration J-90 / J-30 / J-7

## Informations générales

| Champ | Valeur |
|---|---|
| Nom | FRS — Alertes expiration |
| Déclencheur | Planifié — tous les jours à 08h30 |
| Connecteurs | SharePoint, Office 365 Outlook |
| Licence requise | Standard (incluse M365) |
| Dépendance | Lancer après `flow_calcul_statuts` (08h00) |

---

## Logique métier

```
Chaque jour à 08h30, pour chaque document actif (DocumentCourant = true) :

  Calculer DiffJours = DateExpiration - Aujourd'hui

  Si DiffJours = 90 ET TypeDocument/AlerteJ90 = Oui
    → Email Qualité + Achats : "Document expirant dans 90 jours"

  Si DiffJours = 30 ET TypeDocument/AlerteJ30 = Oui
    → Email Qualité + Achats + Contact fournisseur : "Document expirant dans 30 jours"

  Si DiffJours = 7 ET TypeDocument/AlerteJ7 = Oui
    → Email Qualité + Achats + Contact fournisseur : "⚠ URGENT — Document expire dans 7 jours"

  Si DiffJours = 0 (aujourd'hui)
    → Email Qualité + Achats : "⛔ Document expiré aujourd'hui"
```

> **Principe** : on envoie l'alerte uniquement le jour exact (J-90, J-30, J-7), pas chaque jour.
> Le statut "Expire bientôt" reste visible dans le tableau de bord sans spammer les emails.

---

## Construction dans Power Automate

### Déclencheur
- Type : **Récurrence**
- Fréquence : **Jour**, Intervalle : **1**, Heure : **08:30:00**

### Étape 1 — Variables globales (initialiser avant les boucles)
```
varAujourdHui    = utcNow()
varEmailQualite  = "qualite@client.fr"
varEmailAchats   = "achats@client.fr"
```

### Étape 2 — Obtenir les documents actifs avec expiration
- Action : **Obtenir des éléments** (SharePoint) — Liste `Documents`
- Filtre ODATA :
  ```
  DocumentCourant eq 1 and DateExpiration ne null and (Statut eq 'Valide' or Statut eq 'Expire bientôt')
  ```
- Développer : `TypeDocument,Fournisseur,MatierePremiere`
- Sélectionner : `ID,Title,DateExpiration,Statut,FournisseurId,TypeDocument/Title,TypeDocument/AlerteJ90,TypeDocument/AlerteJ30,TypeDocument/AlerteJ7,Fournisseur/Title,Fournisseur/EmailContactQualite,MatierePremiere/Title`

### Étape 3 — Boucle sur chaque document
Pour chaque document, calculer `varDiffJours` (voir flux calcul_statuts).

### Étape 4 — Condition J-90
```
SI varDiffJours = 90 ET items()?['TypeDocument/AlerteJ90'] = true
  → Envoyer email (voir template : alerte_expiration.html)
    Destinataires : varEmailQualite ; varEmailAchats
    Sujet : [ALERTE J-90] [TypeDocument] — [Fournisseur] / [Matière]
    Corps : voir template HTML
```

### Étape 5 — Condition J-30
```
SI varDiffJours = 30 ET items()?['TypeDocument/AlerteJ30'] = true
  → Envoyer email
    Destinataires : varEmailQualite ; varEmailAchats ; items()?['Fournisseur/EmailContactQualite']
    Sujet : [ALERTE J-30] [TypeDocument] — [Fournisseur] / [Matière]
```

### Étape 6 — Condition J-7
```
SI varDiffJours = 7 ET items()?['TypeDocument/AlerteJ7'] = true
  → Envoyer email URGENT
    Destinataires : varEmailQualite ; varEmailAchats ; items()?['Fournisseur/EmailContactQualite']
    Sujet : ⚠ URGENT [J-7] [TypeDocument] — [Fournisseur] / [Matière]
```

### Étape 7 — Condition J=0 (expiré aujourd'hui)
```
SI varDiffJours = 0
  → Envoyer email
    Destinataires : varEmailQualite ; varEmailAchats
    Sujet : ⛔ EXPIRÉ AUJOURD'HUI — [TypeDocument] — [Fournisseur] / [Matière]
```

---

## Expressions Power Automate utiles

```
// Calculer les jours entre aujourd'hui et la date d'expiration
div(
  sub(
    ticks(items('Apply_to_each')?['DateExpiration']),
    ticks(utcNow())
  ),
  864000000000
)

// Formater une date en français
formatDateTime(items('Apply_to_each')?['DateExpiration'], 'dd/MM/yyyy')

// Vérifier si un champ est null/vide
empty(items('Apply_to_each')?['DateExpiration'])
```

---

## Regroupement des alertes (optimisation)

Pour éviter de recevoir des emails individuels pour chaque document,
envisager de regrouper les alertes du jour dans un seul email récapitulatif :

```
Étape 1 : Collecter tous les documents J-90 dans un tableau HTML
Étape 2 : Si le tableau n'est pas vide → envoyer 1 email récapitulatif
Étape 3 : Idem pour J-30 et J-7
```

Cette approche est recommandée pour les clients avec > 50 documents actifs.
Elle nécessite l'utilisation de variables tableau (Array) dans Power Automate.
