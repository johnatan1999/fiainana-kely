# Villageois : `Villager`, `VillagerRoads`, `VillagerVisual`

## Ce que voit le joueur
Cinq villageois vivent au village, chacun avec sa journée :

| Villageois | Maison | Sa journée |
|---|---|---|
| **Rakoto**, fermier | ouest | Part aux rizières par le nord à 6:30, revient discuter sur la place à 16:00, rentre à 18:00 |
| **Naivo**, fermier | est | Part aux rizières à 6:15, passe au marché à 15:30, puis sur la place, rentre à 18:15 |
| **Ravao**, marchande | est | Tient son étal au marché de 7:00 à 17:30, avec une pause sur le banc près de chez elle à midi |
| **Neny Soa**, grand-mère | sud | Se promène sur la place le matin, fait la sieste, s'assoit au banc l'après-midi |
| **Koto**, enfant | sud | Joue sur la place le matin et le soir, traîne au marché l'après-midi |

- Ils marchent **sur les chemins de terre**, d'une maison au marché, à la place, à la sortie.
- Ils **sortent de leur porte** le matin et **rentrent** le soir. La nuit, le village est vide.
- **Quand il pleut**, chacun rentre chez soi, sauf la marchande (étal couvert) et les fermiers
  (le riz aime la pluie).
- **En arrivant dans le village**, chacun est déjà où l'heure le veut : personne ne repart de
  chez lui à 15:00.
- **Avec le joueur** :
  - ils sont solides : on les contourne ;
  - si le joueur leur barre le chemin, ils s'arrêtent et attendent ;
  - quand il s'approche, ils se tournent vers lui et le saluent d'une **bulle** (« Des
    légumes frais au marché ! »), au plus une fois toutes les 45 s.

## Détails techniques
### Les données (`data/villagers/<id>.tres`)
- **`VillagerData`** : `display_name`, `look` (`VillagerLook`), `size` (1 = adulte, 0,8 =
  enfant), `home` (le repère de sa porte), `routine`, `greetings` (textes en français,
  passés par `tr()`).
- **`VillagerStop`** (une étape de `routine`) :
  - `hour`, `minute` : l'heure de départ de l'étape ;
  - `spot` : le repère où aller ;
  - `activity` : `STAND` (reste là et regarde autour), `WANDER` (flâne autour), `INSIDE`
    (entre et disparaît : une porte, ou une sortie de zone) ;
  - `rain_proof` : l'étape se fait aussi sous la pluie.
- **`get_stop(minute)`** : l'étape en cours, ou `null` (= à la maison) avant la première. La
  journée va de 6:00 à 2:00 : après minuit, c'est toujours la dernière étape de la veille.
  Terminer donc la journée par une étape `INSIDE` sur `home`.

### Les chemins : `VillagerRoads` (dans la scène de zone)
- Les **routes** sont ses enfants `Line2D`, tracés sur les chemins de terre. Ils sont visibles
  dans l'éditeur et cachés en jeu.
- Les **repères** sont des `Marker2D` sous `Spots` : `Maison_Ouest`, `Maison_Est`,
  `Maison_Sud`, `Marche`, `Place`, `Banc_Est`, `Sortie_Nord`.
- Deux points de route à moins de `MERGE_DISTANCE` (12 px) forment un carrefour.
- Un repère s'accroche au point de route le plus proche.
- Le chemin le plus court se calcule avec un `AStar2D` (`find_path`). Il n'y a pas de
  navmesh : les villageois suivent les chemins, comme de vrais gens.
- `VillagerRoads.of_zone(zone)` : les routes de la zone (même `owner`).

### Le villageois : `entities/villager/villager.tscn` (`Villager`, `CharacterBody2D`)
- **Couche physique « Animals »** (4) : le joueur bute dessus. Il ne masque rien : il suit les
  routes et attend le joueur de lui-même (`BLOCK_DISTANCE`).
- Suit l'**horloge** (`CLOCK_GROUP`) et la **météo** (`WEATHER_GROUP`). À chaque changement
  d'étape, il calcule son chemin depuis où il est.
- Au premier top d'horloge après le chargement de la zone, il se place directement à son
  étape.
- Vitesse `SPEED` : 55 px/s, contre 220 pour le joueur. Une marche de bout en bout du village
  prend environ 30 s, soit une quarantaine de minutes de jeu.
