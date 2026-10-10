# La forêt et le carnet : `ForestManager`, `Discovery`, `WildAnimal`, `ForageSpot`, `DiscoveryPlace`

## Ce que voit le joueur
- **La forêt (*ala*)** s'ouvre à l'est du village : un panneau « ALA » marque la lisière,
  entre les grands eucalyptus, sous le parc à zébus du village. C'est une zone **sauvage**,
  sans champ :
  - un sentier depuis le village jusqu'à une **clairière** ;
  - un **ruisseau** qui descend de sa **source** (un bassin au nord-est), avec un **gué** là
    où passe le sentier ;
  - des bosquets, de l'herbe haute ;
  - et le **vieil amontana**, un figuier géant, au sud-est.
- **Les animaux à observer** (« Observer : sifaka ») ont chacun **leurs heures et leurs
  saisons**, comme les vrais :

| Animal | Nom malgache | Quand | Où |
|---|---|---|---|
| Sifaka | Simpona | à l'aube (6:00–9:00), toute l'année | dans les arbres, à l'ouest |
| Maki | Maky | l'après-midi (14:00–17:00), en Asotry | dans la clairière |
| Caméléon | Tana | en journée (9:00–16:00), en Asara | sur un buisson |
| Tenrec | Trandraka | la nuit (19:00–2:00), en Asara : il dort tout l'Asotry | au pied d'un arbre |
| Martin-pêcheur | Vintsy | le matin (7:00–11:00), toute l'année | au bord du ruisseau |

  Le sifaka, le maki et le martin-pêcheur se cachent quand il pleut. Ils apparaissent et
  disparaissent en fondu, et bougent un peu (deux images).
- **La cueillette** (« Cueillir : brèdes sauvages ») : une plante cueillie repousse après
  quelques jours, et seulement en sa saison. Ses produits se vendent (rayon nourriture).

| Plante | Nom malgache | Saison | Donne | Repousse |
|---|---|---|---|---|
| Brèdes sauvages | Anamamy | toute l'année | 2 brèdes (600 Ar) | 2 jours |
| Miel sauvage | Tantely | Asotry | 1 miel (4 000 Ar) | 6 jours |
| Ravintsara | Ravintsara | toute l'année | 1 feuille (1 500 Ar) | 4 jours |
| Champignons | Holatra | Asara | 2 champignons (1 800 Ar) | 3 jours |

- **Le carnet (*kahie*)** : un onglet « Carnet » dans le livre de l'inventaire, avec quatre
  pages.
  - **Faune**, **Flore**, **Lieux**, et **Cuisine** (chaque plat, la première fois qu'on le
    cuisine).
  - Une entrée trouvée a son dessin, son texte, le jour où on l'a trouvée et le mot de Fara
    sous son dessin. Une entrée pas encore trouvée reste « ??? », avec un **indice** sur où
    et quand chercher.
  - Chaque nouvelle page s'annonce : « Nouvelle page dans ton carnet : Sifaka (Simpona) -
    Fara l'a dessinée : « Il a l'air de danser ! » (4/17) ».
  - Le soir, Fara parle de ce qu'elle a dessiné.
- **Les lieux se trouvent en y entrant** : la source, le vieil amontana, la clairière.

Côté game design :
- **Le carnet est celui du joueur**, et Fara y dessine tant qu'elle vit à la maison. Si
  elle part un jour (lycée, Tana), le carnet reste, avec ses dessins : un souvenir d'elle.
- **Le coût de l'exploration est le temps** : une matinée en forêt, c'est une matinée sans
  arroser. Il n'y a ni combat ni danger.
- **Les heures et les saisons des animaux** donnent une raison de revenir, et de penser au
  calendrier : le tenrec ne se voit qu'en Asara, la nuit.
- **La forêt nourrit l'économie** sans la déséquilibrer : la cueillette est petite et lente
  à repousser, et le miel, la meilleure, ne vient qu'en saison sèche.

## Détails techniques
**Données : `Discovery`** (`core/data/discovery.gd`, un `.tres` par entrée dans
`data/discoveries/`, id = nom du fichier)
- `category` (`FAUNA`, `FLORA`, `PLACE`), `display_name`, `malagasy_name`, `description`,
  `hint`, `fara_line`.
- Animaux et plantes : `active_from` / `active_to` (minutes, après 1440 = après minuit ;
  égaux = toute la journée), `seasons` (bits de `GameClock.Season`), `shy_of_rain`.
