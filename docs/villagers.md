# Villageois : `Villager`, `VillagerRoads`, `VillagerVisual`, `VillagePaddy`, `NeighbourPaddyManager`

## Ce que voit le joueur
Cinq villageois vivent au village, chacun avec sa journée :

| Villageois | Maison | Sa journée |
|---|---|---|
| **Rakoto**, fermier | ouest | Repique le riz dans la rizière des voisins de 6:30 à 16:00, avec une pause à la cabane à midi. Puis va à la gargote et rentre à 18:00 |
| **Naivo**, fermier | est | Même chose de 6:15 à 15:30 (pause à 11:30), puis passe à l'épicerie et à la gargote, rentre à 18:15 |
| **Ravao**, marchande | est | Tient son étal au marché de 7:00 à 17:30, avec une pause sur le banc près de chez elle à midi. **Le zoma**, elle descend au bourg vendre ses lambas au tsena (6:30–15:30), puis se repose sur le banc |
| **Neny Soa**, grand-mère | sud | Va chercher l'eau au point d'eau au lever, se promène sur la place, fait la sieste, va au banc l'après-midi |
| **Koto**, enfant | sud | **En semaine** (Alatsinainy à Zoma), va à l'école le matin (même sous la pluie) ; **le week-end**, joue au foot dès 8:30. Traîne au marché l'après-midi, joue au foot en fin de journée |

- **Les marchands du bourg** (voir `world_zones.md`) :

| Villageois | Sa journée |
|---|---|
| **Rabe**, collecteur | **Le zoma**, tient l'étal du collecteur de 6:00 à 17:00 (c'est lui qui achète vanille, girofle, café et litchis), puis flâne sur la place. Les autres jours, attend le taxi-brousse le matin, rentre à midi, flâne au marché l'après-midi |
| **Ratsimba**, marchand de zébus | **Le zoma**, à son poteau du tsena omby de 6:00 à 17:00. Les autres jours, au taxi-brousse le matin, chez lui à midi, sur la place l'après-midi |
| **Lalao**, marchande de légumes | **Le zoma**, à son étal de légumes de 6:00 à 17:00. Les autres jours, lave le linge au lavoir le matin, discute sur le pont l'après-midi |

  Ils ont leurs commandes et leurs cadeaux d'amitié : Rabe commande des cultures d'export et
  offre des graines de café puis de **vanille** ; Lalao commande des légumes et offre des
  haricots puis du **girofle**. L'amitié est donc une autre porte vers les cultures chères.

- **La famille du joueur**, à la ferme :

| Qui | Sa journée |
|---|---|
| **Neny**, la mère | Pile le riz au mortier devant la maison dès 6:00, va chercher l'eau au point d'eau du village vers 9:00, étend le linge, cuisine, nourrit les poules, rentre à 18:00 |
| **Dada**, le père | Travaille au verger le matin, déjeune à la maison, coupe du bois l'après-midi, rejoint les hommes à la gargote du village à 16:00, rentre à 18:30 |
| **Fara**, la petite sœur | Va à l'école du village le matin en semaine (le week-end, joue avec les poules dès 9:00), joue avec les poules à midi, au foot au village l'après-midi, rentre vers 17:45 |

  - Leurs répliques sont des **conseils** : arroser, acheter les graines au marché, les
    commandes, les saisons, les poules. Elles servent de tutoriel naturel.
  - Pas de cœurs d'amitié ni de commandes avec eux : c'est la famille. Dans l'inventaire, ils
    sont en tête de l'onglet Villageois (« Famille ») et on y voit où ils sont.
- Ils marchent **sur les chemins de terre**, sortent de leur porte le matin et rentrent le
  soir. La nuit, le village est vide.
- **Les fermiers vont aux rizières** :
  - ils partent par le chemin du nord ;
  - dans la zone des rizières, ils arrivent par le chemin du village et travaillent
    **penchés dans l'eau de la rizière des voisins**, en avançant le long du rang ;
  - ils vont à la cabane à midi, puis repartent vers le village dans l'après-midi ;
  - au village, ils réapparaissent par le chemin du nord après le temps du trajet.
- **La rizière des voisins** est à droite de la cabane, dans les rizières. Ce n'est pas un
  terrain du joueur. Son riz suit chaque saison (deux récoltes par an) :
  - jeunes plants du 1er au 8e jour, en croissance jusqu'au 21e, mûr et doré à partir du 22e ;
  - **la moisson, du 26e au 28e jour** : les fermiers coupent le riz rang après rang, d'ouest
    en est, pendant leurs heures de travail. Les touffes coupées laissent du chaume dans
    l'eau, et des **gerbes** s'alignent sur la diguette, une pour trois touffes ;
  - le matin du 26e jour, une notification annonce la moisson et invite le joueur à aider ;
  - les 29e et 30e jours, la rizière est moissonnée et les gerbes sèchent. La saison suivante,
    tout est repiqué.
