# fiainana-kely

Jeu Godot 4.3 (GDScript, renderer GL Compatibility), ferme/village malgache.
Scène principale : `res://world/world.tscn`.

## Commandes
- Godot : `E:/DEV/Game/Godot_v4.3-stable_win64.exe~1/Godot_v4.3-stable_win64_console.exe`
- Tests unitaires (simulation pure) : `<godot> --headless --path . --script res://tests/run_tests.gd`
- Tests d'intégration, dans l'environnement complet du jeu (autoloads chargés) :
  `<godot> --headless --path . res://tests/runner.tscn -- <test>`, avec `<test>` parmi
  `smoke_test_world`, `zone_wiring_test`, `integration_test_farm`, `behaviour_test`.
  Code de sortie 1 si un test échoue.
  - `behaviour_test` : comportements du monde (poules, oiseaux, clôtures, falaises, lanternes,
    herbe haute, zébus, villageois, commandes, amitié). À compléter quand un comportement visible est ajouté ou modifié.
- Le mode `--script` ne charge pas les autoloads : n'y lancer que `run_tests.gd`. Tout ce qui
  touche aux scènes passe par `tests/runner.tscn`.
- Planches provisoires : `tools/placeholder_art/` (voir son README).

## Conventions
- Textes affichés au joueur : en français. Code et commentaires : en anglais.
- Contenu data-driven (villages, zones, maisons) : un village aujourd'hui, jusqu'à 7 plus tard.
  La ferme du joueur est une zone à part (`farm`), reliée au village : les villages n'ont pas
  de champs du joueur.
- Grille : cases de 48 px. Les nœuds posés sur la carte (FarmView, champs…) doivent tomber sur
  la grille du sol (`GroundLayer` est à `(1, -1)`).

## Pièges
- Scripts sans `@tool` : leur `_ready()` ne s'exécute pas dans l'éditeur. Les UI (CanvasLayer,
  Panel…) doivent être `visible = false` directement dans la .tscn.
- Terrains (`farm_tileset.tres`) : un bit de voisinage « pas de voisin » doit rester vide, jamais
  0 (= Dirt). Sinon `set_cells_terrain_connect()` casse les champs au runtime.
- Si Godot est ouvert, une modification de .tscn/.tres faite hors éditeur peut être écrasée :
  recharger le projet avant d'enregistrer.
- Les scènes (.tscn) sont la référence et s'éditent dans l'éditeur. Pas de modification
  textuelle d'une scène au-delà d'une propriété simple : pour générer ou repeindre (tuiles,
  placements), passer par l'API de Godot (`set_cells_terrain_connect`, `PackedScene`…) dans un
  outil versionné sous `tools/`, jamais par un script jetable hors du dépôt.
- Une image régénérée hors de l'éditeur (planches provisoires) n'est réimportée qu'à
  l'ouverture de l'éditeur (ou `<godot> --headless --editor --path . --quit`) : le jeu lancé
  seul affiche encore l'ancienne texture.
- Performance : ne pas reconstruire une interface fermée sur chaque signal (l'inventaire
  change souvent), et ne pas relancer `set_cells_terrain_connect` sur de grandes zones à
  chaque action (lent). Mesurer d'abord (temps par image) avant d'optimiser.
- Un outil qui réenregistre une scène se lance avec `--editor`
  (`<godot> --headless --editor --path . --script res://tools/<outil>.gd`). Sans ce mode,
  Godot ne connaît pas les valeurs par défaut des scripts et écrit toutes les propriétés
  exportées dans la scène.

## Règles
- Ne pas commit sans demande explicite.

## Documentation (`docs/`)
- Après chaque changement de gameplay, de visuel ou de système, mettre à jour la fiche du
  contrôleur/système concerné dans `docs/` (index : `docs/README.md`). Système nouveau : créer
  sa fiche et l'ajouter à l'index.
- Chaque fiche suit le même plan : **Ce que voit le joueur**, puis **Détails techniques**
  (fichiers, nœuds, signaux, réglages exportés, conventions), puis **À savoir** (limites,
  pièges, pistes).
- La fiche décrit l'état actuel : réécrire ce qui a changé plutôt qu'ajouter un historique.

## Réponses
- Répondre en français.
- Pour toute feature, raisonner aussi en game design : impact sur la boucle de jeu,
  la progression, l'économie, le ressenti du joueur. Proposer des alternatives si besoin.
- Côté Godot : privilégier les pratiques idiomatiques 4.3 (scènes, signaux, Resources,
  @tool pour l'éditeur) et expliquer pourquoi une approche est meilleure.
