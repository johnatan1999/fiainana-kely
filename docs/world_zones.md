# Monde et zones : `WorldManager` et scènes de zone

## Ce que voit le joueur
**Ferme du joueur (`farm`)**, à l'ouest du village. C'est là que commence une nouvelle
partie :
- la maison du joueur (avec son intérieur), où vit **sa famille** : la mère, le père et la
  petite sœur, avec leur journée (voir `villagers.md`) ;
- le poulailler et ses poules en liberté ;
- les quatre terrains de culture, clôturés, avec leurs panneaux d'achat ;
- le verger de manguiers ;
- à l'ouest des champs, le **parc à zébus** du joueur, son abreuvoir et son pâturage (voir
  `zebus.md`) ;
- au nord, la colline ; à l'est, une haie d'eucalyptus avec la trouée du chemin vers le
  village.

**Village (`village`)**, à l'est de la ferme : les villageois, le marché, leurs maisons, le parc
à zébus, la charrette. Son côté ouest, où se trouvait la ferme, est devenu le **centre du
village** :
- l'**école (sekoly)**, avec son mât et le drapeau malgache, et un **terrain de foot (kianja)**
  devant ;
- le **point d'eau (fantsakana)**, avec ses bidons jaunes, et le **lavoir** en pierres plates ;
- la **gargote (hotely)**, avec ses tables et son foyer à trois pierres ;
- le **kiosque d'épicerie**, près du marché ;
- des panneaux en bois : « SEKOLY », « HOTELY », « ÉPICERIE ».

Les villageois s'en servent : Koto va à l'école, Neny Soa chercher l'eau, les fermiers boivent un
verre à la gargote (voir `villagers.md`).
- Centre habité en **terre rouge** (cours des maisons, place du marché, abords des champs),
  entouré d'une **prairie d'herbe sèche**.
- **Chemins** de deux cases reliant les portes à la place, aux champs et aux sorties nord, est
  et sud.
- **Colline au nord** : un plateau avec une paroi rocheuse sert de limite naturelle. Une trouée
  laisse passer le sentier vers les rizières.
- **Haies et bosquets d'eucalyptus**, manguiers près des maisons et un petit verger.
- **Herbe haute** qui ondule au vent et s'écarte au passage du joueur, avec des brins qui
  jaillissent.
- **Vie autour des maisons** : mortiers (fanoto), jarres, sinibe, tas de bois, nattes de riz
  qui sèche, corde à linge avec lambas, charrette à zébus (sarety), bancs, paniers, foin,
  grenier, remise en brique.

**Bourg (`market_town`)**, au bout du chemin sud du village : le gros bourg de la commune, où l'on
descend le **zoma** (vendredi), jour de marché.
- Au nord, l'arrivée depuis le village, entre des eucalyptus.
- Une **rivière** traverse la carte d'ouest en est, avec des roseaux sur les berges. On ne peut
  pas la passer à gué : un **pont en bois** la franchit.
- En aval du pont, sur la berge sud, un **lavoir** en pierres plates et une corde à linge.
- La **place du marché (tsena)**, en terre rouge, avec un panneau « TSENA » : des étals de
  légumes sous des auvents en lamba, des étals de lambas et de paniers, des poules en cage
  (sobika), des sacs de riz, et **l'étal du collecteur** (Rabe), qui est la boutique du marché du
  zoma (voir `shops.md`). La route nord-sud reste libre au milieu.
- Quatre **maisons** autour de la place (portes fermées), des manguiers pour l'ombre.
- Au nord de la rivière, à gauche de la route, le **marché aux zébus** (tsena omby) : un
  enclos, et le poteau du marchand Ratsimba (voir `zebus.md`).
- Au sud, l'**arrêt du taxi-brousse** : un minibus chargé de bagages, un panneau « TAXI » et des
  sacs de riz. La route continue vers le sud mais s'arrête au bord de la carte.
- Le zoma, les marchands sont à leurs étals et Ravao descend du village. Les autres jours, la
  place est calme : Lalao lave le linge à la rivière, Rabe attend le taxi-brousse (voir
  `villagers.md`).

**Rizières (`rice_fields`)**, au bout du sentier nord du village :
- Un ruisseau en haut, un canal d'irrigation à l'ouest.
- **Rizières en terrasses** : la rizière haute est sur un gradin, accessible par l'est ; la
  rizière basse est en contrebas, sous une paroi rocheuse.
- Deux **terres fertiles** clôturées, des panneaux d'achat, une cabane, des gerbes de riz et une
  charrette.
