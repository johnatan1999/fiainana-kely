# Projets de famille : `FamilyProjectManager`, `FamilyProject`, `FamilyProjectsPanel`, `KitchenManager`

## Ce que voit le joueur
- **Dada tient les projets de la famille.** Lui parler (« Parler des projets de la famille »)
  ouvre le panneau « Projets de la famille », bâtiment par bâtiment :
  - **le poulailler** : en ruine au départ (on le reconstruit dedans, 6 000 Ar), puis :

| Projet | Nom malgache | Coût | Travaux | Apporte |
|---|---|---|---|---|
| Poulailler agrandi | Tranon'akoho lehibe | 15 000 Ar | 3 jours | 8 poules au lieu de 4 (une aile et des pondoirs) |
| Poulailler en briques | Tranon'akoho biriky | 35 000 Ar | 4 jours | 12 poules, **les œufs vont tout seuls dans le sac** (le panier), et **les voleurs de poules n'y entrent pas** (voir `chicken_thieves.md`) |

  - **le parc à zébus** (*vala*) :

| Projet | Nom malgache | Coût | Travaux | Apporte |
|---|---|---|---|---|
| Parc agrandi | Vala lehibe | 30 000 Ar | 3 jours | 6 zébus au lieu de 4, tas de fumier de 18 |
| Grand parc avec abri | Vala misy fialofana | 60 000 Ar | 5 jours | 8 zébus, tas de 24, et **l'abreuvoir rempli tient deux jours** |

  - **les annexes de la maison**, construites dans la cour, entre la maison et la clôture du
    champ :

| Projet | Nom malgache | Coût | Travaux | Apporte |
|---|---|---|---|---|
| Grenier à riz | Fitoeram-bary | 25 000 Ar | 3 jours | Sur pilotis, des disques de pierre contre les rats : **25 % de riz en plus à chaque récolte de riz** |
| Cuisine | Lakozia | 20 000 Ar | 3 jours | **Cuisiner** ses récoltes en plats qui se vendent mieux que leurs ingrédients |

- Chaque projet affiche son prix, ses jours de travaux, ce qu'il apporte et son état : à
  lancer, il manque X Ar, en chantier (prêt dans N jours), terminé ✓, « Après : … » ou « Un
  chantier à la fois ».
- **Lancer les travaux** se paie d'avance. **Un seul chantier à la fois.** Des
  **échafaudages** et un panneau « Chantier » se dressent devant le bâtiment.
- **Le valin-tanana** : les amis du village (2 cœurs et plus, au plus 2) viennent aider,
  chacun fait gagner un jour (jamais moins d'un jour). Le panneau le dit (« Ravao et Koto
  viendront aider : 1 jour au lieu de 3 »), et la notification de départ aussi.
- **Le matin où c'est fini** : notification (« C'est fini : poulailler agrandi ! … »), le
  bâtiment a changé de visage. La veille, Dada l'annonce au repas du soir.
- **Ce qu'on voit sur la ferme** :
  - le poulailler en ruine, puis reconstruit en terre et en chaume, avec une aile et des
    pondoirs, puis en briques avec un toit en tôle et un panier d'œufs devant la porte ;
  - **son intérieur grandit avec lui** : une pièce en ruine (trous dans le mur, planches
    tombées), puis 6 × 4 cases et 4 pondoirs, 8 × 4 cases et 8 pondoirs, et enfin 10 × 5
    cases en briques, avec une fenêtre, 12 pondoirs et le panier d'œufs ;
  - le parc qui s'agrandit vers l'ouest (sa barrière passe au sud, face au pâturage), puis
    d'un rang vers le nord avec un abri de chaume.

- **La cuisine** (« Cuisiner », une fois construite) ouvre ses recettes : les ingrédients
  (en rouge s'il en manque, avec ce que contient le sac), le prix de vente du plat,
  « Cuisiner » et « Tout cuisiner (N) ». Les plats vont dans le sac et se vendent à
  l'épicerie, et mieux encore au tsena du zoma.

| Plat | Nom malgache | Ingrédients | Se vend |
|---|---|---|---|
| Maïs grillé | Katsaka natsatsika | 3 maïs | 5 000 Ar |
| Galettes de riz | Mofo gasy | 1 riz, 2 œufs | 7 000 Ar |
| Riz aux brèdes | Vary amin'anana | 2 riz | 10 500 Ar |
| Riz et accompagnement | Vary sy laoka | 1 riz, 2 haricots | 12 000 Ar |
| Rougail de tomates | Lasary voatabia | 3 tomates | 18 000 Ar |

  Le soir, le plat sur la natte est celui que tu as cuisiné, et Neny en parle.
- **Le grenier** (« Regarder le grenier ») rappelle ce qu'il apporte.

Côté game design :
- **De grands objectifs pour l'argent** : 15 000 à 60 000 Ar par palier. C'est la première
  vraie dépense d'investissement après les terrains.
- **Une progression visible** : la ferme change de visage au fil des projets.
- **L'amitié sert à construire** : soigner ses amis du village fait gagner des jours de
  chantier.
- **Un chantier à la fois** : il faut choisir l'ordre (d'abord les œufs ou d'abord les
  zébus ?).