- **Aider à la moisson** :
  - pendant la moisson, l'action **« Aider à moissonner »** apparaît dans la rizière ;
  - chaque appui coupe la touffe debout la plus proche du joueur et lui rapporte **1 graine
    de riz** (« +1 Graine de riz »), le riz de semence que les voisins partagent ;
  - les fermiers l'appellent (« C'est la moisson ! Tu nous aides ? ») et le remercient
    (« Misaotra ! Merci du coup de main ! »), au plus une fois toutes les 20 s ;
  - l'aide du joueur avance la moisson : ce qu'il coupe n'est plus à couper.
- **Quand il pleut**, chacun rentre chez soi, sauf la marchande (étal couvert) et les fermiers
  (le riz aime la pluie).
- **En arrivant dans une zone**, chacun est déjà où l'heure le veut.
- **Commandes** : un villageois peut avoir une commande à proposer (« ! » au-dessus de la tête)
  ou à recevoir (« ? »). On lui parle pour la voir ou la livrer (voir `orders.md`).
- **Amitié** : lui parler affiche les cœurs d'amitié au-dessus de sa tête. Elle grandit en lui
  parlant, en livrant ses commandes et en aidant à la moisson (voir `friendship.md`).
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
  - `rain_proof` : l'étape se fait aussi sous la pluie ;
  - `days` : les jours de la semaine où l'étape a lieu (cases à cocher, bits de
    `GameClock.Weekday`) ; aucune case = tous les jours. Un autre jour, l'étape est sautée et
    la précédente continue. `happens_on(weekday)`, `days_mask([...])`.
- **`get_stop(minute, weekday)`** : l'étape en cours ce jour-là, ou `null` (= à la maison)
  avant la première. La journée va de 6:00 à 2:00 : après minuit, c'est toujours la dernière
  étape de la veille. Terminer donc la journée par une étape `INSIDE` sur `home`.
  - Pour une journée différente le zoma (ou le week-end), donner des `days` aux étapes des
    deux variantes, triées par heure : une étape sans `days` s'applique aussi ce jour-là et
    écraserait la variante.

### Les chemins : `VillagerRoads` (un par zone)
- `zone_id` : l'id de la zone.
- Les **routes** sont ses enfants `Line2D`, visibles dans l'éditeur et cachés en jeu.
- Les **repères** sont des `Marker2D` sous `Spots`.
  - **Village** : `Maison_Ouest`, `Maison_Est`, `Maison_Sud`, `Marche`, `Place`, `Banc_Est`,
    `Vers_rice_fields`, et au centre du village `Sekoly`, `Kianja`, `Fantsakana`, `Hotely`,
    `Epicerie` (routes `Route_Hotely`, `Route_Epicerie`). Les noms affichés dans l'inventaire
    sont dans `InventoryCatalog.SPOT_PLACES`.
  - **Rizières** : `Vers_village`, `Cabane`, `Riziere_Voisins_1`, `Riziere_Voisins_2`.
  - **Bourg** : `Vers_village`, `Pont`, `Lavoir`, `Tsena` (la place), `Tsena_Mpanangona`,
    `Tsena_Legioma_1`, `Tsena_Legioma_3`, `Tsena_Lamba_1` (derrière les étals), `Taxi`,
    `Trano_Rabe`, `Trano_Lalao`, `Tsena_Omby`, `Trano_Ratsimba` (routes `Route_Omby`,
    `Route_Ratsimba`). Le village a `Vers_bourg`, au bout de `Route_Bourg`.
  - **Ferme** : `Trano` (la porte de la maison), `Fanoto`, `Cuisine`, `Bois`, `Linge`,
    `Poulailler`, `Verger`, `Vers_village`. Le village a `Vers_farm`, au bout de `Route_Ferme`.
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
- Suit l'**horloge** (`CLOCK_GROUP`), le **jour de la semaine** (`CALENDAR_GROUP`) et la
  **météo** (`WEATHER_GROUP`).
- Au premier top d'horloge après le chargement d'une zone, il se place directement à son
  étape.
