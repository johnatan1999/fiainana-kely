# La forêt et le carnet : `ForestManager`, `Discovery`, `WildAnimal`, `ForageSpot`, `DiscoveryPlace`

## Ce que voit le joueur
- **La forêt (*ala*)** s'ouvre à l'est du village : un panneau « ALA » marque la lisière,
  sous le parc à zébus du village. C'est une **grande forêt fermée**, sans champ, environ
  3,5 écrans de large sur 5 de haut :
  - **un labyrinthe de sentiers** entre des murs de fourré et de grands arbres (des
    eucalyptus et des arbres à larges feuilles). Les couloirs serpentent, se resserrent et
    s'élargissent. Il y a **beaucoup de boucles et peu d'impasses** : on peut s'y égarer un
    moment, pas s'y perdre ;
  - **sous les feuilles, il fait sombre** : la lumière du jour est tamisée et verte. Les
    arbres deviennent transparents quand on passe dessous ;
  - **des clairières** s'ouvrent dans le labyrinthe, où **le soleil tombe en rayons** : la
    grande clairière, trois petites clairières cachées, la source, le vieil amontana. Les
    rayons s'éteignent au crépuscule ;
  - un **ruisseau** descend de sa **source** (un bassin au nord) jusqu'au sud de la forêt :
    il coupe la forêt en deux, et **on ne le traverse qu'au gué** ;
  - le **vieil amontana**, un figuier géant, au fond du labyrinthe, à l'est du ruisseau.
    Personne n'y cueille de fruits : c'est *fady* ;
  - **un sentier de terre battue** relie la lisière à la clairière, au gué et à l'amontana.
    Des branches mènent à **chaque clairière** et à la source. Aux embranchements, un
    **panneau** nomme le lieu : « LOHARANO » (la source), « SIMPONA » (la clairière du
    sifaka), « TANTELY » (celle des ruches), « AMONTANA » au gué. Dans les grands lieux, un
    panneau « TANÀNA » (le village) rappelle que le sentier ramène à la maison. En suivant
    la terre battue, on ne se perd jamais ; hors du sentier, c'est l'aventure ;
  - **au bout des impasses**, des récompenses : des champignons, des brèdes, le caméléon, le
    tenrec ;
  - trois **manguiers** donnent des fruits, dans les clairières.
- **Les animaux à observer** (« Observer : sifaka ») ont chacun **leurs heures et leurs
  saisons**, comme les vrais :

| Animal | Nom malgache | Quand | Où |
|---|---|---|---|
| Sifaka | Simpona | à l'aube (6:00–9:00), toute l'année | dans une clairière cachée, au nord-ouest |
| Maki | Maky | l'après-midi (14:00–17:00), en Asotry | dans la grande clairière |
| Caméléon | Tana | en journée (9:00–16:00), en Asara | au bout d'une impasse |
| Tenrec | Trandraka | la nuit (19:00–2:00), en Asara : il dort tout l'Asotry | au bout d'une impasse |
| Martin-pêcheur | Vintsy | le matin (7:00–11:00), toute l'année | au bord du ruisseau, avant le gué |

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
- **Se sentir dans la forêt** : fermée, sombre, grande, on y avance à vue. Mais c'est un
  jeu cosy : le sentier et les panneaux ramènent toujours quelque part, les boucles évitent
  les longs culs-de-sac, et explorer les impasses est récompensé.
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

**Règles : `NotebookRules` (`simulation.notebook`, voir `simulation.md`)** (testables, sauvegardées)
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

**La zone** : `world/areas/exterior/forest.tscn`, 96×72 cases (4 608×3 456 px), générée
par `tools/build_forest.gd` (avec `--editor`) à partir d'une graine fixe (`SEED`) et de
ses tables :
1. **Le labyrinthe** : un arbre couvrant aléatoire (parcours en profondeur) sur une grille
   de 18×14 pièces (`MAZE_*` : couloirs de 3 cases, murs de 2). Ensuite :
   - `BRAID` (0,9) : presque toutes les impasses s'ouvrent sur une voisine, ce qui crée
     des boucles. Il en reste quelques-unes, pour les récompenses ;
   - `EROSION` : les bords des murs sont rongés ;
   - `BULGE` : le fourré gonfle dans les couloirs, guidé par un bruit, sans jamais les
     réduire à moins de 2 cases ni couper un passage (`_can_close`, le test du « point
     simple »). Plus `BULGE` est haut, moins il y a de renflements ;
   - `_round_corners` : les coins de fourré qui avancent dans l'ouvert (plus de cases
     ouvertes que de fourré autour) sont dégagés, ce qui donne des murs plus ronds et des
     virages plus larges.
2. **Les lieux** (`REGIONS`) sont creusés en ovales irréguliers : la lisière, la
   clairière, la source, le gué, l'amontana, trois petites clairières.
3. **L'eau** : le bassin de la source et le ruisseau (`STREAM_*`), sauf au gué. L'eau
   bloque le joueur.
4. **L'accessibilité** : tout ce qui n'est pas relié à l'arrivée est rebouché, et chaque
   lieu doit être accessible, sinon l'outil s'arrête.
5. **Le sentier** : le plus court chemin (diagonales permises en terrain ouvert) de
   l'arrivée à la clairière, au gué et à l'amontana (`TRAIL_STOPS`). Ensuite, une branche
   vers chaque lieu de `TRAIL_BRANCHES`, depuis le point du sentier le plus proche, avec un
   panneau à l'embranchement. Le tout fait 2 cases de large. Des panneaux (`SIGNS`) sont
   posés dans les lieux, dont les « TANÀNA ».
