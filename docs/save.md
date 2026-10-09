# Sauvegarde et parties : `SaveController`, `SaveSlots`

## Ce que voit le joueur
- **3 parties** (emplacements), choisies depuis l'écran d'accueil (voir `home_screen.md`) :
  « Continuer » ouvre la liste des parties, « Nouveau jeu » en commence une dans le premier
  emplacement libre.
  - Dans la liste, une partie en cours affiche la saison, le jour et l'année atteints, l'argent, le temps
    de jeu et la date de la dernière sauvegarde. Boutons « Continuer » et « Supprimer ».
    Supprimer demande un second appui (« Vraiment ? »).
  - Un emplacement libre affiche « Nouvelle partie ».
- **La partie se sauvegarde quand le joueur va se coucher**, et seulement à ce moment
  (après le repas du soir, sur « Dormir » - voir `evening.md`) :
  - « Bonne nuit ! La partie est sauvegardée. » au réveil ;
  - une nouvelle partie est sauvegardée dès son début, pour apparaître dans la liste.
- **Quitter pendant la journée** (menu pause : « Menu principal » ou « Quitter ») ramène au
  matin de cette journée. Le bouton prévient d'abord (« Sans sauvegarder ? Confirmer ») et
  il faut appuyer une seconde fois.
- Il n'y a plus de bouton « Sauvegarder » dans le menu pause.

Côté game design :
- **Pas de rechargement pour tricher** : on ne peut pas rejouer un tournoi de coqs, une
  récolte ou une échéance d'écolage en rechargeant. Leurs résultats comptent.
- **Le coucher devient un rituel** : finir sa journée, c'est aussi la mettre à l'abri. On
  ne perd jamais plus d'une journée.
- **Plusieurs parties, pas plusieurs moments** : les emplacements servent à recommencer une
  ferme ou à partager le jeu, pas à revenir en arrière.

## Détails techniques
**Fichiers : `SaveSlots`** (`systems/save/save_slots.gd`, `RefCounted`, tout en statique)
- `SLOT_COUNT` (3). `dir` (`user://saves/`) contient `slot_1.json` à `slot_3.json`.
- **Écriture sûre** (`write`) :
  - on écrit d'abord `<fichier>.tmp` ;
  - la sauvegarde précédente devient `<fichier>.bak` (la veille) ;
  - puis le `.tmp` prend la place du fichier.
  - Un plantage pendant l'écriture ne détruit donc jamais la partie.
- `read` lit le fichier, ou le `.bak` s'il est absent ou illisible.
- `read_summary` donne le résumé de la liste des parties : jour, argent, temps de jeu, date de
  sauvegarde. Pour une sauvegarde plus ancienne, il prend ce qu'elle contient.
- `exists`, `delete`.
- `current` : l'emplacement joué, choisi sur l'écran d'accueil. -1 = aucun : une partie jamais
  sauvegardée (tests, `world.tscn` lancé seul avec F6).
- `migrate_legacy()` : l'ancien `user://savegame.json` (`legacy_path`) devient la partie 1,
  si elle est libre. L'ancien fichier est gardé sous le nom `savegame.json.migrated`.
- Les tests redirigent `dir` et `legacy_path` vers un dossier de test. Ils ne touchent
  jamais aux sauvegardes du joueur.

**Contenu : `SaveController`** (`Gameplay/SaveController`)
- `setup(..., slot)` : `world.gd` lui passe `SaveSlots.current`.
- `save_game()` écrit l'état de la simulation, la zone, le point de retour, la position du
  joueur et un `"summary"`. Il ne fait rien sans emplacement.
- `load_game()` relit la sauvegarde, avec les migrations de format (`SAVE_VERSION`, étapes
  `_migrate_to_vN`, inchangées).
- **Au coucher** : `WorldManager.slept` (émis par `WorldManager.sleep()`, après
  `advance_day()` et le placement au `WakeSpot`) déclenche `save_game()`, puis `night_saved(saved)`. C'est `world.gd` qui
  affiche la notification : `SaveController` n'utilise pas d'autoload, pour que ses
  migrations restent testables en mode `--script`.
- Le temps de jeu est compté dans `_process`, qui s'arrête quand le jeu est en pause.
- **Développement seulement** (`OS.is_debug_build()`) : F5 sauvegarde et F9 recharge à
  tout moment (actions `save_game` et `load_game`).

**Liste des parties : `SaveSlotsPanel`** (`ui/home/`, sur l'écran d'accueil - voir
`home_screen.md`)
- Une carte par emplacement, d'après `SaveSlots.read_summary`. Choisir une partie appelle
  `HomeScreen.play(slot)`, qui fixe `SaveSlots.current` et ouvre `world.tscn`. Le monde
  charge la partie, ou en commence une nouvelle et la sauvegarde aussitôt.
- Retour depuis le jeu : `PauseMenu.title_requested` → l'écran d'accueil.

**Menu pause** (`ui/pause_menu.gd`)
- Boutons : Continuer, Menu principal, Langue, Quitter. Signaux `title_requested` et
  `quit_requested`.
- Quitter et Menu principal demandent confirmation (`_confirm`).

**Tests**
- `run_tests.gd` :
  - une sauvegarde par emplacement et son résumé ;
  - la copie de la veille, lue si la sauvegarde est corrompue ;
  - la suppression ;
  - la reprise de l'ancienne sauvegarde.
- `behaviour_test.gd` :
  - se coucher sauvegarde le nouveau matin et le dit ;
  - recharger ramène à ce matin ;
  - la liste montre les 3 parties et demande avant de supprimer ;
  - le menu pause demande avant de partir.
- **Les tests d'intégration** lancent `world.tscn` sans emplacement : ils jouent une
  partie neuve et ne lisent plus la sauvegarde de la machine.

## À savoir
- **Pas de sauvegarde à la fermeture** de la fenêtre : on reprend au dernier coucher, comme
  avec « Quitter ».
- **Pistes** :
  - un récapitulatif de la journée au coucher (récoltes, ventes, amitié) ;
  - nommer sa ferme à la création d'une partie ;
  - une sauvegarde de reprise à la sortie, effacée au premier chargement, pour quitter en
    pleine journée sans tout perdre et sans pouvoir tricher.
- Les textes nouveaux (écran d'accueil, liste des parties, menu pause) ne sont pas encore dans
  `localization/translations.csv` : en malgache et en anglais, ils s'affichent en
  français.