- La **rizière des voisins**, à droite de la cabane, où Rakoto et Naivo repiquent puis
  moissonnent le riz, et où le joueur peut les aider (voir `villagers.md`). Décor seulement, non achetable. Les trois eucalyptus ouest de la haie sud
  (`Hedge_South_3_*`) ont été retirés pour qu'on la voie depuis le chemin.

## Détails techniques
**Zones**
- Chaque zone est déclarée par un `ZoneData` dans `data/world_zones/`, découvert
  automatiquement par `WorldManager`.
- `WorldManager.change_zone()` **retire l'ancienne zone de l'arbre** avant de la libérer : sans
  ça, ses murs restaient dans l'espace physique jusqu'à la fin de l'image, et le joueur, posé
  au point d'arrivée, pouvait en être éjecté (la colline du village chevauche l'arrivée du
  bourg, ce qui le renvoyait au village). Conséquence : un nœud de zone branché sur la
  simulation doit se débrancher en sortant de l'arbre (`FarmView._exit_tree`).
- `ZoneRoot` (`world/zone_root.gd`) : la taille de la zone vient du `GroundLayer` peint.
  Exports : `bgm`, `camera_zoom` (0.9 par défaut en extérieur, soit environ 27 × 15 cases visibles ;
  1.4 dans les intérieurs), `indoor`.
- **Transitions** (vérifiées par `tests/zone_wiring_test.gd`, et à pied par
  `behaviour_test.gd`) :
  - village ↔ rizières : `ToRiceFields` en haut du sentier nord du village (vers
    `SpawnFrom_VILLAGE`), `ToVillage` en bas des rizières (vers `SpawnFrom_RICE_FIELDS`) ;
  - village ↔ ferme : `ToFarm` sur le bord ouest du village (vers `SpawnFrom_VILLAGE` de la
    ferme), `ToVillage` sur le bord est de la ferme (vers `SpawnFrom_FARM` du village) ;
  - village ↔ bourg : `ToMarketTown` au bout du chemin sud du village (cases 31 à 34 de la
    dernière rangée, vers `SpawnFrom_VILLAGE` du bourg), `ToVillage` en haut de la route nord
    du bourg (vers `SpawnFrom_MARKET_TOWN` du village).
- **Bourg** : construit par `tools/build_market_town.gd` (avec `--editor`) depuis ses tables.
  - Carte de 44 × 34 cases (2 112 × 1 632 px), grille à l'origine `(0, 0)`. Rivière sur les
    rangées 7 et 8 (`StreamLayer`, tuile ruisseau avec collision), sauf sous le pont (colonnes
    20 à 23) ; terre nue (`DIRT`) pour la route, la place et le chemin du lavoir, herbe
    (terrain « Grass ») partout ailleurs ; herbe haute sur les berges et dans les coins.
  - Le pont (`entities/props/bridge.tscn`) est un `Prop` à `z_index` -7 : il se dessine sur
    l'eau, sous les personnages, et ne bloque rien (ce sont les berges qui bloquent).
  - Décors de la planche `assets/sprites/props/market_town.png` (`gen_market_town.gd`) : `bridge`,
    `market_stall_produce`, `market_stall_cloth`, `bush_taxi`, `rice_sacks`, `reeds`,
    `hen_cages`. L'étal du collecteur est `structures/shop/market_stall_shop.tscn`.
  - La scène n'est construite qu'une fois : l'outil refuse de l'écraser ensuite, sauf avec
    `-- --force` (qui perd les retouches faites dans l'éditeur). Il réécrit en revanche à
    chaque fois les décors, les profils de boutique, le `ZoneData`, et ajoute la sortie sud du
    village si elle manque.
- **Centre du village** : `tools/place_village_center.gd` reconstruit le nœud `VillageCenter`
  depuis sa table.
  - L'école et la gargote sont des modèles de maison existants (`house_small_02`,
    `house_small_01`), porte fermée (`locked`), en attendant de vrais bâtiments.
  - Les décors viennent de la planche `assets/sprites/props/village_center.png`
    (`gen_village_center.gd`) : `water_point`, `washing_stones`, `grocery_kiosk`,
    `eatery_table`, `flagpole`, `football_goal`, `hearth`.
  - Le panneau `signboard` (`Signboard`) écrit son texte (export `text`) avec un `Label`.