- `is_inside()`, `is_walking()`, `get_spot_name()`.
- `Bubble` : un `Label` au-dessus de la tête (`z_index` 40, absolu), affiché `BUBBLE_TIME`.

### L'apparence : `VillagerVisual`, `VillagerLook`, `VillagerLayer`
- **Planche de base** : `assets/sprites/characters/villager/base_body.png`, un mannequin
  neutre dessiné clair, teinté par la couleur de peau.
  - Densité 2× (affichée à l'échelle 0,5), cases de 128×256, 6 colonnes × 4 rangées.
  - Rangées : **0 bas** (face), **1 gauche**, **2 droite**, **3 haut** (dos).
  - Colonnes : **0–1** repos (respiration), **2–5** marche.
  - **Pieds sur y = 252**, centrés sur x = 64.
  - Repères (y) : tête 62, yeux 80, menton 98, épaules 106, hanches 168, genoux 210, sol 252.
- **Guide de dessin** : `villager_guide.png`, la même grille avec ces lignes, à mettre en
  calque sous le dessin.
- **Calques d'exemple** (`example_*.png`) : `shirt`, `shorts`, `trousers`, `skirt`, `hair`,
  `hair_bun`, `hat` (chapeau de paille).
- `VillagerLayer` : `texture` et `color`.
- `VillagerLook` : `skin_color`, `body` (vide = le mannequin), `layers` (dessinés dans
  l'ordre).
- `VillagerVisual` (`@tool`) : un `Sprite2D` par calque, tous sur la même image.
  - `play(direction, moving)` ;
  - exports `facing` et `walking`, pour vérifier une apparence dans l'éditeur.

### Outils
Les deux se lancent avec `--editor`.
- **`tools/place_villagers.gd`** :
  - construit `villager.tscn` ;
  - écrit les `.tres` **manquants** de `data/villagers/`. Une fois écrit, un villageois se
    modifie dans l'inspecteur ;
  - reconstruit `VillagerRoads` et `Villagers` dans le village, à partir de ses tables.
- **`tools/placeholder_art/gen_villager_base.gd`** : le mannequin, le guide et les calques
  d'exemple. Sa table `SHEETS` donne, pour chaque calque, les parties couvertes et
  l'épaisseur.

### Tests
- `run_tests.gd` : les étapes de la journée (avant la première, entre deux, après minuit).
- `behaviour_test.gd` :
  - placés selon l'heure en arrivant ;
  - départ et retour à la maison ;
  - attente quand le joueur barre la route, et salut ;
  - abri sous la pluie, sauf pour les étapes `rain_proof` ;
  - tout le monde est rentré la nuit.

## À savoir
**Ajouter un villageois**
1. Dupliquer un `.tres` de `data/villagers/` et changer le nom, le look et la journée.
2. Ajouter une instance de `villager.tscn` sous `Villagers` et lui donner ce `.tres`.

Pour que `place_villagers.gd` le garde, l'ajouter aussi à sa table `VILLAGERS`.

**Ajouter un lieu**
1. Ajouter un `Marker2D` sous `VillagerRoads/Spots`, près d'une route.
2. Si besoin, ajouter ou prolonger une route (`Line2D`) pour le relier au réseau.

Les routes doivent rester **sur les chemins** : les villageois traversent tout le reste (props,
clôtures) sans le voir.

**Dessiner un vêtement**
- Toile de 768×1024 avec `base_body.png` et le guide dessous. Dessiner dans les 24 cases, en
  clair pour la teinte, puis exporter seulement le vêtement.
- **Effacer ce qui passe devant le vêtement**, comme l'avant-bras de profil devant une
  chemise.
- **La rangée droite est le miroir de la gauche** : dessiner à la main dans les deux rangées
  un vêtement asymétrique, comme un lamba sur une épaule.
- Pour remplacer le mannequin par un vrai dessin, garder la grille, les rangées, les colonnes
  et la ligne des pieds. Les calques existants restent alors valables.

**Limites**
- Les fermiers « partent aux rizières » en disparaissant par la sortie nord. On ne les voit
  pas encore travailler dans la zone des rizières.
- Pas d'animation de travail ni de position assise : sur le banc, ils restent debout.

**Pistes**
- Les voir travailler dans les rizières : leur routine continue dans l'autre zone.
- Animations de travail : piler le riz au fanoto, porter sur la tête, repiquer.
- Dialogues, amitié, commandes (« apporte-moi 5 maniocs ») : pour donner un but aux
  rencontres et des débouchés à la récolte.
