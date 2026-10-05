# fiainana-kely

Jeu Godot 4.3 (GDScript, renderer GL Compatibility), ferme/village malgache.
Scène principale : `res://world/world.tscn`.

## Commandes
- Godot : `E:/DEV/Game/Godot_v4.3-stable_win64.exe~1/Godot_v4.3-stable_win64_console.exe`
- Tests (headless) : `<godot> --headless --path . --script res://tests/<fichier>.gd`
  - `run_tests.gd` : tests unitaires de la simulation
  - `smoke_test_world.gd`, `zone_wiring_test.gd`, `integration_test_farm.gd` : tests d'intégration
- En mode `--script`, les autoloads (AudioManager, UIEvents…) ne sont pas chargés : les erreurs
  « Identifier not found » qui en découlent ne viennent pas forcément du code testé.

## Conventions
- Textes affichés au joueur : en français. Code et commentaires : en anglais.
- Contenu data-driven (villages, zones, maisons) : un village aujourd'hui, jusqu'à 7 plus tard.
- Grille : cases de 48 px. Les nœuds posés sur la carte (FarmView, champs…) doivent tomber sur
  la grille du sol (`GroundLayer` est à `(1, -1)`).

## Pièges
- Scripts sans `@tool` : leur `_ready()` ne s'exécute pas dans l'éditeur. Les UI (CanvasLayer,
  Panel…) doivent être `visible = false` directement dans la .tscn.
- Terrains (`farm_tileset.tres`) : un bit de voisinage « pas de voisin » doit rester vide, jamais
  0 (= Dirt). Sinon `set_cells_terrain_connect()` casse les champs au runtime.
- Si Godot est ouvert, une modification de .tscn/.tres faite hors éditeur peut être écrasée :
  recharger le projet avant d'enregistrer.

## Règles
- Ne pas commit sans demande explicite.

## Réponses
- Répondre en français.
- Pour toute feature, raisonner aussi en game design : impact sur la boucle de jeu,
  la progression, l'économie, le ressenti du joueur. Proposer des alternatives si besoin.
- Côté Godot : privilégier les pratiques idiomatiques 4.3 (scènes, signaux, Resources,
  @tool pour l'éditeur) et expliquer pourquoi une approche est meilleure.
