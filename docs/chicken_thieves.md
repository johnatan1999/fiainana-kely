# Voleurs de poules : `ChickenThiefManager`, `CoopPadlock`, `ScatteredFeathers`

## Ce que voit le joueur
- **D'abord une rumeur**, jamais un vol sans prévenir. Un matin, une notification :
  « Mpangalatra akoho ! Des poules ont disparu chez Naivo cette nuit. Un cadenas sur le
  poulailler, au marché, ne serait pas de trop. » Le soir, Neny en reparle au repas.
- **Les voleurs rôdent 3 nuits.** Chaque nuit, ils peuvent venir au poulailler (4 chances sur
  10).
  - **Poulailler ouvert** : au matin, « un voleur est entré dans le poulailler : il manque une
    poule ». Des plumes traînent devant la porte toute la journée, et Dada en parle au repas
    du soir.
  - **Poulailler fermé** : « des voleurs ont essayé d'ouvrir le poulailler : le cadenas a
    tenu ! ». Dada s'en réjouit au repas.
  - Dans les deux cas, ils partent ensuite : **jamais plus d'une poule par alerte**.
- **Les protections** :
  - le **cadenas du poulailler** (*hidy*), 5 000 Ar au marché du village (rayon outils). Il
    se pose tout de suite sur la porte, où on le voit, et quitte l'étalage ;
  - le **poulailler en briques** (projet de famille, niveau 3), qui ferme de lui-même.
- **Ce qui ne peut pas arriver** :
  - rien pendant les **deux premières semaines** (avant le jour 15) ;
  - rien avec moins de 2 poules : **la dernière poule n'est jamais volée** ;
  - pas de nouvelle alerte avant **12 jours de calme**.

Côté game design :
- **La menace est prévenue, évitable et petite.** Le joueur entend la rumeur, a une solution
  abordable au marché, et ne perd au pire qu'une poule (3 500 Ar) : assez pour piquer, jamais
  de quoi décourager.
- **Le vol déjoué se raconte** (notification, repas du soir) : le joueur voit que son achat
  l'a protégé.
- **Le poulailler en briques** gagne une raison de plus d'être construit.
- **La sauvegarde au coucher empêche de recharger** : la perte est réelle, c'est pourquoi elle
  reste légère.

## Détails techniques
**Règles : `FarmSimulation`** (testables, sauvegardées)
- Constantes :
  - `THIEF_FROM_DAY` (15), `THIEF_ALERT_CHANCE` (0,12 par matin) ;
  - `THIEF_ALERT_NIGHTS` (3), `THIEF_NIGHT_CHANCE` (0,4 par nuit) ;
  - `THIEF_COOLDOWN_DAYS` (12), `THIEF_MIN_HENS` (2) ;
  - `PADLOCK_ITEM` (`"coop_padlock"`), `THIEF_RUMOUR_NEIGHBOURS` (les voisins que nomme la
    rumeur).
- `thief_alert_chance` et `thief_night_chance` : les tests les mettent à 0 ou 1.
- `_advance_thieves()`, chaque matin dans `advance_day()` :
  1. si les voleurs rôdaient la nuit passée, ils viennent (avec la chance de la nuit) :
     `_thieves_come()` ;
  2. puis une nouvelle rumeur peut commencer, s'il y a un poulailler, au moins 2 poules, le
     jour 15 passé et le calme écoulé.
- `_thieves_come()` :
  - poulailler sûr → `thieves_foiled`, `DayLog.thieves_foiled` ;
  - sinon une poule tirée au hasard est retirée de `state.animals` : `animal_removed`,
    `chicken_stolen`, `DayLog.chicken_stolen`.
  
  Dans les deux cas l'alerte se termine.
- `is_thief_alert()`, `is_coop_safe()` (niveau 3 ou cadenas), `get_hen_ids()`.
- `is_item_on_sale(item)` : le cadenas seulement pour un poulailler construit et pas encore
  sûr. `buy_item()` le refuse sinon. Acheté, il ne va pas dans le sac : il est posé
  (`coop_secured`).
- **Sauvegarde** : `FarmState.thief_alert_until`, `thief_next_alert_day`, `thief_rumour`,
  `thief_stolen_day`, `coop_padlock`. Les anciennes sauvegardes démarrent sans voleurs ni
  cadenas.

**Lien avec le jeu : `ChickenThiefManager`** (`systems/animal/`, `Gameplay/ChickenThiefManager`)
- Les notifications du matin (rumeur, vol, vol déjoué) et celle de la pose du cadenas.
- Sur le poulailler de la zone (`Coop.GROUP`), près de la porte :
  - `CoopPadlock` (`structures/chicken_coop/coop_padlock.gd`), dessiné en code, tant que le
    cadenas est posé et que le poulailler n'est pas en briques ;
  - `ScatteredFeathers` (`entities/animals/chicken/scattered_feathers.gd`) le jour d'un vol.
  
  Leur place se règle avec `PADLOCK_OFFSET` et `FEATHERS_OFFSET`.
- `AnimalManager` retire la poule volée si elle est à l'écran (`animal_removed`). Les poules
  décoratives de la cour suivent au prochain chargement.
- `ShopUI` cache ce qui n'est pas en vente (`is_item_on_sale`) et se reconstruit quand le
  cadenas est posé.
- Le repas du soir : `EveningManager._thief_lines()`.

**Données** : `data/items/coop_padlock.tres` (catégorie outils, sans action : pas dans la
barre d'outils).

**Tests**
- `run_tests.gd` :
  - la rumeur d'abord, jamais avant le jour 15 ni pour une poule seule ;
  - une seule poule volée, jamais la dernière ;
  - le cadenas (vendu une fois, posé tout de suite, qui tient) et le poulailler en briques ;
  - la sauvegarde.
- `behaviour_test.gd` : rumeur et repas du soir, vol, plumes, cadenas acheté au marché (posé,
  retiré de l'étalage), vol déjoué.

## À savoir
- **Équilibrage** : environ une alerte par mois au plus (chance du matin et calme de 12
  jours), et une chance sur deux à peu près qu'une alerte coûte une poule à un poulailler
  ouvert. Le cadenas est rentable dès la deuxième poule sauvée.
- **Une fois protégé**, le joueur n'entend plus que la rumeur et les vols déjoués. C'est
  voulu : la menace apprend à prendre soin de sa ferme, puis s'efface.
- **Pistes** :
  - **le chien (*alika*)** qui aboie la nuit : une autre protection, en récompense de quête ;
  - les **dahalo** (voleurs de zébus) : un événement d'histoire avec la veillée du fokonolona,
    et le parc à zébus amélioré comme protection ;
  - retrouver la poule volée au tsena du bourg (une petite quête).
