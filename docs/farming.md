# Agriculture : `FarmingController`, `FarmView`, `FarmLandManager`

## Ce que voit le joueur
- **Champs** dessinés à la main dans chaque zone, achetables via des panneaux (`FarmZoneSign`).
  Ils sont entourés de **clôtures** avec un chemin de ronde d'une case et des portails (voir
  `world_zones.md`).
- **Rizières** (zone des rizières) : parcelles **toujours irriguées**, sans arrosoir (il n'y
  fait rien), qui n'acceptent **que le riz**. Le riz reste cultivable sur terre sèche (riz
  pluvial).
- **Cultures vivantes** : elles ondulent au vent selon leur hauteur et s'écartent quand le
  joueur les frôle.
- **Réactions aux actions** :
  - labourer : nuage de terre ;
  - planter : nuage de terre, puis la graine apparaît avec un « pop » ;
  - arroser : gouttelettes et rebond du plant ;
  - récolter : le plant sort du sol en s'étirant et disparaît en fondu.
- **Riz** : 4 stades dessinés (jeunes plants repiqués → touffe dorée avec panicules). Il ne
  bloque pas le joueur, qui peut entrer dans une rizière.

## Détails techniques
**Une grille par zone**
- La simulation n'a qu'une seule grille. `FarmView.grid_offset` (export) place chaque zone dans
  sa propre région : le village est à `(0, 0)`, les rizières à `(100, 0)`.
- `FarmField.get_grid_origin()` ajoute le `grid_offset` du parent.
- Un `FarmView` n'affiche que les parcelles de ses propres champs (`_field_cells`).
- Ne pas changer un `grid_offset` une fois des sauvegardes existantes : les parcelles
  sauvegardées ne correspondraient plus.

**Rizières**
- `FarmField.flooded` (export) : en jeu, ajoute des couches d'eau (`WaterLayer`,
  `LockedWaterLayer`) au-dessus du sol. Dans l'éditeur, les cases sont teintées en bleu et le
  champ s'appelle « Rizière ».
- `PlotState.flooded` est sauvegardé (clé `"flooded"`) et conservé par `reset()`.
- `FarmLandManager.register_field(kind, cells, zone_data, flooded)` marque les cellules, et
  `FarmSimulation.set_tile_flooded()` les applique.
- Règles dans `FarmSimulation` :
  - `can_water()` renvoie faux sur une rizière ;
  - `can_plant()` exige `CropData.grows_in_paddy` sur une rizière ;
  - `advance_day()` compte une rizière comme arrosée.
- `rice.tres` : `grows_in_paddy = true`.
- Eau : `environment/water/water.gdshader`, avec `paddy_water_material.tres` (eau boueuse et
  immobile) et `stream_water_material.tres` (eau profonde qui coule).
  `assets/tileset/water_tileset.tres` : tuile `(0,0)` praticable, tuile `(1,0)` solide.

**Mouvement des cultures**
- `entities/crops/crop_sway.gdshader` et `crop_sway_material.tres`, appliqués par `CropVisual`
  à tous les sprites de stade, **en jeu seulement** (sinon le matériau serait sauvegardé dans
  les scènes).
- Le shader s'appuie sur l'ancrage bas-centre de `CropVisual` : sommets du bas à y = 0 (fixes),
  sommets du haut qui bougent.
- Uniforme global **`player_position`** (`[shader_globals]` dans `project.godot`), mis à jour
  par `PlayerController` à chaque image physique.

**Réactions**
- `PlotView.react(action)` : nuages (`CPUParticles2D`), écrasement, cueillette (`_pluck_out`).
- `FarmView.react_to_action(plot_id, action)` relaie, et `FarmingController` appelle après une
  action réussie. Pour la récolte, l'appel se fait **avant** `harvest()`, pour que le plant
  soit arraché au lieu de disparaître.

**Riz** : `assets/sprites/crops/rice.png` (4 cases de 96×128, dessinées à double densité) et
`entities/crops/rice/rice_visual.tscn` (échelle 0,5, sans `Blocker`).

**Tileset des champs** : sur les tuiles « Arable » de `farm_tileset.tres`, les bits « pas de
voisin » doivent rester vides (voir `CLAUDE.md`).

## À savoir
- Pour qu'une culture bloque le joueur à partir d'un stade, ajouter un `StaticBody2D` sous ce
  stade dans sa scène visuelle (voir `corn_visual.tscn`).
- `rice.png` est un dessin provisoire généré. Pour le remplacer, garder la disposition : 4 cases
  de 96×128, plant posé sur le bord bas.
