# Le chien de la famille : `DogManager`, `Dog`, `DogHouse`, `DogNamePanel`

## Ce que voit le joueur
- **Un chiot de Rakoto.** Après « Le zébu perdu », à partir du jour 8, Rakoto propose une
  quête : sa chienne Vony a eu des petits (voir `quests.md`, « Le chiot de Rakoto »).
  1. On demande d'abord à **Neny**. Elle accepte, à une condition : « c'est toi qui rempliras
     sa gamelle, tous les jours ! ».
  2. On choisit le chiot dans le **panier** (*sobika*), devant la case de Rakoto, la mère
     couchée à côté.
- **On lui donne un nom.** Une fenêtre s'ouvre : un nom est proposé (Tsiky, Bobaka,
  Kintana...), à garder ou à remplacer. « Un autre nom » en tire un autre. Le chiot
  trottine aussitôt aux pieds du joueur.
- **Sa niche apparaît à la ferme**, à gauche de la porte de la maison, avec sa gamelle. Elle
  n'est pas là avant son arrivée.
- **Il suit le joueur partout dehors** : la ferme, le village, la forêt, les rizières, le
  bourg. Il marche sur ses pas, court quand il est distancé, et ne bloque jamais le passage.
  Quand le joueur s'arrête, il s'assoit à côté en remuant la queue, renifle le sol, puis
  finit par se coucher.
- **Il n'entre pas** dans la maison ni dans le poulailler : il attend dehors et revient au
  pied du joueur à la sortie.
- **Le caresser** (« Caresser Kintana ») : un cœur s'envole au-dessus de lui. La première
  caresse de la journée le rend plus attaché, jusqu'à 5 sur 5 (une marche tous les 4 jours
  de caresses).
- **Sa gamelle**, à remplir **une fois par jour** devant la niche (« Remplir la gamelle »),
  avec les restes de riz de la famille : il n'y a rien à acheter.
- **La nuit (à partir de 20:00)** :
  - **s'il a mangé**, il rentre à sa niche et y dort, couché devant la porte. Il relève la
    tête quand le joueur passe près de lui, et **aboie** dans le noir de temps en temps
    (« Wouf ! »), bien plus souvent quand des voleurs rôdent ;
  - **s'il a faim**, il part chercher à manger chez les voisins : la niche reste vide. Le
    soir, Fara le fait remarquer au repas ;
  - si le joueur est loin de la ferme à 20:00, le chien **rentre seul** (« Kintana rentre
    garder la ferme pour la nuit »).
- **Le matin**, en sortant de la maison, le chien arrive en courant depuis sa niche et aboie
  pour dire bonjour.
- **Contre les voleurs de poules** (voir `chicken_thieves.md`) : un chien qui a mangé la
  veille veille toute la nuit. Les voleurs détalent quand il aboie : « Cette nuit, Kintana a
  aboyé à pleine voix : les voleurs de poules ont détalé ! ». Le ventre vide, il est parti, et
  la poule est perdue. Pendant une alerte, la rumeur et Neny rappellent de remplir sa gamelle.
- **Dans l'inventaire**, onglet Élevage : sa fiche (gamelle, attachement, et s'il gardera la
  ferme cette nuit).
- **Il grandit** : petit chiot le jour de son arrivée, chien adulte au bout de 14 jours.

Côté game design :
- **Un compagnon, pas une corvée.** Le chien est d'abord une présence : il accompagne le
  joueur, réagit, l'accueille le matin. Le seul soin obligatoire tient en un geste par jour
  (la gamelle). L'oublier n'a rien de grave : il découche, rien de plus. Il n'y a ni maladie,
  ni départ définitif.
- **Il donne un sens au soin quotidien** : un chien nourri garde la ferme. C'est une autre
  façon de protéger les poules que le cadenas. Le cadenas protège pour toujours une fois
  payé, le chien demande un geste chaque jour mais ne coûte rien.
- **Gagné, pas acheté** : il vient d'une amitié (Rakoto, après le zébu retrouvé). Le joueur
  le nomme, ce qui en fait vraiment le sien.
- **Le son la nuit raconte la menace** : des aboiements plus fréquents annoncent les nuits
  où rôdent les voleurs.

## Détails techniques
**Règles : `FarmSimulation`** (testables, sauvegardées)
- `FarmState.dog` : vide tant qu'il n'y a pas de chien, sinon `name`, `coat`, `since` (le jour
  de son arrivée), `fed_day`, `petted_day`, `bond` (le nombre de jours où il a été caressé).
  C'est une clé optionnelle : une ancienne sauvegarde n'a pas de chien.
