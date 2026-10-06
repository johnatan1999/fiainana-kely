# Monde et zones : `WorldManager` et scènes de zone

## Ce que voit le joueur
**Village (`village`)**
- Centre habité en **terre rouge** (cours des maisons, place du marché, abords des champs),
  entouré d'une **prairie d'herbe sèche**.
- **Chemins** de deux cases reliant les portes à la place, aux champs et aux sorties nord, est
  et sud.
- **Colline au nord** : un plateau avec une paroi rocheuse sert de limite naturelle. Une trouée
  laisse passer le sentier vers les rizières.
- **Haies et bosquets d'eucalyptus**, manguiers près des maisons et un petit verger.
- **Herbe haute** qui ondule au vent et s'écarte au passage du joueur, avec des brins qui
  jaillissent.
- **Clôtures** autour des champs, avec des portails aux arrivées des chemins.
- **Vie autour des maisons** : mortiers (fanoto), jarres, sinibe, tas de bois, nattes de riz
  qui sèche, corde à linge avec lambas, charrette à zébus (sarety), bancs, paniers, foin,
  grenier, remise en brique.

**Rizières (`rice_fields`)**, au bout du sentier nord du village :
- Un ruisseau en haut, un canal d'irrigation à l'ouest.
- **Rizières en terrasses** : la rizière haute est sur un gradin, accessible par l'est ; la
  rizière basse est en contrebas, sous une paroi rocheuse.
- Deux **terres fertiles** clôturées, des panneaux d'achat, une cabane, des gerbes de riz et une
  charrette.
- La **rizière des voisins**, à droite de la cabane, où Rakoto et Naivo repiquent puis
  moissonnent le riz, et où le joueur peut les aider (voir `villagers.md`). Décor seulement, non achetable. Les trois eucalyptus ouest de la haie sud
  (`Haie_Sud_3_*`) ont été retirés pour qu'on la voie depuis le chemin.

## Détails techniques
**Zones**
- Chaque zone est déclarée par un `ZoneData` dans `data/world_zones/`, découvert
  automatiquement par `WorldManager`.
- `ZoneRoot` (`world/zone_root.gd`) : la taille de la zone vient du `GroundLayer` peint.
  Exports : `bgm`, `camera_zoom` (0.9 par défaut en extérieur, soit environ 27 × 15 cases visibles ;
  1.4 dans les intérieurs), `indoor`.
- **Transitions** : `ToRiceFields` en haut du sentier nord du village, vers
  `SpawnFrom_VILLAGE`, et `ToVillage` en bas des rizières, vers `SpawnFrom_RICE_FIELDS`.
  Vérifiées par `tests/zone_wiring_test.gd`.

**Couches de tuiles** (ordre de dessin)
| Couche | z_index | Rôle |
|---|---|---|
| `GroundLayer` | -10 | Terre rouge, `GroundLayer` script (taille de zone) |
| `GrassLayer` | -9 | Terrain « Grass » de `farm_tileset.tres` (herbe sèche, bords fondus) |
| `StreamLayer` | -8 | Eau du ruisseau (rizières) |
| `ClifLayer` | -8 | Terrain « Clif » de `assets/tileset/cliff_tileset.tres` : plateau, tuiles du bord sud en 1×3 avec paroi et collision |
| `FarmView` / champs | -1 | Sol des champs (voir `farming.md`) |
| `TallGrassLayer` | 0, y-sort | Herbe haute, grille 16 px |
| `FenceLayer` | 0, y-sort | Terrain « Clôture » (mode côtés) de `assets/tileset/fence_tileset.tres` |
| `DecorLayer` | 0, y-sort | Tileset `decor_tileset.tres`, encore vide (buissons à venir) |

- Grille du sol : cases de 48 px, avec une origine à `(1, -1)` dans le village et `(0, 0)`
  dans les rizières.
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
- **Routes des charrettes** : `Path2D` y-sortés (`CartRoute_Est`) avec un `ZebuCart` (voir
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
- Les sorties est et sud du village sont dessinées mais ne mènent nulle part (bord de carte).
- La paroi d'une falaise n'est visible que sur sa face sud, et les côtés du plateau ne bloquent
  pas : c'est ce qui permet d'accéder au gradin des rizières par l'est.
- Herbe haute, clôtures, objets générés, eau et riz sont des **dessins provisoires**. Chaque
  système garde son comportement quand on remplace la planche (voir les conventions de chaque
  fiche).
- Si Godot est ouvert, recharger le projet avant d'enregistrer une scène modifiée hors éditeur.
