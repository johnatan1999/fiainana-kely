# Zébus : `GrazingZebu`, `ZebuPen`, zébus du joueur (`ZebuManager`), marché aux zébus

## Ce que voit le joueur
- De petits **troupeaux de zébus** paissent dans les prés : au nord-est du village (4 bêtes)
  et au bord des rizières (3 bêtes). Robes mélangées, comme à Madagascar : brun, fauve, gris,
  presque noir, blanc.
- La plupart du temps ils **broutent** (tête baissée, mâchoire qui bouge), font **quelques
  pas lents** de temps en temps, et parfois **se couchent** pour ruminer.
- Quand le joueur s'approche, le zébu **relève la tête et le regarde**. Il ne fuit pas.
- Ils sont **solides** : on les contourne.
- **Le parc à zébus (vala)** : un enclos en bois à l'est du village, ouvert côté pré.
  - À **18:00**, le troupeau du village rentre au parc, **un par un**, en file par l'ouverture.
    Si le joueur bloque le passage, le zébu s'arrête et le regarde, puis repart.
  - La nuit, les zébus dorment **couchés dans l'enclos**. En arrivant au village de nuit, ils
    y sont déjà.
  - À **6:30**, ils se lèvent et ressortent vers leur pré, chacun à son rythme.
- **Sans parc** (troupeau des rizières), les zébus se couchent dans le champ de 20:00 à 5:45.

**Le marché aux zébus (tsena omby)**, au bourg, au nord de la rivière (à gauche en arrivant du
village) :
- **Le zoma seulement**, de 6:00 à 17:00 : trois zébus à vendre dans l'enclos, et
  **Ratsimba**, le marchand, à son poteau (panneau « OMBY »). Les autres jours, l'enclos est
  vide et le poteau dit « Fermé ».