- **Découpage ferme / village** (`tools/split_farm.gd`, fait une fois) : les deux zones viennent
  de l'ancienne carte du village, **aux mêmes coordonnées**.
  - La ferme en garde la partie ouest (30 cases, 1 440 px), avec la maison, le poulailler, les
    champs, le verger et les lanternes de la maison et du poulailler.
  - Le village garde tout le reste. Les clôtures des champs y sont retirées.
  - Les sorties de la maison et du poulailler mènent à la ferme, et une nouvelle partie démarre
    à la ferme (`World`).
  - **Sauvegardes v8** (`SaveController._migrate_to_v8`) : les ids, fichiers et nœuds sont
    passés en anglais (`tools/rename_to_english.gd`, fait une fois, avec les tables de la
    migration : `v8_english_name`). La migration convertit la zone `bourg` en
    `market_town`, les ids d'objets et de terrains, les ids des arbres et des rizières des
    voisins et le chemin du point de retour.
  - **Sauvegardes v7** (`SaveController._migrate_to_v7`) : les parcelles du village, les
    manguiers du verger, un retour vers la maison ou le poulailler, et un joueur sauvegardé dans
    l'ouest du village passent à la ferme.

**Couches de tuiles** (ordre de dessin)
| Couche | z_index | Rôle |
|---|---|---|
| `GroundLayer` | -10 | Terre rouge, `GroundLayer` script (taille de zone) |
| `GrassLayer` | -9 | Terrain « Grass » de `farm_tileset.tres` (herbe sèche, bords fondus) |
| `StreamLayer` | -8 | Eau du ruisseau (rizières) et de la rivière (bourg) |
| `ClifLayer` | -8 | Terrain « Clif » de `assets/tileset/cliff_tileset.tres` : plateau, tuiles du bord sud en 1×3 avec paroi et collision |
| `FarmView` / champs | -1 | Sol des champs (voir `farming.md`) |
| `TallGrassLayer` | 0, y-sort | Herbe haute, grille 16 px |
| `FenceLayer` | 0, y-sort | Terrain « Clôture » (mode côtés) de `assets/tileset/fence_tileset.tres` |
| `DecorLayer` | 0, y-sort | Tileset `decor_tileset.tres`, encore vide (buissons à venir) |

- Grille du sol : cases de 48 px, avec une origine à `(1, -1)` dans le village et `(0, 0)`
  dans les rizières et le bourg.
- **Colline du village** : plateau sur les 3 rangées du haut, trouée sur les colonnes 30 à 32.
  `HillWalls` (StaticBody2D) empêche de monter sur le plateau par les côtés de la trouée.
- **Herbe haute** : `environment/grass/tall_grass_layer.gd` (`TallGrassLayer`) et
  `tall_grass.gdshader` (vent, poussée du joueur via `player_position`, bruissements amortis).
  Convention : touffes sur une seule rangée de la planche, posées sur le bord bas.
- **Clôtures** : une case de chemin de ronde entre la clôture et les champs. Les cases
  bloquées par un bâtiment ou un tronc sont retirées.
- **Objets de décor** : `entities/props/*.tscn` avec le script `Prop` (ancrage bas-centre,
  collision limitée à la base). Dessins dans `assets/sprites/props/village_props.png`
  (générés, échelle 0,7 à 0,9) et `assets/tileset/exterior.png`. Rangés sous un nœud `Props`
  y-sorté dans chaque zone.
- **Routes des charrettes** : `Path2D` y-sortés (`CartRoute_East`) avec un `ZebuCart` (voir
  `zebu_cart.md`). La charrette garée de la maison de l'est a été retirée, et ses paniers
  déplacés hors de la route.
- **Arbres** : sous un nœud `Trees` y-sorté (voir `trees.md`). **Lanternes** : sous un nœud
  `NightLights` (voir `day_night.md`). **Faune** : nœuds `AmbientLife` (voir
  `ambient_life.md`).

## À savoir
- Le tracé initial (herbe, chemins, falaises, clôtures, placements d'arbres et d'objets) a
  été généré une seule fois. **Les scènes sont maintenant la référence** et s'éditent à la
  main dans l'éditeur, sur les couches et nœuds décrits plus haut. Les planches provisoires,
  elles, se régénèrent avec `tools/placeholder_art/`.
- La sortie est du village est dessinée mais ne mène nulle part (bord de carte). La sortie sud
  mène au bourg.
- La route sud du bourg et son taxi-brousse sont l'amorce des **autres villages** (jusqu'à 7) :
  le taxi-brousse pourra y emmener le joueur.
- La paroi d'une falaise n'est visible que sur sa face sud, et les côtés du plateau ne bloquent
  pas : c'est ce qui permet d'accéder au gradin des rizières par l'est.
- Herbe haute, clôtures, objets générés, eau et riz sont des **dessins provisoires**. Chaque
  système garde son comportement quand on remplace la planche (voir les conventions de chaque
  fiche).
- Si Godot est ouvert, recharger le projet avant d'enregistrer une scène modifiée hors éditeur.