- Constantes :
  - `DOG_NAMES` (les noms proposés), `DOG_NAME_MAX_LENGTH` (14) ;
  - `DOG_COATS` (4, voir `Dog.COATS`), `DOG_GROWN_DAYS` (14) ;
  - `DOG_BOND_PER_HEART` (4), `DOG_MAX_HEARTS` (5).
- Fonctions :
  - `has_dog()` ;
  - `adopt_dog(coat = -1)` (un seul chien ; le nom et la robe sont tirés au hasard) ;
  - `get_dog_name()`, `rename_dog(name)` (le nom est nettoyé, refusé s'il est vide) ;
  - `get_dog_coat()`, `get_dog_growth()` (de 0 à 1) ;
  - `feed_dog()` (une fois par jour), `is_dog_fed()` ;
  - `pet_dog()` (vrai à la première caresse du jour), `is_dog_petted()`, `get_dog_hearts()`.
- `dog_kept_watch()` : demandé au matin, dans `advance_day`. Il est vrai si le chien a mangé
  la veille. `_thieves_come()` le consulte avant le cadenas. Dans ce cas :
  `DayLog.dog_chased_thieves`, le signal `thieves_chased`, et l'alerte prend fin.
- Signaux : `dog_adopted`, `dog_changed`, `thieves_chased`.
- **Arrivée par une quête** : `Quest.reward_unlock = "dog"` (et `reward_unlock_label`, qui
  donne le texte de la récompense, « un chiot »). À la fin de la quête,
  `FarmSimulation._unlock()` appelle `adopt_dog()`.

**Lien avec le jeu : `DogManager`** (`systems/animal/dog_manager.gd`, `Gameplay/DogManager`)
- Il ne décide rien. Ce qu'il fait, selon l'heure (`time_changed`) et la zone
  (`zone_loaded`) :
  - **de jour**, dans une zone qui n'est pas `indoor`, il crée un `Dog` (`PlayerDog`, enfant
    de la zone) qui suit le joueur. Il le pose derrière le joueur, ou, au premier passage
    du jour à la ferme, devant la niche, d'où le chien accourt en aboyant ;
  - **la nuit** (`GUARD_FROM` 20:00 → `GUARD_UNTIL` 6:00), il place le chien à la niche s'il
    a mangé (`guard`, avec `restless` pendant une alerte de voleurs). Sinon, ou loin de la
    ferme, le chien qui suivait le joueur part (`leave`) avec une notification. Une gamelle
    remplie en pleine nuit le fait revenir à la niche ;
  - **`DogHouse`** : visible seulement s'il y a un chien (`set_owned`). Il affiche la gamelle
    (`show_bowl`) et nourrit le chien quand le joueur la remplit (`bowl_interacted`) ;
  - **à l'arrivée du chiot** (`dog_adopted`), il ouvre `DogNamePanel` et donne le nom choisi
    à `rename_dog` ;
  - **les caresses** (`Dog.petted`) passent par `pet_dog`, avec une notification à chaque
    nouvelle marche d'attachement.
- `get_dog()`, `get_dog_house()` : pour les tests.

**Le chien : `entities/dog/dog.tscn`** (`Dog`, un `Node2D` sans physique)
- Il comprend un `Sprite2D` (planche `assets/sprites/animals/dog.png`, 4×3 cases, robe
  claire teintée par `COATS`, échelle `SPRITE_SCALE` multipliée par la croissance depuis
  `PUPPY_SCALE`) et un `InteractableComponent` (`PET_AREA`, réglé dans le script).
