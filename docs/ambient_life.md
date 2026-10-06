# Faune d'ambiance : `AmbientLife`

## Ce que voit le joueur
- **Papillons** (orange, jaunes, blancs, bleus) qui virevoltent au-dessus de l'herbe, avec une
  petite ombre au sol. Ils s'écartent quand le joueur approche.
- **Oiseaux au sol** :
  - le **fody rouge** et le **martin** picorent et sautillent ;
  - à l'approche du joueur (environ 70 px), ils s'envolent, puis reviennent se poser ailleurs
    8 à 20 s plus tard, jamais à côté de lui ;
  - dans les rizières, des **aigrettes** (vorompotsy), plus grandes, marchent lentement dans
    les bassins.
- **Vols de passage** : toutes les 25 à 60 s, 4 à 7 oiseaux traversent le ciel en V, avec leurs
  ombres au sol.
- **La nuit** : papillons et oiseaux partent dormir, aucun vol ne passe, et des **lucioles**
  apparaissent au-dessus de l'herbe.

## Détails techniques
- **Purement décoratif** : pas de collision, rien dans la simulation, rien dans la sauvegarde.
  Tout est recréé au chargement de la zone.
- **`environment/ambient/ambient_life.gd` (`AmbientLife`)** : un nœud à poser dans une zone
  (y-sorté).
  - Exports : `butterfly_count`, `ground_bird_count`, `bird_species` (`fody`, `myna`,
    `egret`), `area` (vide = toute la zone moins `EDGE_MARGIN`), `flocks`, `flock_interval`,
    `firefly_count`.
  - Points d'apparition vérifiés par une requête physique (`intersect_point`, masque 1) :
    jamais dans un mur, un tronc, une clôture ou l'eau profonde. Papillons et lucioles
    apparaissent au-dessus du `GrassLayer`.
  - Suit l'heure via le groupe `night_lights` : `set_night()`, `is_night()` (seuil 0,6).
- **`butterfly.gd`** : errance autour de son point de départ, fuite à l'approche
  (`FLEE_DISTANCE`), `z_index = 3`.
- **`ambient_bird.gd` (`AmbientBird`)** :
  - états `GROUND`, `FLEEING`, `AWAY`, `LANDING`, `FLOCK` ;
  - table `SPECIES` (couleurs, taille, cou) ;
  - origine = l'ombre au sol (y-sort), corps dessiné `_height` px au-dessus ;
  - `go_to_roost()` à la nuit ; pas d'atterrissage tant qu'il fait nuit.
- **`firefly.gd`** : lueur pulsée en *unshaded*, visible seulement la nuit.
- **Placement** :
  - village : un `AmbientLife` (10 papillons, 8 oiseaux) ;
  - rizières : un `AmbientLife` général, plus `Aigrettes` (5 aigrettes limitées aux bassins,
    sans vols).

## À savoir
- Aucun son pour l'instant (chants, battements d'ailes) : à ajouter quand il y aura des
  fichiers audio.
- Tous les animaux sont dessinés par le code (provisoire). Ils pourront être remplacés par des
  sprites sans changer leur comportement.