- Plantes : `item_id`, `quantity`, `regrow_days`.
- Le dessin : `sheet_column`, la colonne de sa première case sur `SHEET` (`forest.png`), sur
  la rangée de sa catégorie (-1 : aucun, pour un lieu). `get_drawing(case)` donne l'image
  (`case` 1 : la seconde image de l'animal, la plante cueillie). C'est aussi l'icône du
  carnet.
- `is_active(minute, saison, pluie)`, `is_in_season(saison)`, `load_all()`.
- Les objets cueillis : `data/items/wild_greens.tres`, `honey`, `ravintsara`, `mushroom`
  (catégorie FOOD, vente seulement), dans `ItemDatabase.ITEM_PATHS`.

**Règles : `FarmSimulation`** (testables, sauvegardées)
- Le carnet :
  - `register_discovery()`, `get_discovery_ids()` (par page, puis une entrée
    `"cuisine:<recette>"` par recette) ;
  - `discover(id)` : une seule fois, sinon `false`. Émet `discovery_made`. Entre dans
    `DayLog.discoveries` ;
  - `is_discovered()`, `get_notebook_progress()` (trouvées / total).
- `cook()` découvre la page du plat (`CUISINE_PREFIX`).
- Les animaux : `is_wildlife_active(id)`, `observe(id)` (seulement s'il est là).
- La cueillette : `can_forage(spot, plante)`, `forage(spot, plante)` (l'objet, la
  repousse, la page, `DayLog.add_harvest`). Émet `forage_changed`.
- **Sauvegarde** : `FarmState.discoveries` (id → jour trouvé), `forage` (spot → premier
  jour où il repousse). Une sauvegarde plus ancienne commence avec un carnet vide.

**Monde**
- `WildAnimal` (`entities/forest/wild_animal.gd`, `discovery_id`) : le dessin de
  l'animal (deux images qui alternent), la respiration, `set_present()` avec fondu, l'action
  pour observer.
- `ForageSpot` (`entities/forest/forage_spot.gd`, `discovery_id` ; l'id du spot est le nom
  du nœud) : le dessin prête à cueillir, ou cueillie, `show_state()`.
- Les deux prennent leurs images dans leur `Discovery` : `ForestManager` la leur donne au
  chargement de la zone (`set_discovery()`), et signale un `discovery_id` inconnu.
- `DiscoveryPlace` (`entities/forest/discovery_place.gd`, `Area2D`, `discovery_id`,
  `size`) : y entrer émet `reached`.
- Les dessins : `assets/sprites/props/forest.png` (`tools/placeholder_art/gen_forest.gd`).
  Rangée 0 : les animaux, deux images chacun. Rangée 1 : les plantes, prêtes puis cueillies.
  Densité 2× (nets).

**La zone** : `world/areas/exterior/forest.tscn`, construite par `tools/build_forest.gd`
(avec `--editor`) d'après ses tables : sol, herbe, herbe haute, ruisseau et gué, arbres et
amontana, animaux (`Wildlife`), plantes (`WildPlants`), lieux (`Places`), vie ambiante,
sortie `ToVillage`. Elle crée aussi `data/world_zones/forest.tres` et, au village,
`ToForest`, `SpawnFrom_FOREST` et le panneau `Sign_Forest`. Comme pour le bourg, la scène
ne se reconstruit pas si elle existe (`-- --force` pour la refaire).

**Lien avec le jeu : `ForestManager`** (`systems/forest/`, `Gameplay/ForestManager`)
- Enregistre les entrées.
- Au chargement d'une zone : branche ses animaux, ses plantes et ses lieux.
- Chaque minute (`time_changed`) et à chaque changement de temps : les animaux présents
  ou non. Chaque matin et à chaque cueillette : l'état des plantes.
- Annonce chaque nouvelle page, plats compris.

**Le carnet dans l'inventaire** : `InventoryCatalog.Category.NOTEBOOK`,
`InventoryCatalog.describe_discovery()`. L'onglet « Carnet » (`InventoryUI._add_notebook_tab`)
compte les pages trouvées. Les onglets font maintenant 56 px pour que six tiennent sur la
page.

**Tests**
- `run_tests.gd` :
  - les heures et les saisons des animaux (et la pluie) ;
  - une page par découverte, plats compris ;
  - la repousse des plantes et leur saison ;
  - la sauvegarde.
- `behaviour_test.gd` :
  - la lisière du village mène à la forêt ;
  - le sifaka à l'aube et le tenrec la nuit ;
  - observer et cueillir écrivent des pages ;
  - la clairière se trouve en y entrant ;
  - l'onglet Carnet de l'inventaire.
- `zone_wiring_test.gd` vérifie tout seul les sorties de la nouvelle zone.

## À savoir
- **Ajouter une entrée** : un `.tres` dans `data/discoveries/`, puis l'animal, la plante ou
  le lieu dans la table de `tools/build_forest.gd` (ou à la main dans l'éditeur), et son
  dessin dans `gen_forest.gd`, dont la colonne va dans `sheet_column`. Aucun code à
  toucher.
- **Dessins provisoires** : les animaux et les plantes sont dessinés en code. Les lieux et
  les plats n'ont pas encore d'icône dans le carnet (une couleur à la place). Le grand
  amontana est un manguier agrandi en attendant son dessin.
- **Le carnet ne donne pas encore de récompense** au-delà du plaisir de le remplir. Pistes :
  - une page complète donne un conte (*angano*) de Neny Soa au repas du soir ;
  - une recette avec les produits de la forêt (brèdes sauvages, champignons) ;
  - un titre au village.
- **Pistes** :
  - d'autres quêtes dans la forêt. Le zébu de Rakoto, le sifaka de Koto et la tisane de
    Neny Soa y mènent déjà (voir `quests.md`) ;
  - la pêche dans le ruisseau ;
  - d'autres lieux à découvrir ;
  - des animaux qui fuient si on court.