- **Chaque niveau apporte du concret** : de la place, et du confort (le panier d'œufs,
  l'abreuvoir qui tient deux jours) qui allège les tâches quotidiennes à mesure que la ferme
  grandit.
- **Le grenier** récompense le riz : la culture reine de Madagascar rapporte un quart de
  plus.
- **La cuisine** ajoute de la valeur : un plat vaut environ un tiers de plus que ses
  ingrédients (38 % pour le maïs grillé, la recette du début de partie). Elle donne un
  débouché aux œufs, aux haricots et aux tomates.
- **Les plats ne s'achètent plus** à l'épicerie (avant : 800 et 1 200 Ar). Sinon, on aurait
  pu les acheter puis les revendre plus cher.

## Détails techniques
**Données : `FamilyProject`** (`core/data/family_project.gd`, un `.tres` par projet dans
`data/projects/`, id = nom du fichier)
- `display_name`, `malagasy_name`, `description` (ce qu'il apporte).
- `building` (`"coop"`, `"zebu_pen"`), `level` (le niveau atteint), `cost`, `build_days`.
- `load_all()`.

**Règles : `FarmSimulation`** (testables, sauvegardées)
- Constantes :
  - `BUILDINGS` (`coop`, `zebu_pen`, `granary`, `kitchen`), `BUILDING_START_LEVELS` (le parc
    à 1, les annexes à 0), `COOP_CAPACITY_BY_LEVEL` (0, 4, 8, 12), `ZEBU_CAPACITY_BY_LEVEL` (·, 4, 6,
    8), `MANURE_MAX_BY_LEVEL` (·, 12, 18, 24) ;
  - `COOP_BASKET_LEVEL` (3), `ZEBU_TROUGH_TWO_DAYS_LEVEL` (3) ;
  - `PROJECT_HELPER_HEARTS` (2), `PROJECT_MAX_HELPERS` (2) ;
  - `GRANARY_RICE_MULTIPLIER` (1,25) sur `GRANARY_CROP` (`rice`), appliqué dans `harvest()`
    après le fumier.
- `get_building_level(building)` : le poulailler est à 0 tant qu'il est en ruine
  (`has_coop`), le parc à 1 au départ.
- `get_zebu_capacity()`, `get_manure_max()`.
- `get_project_state(id)` → `ProjectState` (`DONE`, `BUILDING`, `AVAILABLE`, `LOCKED`,
  `BUSY`).
- `get_project_helpers()`, `get_project_days(id)`, `can_start_project`,
  `start_project(id)` : paie et ouvre le chantier `{"project", "done_day", "helpers"}`.
- `_advance_projects()` (le matin) : le chantier fini fixe le niveau
  (`building_levels`) et la place au poulailler (`coop_capacity`).
- Signaux `project_started`, `project_completed`, et `basket_collected(item, quantité)` :
  les œufs pondus dans le poulailler en briques vont dans le sac au lieu d'être posés au sol.
- Le parc de niveau 3 : remplir l'abreuvoir remplit aussi celui du lendemain
  (`zebu_trough_spare`).
- **La cuisine** : `register_recipe()`, `get_recipe_ids()`, `has_kitchen()`,
  `get_cookable_count(id)`, `can_cook(id)`, `cook(id)`. Les plats cuisinés vont dans
  `DayLog.cooked`.
- **Sauvegarde** : `FarmState.building_levels`, `construction`, `zebu_trough_spare`. Une
  sauvegarde plus ancienne garde ses bâtiments au niveau de départ.

**Lien avec le jeu : `FamilyProjectManager`** (`systems/family/`,
`Gameplay/FamilyProjectManager`)
- Enregistre les projets. Branché après `OrderManager` : Dada salue d'abord, puis le
  panneau s'ouvre (`talk_prompt`).
- **À chaque chargement de zone** :
  - `ChickenCoopBuilding` → `Coop.set_level()` ;
  - si la zone a un `ZebuPasture` (la ferme), le `ZebuPen` placé (niveau 1) est remplacé
    par la scène du niveau (`PEN_LEVELS` : scène, décalage de l'origine, taille) ;
  - un `ConstructionSite` sur le bâtiment en chantier.
- Le parc ne change **qu'au chargement** de la zone, avant que les zébus ne s'y attachent
  (à leur premier tic d'horloge). Les chantiers finissent le matin, quand le joueur dort à
  la maison.

**Recettes : `Recipe`** (`core/data/recipe.gd`, un `.tres` par recette dans
`data/recipes/`, id = nom du fichier)
- `display_name`, `malagasy_name`, `ingredients` (id → nombre), `result` (un `ItemData`),
  `quantity`. Les plats sont des objets `data/items/food_*.tres` (catégorie FOOD, `price` 0 :
  vente seulement), listés dans `ItemDatabase.ITEM_PATHS`.

**La cuisine : `KitchenManager`** (`systems/family/`, `Gameplay/KitchenManager`)
- Enregistre les recettes. L'annexe `Kitchen` ouvre le `CookingPanel`
  (`ui/family/cooking_panel.gd` : `show_recipes()`, signal `cook_requested(id, fois)`).
- L'annexe `Granary` donne un mot sur ce qu'elle apporte.

**Affichage**
- `Coop.set_level(level)` (`structures/chicken_coop/chicken_coop.gd`) : une case de
  `assets/sprites/props/coop_levels.png` (`tools/placeholder_art/gen_coop.gd`, 0 = la ruine,
  puis les niveaux 1 à 3), à densité 2× (nette), même emprise et même porte, donc mêmes
  collisions. L'ancienne image floue de la ruine (`exterior.png`) reste dans la scène, cachée.
- L'intérieur : `CoopInterior` (voir `animals.md`) se construit au niveau du poulailler
  (`CoopInterior.level`, synchronisé par `FamilyProjectManager` ; signal
  `FarmSimulation.coop_built` quand la ruine est reconstruite).
- Les parcs : `entities/zebu/zebu_pen.tscn`, `zebu_pen_2.tscn`, `zebu_pen_3.tscn`, écrits
  par `tools/build_zebu_pen.gd` d'après sa table `LEVELS`. Le niveau 3 contient l'abri
  (`thatched_hut.tscn`).
- **Les annexes** : `HouseAnnex` (`entities/farm/house_annex.gd`, `building` = `granary`
  ou `kitchen`).
  - Invisible et sans collision tant qu'elle n'est pas construite (`set_level`).
  - Ensuite : son image (`assets/sprites/props/house_annexes.png`,
    `tools/placeholder_art/gen_annexes.gd`), sa base solide, son action.
  - Placées dans la ferme par `tools/place_farm_annexes.gd` : `Granary` (860, 684),
    `Kitchen` (1066, 684).
- `ConstructionSite` (`entities/construction/`) : échafaudages, planches, briques et
  panneau, dessinés en code sur la zone `area` du bâtiment.
- `FamilyProjectsPanel` (`ui/family/`) : `show_projects(réplique, sections)`, signal
  `start_requested(id)`. La liste défile au-delà de `LIST_HEIGHT`. Il met le jeu en pause.
- Le repas du soir : Dada annonce la fin du chantier la veille (`evening.md`).

**Tests**
- `run_tests.gd` :
  - les niveaux l'un après l'autre, un chantier à la fois, payé d'avance, fini quelques
    matins plus tard ;
  - l'aide des amis ;
  - le parc plus grand (zébus, fumier, abreuvoir de deux jours) ;
  - le panier du poulailler en briques ;
  - la sauvegarde ;
  - les annexes absentes au départ, le riz du grenier, la cuisine.
- `behaviour_test.gd` : Dada ouvre les projets, et lancer le poulailler agrandi dresse un
  chantier. Une fois fini, le poulailler a son nouveau visage et le parc sa nouvelle
  taille. Le grenier et la cuisine apparaissent une fois construits, et la cuisine cuisine
  la récolte.

## À savoir
- **Ajouter un projet** : un `.tres` dans `data/projects/` (bâtiment, niveau, coût, jours).
  Un nouveau **bâtiment** demande en plus son effet dans `FarmSimulation` et son visuel
  dans `FamilyProjectManager`.
- **La maison familiale** : le grenier et la cuisine sont faits. La chambre de Fara et le toit
  en tôle sont les ajouts suivants.
- **Ajouter une recette** : un `.tres` dans `data/recipes/`, et son plat dans `data/items/`
  (catégorie FOOD, `price` 0, `sell_price` environ un tiers au-dessus des ingrédients),
  ajouté à `ItemDatabase.ITEM_PATHS`.
- **Ne rien poser** dans la cour entre x = 790 et 1140, y = 520 et 690 : c'est la place des
  annexes et du piquet du coq.
- **Dessins provisoires** : le poulailler (`gen_coop.gd`), les annexes (`gen_annexes.gd`) et
  le chantier sont dessinés en code, à densité 2× (nets). Les plats n'ont pas encore
  d'icône. Pour les remplacer, garder l'emprise de 224 × 192 du poulailler (la porte entre
  x = 96 et 126).
- **La place autour du parc** : il s'agrandit vers l'ouest puis vers le nord. Ne rien
  poser de solide entre x = 49 et 433, y = 671 et 911 (coordonnées de la ferme), ni sur la
  ligne droite du pâturage à sa barrière sud.
- Les textes ne sont pas encore traduits (`translations.csv`).
