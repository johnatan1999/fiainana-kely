# Quêtes secondaires : `QuestManager`, `Quest`, `QuestStep`, `QuestTarget`

## Ce que voit le joueur
- **Un villageois a besoin d'un coup de main.** Une notification le dit (« Rakoto a besoin
  d'un coup de main. ») et un **« ! » cyan** flotte au-dessus de sa tête. Le cyan les
  distingue des commandes, dont le « ! » est doré.
- **On lui parle** (« Écouter Rakoto ») : un panneau s'ouvre, le jeu en pause, avec :
  - le titre et l'histoire, racontée par le villageois ;
  - ce qu'il faut faire d'abord ;
  - la récompense ;
  - **Accepter** ou **Plus tard** (Échap aussi). Plus tard, l'offre reste.
- **Pas de délai, rien à perdre.** Une quête ne rate jamais.
- **En cours** : chaque quête s'affiche en haut à droite, sous les commandes, avec son titre
  et **ce qu'il faut faire maintenant**. Une étape qui demande des objets montre où on en est
  (« (1/2) »), en vert quand on les a.
- **Les étapes** s'enchaînent : parler à quelqu'un, lui apporter des objets, aller quelque
  part, utiliser quelque chose dans le monde, trouver une page du carnet. Quand une étape se
  passe avec un villageois, il porte un **« ? » cyan** dès qu'on peut la faire.
- **À la fin** : « Quête terminée : Le zébu perdu (10 000 Ar, l'amitié de Rakoto) », l'argent
  au-dessus du villageois, et le soir, la famille en parle au repas.
- **Le monde garde une trace** : ce qu'une quête a changé reste visible (Volamena broute
  devant chez Rakoto).

**Les quêtes du village**

| Quête | Qui | Quand | En bref | Récompense |
|---|---|---|---|---|
| Le zébu perdu | Rakoto | jour 3 | Retrouver son zébu dans la forêt | 10 000 Ar, un cœur |
| Le sifaka qui danse | Koto | jour 4 | Voir un sifaka, puis lui apporter le dessin de Fara | 3 mangues, un cœur |
| La tisane de Neny Soa | Neny Soa | jour 6, 1 cœur | Sa cruche à la source, une feuille de ravintsara | 3 mofo gasy, un cœur |
| Le chiot de Rakoto | Rakoto | jour 8, après le zébu perdu | Demander à Neny, choisir un chiot | le chien de la famille, un demi-cœur |

**« Le zébu perdu » (Rakoto)**
1. Son zébu Volamena a cassé sa corde et filé vers la forêt. On cherche des **traces** :
   des empreintes de sabots dans la boue, sur le sentier, juste avant le gué.
2. Les traces mènent au **vieil amontana** : Volamena est là, sur le sentier. On
   l'approche : il a peur et il a faim.
3. On l'amadoue avec **2 brèdes sauvages**, cueillies dans la forêt. Il reprend seul le
   sentier du village.
4. On le dit à Rakoto : **10 000 Ar et un cœur d'amitié** (100 points). Le soir, Dada
   raconte que « toute la gargote » en parle. Volamena broute désormais sur l'herbe,
   devant chez Rakoto.

**« Le sifaka qui danse » (Koto)**
1. Koto a entendu parler d'un lémurien qui danse, mais sa mère ne le laisse pas aller seul
   en forêt. Il faut **observer un sifaka** (à l'aube, à l'ouest). Si le sifaka est déjà
   dans le carnet, l'étape est faite tout de suite.
2. On demande à **Fara** de recopier son dessin du carnet (« ? » cyan au-dessus d'elle).
3. On porte le dessin à Koto : 3 mangues et un cœur. Le soir, Fara raconte que Koto l'a
   montré à toute l'école.

**« La tisane de Neny Soa » (Neny Soa, après un cœur d'amitié)**
1. Les petits du village toussent. Neny Soa a laissé sa **cruche à la source** de la forêt,
   et ses jambes ne l'y portent plus : on la remplit (la cruche n'est là que pendant cette
   étape, au bord du bassin, à côté du ravintsara).
2. On rapporte l'eau avec **une feuille de ravintsara** : 3 mofo gasy et un cœur. Le soir,
   Neny raconte que Neny Soa t'appelle « zafy », comme son petit-enfant.

**« Le chiot de Rakoto » (Rakoto, après « Le zébu perdu »)**
1. Sa chienne Vony a eu des petits, et avec les voleurs de poules qui rôdent, un chien à la
   ferme serait utile. On demande d'abord à **Neny** (« ? » cyan sur elle). Elle accepte, si
   c'est toi qui remplis la gamelle.
2. On choisit un chiot dans le **panier**, devant la case de Rakoto, la mère couchée à côté.
   Le chiot suit aussitôt le joueur, qui lui donne un nom. Le soir, Fara raconte qu'il a
   déjà choisi sa place devant la porte. Tout le reste est dans `dog.md`.

Côté game design :
- **Les quêtes racontent le village** : là où les commandes font de l'économie (vite, avec
  un délai), les quêtes font de l'histoire (lentement, sans pression).
