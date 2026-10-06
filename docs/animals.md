# Animaux : `AnimalManager` / `Chicken`

## Ce que voit le joueur
- **Au village**, les poules picorent en liberté autour de leur coin.
- **Vers 18:50 (crépuscule)**, elles se dirigent vers la porte du poulailler, un peu plus vite
  que d'habitude, et entrent une à une. La nuit, la cour est vide, y compris si le joueur
  revient en pleine nuit.
- **Vers 6:20, juste après le réveil**, elles ressortent une par une par la porte et retournent
  à leur coin.
- **Dans le poulailler**, les poules simulées dorment toute la nuit et reprennent leur journée
  au matin (manger, boire, se promener).

## Détails techniques
- **Deux sortes de poules** :
  - **simulées** : créées par `AnimalManager` dans le poulailler intérieur, avec un
    `AnimalState` ;
  - **en liberté** (`start_wild` ou `setup_wild`) : placées dans la scène du village, ou
    décoratives et créées par `WorldManager._spawn_decorative_chickens()`.
- **Suivi de l'heure** : `Chicken` rejoint le groupe `night_lights` et reçoit
  `set_night(amount)` (voir `day_night.md`).
- **État `ROOSTING`** : la poule est rentrée, invisible, sans collision. Dans
  `_process_roosting()`, elle ressort quand `night <= WAKE_AT`, après un délai aléatoire
  (`WAKE_DELAY_MAX`).
- **Seuils** : `ROOST_AT = 0.4` (rentrée), `WAKE_AT = 0.25` (sortie). Autres réglages :
  `HOME_SPEED`, `HOME_STUCK_TIME`, `FADE_TIME`.
- **Trajet du soir** : `_head_home()` marche jusqu'à `Coop.get_door_position()`. Le poulailler
  est trouvé par le groupe `Coop.GROUP` (`"chicken_coops"`), en prenant le plus proche.
- **Pas de recherche de chemin** : une poule bloquée plus de `HOME_STUCK_TIME` « fait le tour »
  hors de vue (`_go_in()` en fondu).
- **Zone chargée de nuit** : le premier `set_night()` fait rentrer les poules instantanément.
- **Écartement entre poules** (`_separation_velocity`) : les poules invisibles sont ignorées,
  pour que celles déjà rentrées ne repoussent pas celles qui arrivent à la porte.
- **Poules simulées la nuit** : elles passent en `SLEEP` tant que `night >= ROOST_AT`.

## À savoir
- Le poulailler du village est à `(232, 580)`, entre la colline et la maison de l'ouest. Son
  point d'arrivée est `SpawnFrom_CHICKEN_COOP`.
- Une zone sans `Coop` : les poules en liberté continuent simplement de picorer la nuit.
