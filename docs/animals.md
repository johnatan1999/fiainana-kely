# Animaux : `AnimalManager` / `Chicken`

## Ce que voit le joueur
- **À la ferme**, les poules picorent en liberté autour de leur coin.
- **À 18:45**, elles se dirigent vers la porte du poulailler, un peu plus vite
  que d'habitude, et entrent une à une. La nuit, la cour est vide, y compris si le joueur
  revient en pleine nuit.
- **À 6:15, juste après le réveil**, elles ressortent une par une par la porte et retournent
  à leur coin.
- **Dans le poulailler**, les poules simulées dorment toute la nuit et reprennent leur journée
  au matin (manger, boire, se promener).

## Détails techniques
- **Deux sortes de poules** :
  - **simulées** : créées par `AnimalManager` dans le poulailler intérieur, avec un
    `AnimalState` ;
  - **en liberté** (`start_wild` ou `setup_wild`) : placées dans la scène de la ferme, ou
    décoratives et créées par `WorldManager._spawn_decorative_chickens()`.
- **Suivi de l'heure** : `Chicken` rejoint `DayNightController.CLOCK_GROUP` et reçoit
  `set_time_of_day(minute)` (voir `day_night.md`). Elle suit **l'horloge, pas la lumière** :
  retoucher les couleurs du ciel ne change pas ses horaires.
- **Horaires** : `ROOST_MINUTE` (18:45) et `WAKE_MINUTE` (6:15). `Chicken.is_roost_time()`
  dit si l'on est dans les heures de nuit.
- **État `ROOSTING`** : la poule est rentrée, invisible, sans collision. Dans
  `_process_roosting()`, elle ressort à `WAKE_MINUTE`, après un délai aléatoire
  (`WAKE_DELAY_MAX`).
- **Autres réglages** : `HOME_SPEED`, `HOME_STUCK_TIME`, `FADE_TIME`.
- **Fondus de la porte** (`_door_tween`) : un seul à la fois. Une poule qui ressort pendant
  son fondu d'entrée annule l'ancien, sinon il la cacherait de nouveau.
- **Trajet du soir** : `_head_home()` marche jusqu'à `Coop.get_door_position()`. Le poulailler
  est trouvé par le groupe `Coop.GROUP` (`"chicken_coops"`), en prenant le plus proche.
- **Pas de recherche de chemin** : une poule bloquée plus de `HOME_STUCK_TIME` « fait le tour »
  hors de vue (`_go_in()` en fondu).
- **Zone chargée de nuit** : le premier `set_time_of_day()` fait rentrer les poules
  instantanément.
- **Écartement entre poules** (`_separation_velocity`) : les poules invisibles sont ignorées,
  pour que celles déjà rentrées ne repoussent pas celles qui arrivent à la porte.
- **Poules simulées la nuit** : elles passent en `SLEEP` pendant les heures de nuit.

## À savoir
- Le poulailler de la ferme est à `(232, 580)`, sous la colline. Son
  point d'arrivée est `SpawnFrom_CHICKEN_COOP`.
- Une zone sans `Coop` : les poules en liberté continuent simplement de picorer la nuit.
- **Le poulailler grandit** avec les projets de famille (voir `family_projects.md`) : 4,
  puis 8, puis 12 poules (`coop_capacity`). Son visage change aussi (`Coop.set_level`).
  Au niveau 3, les œufs vont directement dans le sac au lieu d'être posés au sol.
- **L'intérieur du poulailler** (`chicken_coop_interior.tscn`) n'est plus une image : c'est
  une pièce construite en code par `CoopInterior`
  (`structures/chicken_coop/coop_interior.gd`), nette à tout zoom, à la taille du niveau
  (`LEVELS` : cases du sol, murs en terre, en ruine ou en briques, nombre de pondoirs).
  - Il en déduit les collisions des murs, la porte de sortie, le point d'arrivée, les
    gamelles (avec leurs images nettes, `coop_bowls.png`), la zone des poules
    (`ChickenArea`) et les limites de la caméra.
  - Il se construit dans son `_ready()`, avant que la caméra ne lise les limites, à partir
    de `CoopInterior.level`, que `FamilyProjectManager` tient à jour.
  - `tools/build_coop_interior.gd` a mis la scène dans cet état.
  - **Agrandir encore** = une ligne dans `LEVELS`. `preview_level` montre un niveau dans
    l'éditeur.
