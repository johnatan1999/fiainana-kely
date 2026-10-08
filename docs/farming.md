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
- **Labour aux zébus** : avec la **charrue à zébus** (angadin'omby, 15 000 Ar à l'épicerie du
  village) en main, l'action « Labourer (zébus) » laboure d'un coup **jusqu'à 4 parcelles en
  ligne** devant le joueur.
  - Un attelage de deux zébus apparaît et tire la charrue le long du sillon ; chaque parcelle
    se retourne quand le soc y passe. Le joueur marche derrière, sans pouvoir rien faire
    d'autre ; l'attelage disparaît ensuite.
  - Le sillon s'arrête au bord du champ, à une parcelle déjà labourée ou plantée.
  - Il faut **deux zébus d'au moins 15 jours de croissance** (voir `zebus.md`). Sinon, ou si
    l'attelage a déjà labouré **24 parcelles** aujourd'hui, un message explique pourquoi.
  - Ça marche aussi dans les rizières : labourer la rizière aux zébus est la tradition.
- **Fumure** : le **fumier de zébu** (ramassé au parc, voir `zebus.md`) se tient en main comme
  les graines. L'action « Fumer » l'épand sur une parcelle **labourée ou plantée** : des mottes
  sombres apparaissent sur la terre, et la **prochaine récolte** de la parcelle est **plus
  grosse de moitié** (arrondie au-dessus). Une seule fois par récolte : la récolte consomme le
  fumier.
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
- **Dessin du sol** (terre arable, verrouillée, labourée, mouillée, eau) : le raccord
  automatique des tuiles (`set_cells_terrain_connect`) est coûteux. On ne repeint donc que le
  nécessaire :
  - `FarmView._queue_soil_redraw(plot_id)` ne marque que **le champ qui contient la
    parcelle** (tous les champs sans `plot_id` : chargement, achat) ;
  - le rendu est groupé une fois par image ;
  - `FarmField._paint()` saute un calque dont les cases n'ont pas changé. Quand des cases
    sont seulement ajoutées (labourer, arroser), il ne raccorde que celles-là.

  Avant cette correction, repeindre tous les champs figeait le jeu 250 à 450 ms à chaque
  labour ou arrosage.
- **`FarmLandManager`** distingue deux sortes de « zone » :
  - le **terrain achetable** : `zone_id`, l'id de `FarmZoneData`, par exemple `zone_east` ;
  - la **zone du monde** où il se trouve : `world_zone_id`.

  `register_field(..., world_zone_id)` est appelé par `register_fields_in(zone, world_zone_id)`.
- **Sauvegarde v6** : chaque parcelle sauvegarde sa `"zone"`. `_migrate_to_v6` convertit les
  sauvegardes antérieures, où les rizières étaient à x ≥ 100 dans la grille unique : elles
  deviennent `rice_fields` (x − 100), et toutes les autres parcelles deviennent `village`. La v7
  les fait passer à la ferme (`farm`), où sont maintenant les champs (voir `world_zones.md`).

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

**Labour aux zébus**
- `FarmAction.Type.PLOUGH` (5), outil `data/items/tool_plough.tres` (écrit par
  `tools/build_zebu_market.gd`, vendu à l'épicerie du village).
- Règles (`FarmSimulation`) : `ZEBU_TEAM_SIZE` (2), `ZEBU_WORK_MIN_DAYS` (15), `PLOUGH_REACH`
  (4), `PLOUGH_CELLS_PER_DAY` (24) ; `check_plough()` → `PloughCheck` (`OK`, `NO_TEAM`,
  `TIRED`), `is_ploughable(plot)` (pas de culture, pas encore labourée),
  `can_plough(plot)`, `plough(plot)` (laboure une parcelle et compte dans le quota),
  `get_plough_cells_left()`. `FarmState.plough_cells_today` est sauvegardé et remis à zéro
  chaque matin.
- `FarmingController` : `get_furrow(plot, step)` (le sillon), `_plough_furrow()` qui
  bloque le joueur (`input_enabled`), crée un `PloughTeam` dans la zone, l'avance parcelle
  par parcelle (`walk_to` / `arrived`) et appelle `plough()` à chaque arrivée.
- **`PloughTeam`** (`entities/zebu/plough_team.gd`, construit en code) : la charrue (planche
  `zebu_market.png`, case 3) et deux zébus de la planche des zébus, aux robes des zébus du
  joueur. Son origine est le soc. S'il est libéré en route (changement de zone), il émet
  quand même `arrived` pour ne pas bloquer le contrôleur.

**Fumure**
- `FarmAction.Type.FERTILIZE` (6), objet `manure`. `PlotState.fertilized` (sauvegardé, clé
  optionnelle `"fertilized"`) ; `FarmSimulation.harvest()` multiplie la quantité par
  `MANURE_YIELD_MULTIPLIER` (après les malus d'arrosage et de saison) et remet le drapeau à
  `false`.
- `PlotView` montre les mottes (planche `manure.png`, case 3, à l'échelle d'une case,
  `z_index` -1 : sous la culture et les personnages). `is_manure_shown()`.

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
- Le gain du fumier n'apparaît pas dans le message de récolte (« +3 Maïs ») : il faudrait
  ajouter l'information au signal `crop_harvested`.
- La planche des zébus n'a qu'une vue de profil : en labourant vers le haut ou le bas,
  l'attelage reste de profil.
- Les zébus de l'attelage sont « virtuels » : ceux du parc continuent de paître pendant le
  labour.
- `rice.png` est un dessin provisoire généré. Pour le remplacer, garder la disposition : 4 cases
  de 96×128, plant posé sur le bord bas.
