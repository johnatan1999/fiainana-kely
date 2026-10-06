# Commandes des villageois : `OrderManager`, `OrderTemplate`

## Ce que voit le joueur
- **Le matin, des villageois ont une commande à proposer.** Une notification le dit (« Ravao
  a une commande pour toi. ») et un **« ! » doré** flotte au-dessus de leur tête.
- **On leur parle** (touche d'interaction, « Voir la commande de Ravao »). Un panneau s'ouvre,
  le jeu en pause :
  - la phrase du villageois (« Le maïs grillé se vend bien en ce moment. Tu m'apportes 5 épis
    ? ») ;
  - l'objet, son icône et la quantité ;
  - la **récompense** et le **délai** ;
  - les boutons **Accepter** et **Refuser**. Échap ferme sans décider : l'offre reste.
- **Commandes acceptées** : elles s'affichent en haut à droite dans le cadre « Commandes ».
  - Pour chacune : le villageois, ce que le joueur a déjà sur ce qu'il faut (« 1/4 manioc »)
    et les jours restants.
  - **En vert** quand on peut livrer, **en rouge** le dernier jour.
- **Quand on a tout**, un **« ? »** apparaît au-dessus du villageois. On lui parle là où il est
  (Ravao au marché, les fermiers aux rizières…) et la livraison se fait : « +8 500 Ar », et il
  remercie.
- **On lui parle avant d'avoir tout** : il rappelle ce qu'il attend et le temps qu'il reste.
- **Délai dépassé** : la commande disparaît, avec la notification « Koto n'a pas reçu sa
  commande à temps. ». Rien d'autre n'est perdu.
- **Ce que paie une commande** : 30 à 60 % de plus que la boutique, ce qui pousse à varier les
  cultures. S'y ajoute 5 % par cœur d'amitié avec le villageois (voir `friendship.md`), affiché
  dans le panneau.
- **Jamais de commande impossible** : un villageois ne demande que ce que le joueur peut avoir
  à temps.
- **Chaque villageois demande des choses qui lui ressemblent** :
  - Ravao : des légumes pour son étal ;
  - Neny Soa : des mangues, des œufs, de quoi cuisiner ;
  - Rakoto : du riz, du manioc ;
  - Naivo : des cultures de saison sèche ;
  - Koto : de petites demandes.

## Détails techniques
**Données : `OrderTemplate`** (`core/data/order_template.gd`), dans `VillagerData.orders`
- Champs :
  - `item_id` : un id de culture ou d'objet ;
  - `quantity` : la quantité, tirée entre x et y ;
  - `unit_reward` : en Ariary par unité ;
  - `days` : le délai, en comptant le jour où la commande est acceptée ;
  - `request_line` : la phrase de demande, en français, avec `%d` pour la quantité. L'objet
    est nommé dans la phrase elle-même. Vide = une phrase générique ;
  - `thanks_line` : la phrase de remerciement.
- Les commandes de chaque villageois sont dans sa fiche `data/villagers/<id>.tres` et se
  modifient dans l'inspecteur. `tools/place_villagers.gd` les remplit depuis sa table
  `VILLAGERS`, seulement si la fiche n'en a pas.

**Règles : `FarmSimulation`** (testables, sauvegardées)
- `register_order_giver(id, templates)` : l'id est le nom du fichier de la fiche.
- Chaque matin (`advance_day` → `_advance_orders`) :
  1. les commandes acceptées dont le délai est passé expirent (`order_expired`) ;
  2. les offres non acceptées depuis `ORDER_OFFER_DAYS` (2) disparaissent ;
  3. `refresh_order_offers()` (une fois par jour) : un villageois sans commande ni temps de
     pause propose une commande avec la probabilité `order_offer_chance` (0,5), avec au plus
     `ORDER_MAX_OFFERS` (2) offres en attente.
- **`can_fulfil(item, quantity, days)`** décide si une commande peut être proposée. Il faut :
  - que le joueur l'ait déjà dans son inventaire ;
  - **ou** une culture de la saison (ou de toute saison), avec un délai plus long que sa
    pousse, et une rizière inondée au joueur si c'est du riz ;
  - **ou** des œufs avec des poules ;
  - **ou** un fruit de saison sur un arbre du joueur.
- `accept_order` (au plus `ORDER_MAX_ACTIVE` = 3 en cours), `decline_order`,
  `can_deliver_order`, `deliver_order` (retire les objets, paie `get_order_payment`, avec le
  prix d'ami, renvoie la somme, ajoute de l'amitié).
- Après une livraison, un refus ou une expiration, le villageois fait une pause de
  `ORDER_COOLDOWN_DAYS` (2) jours.
- `get_order`, `is_order_offered`, `is_order_active`, `get_active_orders`,
  `get_order_days_left`, `get_order_template`. Signal `order_changed`.
- **Sauvegarde** : `FarmState.orders` (par villageois : objet, quantité, récompense, modèle,
  jour de l'offre, dernier jour), `order_cooldowns`, `order_roll_day`. Les anciennes
  sauvegardes démarrent sans commande.

**Lien avec le jeu : `OrderManager`** (`systems/orders/order_manager.gd`, `Gameplay/OrderManager`)
- Enregistre au démarrage les commandes de toutes les fiches de `data/villagers/`.
- Quand le joueur parle à un villageois (`Villager.interacted`), il répond selon le cas :
  offre → `OrderPanel` ; commande livrable → livraison ; en cours → rappel ; sinon → salut.
- Met à jour les marques (`Villager.set_order_mark` : « ! » ou « ? »), l'action proposée
  (`set_prompt`) et `OrdersTracker`.
- Annonce le matin qui a une nouvelle commande, et signale les commandes expirées.

**Interface** (`ui/orders/`, sous `UI` dans `world.tscn`, construite en code)
- `OrderPanel` : met le jeu en pause, comme la boutique. Signaux `accepted` et `declined`.
- `OrdersTracker` : le cadre en haut à droite, `show_orders(rows)`.

**Villageois** : `villager.tscn` a un `InteractableComponent` (portée `TALK_REACH`) et un
`Label` `Mark`. `Villager.greet()` salue tout de suite, `say(text)` affiche une phrase dans la
bulle.

**Tests**
- `run_tests.gd` :
  - seulement des commandes faisables (saison, rizière, poules, temps de pousse) ;
  - acceptation, livraison et paiement, puis la pause ;
  - offre qui disparaît, commande qui expire sans pénalité ;
  - 3 commandes au plus ;
  - sauvegarde et chargement.
- `behaviour_test.gd` : le parcours complet, « ! », panneau, acceptation, suivi, « ? »,
  livraison et paiement.

## À savoir
- **Ajouter une commande** : dans la fiche du villageois, ajouter un `OrderTemplate` à
  `orders`. Vérifier que `days` laisse le temps de faire pousser la culture (pousse + 1 jour
  au moins), sinon elle ne sera jamais proposée tant que le joueur n'en a pas en stock.
- **Équilibrage** : `unit_reward` est fixé à la main, entre 30 et 60 % au-dessus du prix de
  vente. Si les prix de la boutique changent, revoir les commandes.
- **Les villageois qui passent par plusieurs zones** (les fermiers) ont une seule commande :
  on peut leur livrer dans l'une ou l'autre zone.
- **L'amitié** (`friendship.md`) : une commande livrée rapproche du villageois, et ses cœurs
  augmentent ce que paient ses commandes.
- **Pistes** : un tableau d'annonces sur la place, de grandes commandes de fête.
''')