- Lui parler ouvre la fenêtre du marché :
  - **acheter un jeune zébu** (vantotr'omby) pour **25 000 Ar**, si le parc de la ferme a de
    la place (4 zébus au plus) ;
  - **vendre** chacun de ses zébus à sa **valeur du jour**.
- Le zébu acheté porte le nom de sa robe : Mena (brun), Mavo (fauve), Lavenona (gris),
  Mainty (noir), Fotsy (blanc), numéroté s'il y en a déjà un (« Mena 2 »).

**Les zébus du joueur**, à la ferme :
- Ils vivent dans le **parc de la ferme**, à l'ouest des champs : ils paissent devant le jour
  et rentrent dormir dans l'enclos à 18:00, comme le troupeau du village.
- **L'abreuvoir** (un tronc creusé et un râtelier à foin), contre le parc : le **remplir une
  fois par jour** (« Remplir l'abreuvoir ») suffit pour tout le troupeau. **La pluie le
  remplit** toute seule.
- **Au travail** : à partir de 15 jours de croissance, deux zébus peuvent tirer la **charrue**
  et labourer 4 parcelles d'un coup, 24 par jour (voir `farming.md`).
- **Le fumier** (zezik'omby) : chaque nuit après un jour d'abreuvoir plein, chaque zébu laisse
  1 fumier sur le **tas** à côté du parc (petit tas, puis gros tas ; 12 au plus).
  « Ramasser le fumier (N) » met tout le tas dans le sac. Épandu sur une parcelle (voir
  `farming.md`), il rend la récolte **50 % plus grosse**. Il se vend aussi 200 Ar à l'épicerie.
- Chaque jour où l'abreuvoir a été plein, chaque zébu **grandit d'un jour**. Sa valeur monte
  de **18 000 Ar** (le jour de l'achat : la marge du marchand) à **60 000 Ar** une fois adulte,
  au bout de **30 jours de soins**. Un jour oublié ne fait rien perdre : il ne grandit pas.
- Dans l'inventaire, onglet Élevage : chaque zébu, sa croissance, sa valeur au marché, et si
  l'abreuvoir est rempli aujourd'hui.

**Boucle de jeu visée** : le zébu est la **tirelire** malgache. On y place l'argent des
récoltes (25 000 Ar immobilisés), une petite corvée par jour le fait fructifier (+35 000 Ar en
un mois par bête), et on le revend un zoma quand on a besoin de liquidités, ou pour acheter des
graines d'export. Le parc limité à 4 zébus borne le revenu, et le marché n'ouvre qu'un jour par
semaine, ce qui oblige à prévoir.

## Détails techniques
**Le zébu : `entities/zebu/grazing_zebu.tscn`** (`GrazingZebu`, un `CharacterBody2D` en
`motion_mode` flottant)
- `Sprite2D` (échelle 0,8, ancré en bas) et collision rectangulaire au sol (70×14).
- **Couche physique « Animals »** (4), qu'il ne masque pas : les zébus se croisent sans se
  bloquer. Il masque « World » (1) : clôtures et arbres l'arrêtent. Le joueur (qui masque
  Animals) ne le traverse pas.
- **Exports** : `wander_radius` (110 px autour de l'endroit où il est posé), `coat` (indice
  dans `COATS`, -1 = au hasard).
- **Activités** : `GRAZE` (4–10 s), `WALK` (point au hasard autour du point de départ,
  abandonné s'il est bloqué ou trop long), `REST` (15–30 s), et pour le parc `GO_IN`, `PENNED`,
  `GO_OUT`.
  - Joueur à moins de `WATCH_DISTANCE` (72 px) : image « regarde », tourné vers lui.
  - Suit l'**horloge** (`DayNightController.CLOCK_GROUP`, `set_time_of_day`). Au premier top
    d'horloge après le chargement de la zone, il cherche son parc (`ZebuPen.nearest`) et, si
    c'est la nuit, s'y place directement.
  - Avec parc : `PEN_FROM` (18:00) / `PEN_UNTIL` (6:30), départ décalé au hasard
    (`SET_OFF_DELAY_MAX`), vitesse `COMMUTE_SPEED`. Sans parc : `SLEEP_FROM` / `WAKE_AT`.
  - **Pas de pathfinding** : le zébu suit les repères du parc en ligne droite. Bloqué par le
    joueur, il attend. Bloqué par autre chose plus de `STUCK_TIME` (1,5 s), il passe au travers
    jusqu'au repère suivant.
- Les troupeaux posés dans les scènes sont de l'**ambiance pure** : aucun état de simulation.
  Ceux du joueur sont créés par `ZebuManager` à partir de la simulation.

**Le parc : `entities/zebu/zebu_pen.tscn`** (`ZebuPen`, groupe `"zebu_pens"`)
- Autonome : sa clôture est sa propre `TileMapLayer` (`Fence`, terrain de clôture de
  `fence_tileset.tres`). On le place et on le déplace d'un bloc.
- Repères : `Gate` (devant l'ouverture, dehors), `Entrance` (juste dedans), `Spots/*` (places
  pour la nuit ; plusieurs zébus se partagent une place, légèrement décalés, s'il en manque).
- `nearest(zebu)` : le parc le plus proche **de la même zone** (même `owner`), à moins de
  `REACH` (700 px). `claim_spot()`, `route_in(spot)`, `route_out(pasture)`.
- À poser **sur la grille** (son origine est le coin d'une case de clôture), ouverture tournée
  vers le pré, sans obstacle entre le pré et `Gate`.

**Les règles : `FarmSimulation`** (comme les poules)
- Constantes : `ZEBU_PEN_CAPACITY` (4), `ZEBU_PRICE` (25 000), `ZEBU_CALF_VALUE` (18 000),
  `ZEBU_ADULT_VALUE` (60 000), `ZEBU_GROW_DAYS` (30), `ZEBU_NAMES` (par robe).
- `buy_zebu(coat = -1)` → id (`"zebu_<n>"`), `can_buy_zebu()`, `sell_zebu(id)` → ce qui est
  payé, `get_zebu_ids()`, `get_zebu(id)`, `get_zebu_value(id)` (interpolée, arrondie à
  500 Ar), `is_zebu_grown(id)`, `fill_zebu_trough()`, `is_zebu_trough_full()` (rempli, ou il
  pleut).
- `advance_day()` : un jour de croissance si l'abreuvoir était plein, et le fumier sur le
  tas, puis l'abreuvoir se vide.
- **Fumier** : `MANURE_ITEM` (`"manure"`, objet `data/items/manure.tres`, catégorie Élevage,
  action `FERTILIZE`), `MANURE_PER_ZEBU` (1), `MANURE_PILE_MAX` (12),
  `MANURE_YIELD_MULTIPLIER` (1,5) ; `get_manure_pile()`, `collect_manure()`,
  `can_fertilize(plot)`, `fertilize(plot)`. Sauvegarde : `FarmState.manure_pile`.
- Signal `zebus_changed`.
- **Sauvegarde** : `FarmState.zebus` (id → `name`, `coat`, `grown_days`), `next_zebu_index`,
  `zebu_trough_full`, clés optionnelles (une ancienne sauvegarde n'a pas de zébus).
- L'objet « Zébu » (`data/items/animal_zebu.tres`) n'est pas dans le catalogue
  (`ItemDatabase.ITEM_PATHS`) : les zébus ne sont pas des objets, on les achète au tsena omby.
- **Au travail** : deux zébus d'au moins `ZEBU_WORK_MIN_DAYS` (15) jours de croissance tirent
  la charrue (voir `farming.md`).

**Le lien avec le monde : `ZebuManager`** (`systems/animal/zebu_manager.gd`, nœud
`Gameplay/ZebuManager`)
- Dans une zone avec un repère **`ZebuPasture`** (la ferme) : un `GrazingZebu` par zébu
  possédé, sous un nœud `PlayerZebus` créé au besoin, réparti autour du repère (`SPREAD`),
  de la bonne robe, `owner` = la zone (pour que `ZebuPen.nearest` trouve le parc).
- **`ManureHeap`** (`entities/zebu/manure_heap.tscn`, un `Prop` sans collision : les zébus
  passent à côté pour aller au parc) : `show_amount(n)` (caché à 0, gros tas à partir de 6),
  signal `interacted`.
- **`ZebuTrough`** (`entities/zebu/zebu_trough.tscn`, un `Prop`) : `show_state(full,
  can_fill)` change l'image (vide / plein) et l'action ; signal `interacted`.
- **`ZebuMarket`** (`entities/zebu/zebu_market.tscn`, groupe `"zebu_markets"`) : le poteau du
  marchand et son panneau. Ouvert selon un `ShopProfile` (`data/shops/zebu_market.tres` :
  zoma, 6:00–17:00, voir `shops.md`), il émet `requested` ; fermé, il affiche
  `closed_message`.
- **`ZebuMarketPanel`** (`ui/zebu/zebu_market_panel.gd`, nœud `UI/ZebuMarketPanel`, construit
  en code, met le jeu en pause) : `show_market(...)`, signaux `buy_requested`,
  `sell_requested(zebu_id)`.
- **`MarketDayOnly`** (`entities/zebu/market_day_only.gd`) : le `ZebuHerd` du bourg. Ses
  enfants (les zébus à vendre) ne sont dans l'arbre que le jour du marché
  (`GameClock.MARKET_DAY`) : les autres jours, ils sont retirés de l'arbre, pas seulement
  cachés, pour ne pas gêner le passage.

**Outils** (scènes générées par l'API de Godot, à lancer avec `--editor`, voir `CLAUDE.md`)
- `tools/build_zebu_pen.gd` : construit `zebu_pen.tscn` (taille, ouverture, places).
- `tools/build_zebu_market.gd` : construit `zebu_trough.tscn`, `zebu_market.tscn`,
  `manure_heap.tscn` et écrit `data/shops/zebu_market.tres`, `data/items/tool_plough.tres`,
  `data/items/manure.tres`. Planche du fumier : `assets/sprites/props/manure.png`
  (`gen_manure.gd`). Dessins : `assets/sprites/props/zebu_market.png`
  (`gen_zebu_market.gd`). Lancer d'abord `--editor --quit` après avoir régénéré la planche,
  sinon les scènes sont construites sans texture.
- `tools/place_zebu_herds.gd` : table zone → positions des zébus et case du parc, et en option
  `wander_radius`, `market_only` (troupeau `MarketDayOnly`), `market` (le poteau),
  `pasture` et `trough` (zébus du joueur), `remove_trees`. Reconstruit `ZebuHerd`, `ZebuPen`,
  `ZebuPasture`, `ZebuTrough` et `ZebuMarket` dans chaque scène de zone.
  - Ferme : parc à la case (3, 15), pâturage (320, 1030), abreuvoir (290, 960), tas de
    fumier (185, 955).
  - Bourg : parc à la case (6, 1), poteau (200, 310), deux eucalyptus retirés.
- **Dessin** : `assets/sprites/animals/zebu.png`, généré par
  `tools/placeholder_art/gen_zebu.gd`. Profil vers la droite, densité 2×, cases de 128×96
  (`hframes = 4`, `vframes = 2`) : 0–3 marche (0 = debout), 4–5 broute, 6 couché, 7 tête
  levée. **Robe claire**, teintée par `self_modulate` : une seule planche pour tout le
  troupeau.

**Tests**
- `tests/behaviour_test.gd` : le troupeau reste dans son pré ; un zébu regarde le joueur
  proche et on ne le traverse pas ; le troupeau rentre au parc le soir, dort dans l'enclos et
  ressort le matin ; il y est déjà en arrivant de nuit ; le troupeau sans parc dort dans le
  champ. Marché aux zébus : fermé et vide un Alarobia, ouvert le zoma avec Ratsimba, achat,
  zébu sur la ferme, abreuvoir rempli, zébu dans le parc la nuit, revente.
- `tests/run_tests.gd` : achat, croissance seulement les jours d'abreuvoir plein, pluie, valeur
  adulte, vente, parc plein, argent insuffisant, noms, sauvegarde.

## À savoir
- Les zébus des **charrettes** (`zebu_cart.md`) ont leur propre planche. Une vraie planche
  pourra servir aux deux : garder le profil vers la droite et les cases de 128×96.
- Ne pas poser de troupeau sur un chemin étroit : un zébu bloque le passage.
- Le chemin pré → parc doit rester dégagé (pas de pathfinding). Un obstacle n'est pas
  bloquant, mais le zébu le traverse, ce qui se voit.
- Relancer `place_zebu_herds.gd` remet les troupeaux à la table : y reporter les retouches
  faites à la main.
- Les zébus du joueur servent à **épargner** et à **labourer**. Labourer ne les fatigue que
  pour la journée : ça ne change ni leur croissance ni leur valeur.
- Le parc de la ferme a une place par zébu (`ZebuPen.Spots`, 4) : augmenter
  `ZEBU_PEN_CAPACITY` demande un parc plus grand.
- **Pistes** :
  - zébus utiles : **charrette** du joueur (transport, vente en gros), piétinement des
    rizières (hitsakitsaka) ;
  - un compost (fumier + paille de riz) plus fort que le fumier seul ;
  - prix du marché qui varient (plus chers avant les fêtes, le famadihana) ;
  - un veau né au parc, ou un zébu offert par la famille ;
  - un bouvier qui mène le troupeau, une barrière qui se ferme le soir, meuglements.
