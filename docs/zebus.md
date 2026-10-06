# Zébus en liberté : `GrazingZebu`, `ZebuPen`

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
- **Ambiance pure** : aucun état de simulation, rien n'est sauvegardé.

**Le parc : `entities/zebu/zebu_pen.tscn`** (`ZebuPen`, groupe `"zebu_pens"`)
- Autonome : sa clôture est sa propre `TileMapLayer` (`Fence`, terrain de clôture de
  `fence_tileset.tres`). On le place et on le déplace d'un bloc.
- Repères : `Gate` (devant l'ouverture, dehors), `Entrance` (juste dedans), `Spots/*` (places
  pour la nuit ; plusieurs zébus se partagent une place, légèrement décalés, s'il en manque).
- `nearest(zebu)` : le parc le plus proche **de la même zone** (même `owner`), à moins de
  `REACH` (700 px). `claim_spot()`, `route_in(spot)`, `route_out(pasture)`.
- À poser **sur la grille** (son origine est le coin d'une case de clôture), ouverture tournée
  vers le pré, sans obstacle entre le pré et `Gate`.

**Outils** (scènes générées par l'API de Godot, à lancer avec `--editor`, voir `CLAUDE.md`)
- `tools/build_zebu_pen.gd` : construit `zebu_pen.tscn` (taille, ouverture, places).
- `tools/place_zebu_herds.gd` : table zone → positions des zébus et case du parc. Reconstruit
  `ZebuHerd` et `ZebuPen` dans chaque scène de zone.
- **Dessin** : `assets/sprites/animals/zebu.png`, généré par
  `tools/placeholder_art/gen_zebu.gd`. Profil vers la droite, densité 2×, cases de 128×96
  (`hframes = 4`, `vframes = 2`) : 0–3 marche (0 = debout), 4–5 broute, 6 couché, 7 tête
  levée. **Robe claire**, teintée par `self_modulate` : une seule planche pour tout le
  troupeau.

**Tests** (`tests/behaviour_test.gd`) : le troupeau reste dans son pré ; un zébu regarde le
joueur proche et on ne le traverse pas ; le troupeau rentre au parc le soir, dort dans
l'enclos et ressort le matin ; il y est déjà en arrivant de nuit ; le troupeau sans parc dort
dans le champ.

## À savoir
- Les zébus des **charrettes** (`zebu_cart.md`) ont leur propre planche. Une vraie planche
  pourra servir aux deux : garder le profil vers la droite et les cases de 128×96.
- Ne pas poser de troupeau sur un chemin étroit : un zébu bloque le passage.
- Le chemin pré → parc doit rester dégagé (pas de pathfinding). Un obstacle n'est pas
  bloquant, mais le zébu le traverse, ce qui se voit.
- Relancer `place_zebu_herds.gd` remet les troupeaux à la table : y reporter les retouches
  faites à la main.
- **Pistes** :
  - un bouvier qui mène le troupeau ;
  - une barrière qui se ferme le soir ;
  - meuglements ;
  - zébus achetables et utiles (labour, fumier, charrette du joueur), avec un vrai état
    sauvegardé, comme les poules.
