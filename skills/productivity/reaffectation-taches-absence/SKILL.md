---
name: reaffectation-taches-absence
description: "Produit un plan de continuité pendant une absence de 2 semaines en inventoriant les tâches, en proposant une répartition par collègue, et en signalant les risques de charge ou de compétence."
disable-model-invocation: true
---

# Reaffectation Taches Absence

## Instructions

Je serai en vacances 2 semaines.
Je veux une passation actionnable en masse, avec validation humaine avant exécution.
PHASE 1 - PROPOSITION (AUCUNE EXECUTION)
1) Identifie mes tâches ouvertes prioritaires (Task where OwnerId est mon Id).
2) Classe-les: CRITIQUE / IMPORTANT / STANDARD.
3) Propose une répartition par collègue.
4) Propose les follow-ups à créer:
  - J+1 pour CRITIQUE
  - J+3 pour IMPORTANT
  - J+7 pour STANDARD
5) Affiche un PLAN D’ACTIONS PROPOSÉES avec:
  - Action (REASSIGN / RESCHEDULE) 
  - Justification
  - Nouvel owner proposé
  - Due date proposée
6) Les formations internes doivent être replanifiées et rester à mon nom


Puis demande explicitement:
"Validez-vous l'exécution ? Répondez OUI pour exécuter, NON pour modifier."
PHASE 2 - EXECUTION (UNIQUEMENT SI OUI)
6) Si la réponse est OUI: utilise CRM Assistant pour exécuter les actions proposées. Fais une action à la fois.
7) Si la réponse est NON: attends les modifications utilisateur et régénère le plan.
PHASE 3 - PREUVE
8) Affiche le résultat d’exécution:
  - Action
  - Statut DONE/FAILED
  - Détail erreur si FAILED
9) Fournis les KPI:
  - Nombre proposé
  - Nombre exécuté
  - Nombre en échec
  - % réussite
  - Gain de temps estimé