6. **Les buissons isolés** (`SHRUBS`) dans les espaces ouverts, jamais côte à côte ni près
   du sentier : ils ne bloquent rien.

Calques et nœuds de la scène :
- `ThicketLayer` : une touffe de feuillage par case de mur. C'est une `TileMapLayer`
  triée en profondeur avec le joueur (le pied de la touffe est au bas de la case), avec
  collision.
  - Les cases du bord, ouvertes sur 2 côtés ou plus, reçoivent une touffe plus petite et
    plus ronde (`THICKET_SMALL_FROM`) : les murs n'ont pas un contour carré.
  - Chaque touffe est un peu décalée de sa case (une tuile alternative par décalage,
    `THICKET_JITTER`) : plus de lignes de grille. La collision, elle, reste sur la case.
  - Le jeu de tuiles `assets/tileset/thicket_tileset.tres` est écrit par l'outil. Le
    dessin `thicket.png` (10 variantes de 96×96 : 6 grandes, 4 petites, deux cases de large
    pour se chevaucher) vient de `tools/placeholder_art/gen_thicket.gd`.
- `Trees` : environ 250 arbres sur les bords des murs, surtout côté sud, là où l'on voit
  leur pied. Ce sont des eucalyptus et des `forest_tree` (`data/trees/forest_tree.tres`,
  écrit par l'outil : le dessin du manguier, sans fruits, donc décoratif). S'y ajoutent
  le vieil amontana (décoratif aussi) et trois manguiers fruitiers (`FRUIT_MANGOS`).
- `Sunlight` : un `Sunbeam` par clairière (`environment/lighting/sunbeam.gd`) :
  - une `PointLight2D` chaude éclaircit la clairière par-dessus l'ombre de la zone ;
  - des rayons obliques dessinés en code respirent doucement (redessinés 10 fois par
    seconde) ;
  - il est dans `DayNightController.LIGHT_GROUP` et s'éteint au crépuscule.
- **L'ombre de la canopée** : `ZoneRoot.shade` (`SHADE`), multipliée par
  `DayNightController` à la teinte du ciel.
- `Anchors` : des repères pour d'autres outils (`Tracks`, `LostZebu`, `SpringJar`).
  `tools/place_quest_targets.gd` y pose les cibles des quêtes, qui suivent donc la forêt
  quand elle est regénérée.
- `Wildlife`, `WildPlants`, `Places`, `Props` (roseaux, panneaux), `AmbientLife`, et la
  sortie `ToVillage`.

L'outil crée aussi `data/world_zones/forest.tres` et, au village, `ToForest`,
`SpawnFrom_FOREST` et le panneau `Sign_Forest`. La scène ne se reconstruit pas si elle
existe : `-- --force` la refait, puis il faut relancer `place_quest_targets.gd`.

**Performances** (mesurées, sans synchro verticale, avec la première version de 400
arbres) : environ 7,4 ms par image dans la forêt, contre 4,9 ms au village. Les arbres en
coûtaient environ 1 ms ; les rayons de soleil moins encore depuis qu'ils ne se
redessinent plus à chaque image. Il y a maintenant moins d'arbres.

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
  - la forêt est grande et ombragée, et ses murs de fourré arrêtent le joueur ;
  - le soleil tombe dans la clairière de jour, pas la nuit ;
  - l'onglet Carnet de l'inventaire.
- `zone_wiring_test.gd` vérifie tout seul les sorties de la nouvelle zone.

## À savoir
- **Ajouter une entrée** : un `.tres` dans `data/discoveries/`, puis l'animal, la plante ou
  le lieu dans la table de `tools/build_forest.gd` (`ANIMALS`, `PLANTS` : une région, une
  impasse `dead_end:<n>` ou `stream`), et son dessin dans `gen_forest.gd`, dont la colonne
  va dans `sheet_column`. Aucun code à toucher.
- **Changer la forêt** : modifier les tables ou la graine (`SEED`), puis la reconstruire
  avec `-- --force` et relancer `place_quest_targets.gd`. Une autre graine donne un tout
  autre labyrinthe : les lieux restent à leur place, mais les impasses changent.
- **Régler la difficulté** : `BRAID` (plus haut : moins d'impasses), `BULGE` (plus haut :
  couloirs plus larges), `TRAIL_BRANCHES` (où mène le sentier), `SIGNS`. Une première
  version, avec `BRAID` à 0,55 et `BULGE` à 0,15, était trop difficile : on s'y perdait.
- **Retouches à la main** : possibles dans l'éditeur, mais une reconstruction les efface.
  Mieux vaut régler les tables.
- **L'identifiant des plantes** est leur nom de nœud (`Greens_1`...). Le garder d'une
  reconstruction à l'autre garde leur repousse dans les sauvegardes.
- **Dessins provisoires** : les animaux et les plantes sont dessinés en code. Les lieux et
  les plats n'ont pas encore d'icône dans le carnet (une couleur à la place). Le grand
  amontana est un arbre à larges feuilles agrandi, en attendant son dessin. Le fourré est
  un dessin provisoire en touffes.
- **Pistes pour la forêt** : des bruits d'oiseaux et de feuilles, des feuilles qui
  tombent, une brume le matin, Fara qui note les chemins sur une carte du carnet, une
  deuxième traversée du ruisseau (un tronc couché).
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
