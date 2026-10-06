# Villageois : `Villager`, `VillagerRoads`, `VillagerVisual`, `VillagePaddy`

## Ce que voit le joueur
Cinq villageois vivent au village, chacun avec sa journée :

| Villageois | Maison | Sa journée |
|---|---|---|
| **Rakoto**, fermier | ouest | Repique le riz dans la rizière des voisins de 6:30 à 16:00, avec une pause à la cabane à midi. Puis discute sur la place et rentre à 18:00 |
| **Naivo**, fermier | est | Même chose de 6:15 à 15:30 (pause à 11:30), puis passe au marché et sur la place, rentre à 18:15 |
| **Ravao**, marchande | est | Tient son étal au marché de 7:00 à 17:30, avec une pause sur le banc près de chez elle à midi |
| **Neny Soa**, grand-mère | sud | Se promène sur la place le matin, fait la sieste, va au banc l'après-midi |
| **Koto**, enfant | sud | Joue sur la place le matin et le soir, traîne au marché l'après-midi |

- Ils marchent **sur les chemins de terre**, sortent de leur porte le matin et rentrent le
  soir. La nuit, le village est vide.
- **Les fermiers vont aux rizières** :
  - ils partent par le chemin du nord ;
  - dans la zone des rizières, ils arrivent par le chemin du village et travaillent
    **penchés dans l'eau de la rizière des voisins**, en avançant le long du rang ;
  - ils vont à la cabane à midi, puis repartent vers le village dans l'après-midi ;
  - au village, ils réapparaissent par le chemin du nord après le temps du trajet.
- **La rizière des voisins** est à droite de la cabane, dans les rizières. Son riz pousse au
  fil de chaque saison : jeunes plants au début, mûr à la fin. Ce n'est pas un terrain du
  joueur.
- **Quand il pleut**, chacun rentre chez soi, sauf la marchande (étal couvert) et les fermiers
  (le riz aime la pluie).
- **En arrivant dans une zone**, chacun est déjà où l'heure le veut.
- **Avec le joueur** :
  - ils sont solides ;
  - si le joueur leur barre le chemin, ils s'arrêtent et attendent ;
  - quand il s'approche, ils se redressent, se tournent vers lui et le saluent d'une
    **bulle**, au plus une fois toutes les 45 s.

## Détails techniques
### Les données (`data/villagers/<id>.tres`)
- **`VillagerData`** : `display_name`, `look` (`VillagerLook`), `size` (1 = adulte, 0,8 =
  enfant), `home_zone` (`"village"`), `home` (le repère de sa porte), `routine`, `greetings`
  (textes en français, passés par `tr()`).
- **`VillagerStop`** (une étape de `routine`) :
  - `hour`, `minute` : l'heure de départ de l'étape ;
  - `zone` : la zone de l'étape, un id de `WorldManager` (vide = `home_zone`) ;
  - `spot` : le repère où aller dans cette zone ;
  - `activity` :
    - `STAND` : reste là et regarde autour ;
    - `WANDER` : flâne autour ;
    - `INSIDE` : entre et disparaît (une porte) ;
    - `WORK` : penché au travail, avance d'un pas le long du rang de temps en temps ;
  - `rain_proof` : l'étape se fait aussi sous la pluie.
- **`get_stop(minute)`** : l'étape en cours, ou `null` (= à la maison) avant la première. La
  journée va de 6:00 à 2:00 : après minuit, c'est toujours la dernière étape de la veille.
  Terminer donc la journée par une étape `INSIDE` sur `home`.

### Les chemins : `VillagerRoads` (un par zone)
- `zone_id` : l'id de la zone.
- Les **routes** sont ses enfants `Line2D`, visibles dans l'éditeur et cachés en jeu.
- Les **repères** sont des `Marker2D` sous `Spots`.
  - **Village** : `Maison_Ouest`, `Maison_Est`, `Maison_Sud`, `Marche`, `Place`, `Banc_Est`,
    `Vers_rice_fields`.
  - **Rizières** : `Vers_village`, `Cabane`, `Riziere_Voisins_1`, `Riziere_Voisins_2`.
- **`Vers_<zone>`** : le repère où le chemin quitte la carte vers cette zone. `exit_to(zone)`
  le renvoie.
- Deux points de route à moins de 12 px forment un carrefour. Un repère s'accroche au point de
  route le plus proche.
- Le chemin le plus court se calcule avec un `AStar2D` (`find_path`). Il n'y a pas de
  navmesh : les villageois suivent les chemins.

### Le villageois : `entities/villager/villager.tscn` (`Villager`, `CharacterBody2D`)
- **Un nœud par zone traversée**, avec le même `VillagerData`. Les fermiers ont donc un
  `Villager` au village et un aux rizières.
- **Dans une zone, une étape ailleurs** (`zone` différente de celle des routes) devient « aller
  à `Vers_<zone>` et disparaître ». Sans chemin vers cette zone, il passe par le chemin vers
  `home_zone`.
- **Une étape ici après une étape ailleurs** : il réapparaît à `Vers_<zone d'où il vient>`
  après `ARRIVAL_DELAY` (12 s, le temps du trajet), puis marche jusqu'à son repère.
- **Couche physique « Animals »** (4) : le joueur bute dessus. Il ne masque rien : il suit les
  routes et attend le joueur de lui-même (`BLOCK_DISTANCE`).
- Suit l'**horloge** (`CLOCK_GROUP`) et la **météo** (`WEATHER_GROUP`).
- Au premier top d'horloge après le chargement d'une zone, il se place directement à son
  étape.
