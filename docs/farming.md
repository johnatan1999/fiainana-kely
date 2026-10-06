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
- **Récolte** : « +3 Maïs » avec l'icône de la culture apparaît au-dessus de la parcelle, monte
  et s'efface. Si la récolte a été réduite, la raison s'affiche dessous en orange (« peu
  arrosé », « hors saison »).

## Détails techniques
**Une grille par zone**
- Une parcelle est identifiée par **zone du monde + case** : `FarmState.plot_zones`
  (plot_id → id de `ZoneData`) et `plot_positions` (case dans la grille de sa zone).
  Deux zones peuvent donc utiliser les mêmes cases sans conflit.
- **API** : `add_tile`, `remove_tile`, `clear_tile`, `get_plot_id_at`, `set_tile_flooded`
  prennent un `zone_id` ; `get_plot_zone(plot_id)` renvoie la zone d'une parcelle.
  - La **valeur par défaut** `FarmState.DEFAULT_ZONE` (`""`) est **réservée aux tests**,
    qui ne manipulent qu'une seule zone.
  - **Le code du jeu doit toujours passer un vrai `zone_id`.**
- **`FarmView`** reçoit sa zone dans `setup(simulation, zone_id)`, appelé par
  `FarmingController` avec `WorldManager.current_zone_id`. Il n'affiche que les parcelles de
  cette zone.
- **`FarmField.get_cells()`** renvoie des cases locales à la grille de sa zone : la position
  du champ sous `FarmView`, en cases.
- **`FarmLandManager`** distingue deux sortes de « zone » :
  - le **terrain achetable** : `zone_id`, l'id de `FarmZoneData`, par exemple `zone_east` ;
  - la **zone du monde** où il se trouve : `world_zone_id`.

  `register_field(..., world_zone_id)` est appelé par `register_fields_in(zone, world_zone_id)`.
- **Sauvegarde v6** : chaque parcelle sauvegarde sa `"zone"`. `_migrate_to_v6` convertit les
  sauvegardes antérieures, où les rizières étaient à x ≥ 100 dans la grille unique : elles
  deviennent `rice_fields` (x − 100), et toutes les autres parcelles deviennent `village`.

**Rizières**
- `FarmField.flooded` (export) : en jeu, ajoute des couches d'eau (`WaterLayer`,
  `LockedWaterLayer`) au-dessus du sol. Dans l'éditeur, les cases sont teintées en bleu et le
  champ s'appelle « Rizière ».
- `PlotState.flooded` est sauvegardé (clé `"flooded"`) et conservé par `reset()`.
- `FarmLandManager.register_field(kind, cells, zone_data, flooded, world_zone_id)` marque les
  cases, et `FarmSimulation.set_tile_flooded()` les applique.
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

**Retour de récolte**
- `FarmSimulation.crop_harvested(plot_id, crop_id, quantity, under_watered, off_season)` :
  émis par `harvest()`. La simulation donne des faits, pas de texte.
- `FarmView._on_crop_harvested()` (parcelles de sa zone seulement) fait apparaître un
  `HarvestPopup` (`ui/world/harvest_popup.gd`) au-dessus de la parcelle.
- `HarvestPopup.spawn(parent, global_pos, icon, text, note)` : icône et texte, avec une note
  optionnelle. Dessiné en *unshaded* (lisible la nuit), avec `z_index` 50 en absolu. Il monte,
  s'efface et se libère tout seul. Réutilisé par les arbres.

**Riz** : `assets/sprites/crops/rice.png` (4 cases de 96×128, dessinées à double densité) et
`entities/crops/rice/rice_visual.tscn` (échelle 0,5, sans `Blocker`).

**Tileset des champs** : sur les tuiles « Arable » de `farm_tileset.tres`, les bits « pas de
voisin » doivent rester vides (voir `CLAUDE.md`).

## À savoir
- **Ajouter une zone de culture** : un `FarmView` et ses `FarmField` dans la scène de la zone.
  Rien à régler : sa grille est la sienne.
- Pour qu'une culture bloque le joueur à partir d'un stade, ajouter un `StaticBody2D` sous ce
  stade dans sa scène visuelle (voir `corn_visual.tscn`).
- `rice.png` est un dessin provisoire généré. Pour le remplacer, garder la disposition : 4 cases
  de 96×128, plant posé sur le bord bas.