- **Il suit une piste** : une position du joueur tous les `TRAIL_STEP` px (`TRAIL_MAX` au
  plus). Il la parcourt en restant à `FOLLOW_DISTANCE` derrière, au pas (`WALK_SPEED`), ou en
  courant au-delà de `RUN_BEYOND`. Il contourne ainsi ce que le joueur a contourné, sans
  collision ni recherche de chemin. Au-delà de `LOST_BEYOND` (joueur déplacé d'un coup), il
  est reposé derrière le joueur (`put_near_player`).
- **À l'arrêt** : il remue la queue (`WAG_UNTIL`), s'assoit, renifle (`SNIFF_FROM` à
  `SNIFF_UNTIL`), puis se couche (`LIE_AFTER`).
- **À la niche** : il dort, relève la tête quand le joueur passe à moins de
  `NOTICE_DISTANCE`, et aboie toutes les `NIGHT_BARK_CALM` secondes (`NIGHT_BARK_RESTLESS`
  quand il est agité).
- **Aboyer** : `bark(count)` joue `AudioManager.play_dog_bark_sfx()`, de plus en plus bas
  avec la distance (`BARK_DB_PER_PX`, jusqu'à `BARK_MIN_DB`). Un « Wouf ! » flotte au-dessus
  de lui (`HarvestPopup`).
- **Caressé** : il fait une tête contente, et un cœur est dessiné en code (`_draw`) pendant
  `HAPPY_TIME`.
- Les cases de la planche : 0–3 trot, 4–5 assis (queue basse, puis qui remue), 6 couché tête
  levée, 7 endormi, 8 aboie, 9 renifle, 10 content, 11 caressé.

**La niche : `entities/dog/dog_house.tscn`** (`DogHouse`, un `Prop`)
- Elle comprend la niche (`House`), la gamelle (`Bowl`, vide ou pleine), une `Base` qui
  bloque le joueur, le repère `Bed` (là où dort le chien) et un `InteractableComponent` sur
  la gamelle.
- Dans la ferme, elle est en `(712, 594)`, à gauche de la porte de la maison.

**Le panier de chiots : `entities/dog/puppy_basket.tscn`** (un `Prop`) : le panier et la
mère couchée. C'est l'apparence de la cible de quête `puppy_basket` (`PuppyBasket`, au
village, en `(300, 1180)`, posée par `tools/place_quest_targets.gd`).

**Le nom : `DogNamePanel`** (`ui/dog/`, sous `UI` dans `world.tscn`, construit en code) :
`open(name, giver_name)`, `confirm()`, et le signal `named(name)`. Le jeu est en pause tant
qu'il est ouvert. Échap garde le nom affiché.

**Son** : `AudioManager.sfx_dog_bark`. S'il est vide, un aboiement est généré en code
(`_make_bark` : un son grave et bourdonnant qui monte puis descend, un souffle à l'attaque,
une chute rapide).

**Ailleurs**
- `ChickenThiefManager` : la notification du matin quand le chien a chassé les voleurs. La
  rumeur rappelle la gamelle, et le vol rappelle que le chien avait faim.
- `EveningManager` : `_thief_lines()` (le chien qui a chassé les voleurs, ou qui avait faim
  la nuit du vol) et `_dog_lines()` (Fara, si la gamelle est restée vide).
- `InventoryCatalog.describe_dog()` et `dog_icon()` : la fiche de l'onglet Élevage.

**Outils**
- `tools/placeholder_art/gen_dog.gd` : les planches `dog.png` et `dog_props.png`.
- `tools/build_dog.gd` (avec `--editor`) : il construit les trois scènes et pose la niche
  dans la ferme (`DOG_HOUSE_POSITION`).

**Tests**
- `run_tests.gd` :
  - la quête de Rakoto (après le zébu perdu, Neny d'abord, puis le panier) qui donne un seul
    chien ;
  - la gamelle et les caresses (une fois par jour, jusqu'à 5), le nom ;
  - le chien nourri qui chasse les voleurs, et celui qui a faim ;
  - la sauvegarde.
- `behaviour_test.gd` :
  - pas de niche avant le chien, puis le nom choisi, la niche et la gamelle vide ;
  - le chien qui suit le joueur, puis s'assoit ;
  - la caresse et la gamelle ;
  - la nuit à la niche, endormi, avec ses aboiements ;
  - le village, le retour à la ferme à la nuit tombée, l'attente devant la maison, et Fara qui
    parle de la gamelle.

## À savoir
- **Le chien est un compagnon sans état** dans le monde : `DogManager` le recrée à chaque
  zone. Seule la simulation garde ce qui compte.
- **Pas de collision** : il ne bloque ni le joueur ni les villageois, et passe sous les
  décors. La piste lui évite la plupart des obstacles. Le joueur téléporté (une porte, le
  réveil) le fait reposer derrière lui.
- **La robe noire** est presque invisible la nuit devant la niche. C'est réaliste, mais une
  vraie planche pourra ajouter un liseré clair.
- **L'aboiement généré** reste un son provisoire : un vrai enregistrement dans
  `sfx_dog_bark` (sur `audio_manager.tscn`) sera bien meilleur.
- **Une seule quête donne un chien** (`reward_unlock`). D'autres déblocages peuvent passer
  par `FarmSimulation._unlock()`.
- **Pistes** :
  - l'attachement qui débloque des choses : il déniche des champignons ou du miel en forêt,
    il ramène une poule égarée ;
  - il aboie à l'approche des **dahalo** (voleurs de zébus) : une alerte et le temps de
    réveiller le fokonolona ;
  - des jeux : lancer un bâton, le faire asseoir ;
  - il mange une partie des restes du repas du soir (un choix : le nourrir mieux ou non) ;
  - le renommer depuis sa fiche dans l'inventaire.
