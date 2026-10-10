# Projets de famille : `FamilyProjectManager`, `FamilyProject`, `FamilyProjectsPanel`

## Ce que voit le joueur
- **Dada tient les projets de la famille.** Lui parler (« Parler des projets de la famille »)
  ouvre le panneau « Projets de la famille », bâtiment par bâtiment :
  - **le poulailler** : en ruine au départ (on le reconstruit dedans, 6 000 Ar), puis :

| Projet | Nom malgache | Coût | Travaux | Apporte |
|---|---|---|---|---|
| Poulailler agrandi | Tranon'akoho lehibe | 15 000 Ar | 3 jours | 8 poules au lieu de 4 (une aile et des pondoirs) |
| Poulailler en briques | Tranon'akoho biriky | 35 000 Ar | 4 jours | 12 poules, et **les œufs vont tout seuls dans le sac** (le panier) |

  - **le parc à zébus** (*vala*) :

| Projet | Nom malgache | Coût | Travaux | Apporte |
|---|---|---|---|---|
| Parc agrandi | Vala lehibe | 30 000 Ar | 3 jours | 6 zébus au lieu de 4, tas de fumier de 18 |
| Grand parc avec abri | Vala misy fialofana | 60 000 Ar | 5 jours | 8 zébus, tas de 24, et **l'abreuvoir rempli tient deux jours** |

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
  - le parc qui s'agrandit vers l'ouest (sa barrière passe au sud, face au pâturage), puis
    d'un rang vers le nord avec un abri de chaume.

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

## Détails techniques
**Données : `FamilyProject`** (`core/data/family_project.gd`, un `.tres` par projet dans
`data/projects/`, id = nom du fichier)
- `display_name`, `malagasy_name`, `description` (ce qu'il apporte).
- `building` (`"coop"`, `"zebu_pen"`), `level` (le niveau atteint), `cost`, `build_days`.
- `load_all()`.

**Règles : `FarmSimulation`** (testables, sauvegardées)
- Constantes :
  - `BUILDINGS`, `COOP_CAPACITY_BY_LEVEL` (0, 4, 8, 12), `ZEBU_CAPACITY_BY_LEVEL` (·, 4, 6,
    8), `MANURE_MAX_BY_LEVEL` (·, 12, 18, 24) ;
  - `COOP_BASKET_LEVEL` (3), `ZEBU_TROUGH_TWO_DAYS_LEVEL` (3) ;
  - `PROJECT_HELPER_HEARTS` (2), `PROJECT_MAX_HELPERS` (2).
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

**Affichage**
- `Coop.set_level(level)` (`structures/chicken_coop/chicken_coop.gd`) : niveau 0, l'image
  de la ruine. Niveaux 1 à 3 : une case de `assets/sprites/props/coop_levels.png`
  (`tools/placeholder_art/gen_coop.gd`), même emprise et même porte que la ruine, donc
  mêmes collisions.
- Les parcs : `entities/zebu/zebu_pen.tscn`, `zebu_pen_2.tscn`, `zebu_pen_3.tscn`, écrits
  par `tools/build_zebu_pen.gd` d'après sa table `LEVELS`. Le niveau 3 contient l'abri
  (`thatched_hut.tscn`).
- `ConstructionSite` (`entities/construction/`) : échafaudages, planches, briques et
  panneau, dessinés en code sur la zone `area` du bâtiment.
- `FamilyProjectsPanel` (`ui/family/`) : `show_projects(réplique, sections)`, signal
  `start_requested(id)`. Il met le jeu en pause.
- Le repas du soir : Dada annonce la fin du chantier la veille (`evening.md`).

**Tests**
- `run_tests.gd` :
  - les niveaux l'un après l'autre, un chantier à la fois, payé d'avance, fini quelques
    matins plus tard ;
  - l'aide des amis ;
  - le parc plus grand (zébus, fumier, abreuvoir de deux jours) ;
  - le panier du poulailler en briques ;
  - la sauvegarde.
- `behaviour_test.gd` : Dada ouvre les projets, et lancer le poulailler agrandi dresse un
  chantier. Une fois fini, le poulailler a son nouveau visage et le parc sa nouvelle
  taille.

## À savoir
- **Ajouter un projet** : un `.tres` dans `data/projects/` (bâtiment, niveau, coût, jours).
  Un nouveau **bâtiment** demande en plus son effet dans `FarmSimulation` et son visuel
  dans `FamilyProjectManager`.
- **La maison familiale** est la suite prévue : elle grandit par des **ajouts** (grenier à
  riz, cuisine, chambre de Fara, toit en tôle), chacun ouvrant une suite de jeu.
- **Dessins provisoires** : le poulailler (`gen_coop.gd`) et le chantier sont dessinés en
  code. Pour les remplacer, garder l'emprise de 224 × 192 du poulailler (la porte entre
  x = 96 et 126).
- **La place autour du parc** : il s'agrandit vers l'ouest puis vers le nord. Ne rien
  poser de solide entre x = 49 et 433, y = 671 et 911 (coordonnées de la ferme), ni sur la
  ligne droite du pâturage à sa barrière sud.
- Les textes ne sont pas encore traduits (`translations.csv`).
