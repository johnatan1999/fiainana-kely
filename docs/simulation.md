# La simulation : `FarmSimulation` et ses domaines (`SimRules`)

## Ce que voit le joueur
Rien directement. La simulation, ce sont **toutes les règles du jeu** : ce que rapporte une
récolte, quand un zébu grandit, ce que fait la nuit. Elle ne dessine rien : le monde et
l'interface l'écoutent et l'appellent. C'est pourquoi les règles se testent sans lancer le
jeu (`tests/run_tests.gd`).

## Détails techniques
**Le hub : `FarmSimulation`** (`systems/simulation/farm_simulation.gd`, `RefCounted`). Il
contient ce que tous les domaines partagent :
- **l'état** : `state` (`FarmState`, tout ce qui est sauvegardé), et `day_log` (`DayLog`,
  le journal du jour, pour le repas du soir) ;
- **tous les signaux** (`money_changed`, `quest_changed`, `dog_changed`...). Un écouteur n'a
  pas besoin de savoir quel domaine a changé les choses ;
- **le sac et l'argent** : `add_item(id, quantité)` (négatif : retirer) et
  `add_money(montant)`, qui émettent `inventory_changed` et `money_changed`, ainsi que
  `spend_money(montant)` ;
- **l'horloge et la météo** : `advance_time()`, `is_raining()`, `set_weather()`,
  `rain_chance` ;
- **la nuit** : `advance_day()` appelle les crochets de chaque domaine dans un ordre voulu.
  D'abord la journée qui finit (cultures, poules, zébus, arbres, coq), puis le nouveau
  matin (météo, voleurs, commandes, écolage, chantier, quêtes, panier du poulailler) ;
- **les conditions d'histoire** : `get_conditions()` (écolage en retard, quêtes) ;
- **la sauvegarde** : `to_save_data()`, `load_save_data()`.

**Les domaines** (`systems/simulation/rules/`). Chacun hérite de `SimRules` et s'atteint par
son nom : `simulation.zebus.buy_zebu()`. Il contient ses constantes
(`ZebuRules.ZEBU_PRICE`), ses données enregistrées et ses règles.

| Accès | Classe | Domaine |
|---|---|---|
| `fields` | `FieldRules` | Les parcelles et la grille : labourer, planter, arroser, récolter, le fumier épandu ; demain (cultures mûres, cases sèches) |
| `animals` | `AnimalRules` | Le poulailler et les poules : achat, installation, soins, œufs, naissances, reconstruction |
| `zebus` | `ZebuRules` | Les zébus : marché, abreuvoir, croissance, labour, fumier |
| `trees` | `TreeRules` | Les arbres fruitiers |
| `cockfight` | `CockfightRules` | Le coq de combat et le tournoi du dimanche |
| `friendship` | `FriendshipRules` | L'amitié : points, cœurs, cadeaux, ce que vaut chaque geste (`FRIENDSHIP_*`) |
| `projects` | `ProjectRules` | Les projets de famille : bâtiments, niveaux, chantier |
| `kitchen` | `KitchenRules` | La cuisine et les recettes |
| `notebook` | `NotebookRules` | Le carnet et la forêt : pages, animaux, cueillette |
| `thieves` | `ThiefRules` | Les voleurs de poules et le cadenas |
| `dog` | `DogRules` | Le chien de la famille |
| `quests` | `QuestRules` | Les quêtes secondaires |
| `school` | `SchoolRules` | L'écolage de Fara |
| `orders` | `OrderRules` | Les commandes des villageois |
| `neighbours` | `NeighbourRules` | Les rizières des voisins et l'entraide à la moisson |
| `market` | `MarketRules` | Acheter et vendre (graines, objets, récoltes) |
| `hotbar` | `HotbarRules` | La disposition de la barre d'outils |

**`SimRules`** (`rules/sim_rules.gd`), la base des domaines :
- `sim` (le hub), `state` et `day_log` : les raccourcis vers ce qui est partagé ;
- le hub est tenu par une **référence faible** (`WeakRef`). Le hub tient ses domaines, et
  deux `RefCounted` qui se tiennent l'un l'autre ne seraient jamais libérés (une fuite à la
  fermeture).

**Conventions**
- **Un domaine en appelle un autre par le hub** : `sim.projects.get_building_level("coop")`.
  Il lit les constantes d'un autre par sa classe : `ProjectRules.COOP_BASKET_LEVEL`.
- **Les signaux restent sur le hub** : un domaine émet `sim.dog_changed.emit()`. Les
  écouteurs se branchent sur `simulation.dog_changed`.
- **Les crochets de la nuit** sont publics et nommés `advance_*`
  (`thieves.advance_thieves()`). Seul `advance_day()` les appelle, et les tests.
- **Les données** (quêtes, recettes, pages du carnet...) s'enregistrent auprès de leur
  domaine (`simulation.quests.register_quest()`), par leur manager au démarrage.

## À savoir
- **Ajouter un domaine** :
  1. créer `rules/<nom>_rules.gd` (`extends SimRules`) ;
  2. le déclarer et le créer dans le hub (`var`, puis `_init`) ;
  3. brancher ses crochets dans `advance_day()` si la nuit le concerne ;
  4. ajouter ses champs sauvegardés à `FarmState`, avec une clé optionnelle pour les
     anciennes sauvegardes ;
  5. ajouter ses signaux au hub, s'il en a.
- **L'ordre de la nuit compte** : par exemple, les voleurs passent après le tirage de la
  météo et avant les commandes, et le panier du poulailler après le début du nouveau
  journal. Le modifier change ce que le joueur voit le matin.
- **L'état reste un seul `FarmState`**, sauvegardé d'un bloc. Les domaines ne gardent rien
  de sauvegardé chez eux : seulement leurs données enregistrées (les `.tres` chargés) et des
  réglages pour les tests (`orders.order_offer_chance`, `thieves.thief_alert_chance`).
- **Piste** : découper aussi `FarmState` par domaine (une sous-structure par domaine, avec
  son `to_dict()`), comme `DogState`.
