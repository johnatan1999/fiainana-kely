# Arbres : `TreeManager`

## Ce que voit le joueur
- Des arbres placés à la main : **eucalyptus** (décor, en haies et bosquets) et **manguiers**
  (fruitiers). Chacun a une taille et une orientation un peu différentes.
- Le joueur passe derrière le feuillage, qui devient transparent quand il est dessous. Seul le
  tronc bloque.
- Le **feuillage bouge** : balancement lent, frémissement des feuilles, et réaction plus forte
  quand le joueur passe dessous.
- **Manguier** :
  - en **Asara**, un lot de 2 à 4 mangues mûrit tous les 4 jours ; on les cueille avec E
    (« Cueillir (Mangue) ») ;
  - les mangues non cueillies pourrissent à la fin d'Asara, et rien ne pousse en Asotry ;
  - un arbre découvert en saison est déjà chargé de fruits ;
  - hors saison, le prompt indique « Manguier : fruits dans N jours », « …demain » ou
    « …en Asara ».
- La mangue se vend 800 Ar au marché (catégorie Nourriture, vente seulement).

## Détails techniques
**Données : `TreeData`** (`core/data/tree_data.gd`, `@tool`)
- `id`, `display_name`, `malagasy_name`, `visual_scene`.
- Fruits : `fruit_item_id` (vide = arbre décoratif), `fruit_cycle_days`, `yield_min/max`,
  `fruit_season`.
- Espèces : `data/trees/mango_tree.tres`, `data/trees/eucalyptus.tres`. Les espèces fruitières
  doivent figurer dans `World.TREE_RESOURCES`.

**Arbre placé : `WorldTree`** (`entities/trees/world_tree.tscn`, `@tool`)
- Exports : `tree_data`, `flip`, `size_scale`, **`tree_id`**.
- **`tree_id`** : identité de l'arbre dans la sauvegarde, unique dans sa zone.
  - Donné une fois dans l'éditeur, à la pose de l'arbre (`_ensure_unique_id()`, au format
    `tree_xxxxxxxx`).
  - Un arbre **dupliqué** reçoit un nouvel id : la copie l'aurait sinon hérité.
  - Les arbres posés avant l'existence des ids gardent leur ancien id (`Trees/<nom>`), donc
    les sauvegardes existantes sont conservées.
- Instancie la scène visuelle de l'espèce comme enfant `Visual`, sans propriétaire, donc jamais
  sauvegardée dans la zone. Sans scène visuelle, un `TreeVisual` vide dessine un arbre
  provisoire.
- Émet `interacted`, et reçoit `show_state(prompt, ripe)` de `TreeManager`.

**Apparence : `TreeVisual`** (`entities/trees/tree_visual.gd`, `@tool`)
- États : `Bare` et `Fruiting` (si un état manque, on retombe sur le précédent). Sprites
  ancrés bas-centre comme `CropVisual`.
- Nœuds optionnels : `Trunk` (collision), `FadeArea` (zone de fondu), `Canopy` (ce qui
  s'efface et ondule ; sans `Canopy`, c'est l'arbre entier).
- Exports du dessin provisoire : `placeholder_canopy_color`, `placeholder_fruit_color`,
  `placeholder_scale`, ainsi que `preview_state`.
- Scènes : `entities/trees/mango/mango_visual.tscn`, `entities/trees/eucalyptus/eucalyptus_visual.tscn`.

**Feuillage** : `entities/trees/tree_foliage.gdshader` et `tree_foliage_material.tres`,
appliqués en jeu seulement. Balancement par les sommets, frémissement par une déformation
d'UV, et réaction via l'uniforme global `player_position`.

**Simulation et lien : `TreeManager`** (`systems/tree/tree_manager.gd`)
- À chaque chargement de zone, enregistre les arbres fruitiers dans la simulation, sous l'id
  `"<zone_id>:<tree_id>"`.
- Signale un arbre sans `tree_id` (il utilise alors son chemin dans la scène) et un id en
  double (le deuxième arbre n'est pas enregistré).
- `tests/zone_wiring_test.gd` vérifie que, dans chaque zone, tous les arbres ont un
  `tree_id` et qu'ils sont tous différents.
- `FarmSimulation` : `register_tree`, `can_harvest_tree`, `harvest_tree`,
  `get_tree_days_until_fruit`, signal `tree_changed`. L'avancement se fait chaque jour dans
  `_advance_trees()`.
- `FarmState.trees` est sauvegardé (clé `"trees"`). État par arbre : `TreeState`
  (`fruit_ready`, `days_growing`).

## À savoir
- **Ne jamais modifier un `tree_id` à la main** une fois qu'une sauvegarde peut le
  référencer : l'arbre repartirait de zéro. Renommer ou déplacer le nœud, en revanche, ne
  pose aucun problème.
- Un id généré dans l'éditeur n'est conservé que si la scène est enregistrée. L'éditeur la
  marque comme modifiée pour qu'on y pense.
- Sprite sheet : laisser 1 à 2 px transparents entre les arbres, sinon le frémissement peut
  piocher des pixels de l'arbre voisin.
- **Équilibrage** : 8 manguiers rapportent environ 4 800 Ar par jour en moyenne pendant
  Asara.
