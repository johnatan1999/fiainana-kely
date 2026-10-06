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
| [day_night.md](day_night.md) | `DayNightController` : heure, cycle jour/nuit, lanternes, HUD |
| [farming.md](farming.md) | `FarmingController`, `FarmView`, `FarmLandManager` : champs, rizières, cultures |
| [trees.md](trees.md) | `TreeManager` : arbres, arbres fruitiers, feuillage |
| [animals.md](animals.md) | `AnimalManager` / `Chicken` : poules et poulailler |
| [ambient_life.md](ambient_life.md) | `AmbientLife` : papillons, oiseaux, lucioles |
| [world_zones.md](world_zones.md) | `WorldManager` et scènes de zone : village, rizières, décor |
| [weather.md](weather.md) | `WeatherController` : pluie, ciel couvert, arrosage par la pluie |
| [hud.md](hud.md) | `HUD`, `HotbarUI`, retours visuels : interface en jeu |
