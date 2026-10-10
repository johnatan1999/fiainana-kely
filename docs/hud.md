# Interface en jeu : `HUD`, `HotbarUI`, retours visuels

## Ce que voit le joueur
- **En haut à gauche (`HUD`)** : saison et **jour de la semaine** (« Asara · Zoma »), année,
  **heure** (par pas de 10 minutes),
  **icône de pluie** les jours de pluie, progression de la saison et argent. Les gains et
  dépenses d'argent s'animent (+/−).
- **En bas au centre (`HotbarUI`)** : la barre d'outils et de graines (8 cases). Les récoltes
  n'y vont pas : elles vont dans le sac, qui s'ouvre depuis le menu pause.
- **En haut de l'écran (`Toast`)** : les messages courts (« Poulailler plein », « Manguier :
  fruits dans 3 jours »).
- **Dans le monde (`HarvestPopup`)** : « +3 Maïs » au-dessus de ce qui vient d'être récolté
  (voir `farming.md`).
- **En haut à droite (`OrdersTracker`)** : les commandes acceptées (voir `orders.md`), et
  dessous les rappels à date (`show_reminders()` : l'écolage de Fara, voir `school.md`), puis
  les quêtes en cours avec leur prochaine étape (`show_quests()`, voir `quests.md`).
- **L'inventaire (`InventoryUI`, touche I)** : un livre avec 5 onglets (Cultures, Élevage,
  Outils, Nourriture, **Villageois**), la grille de l'onglet choisi et une fiche détaillée.
  L'onglet Élevage montre aussi les poules, les zébus et le chien (voir `dog.md`). Dans
  l'onglet Villageois, la grille montre le portrait de chacun, et la fiche son rôle, sa maison,
  son prochain cadeau, son amitié, son prix d'ami, sa commande et l'endroit où il est en ce
  moment (voir `friendship.md`).

## Détails techniques
- **`HUD.gd`** : `TimeLabel` est mis à jour par `time_changed` (voir `day_night.md`).
  `DateLabel` montre la saison et le jour de la semaine ; le jour de la saison est sur la
  barre (`DaysLabel`, « 5/30 »).
- **`Toast`** (`ui/notifications/toast.gd`) : alimenté par `UIEvents.notify()`. Un nouveau
  message remplace celui affiché.
- **Onglet Villageois de l'inventaire** :
  - ajouté en code par `InventoryUI` (`_add_villagers_tab`). Pour qu'il tienne, les 5 onglets
    sont raccourcis (`InventoryCategoryTab.set_compact`, `TAB_HEIGHT`) ;
  - catégorie `InventoryCatalog.Category.VILLAGERS`, fiches par `describe_villager()`.
    L'endroit où se trouve le villageois vient de sa routine et de la météo, sans que sa zone
    soit chargée. Les noms des lieux sont dans `SPOT_PLACES` et `HOME_PLACES` ;
  - portraits : `VillagerPortrait.make(look)` compose le visage et les épaules à partir des
    calques teintés du villageois, une fois par apparence (en cache).

## À savoir
- Un journal des objets reçus (« Maïs +3 (12) » en bas à gauche) a été essayé puis retiré :
  visuellement trop chargé. Le retour de récolte passe uniquement par `HarvestPopup`.
