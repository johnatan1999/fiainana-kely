# Animaux : `AnimalManager` / `Chicken`

## Ce que voit le joueur
- **Au village**, les poules picorent en liberté autour de leur coin.
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
  - **en liberté** (`start_wild` ou `setup_wild`) : placées dans la scène du village, ou
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
- Le poulailler du village est à `(232, 580)`, entre la colline et la maison de l'ouest. Son
  point d'arrivée est `SpawnFrom_CHICKEN_COOP`.
- Une zone sans `Coop` : les poules en liberté continuent simplement de picorer la nuit.