- **Elles font traverser le jeu** : le zébu perdu fait découvrir la forêt, sa cueillette et
  le gué, et rapproche de Rakoto.
- **La récompense compte, mais n'est pas le cœur** : une somme correcte (un peu plus d'une
  commande) et surtout l'amitié, un mot à table et un monde qui change.
- **Le rythme** : une quête se débloque par le jour, l'amitié, une quête finie avant ou une
  page du carnet. On peut donc les enchaîner en petites histoires (Rakoto, puis Naivo...).

## Détails techniques
**Données** (un `.tres` par quête dans `data/quests/`, id = nom du fichier)
- `Quest` (`core/data/quest.gd`) :
  - `title`, `giver` (id du villageois), `offer_line` (l'histoire) ;
  - **Conditions** : `min_day`, `min_hearts` (amitié avec le donneur), `after_quests`
    (quêtes à finir avant), `after_discoveries` (pages du carnet), `seasons` ;
  - **Étapes** : `steps` (des `QuestStep`, dans l'ordre) ;
  - **Récompense** : `reward_money`, `reward_items` (id → quantité), `reward_friendship`
    (points, 100 = un cœur), `reward_unlock` (ce que la quête apporte à la ferme hors objets :
    `"dog"`, voir `dog.md`) et `reward_unlock_label` (son texte dans la récompense, « un
    chiot »), `evening_speaker` et `evening_line` (la phrase du repas).
- `QuestStep` (`core/data/quest_step.gd`), selon son `kind` :

| `kind` | Ce qu'il faut faire | Champs |
|---|---|---|
| `TALK` | Parler à quelqu'un | `villager` |
| `BRING` | Lui donner des objets (retirés du sac) | `villager`, `item_id`, `quantity` |
| `REACH` | Marcher jusqu'à une cible | `target` (zone d'arrivée) |
| `INTERACT` | Utiliser une cible, avec ou sans objets (utilisés) | `target`, `item_id`, `quantity` |
| `DISCOVER` | Avoir une page du carnet (déjà trouvée : faite tout de suite) | `discovery_id` |

  Et pour toutes : `objective` (le texte du suivi), `prompt` (l'action affichée), `line`
  (dite à la fin de l'étape : par le villageois pour `TALK`/`BRING`, sinon en
  notification), `waiting_line` (quand il manque les objets).

**Règles : `QuestRules` (`simulation.quests`, voir `simulation.md`)** (testables, sauvegardées)
- `register_quest`, `get_quest`, `get_quest_ids`.
- `is_quest_available` (pas commencée, pas finie, conditions remplies),
  `get_quest_offered_by(villager)`, `start_quest`.
- `get_active_quests` (dans l'ordre d'acceptation), `get_quest_step`,
  `get_quest_step_index`, `get_quest_item_progress`, `can_do_quest_step`.
- **Avancer** :
  - `quest_talk(villager)` pour `TALK` et `BRING` ;
  - `quest_trigger(target)` pour `REACH` et `INTERACT` ;
  - `DISCOVER` avance tout seul (`discover()`).
  
  Chacun renvoie l'id de la quête qui a avancé, ou `""`.
- `get_quest_waiting_on(villager)`, `get_quest_at_target(target)`.
- La dernière étape faite : la récompense, `DayLog.quests_done`, signaux `quest_changed` et
  `quest_completed`. `quest_changed("")` chaque matin (de nouvelles quêtes ont pu s'ouvrir).
- **Conditions d'histoire** (`get_conditions()`) : `quest_active:<id>` et
  `quest_done:<id>`. La journée d'un villageois peut en dépendre
  (`VillagerStop.only_if` / `unless`, voir `villagers.md`).
- **Sauvegarde** : `FarmState.quests` (id → `{"step", "since"}`) et `quests_done` (id →
  jour). Une ancienne sauvegarde n'a aucune quête commencée.

**Monde : `QuestTarget`** (`entities/quest/quest_target.gd`, groupe `quest_targets`)
- `target_id` : son id dans les étapes (unique dans le jeu).
- `appears` :
  - `DURING_STEP` : visible tant qu'une étape l'attend. Avec `reach_size`, on y entre
    (`REACH`) ; sinon on l'utilise, dans `interact_size` (`INTERACT`) ;
  - `AFTER_DONE` : visible une fois `quest_id` finie (décor).
- Son apparence, ce sont ses enfants : un `Sprite2D`, `HoofPrints`
  (`entities/quest/hoof_prints.gd`, des empreintes de sabots dessinées en code), ou une
  scène (un décor : la cruche de Neny Soa). Leurs collisions sont coupées tant que la cible
  est cachée : un décor invisible ne bloque pas le joueur.
- **Posées par `tools/place_quest_targets.gd`** (avec `--editor`), d'après sa table
  `TARGETS`. Elles vont sous `QuestTargets` (y-trié) dans chaque zone, et une cible du même
  nom est remplacée. On peut aussi les poser à la main dans l'éditeur.

**Lien avec le jeu : `QuestManager`** (`systems/quests/`, `Gameplay/QuestManager`)
- **Un seul rafraîchissement par image** (`_queue_refresh`) : l'inventaire change souvent (une
  récolte, une étape et sa récompense), et chaque changement redessinait les marques, les
  cibles et le suivi. Une quête nouvellement proposée est annoncée tout de suite, pour
  garder sa place parmi les notifications (avant « Bonne nuit ! », pas par-dessus). Le
  suivi (`OrdersTracker.show_quests`) ne se reconstruit que si ce qu'il affiche change.
- Enregistre les quêtes (`Quest.load_all()`).
- Parler à un villageois :
  - une étape l'attend : il la fait (`quest_talk`) et dit sa `line`, ou rappelle ce qu'il
    attend ;
  - sinon, une quête à offrir ouvre `QuestPanel`.
- Les cibles de la zone : affichées ou non, leur action, leur déclenchement.
- Les marques cyan (`Villager.set_order_mark(mark, color)`), les actions, le suivi
  (`OrdersTracker.show_quests`), les conditions données aux villageois.
- Annonce une quête qui devient disponible (une fois), une quête acceptée, une quête
  terminée.
- **`OrderManager` s'efface** devant un villageois qu'une quête occupe
  (`QuestManager.has_quest_business`) : pas de commande proposée ni livrée pendant ce temps.
  Il est branché avant `QuestManager` dans `world.gd`, ce qui le fait répondre en premier
  (et se taire).

**Interface** : `QuestPanel` (`ui/quests/`, sous `UI` dans `world.tscn`, construit en code),
signaux `accepted` et `postponed`.

**Repas du soir** : `EveningManager._quest_lines()` : la `evening_line` des quêtes finies dans
la journée, en tête de la conversation.

**Tests**
- `run_tests.gd` :
  - la quête proposée à son jour ;
  - les étapes dans l'ordre (pas de raccourci, les objets) ;
  - les conditions (cœurs, quête d'avant), `DISCOVER` et `BRING` ;
  - la sauvegarde ;
  - **la cohérence des données** : chaque quête de `data/quests/` nomme des villageois, des
    objets, des pages et des quêtes qui existent.
- `behaviour_test.gd` : les trois premières quêtes (le chiot de Rakoto : voir `dog.md`). Pour Koto et Neny Soa : les deux « ! », la cruche
  (et sa collision), l'attente de la feuille, le « ? » sur Fara à la ferme. Et la quête de
  Rakoto de bout en bout. Le « ! » cyan, le panneau, le
  suivi, les traces, le zébu et les brèdes, le « ? », la récompense, le repas du soir et
  Volamena au village.

## À savoir
**Ajouter une quête**
1. Créer `data/quests/<id>.tres` (une `Quest`, dans l'inspecteur ou en dupliquant
   `rakoto_lost_zebu.tres`) : donneur, histoire, conditions, étapes, récompense.
2. Si une étape a lieu dans le monde (`REACH`, `INTERACT`) : ajouter une ligne à
   `TARGETS` dans `tools/place_quest_targets.gd` et le relancer. Ou poser un `QuestTarget`
   à la main.
3. Lancer `run_tests.gd` : le test de cohérence signale un villageois, un objet, une page ou
   un `reward_unlock` mal nommés.

Aucun code à écrire tant que les étapes rentrent dans les cinq types.

**Limites**
- **Un villageois occupé par une quête ne propose ni ne reçoit de commande** jusqu'à la fin
  de l'étape qui le concerne. Ça reste simple, mais une longue étape `BRING` bloque ses
  commandes.
- **Pas de journal des quêtes finies** : le suivi ne montre que celles en cours. Piste : une
  page « Histoires » dans le carnet.
- **Les phrases de fin d'étape avec un villageois passent par sa bulle** : courtes de
  préférence (3 s à l'écran).
- **Une `TALK` ou `BRING` se fait n'importe où** : là où se trouve le villageois, dans
  n'importe quelle zone.
- **Le zébu perdu est un sprite fixe**, sans animation (il ne broute pas, ne suit pas le
  joueur).

**Pistes**
- D'autres quêtes : une suite pour Rakoto (`after_quests`), Naivo, Ravao, les marchands du
  bourg. Des quêtes de saison (`seasons` : le miel en Asotry).
- Une étape « suivre » (le zébu qui suit le joueur jusqu'au village).
- Des quêtes qui changent la journée d'un villageois (`only_if` avec `quest_active:<id>`).