- Chaque villageois a **sa place autour d'un repère partagé**, toujours la même, tirée de son
  nom (`SPOT_SPREAD`) : deux fermiers à la cabane ne se superposent pas.
- Vitesse `SPEED` : 55 px/s.
- `is_inside()`, `is_walking()`, `is_working()`, `get_spot_name()`.
- `Bubble` : un `Label` au-dessus de la tête.

### La rizière des voisins : `VillagePaddy` (`structures/farm/village_paddy/`)
- Un décor `@tool`, construit en code à partir de `size` (rien n'est enregistré dans la
  scène).
- Il contient :
  - un sol labouré assombri (comme une rizière `FarmField`) ;
  - l'eau peu profonde de la rizière (`paddy_water_material`) ;
  - un plant de riz (`rice_visual.tscn`) par case.
- **Stade du riz** selon le jour de la saison (`STAGE_FROM_DAY`) : pousse du 1er au 8e jour,
  croissance du 9e au 21e, mûr à partir du 22e. Deux récoltes par an, comme sur les hautes
  terres.
- Il reçoit la date par **`DayNightController.CALENDAR_GROUP`** (`set_date`).
- `get_rect()`, `get_stage()`. À placer sur la grille, sous un nœud y-sorté : ses plants se
  trient avec les fermiers.

### L'apparence : `VillagerVisual`, `VillagerLook`, `VillagerLayer`
- **Planche de base** : `assets/sprites/characters/villager/base_body.png`, un mannequin
  neutre dessiné clair, teinté par la couleur de peau.
  - Densité 2× (affichée à l'échelle 0,5), cases de 128×256, **8 colonnes** × 4 rangées
    (1024×1024).
  - Rangées : **0 bas** (face), **1 gauche**, **2 droite**, **3 haut** (dos).
  - Colonnes : **0–1** repos (respiration), **2–5** marche, **6–7** travail (penché, les
    mains vers le sol puis remontées).
  - **Pieds sur y = 252**, centrés sur x = 64.
  - Repères (y) : tête 62, yeux 80, menton 98, épaules 106, hanches 168, genoux 210, sol 252.
- **Guide de dessin** : `villager_guide.png`.
- **Calques d'exemple** (`example_*.png`) : `shirt`, `shorts`, `trousers`, `skirt`, `hair`,
  `hair_bun`, `hat`.
- `VillagerLayer` : `texture` et `color`.
- `VillagerLook` : `skin_color`, `body`, `layers`.
- `VillagerVisual` (`@tool`) : un `Sprite2D` par calque, tous sur la même image.
  - `play(direction, moving, working)` ;
  - exports `facing`, `walking` et `working`, pour vérifier une apparence dans l'éditeur.

### Outils
Les deux se lancent avec `--editor`.
- **`tools/place_villagers.gd`** :
  - construit `villager.tscn` ;
  - écrit les `.tres` manquants (supprimer un fichier pour qu'il soit réécrit depuis la
    table) ;
  - pour chaque zone de sa table `ZONES` : reconstruit `VillagerRoads`, les rizières des
    voisins (`RizieresVoisins`) et `Villagers` (un nœud par villageois dont la journée passe
    par la zone) ;
  - retire les arbres listés dans `remove_trees` et l'herbe haute sous les rizières.
- **`tools/placeholder_art/gen_villager_base.gd`** : le mannequin, le guide et les calques
  d'exemple.

### Tests
- `run_tests.gd` : les étapes de la journée.
- `behaviour_test.gd` :
  - villageois du village : placés selon l'heure, départ et retour à la maison, attente du
    joueur et salut, abri sous la pluie, village vide la nuit ;
  - fermiers dans la rizière à 9:00, penchés au travail, au travail sous la pluie ;
  - le riz des voisins qui pousse au fil de la saison ;
  - départ vers le village à 16:00, arrivée au village par le chemin du nord après le
    trajet.

## À savoir
**Ajouter un villageois**
1. Dupliquer un `.tres` de `data/villagers/` et changer le nom, le look et la journée.
2. Ajouter une instance de `villager.tscn` sous `Villagers` **dans chaque zone où passe sa
   journée**, avec ce `.tres`.

Pour que `place_villagers.gd` le garde, l'ajouter aussi à sa table `VILLAGERS`.

**Ajouter un lieu**
1. Ajouter un `Marker2D` sous `VillagerRoads/Spots`.
2. Si besoin, ajouter ou prolonger une route (`Line2D`).

Les routes doivent rester **sur les chemins** : les villageois traversent tout le reste.

**Relier une nouvelle zone**
Ajouter, dans les deux zones, un repère `Vers_<autre zone>` là où le chemin quitte la carte,
relié aux routes.

**Points d'attention**
- Le point d'apparition du joueur aux rizières est sur le chemin des fermiers : s'il y reste
  planté, ils l'attendent.
- **Dessiner un vêtement** : toile de 1024×1024 avec `base_body.png` et le guide dessous ;
  dessiner les 32 cases, en clair pour la teinte.
  - Effacer ce qui passe devant le vêtement.
  - La rangée droite est le miroir de la gauche.
  - Pour remplacer le mannequin par un vrai dessin, garder la grille, les rangées, les
    colonnes et la ligne des pieds.

**Limites**
- Sur le banc, les villageois restent debout, faute d'animation assise.
- Le riz des voisins ne se récolte pas : les fermiers repiquent toute la saison.

**Pistes**
- Récolte chez les voisins en fin de saison (gerbes, battage), à laquelle le joueur peut
  aider contre du riz ou de l'amitié.
- Animations de travail supplémentaires : piler le riz au fanoto, porter sur la tête.
- Dialogues, amitié, commandes (« apporte-moi 5 maniocs »).
