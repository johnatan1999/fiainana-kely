# Combats de coqs : `CockfightManager`, `TetheredRooster`, `CockfightRing`

## Ce que voit le joueur
- **Rakoto offre un coq** : à partir du 3e jour, Rakoto, le grand amateur du village,
  interpelle le joueur (« Hé ! Tu t'intéresses aux coqs de combat ? », action « Écouter
  Rakoto »). Lui parler donne un jeune coq, **Kotroka**. Une commande de Rakoto en attente
  passe avant.
- **Le coq vit à la ferme**, attaché par une corde à un piquet devant la maison. Il picore et
  parade autour du piquet, jamais plus loin que la corde. Une bulle « grain » flotte
  au-dessus de lui tant qu'il n'a pas mangé de la journée.
- **S'en occuper** (« S'occuper de Kotroka ») ouvre son panneau :
  - **force** et **endurance** (sur 100 chacune), et sa **puissance** (la somme) ;
  - **donner 1 maïs ou 1 riz** (une fois par jour) : +1 endurance le soir ;
  - **entraîner** (une fois par jour) : s'il a aussi mangé, +2 force et +1 endurance de
    plus. Sans grain, l'entraînement ne sert à rien, et le panneau le dit ;
  - **rien ne se perd** : un jour oublié ne fait que ralentir sa progression ;
  - le classement de la saison et la date du prochain tournoi.
- **Le tournoi, l'Alahady de 14:00 à 17:00, au bourg** :
  - une **arène** (kianja) sur l'herbe au nord-est de la place, près du pont, avec son
    panneau « ADY AKOHO » ;
  - pendant le tournoi, deux coqs s'y affrontent pour le spectacle, et **les amateurs**
    viennent regarder : Rakoto, Naivo et Koto descendent du village, Rabe et Ratsimba sont
    déjà au bourg ;
  - le matin, une notification annonce le tournoi (si le joueur a un coq).
- **Inscrire son coq** (« Inscrire ton coq au tournoi ») : **3 combats** contre des coqs de
  villageois, du plus faible au plus fort.
  - Chaque combat se joue sous les yeux du joueur : les coqs se jaugent, s'élancent, des
    plumes volent, la jauge de vigueur du coq touché baisse. Le perdant s'enfuit.
  - « Passer » saute à la fin.
  - L'issue dépend des puissances et d'un peu de hasard : le joueur ne joue pas le combat,
    **son travail, c'est l'élevage**.
- **Récompenses, sans aucun pari** :
  - **une prime de participation** : 2 000 Ar à chaque tournoi, gagné ou perdu ;
  - **l'amitié** : chaque combat rapproche du propriétaire du coq adverse (+15) ;
  - **le prestige** : 3 points par victoire, 1 par défaite, et un **classement de la
    saison** ;
  - à la fin de la saison, le premier est **le meilleur coq du village** (★ dans le
    classement). Si c'est celui du joueur : notification, +40 d'amitié avec tous les
    amateurs, et ils le félicitent pendant 3 jours (« Voilà le maître du meilleur coq du
    village ! »).
- **Une fois par Alahady**. En dehors du tournoi, l'arène montre le classement.
- **Les coqs des villageois** :

| Coq | Propriétaire | Puissance de départ | Par semaine |
|---|---|---|---|
| Kely | Koto | 45 | +2 |
| Mena | Ratsimba | 70 | +3 |
| Tsara | Naivo | 95 | +3 |
| Varatra | Rabe | 120 | +3 |
| Mahery | Rakoto | 145 | +3 |

Côté game design :
- C'est une **progression d'élevage**, comme les zébus : un soin quotidien court (un grain,
  un entraînement) et un rendez-vous hebdomadaire qui en montre le résultat.
- **Courbe** : le coq du joueur part à 40 et gagne jusqu'à 4 par jour bien soigné.
  - Il bat Kely dès la première semaine.
  - Il égale Tsara au bout de 2 semaines environ.
  - Il égale Mahery au bout d'une saison.
  - Le titre de fin de saison se mérite.
- **Pas de pari** : l'argent ne dépend pas du résultat, et la prime reste petite. Le tournoi
  ne concurrence pas la ferme ; il récompense la régularité et donne du lien social.
