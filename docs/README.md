# Documentation technique

Une fiche par contrôleur / système. Chaque fiche décrit l'état **actuel** du jeu, avec le
même plan :

1. **Ce que voit le joueur** : le comportement en jeu, sans jargon.
2. **Détails techniques** : fichiers, nœuds, signaux, réglages exportés, conventions.
3. **À savoir** : limites, pièges, pistes d'évolution.

Règle (voir `CLAUDE.md`) : tout changement de gameplay, de visuel ou de système met à jour
la fiche concernée, ou en crée une nouvelle ajoutée à cet index.

| Fiche | Contrôleur / système |
|---|---|
| [day_night.md](day_night.md) | `DayNightController` : heure, jours de la semaine, cycle jour/nuit, lanternes, HUD |
| [farming.md](farming.md) | `FarmingController`, `FarmView`, `FarmLandManager` : champs, rizières, cultures |
| [trees.md](trees.md) | `TreeManager` : arbres, arbres fruitiers, feuillage |
| [animals.md](animals.md) | `AnimalManager` / `Chicken` : poules et poulailler |
| [ambient_life.md](ambient_life.md) | `AmbientLife` : papillons, oiseaux, lucioles |
| [world_zones.md](world_zones.md) | `WorldManager` et scènes de zone : ferme du joueur, village, bourg, rizières, décor |
| [zebu_cart.md](zebu_cart.md) | `ZebuCart` : charrettes à zébus sur les routes |
| [zebus.md](zebus.md) | `GrazingZebu`, `ZebuPen`, `ZebuManager`, `ZebuMarketPanel` : zébus en liberté, parcs, zébus du joueur, marché aux zébus |
| [villagers.md](villagers.md) | `Villager`, `VillagerRoads`, `VillagerVisual`, `VillagePaddy`, `NeighbourPaddyManager` : villageois, journées, fermiers et moisson chez les voisins, apparence par calques |
| [orders.md](orders.md) | `OrderManager`, `OrderTemplate` : commandes des villageois, panneau, suivi |
| [home_screen.md](home_screen.md) | `HomeScreen`, `Campfire`, `SaveSlotsPanel`, `SettingsPanel` : écran d'accueil (nuit au village, feu de camp), liste des parties, paramètres |
| [family_projects.md](family_projects.md) | `FamilyProjectManager`, `FamilyProject`, `FamilyProjectsPanel`, `KitchenManager` : projets de famille avec Dada (poulailler, parc à zébus, grenier, cuisine), chantiers et entraide, cuisine |
| [chicken_thieves.md](chicken_thieves.md) | `ChickenThiefManager`, `CoopPadlock`, `ScatteredFeathers` : les voleurs de poules (rumeur, nuits, cadenas, poulailler en briques) |
| [quests.md](quests.md) | `QuestManager`, `Quest`, `QuestStep`, `QuestTarget` : les quêtes secondaires (données, étapes, cibles dans le monde), et comment en ajouter |
| [forest.md](forest.md) | `ForestManager`, `Discovery`, `WildAnimal`, `ForageSpot`, `DiscoveryPlace` : la forêt (animaux à observer, cueillette, lieux) et le carnet du joueur |
| [evening.md](evening.md) | `EveningManager`, `EveningPanel`, `DayLog` : le repas du soir en famille au coucher, le bilan de la journée et demain |
| [save.md](save.md) | `SaveController`, `SaveSlots` : 3 parties, sauvegarde au coucher, menu pause |
| [cockfight.md](cockfight.md) | `CockfightManager`, `TetheredRooster`, `CockfightRing` : coq de combat du joueur, tournoi de l'Alahady au bourg, classement |
| [school.md](school.md) | `SchoolManager`, `SchoolPanel` : écolage de Fara, directrice de l'école, Fara renvoyée à la maison |
| [friendship.md](friendship.md) | `FriendshipManager`, `FriendshipReward` : amitié avec les villageois, cœurs, cadeaux, prix d'ami |
| [shops.md](shops.md) | `Shop`, `ShopProfile`, `ShopUI` : épicerie du village, marché du zoma au bourg |
| [weather.md](weather.md) | `WeatherController` : pluie, ciel couvert, arrosage par la pluie |
| [hud.md](hud.md) | `HUD`, `HotbarUI`, retours visuels : interface en jeu |
