# Amitié avec les villageois : `FriendshipManager`, `FriendshipReward`

## Ce que voit le joueur
- Chaque villageois a une **amitié de 0 à 5 cœurs** avec le joueur.
- **Quand on lui parle**, une **rangée de cœurs** apparaît un moment au-dessus de sa tête :
  - des cœurs pleins ;
  - le suivant, rempli en partie selon la progression ;
  - puis des cœurs vides.
- **Ce qui rapproche** :
  - **lui parler** : une fois par jour, un petit peu ;
  - **lui livrer une commande** : beaucoup ;
  - **aider à la moisson** dans la rizière des voisins : chaque touffe coupée rapproche un peu
    les fermiers qui y travaillent (Rakoto, Naivo).
- **L'amitié ne baisse jamais** : une commande ratée ne fait rien perdre (jeu cosy).
- **Pas d'amitié avec la famille** (mère, père, sœur) : leur fiche a `family` coché, et
  `FriendshipManager` les ignore (pas de cœurs, pas de points).
- **Nouveau cœur** :
  - une notification (« Ravao et toi êtes plus proches : 2 cœur(s). ») ;
  - **à 2 et à 4 cœurs, un cadeau** : il apparaît au-dessus du villageois (« +5 Graine de
    tomate »), il dit un mot, et le cadeau va dans l'inventaire.
- **Le « prix d'ami »** : chaque cœur ajoute 5 % à ce que paient ses commandes. Le panneau
  l'affiche (« Récompense : 9 400 Ar (+10 % d'amitié) »).

| Villageois | Cadeau à 2 cœurs | Cadeau à 4 cœurs |
|---|---|---|
| Ravao | 5 graines de tomate | 5 plants de pomme de terre |
| Neny Soa | Un riz aux brèdes | 2 « riz et accompagnement » |
| Rakoto | 6 riz de semence | 12 riz de semence |
| Naivo | 5 graines d'arachide | 6 boutures de patate douce |
| Koto | 2 mangues | 4 graines d'arachide |

Côté game design, les cadeaux ouvrent des cultures que le joueur n'aurait pas forcément
essayées, et le prix d'ami récompense la fidélité à un villageois.

## Détails techniques
**Données : `FriendshipReward`** (`core/data/friendship_reward.gd`), dans
`VillagerData.friendship_rewards`
- Champs : `hearts` (le palier), `item_id`, `quantity`, `line` (en français, `tr()`).
- `tools/place_villagers.gd` les remplit depuis sa table (`"gifts"`), seulement si la fiche
  n'en a pas.

**Règles : `FriendshipRules` (`simulation.friendship`, voir `simulation.md`)** (testables, sauvegardées)
- Constantes :
  - `FRIENDSHIP_PER_HEART` (100 points) et `FRIENDSHIP_MAX_HEARTS` (5) ;
  - gains : `FRIENDSHIP_TALK` (10, une fois par jour), `FRIENDSHIP_ORDER` (60),
    `FRIENDSHIP_HARVEST_HELP` (5 par touffe) ;
  - `ORDER_BONUS_PER_HEART` (0,05).
- `register_friend(id, rewards)`, `get_friendship`, `get_hearts`, `get_heart_progress`.
- `add_friendship(id, points)` :
  - plafonné à 5 cœurs ;
  - chaque cœur atteint donne son cadeau, ajouté à l'inventaire ;
  - signaux `friendship_changed` et `friendship_level_up(id, hearts, reward)`.
- `talk_to(id)` : compte une fois par jour.
- `deliver_order` paie `get_order_payment(id)` (récompense et prix d'ami, arrondis à 100 Ar)
  et ajoute `FRIENDSHIP_ORDER`.
- **Sauvegarde** : `FarmState.friendship` (points par villageois) et `friendship_talk_day`.
  Les anciennes sauvegardes démarrent à zéro.

**Lien avec le jeu : `FriendshipManager`** (`systems/villagers/`, `Gameplay/FriendshipManager`)
- Enregistre les cadeaux des fiches de `data/villagers/`.
- Quand le joueur parle à un villageois : `talk_to`, puis les cœurs au-dessus de sa tête.
  Il est branché avant `OrderManager`, qui répond ensuite (commande ou salut).
- Sur un nouveau cœur : notification, popup du cadeau, et la phrase du cadeau, différée
  pour passer après le salut.
- `NeighbourPaddyManager` ajoute l'amitié des fermiers quand le joueur coupe une touffe.

**Affichage : `HeartsDisplay`** (`entities/villager/hearts_display.gd`)
- Dessiné en code (courbe de cœur, remplissage partiel), sans police ni image.
- Créé par `Villager`, affiché par `show_hearts(hearts, max, progress)` pendant `HEARTS_TIME`.

**Tests**
- `run_tests.gd` :
  - une fois par jour pour les discussions ;
  - les cœurs et les cadeaux (un seul par palier, plafond à 5) ;
  - le prix d'ami et l'amitié gagnée par une livraison ;
  - la sauvegarde.
- `behaviour_test.gd` : parler à Ravao affiche les cœurs. À 2 cœurs, elle offre des graines
  de tomate avec un mot.

## À savoir
- **Équilibrage** : 5 cœurs demandent environ 500 points, soit à peu près 6 commandes et
  quelques semaines de discussions. Ça se règle avec les constantes.
- **Récapitulatif** : l'onglet **Villageois** de l'inventaire montre, pour chacun, son
  portrait, ses cœurs et la progression vers le suivant, son prix d'ami, son prochain cadeau,
  sa commande et l'endroit où le trouver (voir `hud.md`).
- **Pistes** :
  - des dialogues qui changent avec l'amitié ;
  - offrir des cadeaux aux villageois (objets aimés ou détestés) ;
  - des événements à haut palier (invitation à manger, aide aux champs) ;
  - un anniversaire par villageois.