- **Le maïs et le riz** trouvent une petite utilité de plus.
- **Le dimanche** a enfin son rendez-vous, comme le zoma le vendredi.

## Détails techniques
**Données : `FightingRoosterData`** (`core/data/fighting_rooster_data.gd`)
- Un `.tres` par coq dans `data/roosters/` ; son id est le nom du fichier.
- `display_name`, `owner_id` (id d'un villageois), `base_power`, `power_per_week`, `color`
  (teinte du dessin). `load_all()`.

**Règles : `CockfightRules` (`simulation.cockfight`, voir `simulation.md`)** (testables, sauvegardées)
- Le coq :
  - `ROOSTER_NAME`, `ROOSTER_START_STAT` (20), `ROOSTER_MAX_STAT` (100) ;
  - `ROOSTER_FEED_ITEMS` (`corn`, `rice`), `ROOSTER_FED_ENDURANCE`,
    `ROOSTER_TRAINED_FORCE`, `ROOSTER_TRAINED_ENDURANCE` ;
  - `adopt_rooster()`, `has_rooster()`, `get_rooster()`, `get_rooster_power()` ;
  - `can_feed_rooster` / `feed_rooster(item_id)`, `can_train_rooster` /
    `train_rooster()`, `is_rooster_fed_today()`, `is_rooster_trained_today()` ;
  - `advance_rooster()` en fin de journée.
- Le tournoi :
  - `COCKFIGHT_DAY`, `COCKFIGHT_HOURS`, `COCKFIGHT_BOUTS`, `COCKFIGHT_WIN_POINTS`,
    `COCKFIGHT_LOSS_POINTS`, `COCKFIGHT_ENTRY_PRIZE`, `COCKFIGHT_POWER_SCALE`,
    `COCKFIGHT_NPC_MAX_POWER`, `COCKFIGHT_HITS_TO_WIN`, `FRIENDSHIP_COCKFIGHT`,
    `FRIENDSHIP_CHAMPION` ;
  - `register_fighting_rooster()`, `get_cockfight_power(id)` (le joueur : `"player"`) ;
  - `check_cockfight()` → `CockfightCheck` (`OK`, `NO_ROOSTER`, `CLOSED`,
    `ALREADY_ENTERED`) ;
  - `enter_cockfight()` rend les combats `{"opponent", "won", "hits"}`. `hits` est la
    suite des coups, telle qu'elle sera montrée : le vainqueur en porte
    `COCKFIGHT_HITS_TO_WIN`, dont le dernier ;
  - un combat se tire d'une **sigmoïde** de l'écart de puissance : un écart de 20 donne
    environ 73 % de chances de gagner ;
  - le dimanche soir (`play_villagers_bouts()`), chaque coq de villageois livre le reste
    de ses 3 combats contre les autres. Seul son propre résultat compte ;
  - au changement de saison (`end_cockfight_season()`), le premier devient
    `cockfight_champion`, puis les points repartent de zéro. Ça émet
    `cockfight_season_ended` ;
  - `get_cockfight_ranking()` (points, puis puissance), `get_cockfight_rank()`,
    `get_cockfight_points()`, `get_cockfight_champion()`.
- Signaux : `rooster_changed`, `cockfight_changed`, `cockfight_season_ended(champion_id)`.
- **Sauvegarde** : `FarmState.rooster`, `cockfight_points`, `cockfight_week_bouts`,
  `cockfight_entered_day`, `cockfight_champion`. Une sauvegarde plus ancienne commence sans
  coq.

**Lien avec le jeu : `CockfightManager`** (`systems/cockfight/`, `Gameplay/CockfightManager`)
- Enregistre les coqs de `data/roosters/`.
- **Rakoto** (`GIFTER_ID`) : `call_out` et `talk_prompt` tant que le coq n'est pas donné
  (`GIFT_FROM_DAY`). Lui parler appelle `adopt_rooster()`. Il est branché après
  `OrderManager`.
- **`RoosterStake`** (un `Marker2D` de la zone, la ferme) : il y crée un
  `TetheredRooster` nommé `PlayerRooster` quand le joueur a un coq. Interagir ouvre le
  `RoosterPanel`.
- **`CockfightRing`** (groupe `cockfight_rings`) : pendant le tournoi, l'inscription joue
  les combats dans le `CockfightPanel`. Sinon, le panneau montre le classement et un mot.
- Les nouvelles : tournoi le dimanche matin, meilleur coq de la saison, félicitations des
  amateurs (`call_out`, `CHAMPION_PRAISE_DAYS`).

**Monde**
- `TetheredRooster` (`entities/cockfight/tethered_rooster.gd`), construit en code :
  - le piquet, la corde (`_draw`), le coq (`data/rooster.tres`) qui erre dans `TETHER` ;
  - la bulle de grain (`NeedBubble`) ;
  - `show_state(prompt, hungry)`.
- `CockfightRing` (`entities/cockfight/cockfight_ring.gd`), `@tool` : on le voit dans
  l'éditeur.
  - Le sol et la corde sont dessinés en code sur une couche `Floor` (`z_index` -7, sous
    tout ce qui est trié en y).
  - Le panneau « ADY AKOHO » est une instance de `signboard.tscn`.
  - Les deux coqs du spectacle et le texte de l'action suivent l'heure
    (`CLOCK_GROUP` / `CALENDAR_GROUP`) ; `set_prompts(pendant, sinon)`.
- **Placement** : `tools/place_cockfight.gd` (avec `--editor`) pose `RoosterStake` à la
  ferme et `CockfightRing` au bourg, d'après sa table.
- **Spectateurs** : les repères `Cockfight_South`, `Cockfight_West`, `Cockfight_East` et la
  route `Road_Cockfight` du bourg, plus les étapes `SUNDAY` des amateurs. Tout est dans la
  table de `tools/place_villagers.gd`.

**Interface** (`ui/cockfight/`, construite en code, met le jeu en pause)
- `RoosterPanel` : `show_rooster(rooster, ranking, note)`, signaux `feed_requested(item_id)`
  et `train_requested`.
- `CockfightPanel` :
  - `play_tournament(name, bouts, summary, ranking)` joue les combats ;
  - `show_ranking(note, ranking)` affiche le classement seul ;
  - `skip()`, `is_playing()`.
- `CockfightRankingList` : la liste du classement, partagée par les deux panneaux.

**Tests**
- `run_tests.gd` :
  - le coq offert une seule fois ;
  - la croissance avec le soin, le plafond ;
  - le tournoi le dimanche après-midi, une seule fois, avec la prime, l'amitié et les
    points ;
  - les chances selon la puissance et la forme des coups ;
  - les combats des villageois ;
  - le meilleur coq de la saison ;
  - la sauvegarde.
- `behaviour_test.gd` : Rakoto offre le coq ; le coq est attaché au piquet et on le nourrit
  et l'entraîne depuis son panneau ; le dimanche, les amateurs sont autour de l'arène et les
  3 combats se jouent ; ensuite, l'arène montre le classement.

## À savoir
- **Dessins** :
  - les coqs utilisent la planche des poules (`chickens.png`, `data/rooster.tres`) ;
  - les coqs des villageois ne se distinguent que par une teinte légère (`color`). De vrais
    plumages (planches dédiées) les rendraient reconnaissables ;
  - l'arène et le piquet sont dessinés en code, comme des planches provisoires.
- **Un seul coq** à la fois, et son nom est fixe. Pistes :
  - le renommer ;
  - un deuxième coq élevé à partir d'un poussin du poulailler ;
  - une blessure légère après une défaite (une journée de repos), sans perte définitive.
- **Équilibrage** : tout passe par les constantes de `CockfightRules` et les `.tres` de
  `data/roosters/`. Le 50/50 est à puissance égale ; `COCKFIGHT_POWER_SCALE` règle la part
  du hasard.
- **Pistes** :
  - des titres d'année (meilleur coq de l'année) ;
  - des tournois de fête (Alahamadibe, 26 juin) avec plus de monde ;
  - un mot propre à chaque amateur après un combat ;
  - un vrai coq qui vient à l'arène avec le joueur au lieu d'un combat « à distance ».
