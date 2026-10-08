# Cycle jour/nuit : `DayNightController`

## Ce que voit le joueur
- La journée commence à **6:00**. L'heure s'affiche dans le HUD à côté de la date, par pas de
  10 minutes (`21:30`).
- Le monde change de teinte au fil de la journée :

  | Heure | Ambiance |
  |---|---|
  | 5:30 – 7:30 | Aube rosée, puis lever du soleil orangé |
  | 8:30 – 16:00 | Plein jour |
  | 17:30 – 18:30 | Heure dorée, puis coucher du soleil |
  | 19:00 | Crépuscule : les lanternes s'allument |
  | 20:00 – 2:00 | Nuit bleue, lisible, avec des flaques de lumière chaude aux portes |

- Le temps **s'arrête à 2:00** : la nuit dure jusqu'à ce que le joueur dorme. Pas de malaise
  forcé. Dormir passe au jour suivant à 6:00.
- Les intérieurs (maison, poulailler) ne prennent pas la couleur du ciel : ils deviennent
  chauds et tamisés la nuit.
- Le HUD n'est jamais assombri.
- **La semaine malgache** : chaque jour a son nom, affiché dans le HUD à côté de la saison
  (« Asara · Talata »). Le jour 1 est un Alatsinainy (lundi) : Alatsinainy, Talata, Alarobia,
  Alakamisy, **Zoma** (jour de marché au bourg), Sabotsy, Alahady. Les enfants ne vont à
  l'école qu'en semaine, et le zoma, on descend au marché (voir `villagers.md`, `shops.md`).

## Détails techniques
**Simulation**
- `GameClock.minute_of_day` : minutes depuis minuit (au-delà de 1440 = après minuit, toujours
  le même jour). `DAY_START_MINUTE = 360`, `LATEST_MINUTE = 1560` (2:00).
  `advance_minutes()`, `get_hour()`, `get_minute()`. `advance_day()` remet 6:00.
- **Semaine** : `GameClock.Weekday` (`ALATSINAINY` … `ALAHADY`), `WEEKDAY_NAMES`,
  `get_weekday()` (tiré de `current_day`, rien de plus n'est sauvegardé),
  `get_weekday_on(day)`, `get_weekday_name(weekday)`, `MARKET_DAY` (`ZOMA`),
  `is_market_day()`, `days_to_market()`.
- `FarmSimulation.advance_time(minutes: float)` : cumule les fractions et émet
  `time_changed(minute_of_day)` à chaque minute entière.
- Sauvegarde : clé `"minute"` dans `FarmState.to_dict()`. Les anciennes sauvegardes, sans
  cette clé, repartent à 6:00.

**`systems/time/day_night_controller.gd`** (nœud `Gameplay/DayNightController` dans `world.tscn`)
- `REAL_SECONDS_PER_MINUTE = 0.7` : 6:00 → minuit dure environ 12,5 min réelles.
- Teinte le monde avec un `CanvasModulate` créé en code. Les `CanvasLayer` (UI, fondu) ne sont
  pas affectés.
- Tableau `SKY` : heure → couleur, interpolé en douceur. Intérieur : `INDOOR_DAY` →
  `INDOOR_NIGHT` selon la nuit.
- `get_night_amount()` : 0 le jour, 1 en pleine nuit (déduit de la luminosité du ciel).
- **Canaux d'horloge, volontairement séparés.** Tous sont aussi envoyés au chargement d'une
  zone, pour que ses nœuds démarrent dans le bon état.
  - **`LIGHT_GROUP`** (`"light_listeners"`) : `set_night(amount)` quand la lumière change.
    **Uniquement pour le visuel** : `NightLight`, `AmbientLife`.
  - **`CLOCK_GROUP`** (`"clock_listeners"`) : `set_time_of_day(minute_of_day)` à chaque
    minute. **Pour tout comportement réglé sur l'heure** : `Chicken`, `GrazingZebu`,
    `ZebuCart`, `Villager`.
  - **`CALENDAR_GROUP`** (`"calendar_listeners"`) : `set_weekday(weekday)` à chaque nouveau
    jour, avant le premier `set_time_of_day` du jour. Pour ce qui suit **la semaine** :
    `Villager` (école en semaine, marché le zoma), `Shop` (jours d'ouverture).
  - Règle : un comportement ne doit jamais dépendre de la lumière. Les couleurs du ciel
    (`SKY`) sont un réglage visuel qu'on doit pouvoir retoucher librement.
- `ZoneRoot.indoor` (export) : coché sur `player_interior_house` et `chicken_coop_interior`.
- `set_overcast(0..1)` / `get_overcast()` : ciel couvert par la pluie, multiplié à la teinte
  de l'heure par `OVERCAST_TINT` (voir `weather.md`).

**Lanternes : `environment/lighting/night_light.gd` (`NightLight`)**
- `PointLight2D` (texture radiale générée en code) et une petite flamme dessinée en
  *unshaded* pour rester vive dans le noir. Légère vacillation.
- Exports : `color`, `energy`, `radius`, `show_flame`.
- La lumière est réglée dès `set_night()`, pas seulement à l'image suivante : elle
  correspond toujours à l'état reçu, quel que soit le rythme des images.
- Placées sous un nœud `NightLights` (`z_index = 1`) dans chaque zone : portes des maisons,
  poulailler, marché, cabane des rizières.

**HUD** : `TimeLabel` (`ui/HUD.tscn`), mis à jour par `time_changed`.

## À savoir
- Rien ne dépend encore de l'heure côté gameplay (marché, cultures, énergie).
- Le temps tourne aussi quand un menu est ouvert, sauf si ce menu met l'arbre en pause.
- Un objet *unshaded* (`CanvasItemMaterial.LIGHT_MODE_UNSHADED`) ignore le `CanvasModulate` :
  c'est ce qu'utilisent les lucioles et les flammes.
- En headless, le renderer factice peut afficher des erreurs de shader sans conséquence.
