# fiainana-kely

Jeu Godot 4.3 (GDScript, renderer GL Compatibility), ferme/village malgache.
Scène principale : `res://ui/home/home_screen.tscn` (écran d'accueil : nuit au village,
3 parties, paramètres), qui ouvre `res://world/world.tscn`. Lancé seul (F6), le monde joue une partie neuve, jamais sauvegardée.

## Commandes
- Godot : `E:/DEV/Game/Godot_v4.3-stable_win64.exe~1/Godot_v4.3-stable_win64_console.exe`
- Tests unitaires (simulation pure) : `<godot> --headless --path . --script res://tests/run_tests.gd`
- Tests d'intégration, dans l'environnement complet du jeu (autoloads chargés) :
  `<godot> --headless --fixed-fps 60 --path . res://tests/runner.tscn -- <test>`, avec `<test>` parmi
  `smoke_test_world`, `zone_wiring_test`, `integration_test_farm`, `behaviour_test`.
  Code de sortie 1 si un test échoue, 2 si le script de test ne compile pas, 3 s'il ne se
  termine pas en 10 minutes (bloqué).
  - `--fixed-fps 60` : chaque image avance le jeu de 1/60 s sans attendre l'horloge réelle.
    Même déroulé, bien plus rapide (`behaviour_test` : ~13 s au lieu de ~3 min 30). Ne pas
    l'oublier.
  - `behaviour_test` : comportements du monde (poules, oiseaux, clôtures, falaises, lanternes,
    herbe haute, zébus, villageois, commandes, amitié). À compléter quand un comportement visible est ajouté ou modifié.
- Le mode `--script` ne charge pas les autoloads : n'y lancer que `run_tests.gd`. Tout ce qui
  touche aux scènes passe par `tests/runner.tscn`.
- Planches provisoires : `tools/placeholder_art/` (voir son README).

## Conventions
- Textes affichés au joueur : en français. Code et commentaires : en anglais.
- Tous les identifiants sont en anglais, même pour les notions malgaches : variables, enums,
  fichiers, scènes, nœuds, ids de données (zones, objets, repères). Exemples :
  `Weekday.FRIDAY`, `market_town`, `Hedge_South_1_01`, `tool_spade`. Le français et le
  malgache ne vont que dans les textes affichés (« Zoma », « Angady », « Bourg »). Les noms
  propres des personnages (`rakoto`, `NenySoa`) restent tels quels.
- Contenu data-driven (villages, zones, maisons) : un village aujourd'hui, jusqu'à 7 plus tard.
  La ferme du joueur est une zone à part (`farm`), reliée au village : les villages n'ont pas
  de champs du joueur.
- Règles du jeu : dans la simulation, jamais dans les nœuds. `FarmSimulation` est le hub (état,
  signaux, nuit, sauvegarde), et chaque domaine a son fichier de règles sous
  `systems/simulation/rules/` (`simulation.zebus`, `simulation.quests`...). Voir
  `docs/simulation.md`.
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
- Fichiers renommés ou déplacés hors de l'éditeur (`git mv`) : mettre à jour leurs chemins
  `res://` partout (y compris `source_file` des `.import`, pour garder les uid), puis supprimer
  `.godot/uid_cache.bin` et `.godot/editor/filesystem_cache*` et relancer
  `<godot> --headless --editor --path . --quit`. Sinon le cache garde les anciens chemins
  (ressources introuvables, plantages intermittents à la fermeture).
- Dossiers de données (`data/quests/`, `data/discoveries/`, les zones...) : les lister avec
  `ResourceDir.list()` / `ResourceDir.load_all()` (`core/util/resource_dir.gd`), jamais en
  cherchant les `.tres` avec `DirAccess` : dans le jeu exporté, ils deviennent
  `.tres.remap` et le dossier semblerait vide.
- Son : tout passe par `AudioManager`. Un son arrêté n'est libéré qu'au passage suivant du
  thread audio. À la fermeture, `AudioManager._exit_tree()` arrête tous les lecteurs et
  laisse 120 ms au thread pour les libérer. Sans ça, des sons restent en attente (surtout en
  `--fixed-fps`), fuient, et Godot plante parfois à la fermeture (signal 11, sans trace). Un
  nouveau lecteur audio doit être ajouté à cet arrêt.
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