- Chaque villageois a **sa place autour d'un repère partagé**, toujours la même, tirée de son
  nom (`SPOT_SPREAD`) : deux fermiers à la cabane ne se superposent pas.
- Vitesse `SPEED` : 55 px/s.
- `is_inside()`, `is_walking()`, `is_working()`, `get_spot_name()`.
- `Bubble` : un `Label` au-dessus de la tête.

### La rizière des voisins
**Règles : `FarmSimulation`** (comme les arbres fruitiers)
- Constantes :
  - `NEIGHBOUR_RICE_STAGES` : jour de la saison → stade du riz ;
  - `NEIGHBOUR_HARVEST_FROM_DAY` (26) et `NEIGHBOUR_HARVEST_DAYS` (3) : quand se fait la
    moisson ;
  - `NEIGHBOUR_WORK_HOURS` (6:30–16:00) : les heures où les fermiers coupent ;
  - `NEIGHBOUR_HARVEST_REWARD` (`"rice_seed"`) : ce que rapporte une touffe.
- `register_neighbour_paddy(id, size)` : appelé au chargement de la zone. L'id vaut
  `"<zone>:<nom du nœud>"`.
- `get_neighbour_rice_stage()`.
- `get_neighbour_harvest_progress()` : de 0 à 1, au fil des heures de travail des jours de
  moisson.
