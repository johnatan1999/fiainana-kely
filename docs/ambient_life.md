# Faune d'ambiance : `AmbientLife`

## Ce que voit le joueur
- **Papillons** (orange, jaunes, blancs, bleus) qui virevoltent au-dessus de l'herbe, avec une
  petite ombre au sol. Ils s'écartent quand le joueur approche.
- **Oiseaux au sol** :
  - le **fody rouge** et le **martin** picorent et sautillent ;
  - à l'approche du joueur (environ 70 px), ils s'envolent **avec un bruit d'ailes** :
    - s'il y a un arbre à portée, à l'opposé du joueur, ils vont **se cacher dans son
      feuillage** ;
    - sinon, ils filent en accélérant et en montant, et ne disparaissent qu'une fois **sortis
      de l'écran** ;
  - ils reviennent se poser ailleurs 8 à 20 s plus tard, jamais à côté du joueur ;
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
  - `go_to_roost()` à la nuit, sans bruit ; pas d'atterrissage tant qu'il fait nuit ;
  - fuite (`_flee`) :
    - `_find_perch()` cherche l'arbre le plus proche (groupe `WorldTree.GROUP`) à moins de
      `PERCH_SEARCH_DISTANCE`, dans la direction opposée au joueur ;
    - l'oiseau vole jusqu'à `WorldTree.get_perch_position()` (centre de la `FadeArea` du
      feuillage), puis s'efface en `PERCH_FADE_TIME` ;
    - sans arbre : il accélère jusqu'à `FLEE_MAX_SPEED`, monte jusqu'à `FLEE_HEIGHT`, et
      disparaît hors du champ de la caméra ;
    - garde-fou : `FLEE_MAX_TIME`.
- **`firefly.gd`** : lueur pulsée en *unshaded*, visible seulement la nuit.
- **Placement** :
  - village : un `AmbientLife` (10 papillons, 8 oiseaux) ;
  - rizières : un `AmbientLife` général, plus `Aigrettes` (5 aigrettes limitées aux bassins,
    sans vols).
- **Son d'envol** : `AudioManager.play_bird_flight_sfx()`, avec le slot `sfx_bird_flight` →
  `assets/audio/SFX/Audio_SFX_Flying_Bird.wav`.
  - Volume `BIRD_FLIGHT_VOLUME_DB` (-6 dB), hauteur variée de 0,9 à 1,15.
  - Au plus un son toutes les `BIRD_FLIGHT_MIN_INTERVAL` (0,6 s), pour que plusieurs oiseaux
    qui s'envolent ensemble fassent un seul bruit.
  - L'oiseau appelle l'autoload par `get_node_or_null("/root/AudioManager")`, pour rester
    testable en mode `--script`, où il est alors muet.

## À savoir
- Pas encore de chants d'oiseaux d'ambiance : seulement l'envol.
- Tous les animaux sont dessinés par le code (provisoire). Ils pourront être remplacés par des
  sprites sans changer leur comportement.