- `is_neighbour_harvest_on()`.
- `is_neighbour_tuft_cut(id, cell)` : une touffe est coupée si les fermiers en sont là (ordre
  colonne par colonne depuis l'ouest), ou si le joueur l'a coupée.
- `help_neighbour_harvest(id, cell)` : renvoie le riz de semence gagné, ou 0 hors moisson,
  pour une touffe déjà coupée ou une case hors de la rizière. Émet `neighbour_paddy_changed`.
- **Sauvegarde** : `FarmState.neighbour_harvest` (clé optionnelle `"neighbour_harvest"`)
  garde les touffes coupées par le joueur, par rizière et par saison. Une nouvelle saison
  repart de zéro.

**Lien avec la zone : `NeighbourPaddyManager`** (`systems/farm/`, nœud `Gameplay`)
- Fait le lien entre la simulation et les `VillagePaddy` de la zone chargée, comme
  `TreeManager`.
- Rafraîchit l'affichage à chaque minute et chaque jour : stade du riz, touffes coupées,
  action « Aider à moissonner ».
- Gère l'appui du joueur : son, `HarvestPopup`, remerciement d'un fermier (`Villager.say`).
- Donne aux villageois qui travaillent dans la rizière leur appel à l'aide
  (`Villager.call_out`).
- Annonce la moisson au réveil du 26e jour, mais pas au chargement d'une sauvegarde.

**Affichage : `VillagePaddy`** (`structures/farm/village_paddy/`)
- Un décor `@tool`, construit en code à partir de `size` : sol labouré assombri, eau peu
  profonde (`paddy_water_material`), une touffe de riz (`rice_visual.tscn`) par case.
- Les gerbes (`hay_sheaf.tscn`, réduites, sans collision) sont posées sur la diguette du bas.
- Une zone d'interaction (`InteractableComponent`) couvre toute la rizière.
- Purement passif : `show_state(stage, cut)`, `set_prompt(prompt)`, `tuft_near(point)`,
  `get_tuft_position(cell)`, `get_rect()`, `get_sheaf_count()`, signal `interacted`.
- À placer sur la grille, sous un nœud y-sorté : ses touffes se trient avec les fermiers.

### L'apparence : `VillagerVisual`, `VillagerLook`, `VillagerLayer`
- **Planche de base** : `assets/sprites/characters/villager/base_body.png`, **calquée sur le
  sprite du joueur** (`player2.png`). Même silhouette, même style peint, mêmes animations,
  passée en gris clair pour être teintée par la couleur de peau. **Provisoire**, en attendant
  de vrais designs de personnages.
  - Densité 2× (affichée à l'échelle 0,5), cases de 128×256, **8 colonnes** × 4 rangées
    (1024×1024). Les images du joueur (1×) sont agrandies ×2 au plus proche voisin : à
    l'échelle 0,5, elles s'affichent exactement comme le joueur.
  - Rangées : **0 bas** (face), **1 gauche**, **2 droite**, **3 haut** (dos).
  - Colonnes :
    - **0–1** : repos (`idle_*` du joueur) ;
    - **2–5** : marche (`walk_*`) ;
    - **6–7** : travail, accroupi les mains au sol (`harvest_left` / `harvest_right`).
      Il n'existe pas de vue de face ni de dos : de face et de dos, c'est l'image de repos,
      et les villageois travaillent de profil.
  - **Pieds sur y = 252**, centrés sur x = 64.
- **Calques**, tirés des mêmes images :
  - `shirt`, `shorts`, `hair` : le t-shirt, le short et les cheveux du joueur, séparés par
    couleur (blanc, vert, sombre en haut de la tête). Les ombres de la peinture sont
    gardées ;
  - `trousers` : le short prolongé sur les jambes jusqu'aux chevilles ;
  - `skirt` : une jupe droite de la taille à mi-mollet, qui s'évase selon l'écart des
    jambes ;
  - `hair_bun`, `hat` : un chignon (à l'arrière de la tête) et un chapeau de paille, posés
    sur la tête repérée dans chaque image.
- **Guide de dessin** : `villager_guide.png`, avec les bords des cases, la ligne des pieds et
  la silhouette en transparence.
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
    table) ; avec `-- --routines`, réécrit les journées de tous depuis la table, sans toucher
    au reste ;
  - dans la table, une étape peut avoir un 7e élément : ses jours (`SCHOOL_DAYS`, `WEEKEND`,
    `MARKET`, `NOT_MARKET`) ;
  - pour chaque zone de sa table `ZONES` : reconstruit `VillagerRoads`, les rizières des
    voisins (`RizieresVoisins`) et `Villagers` (un nœud par villageois dont la journée passe
    par la zone) ;
  - retire les arbres listés dans `remove_trees` et l'herbe haute sous les rizières.
- **`tools/placeholder_art/gen_villager_from_player.gd`** : écrit les planches actuelles
  (corps, calques, guide) à partir de `player2.png`. Les images utilisées sont dans sa table
  `FRAMES`, et la séparation par couleur dans `_sort()`.
- `tools/placeholder_art/gen_villager_base.gd` : l'ancien mannequin, au squelette dessiné
  par code. **Il écrit les mêmes fichiers** : le lancer remplace les planches calquées sur le
  joueur.

### Tests
- `run_tests.gd` :
  - les étapes de la journée, et les étapes réservées à certains jours de la semaine ;
  - le calendrier du riz des voisins et l'avancement de la moisson ;
  - l'aide du joueur : seulement pendant la moisson, sur une touffe debout, une seule fois ;
  - la sauvegarde des touffes coupées, et la remise à zéro à la saison suivante.
- `behaviour_test.gd` :
  - villageois du village : placés selon l'heure, départ et retour à la maison, attente du
    joueur et salut, abri sous la pluie, village vide la nuit ;
  - fermiers dans la rizière à 9:00, penchés au travail, au travail sous la pluie ;
  - la moisson : à moitié coupée le 27e jour, gerbes, action proposée, touffe coupée par le
    joueur contre une graine de riz, appel des fermiers, tout coupé le 29e jour ;
  - départ vers le village à 16:00, arrivée au village par le chemin du nord après le
    trajet ;
  - pas d'école le dimanche (Koto au foot), école un jour de semaine ;
  - au bourg : marchands au lavoir et au taxi en semaine, à leurs étals le zoma, Ravao
    descendue du village.

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
  - Pour les vrais designs de personnages, garder la grille, les rangées, les colonnes et la
    ligne des pieds : le code et les looks restent valables.
- Après avoir régénéré les planches, ouvrir l'éditeur (ou lancer `--editor --quit`) pour les
  réimporter.
- **Silhouette provisoire** : tous les villageois ont le corps du joueur, un jeune garçon. La
  grand-mère et les fermiers en ont les proportions, et le joueur se distingue moins de la
  foule. À régler avec les vrais designs.

**Limites**
- Sur le banc, les villageois restent debout, faute d'animation assise.
- La moisson finie (29e et 30e jours), les fermiers restent penchés dans la rizière vide :
  on peut lire ça comme la préparation du sol, mais une vraie activité (battage des gerbes)
  serait mieux.
- La récompense est fixée à 1 graine de riz (1 500 Ar) par touffe, soit au plus environ 20 par
  saison. C'est volontairement modeste : du riz récolté (4 000 Ar pièce) rendrait l'aide plus
  rentable que la rizière du joueur.

**Pistes**
- Après la moisson : battage des gerbes sur la natte, puis riz qui sèche au soleil.
- Quand l'amitié existera : l'aide à la moisson la fera monter.
- Animations de travail supplémentaires : piler le riz au fanoto, porter sur la tête.
- Dialogues, amitié, commandes (« apporte-moi 5 maniocs »).
