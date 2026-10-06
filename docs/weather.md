# Météo : `WeatherController`

## Ce que voit le joueur
- Chaque matin, le temps du jour est tiré selon la saison : il pleut environ **un jour sur
  deux en Asara** (saison des pluies) et **rarement en Asotry** (environ 8 % des jours).
- **Un jour de pluie** :
  - **toutes les parcelles labourées sont arrosées dès le réveil**, y compris celles plantées
    plus tard dans la journée : pas besoin d'arrosoir ;
  - au réveil, la notification « **Il pleut : les cultures sont arrosées.** » apparaît, et une
    **icône de nuage** s'affiche dans le HUD à côté de l'heure ;
  - le ciel se couvre (lumière plus grise et bleutée, de jour comme de nuit), un rideau de
    pluie oblique tombe, et de petites éclaboussures marquent le sol ;
  - on entend la pluie, plus étouffée à l'intérieur ;
  - les papillons se cachent et les vols d'oiseaux s'arrêtent.
- **À l'intérieur**, il ne pleut pas, la lumière est seulement un peu plus grise et le son
  étouffé.

## Détails techniques
**Simulation**
- `FarmState.weather` (`FarmState.Weather` : `CLEAR`, `RAIN`) est sauvegardé (clé
  `"weather"`). Les anciennes sauvegardes ont un temps clair.
- `FarmSimulation.advance_day()` tire la météo du jour : `_roll_weather()` selon `RAIN_CHANCE`
  (par saison), puis `set_weather()`.
- `set_weather(weather)` : la pluie arrose les parcelles **labourées** non arrosées. Les
  terres en friche restent sèches, car un sol mouillé est dessiné comme un sol travaillé.
  Émet `weather_changed`.
- `is_raining()`.
- `FarmSimulation.rain_chance` : copie de `RAIN_CHANCE` propre à chaque partie. Les tests la
  vident (`{}`) pour que `advance_day()` reste déterministe.

**Affichage : `systems/weather/weather_controller.gd`** (`Gameplay/WeatherController`,
initialisé par `World` avec `setup(simulation, world_manager, day_night, player)`)
- **Pluie dans le monde** (pas sur un `CanvasLayer`), pour qu'elle s'assombrisse la nuit avec
  le reste. Le nœud `Rain` suit `camera.get_screen_center_position()`, c'est-à-dire la vue
  réelle, y compris en bord de carte.
  - **Gouttes** : `CPUParticles2D` en coordonnées locales, qui suivent la vue, avec
    `z_index` 60.
  - **Éclaboussures** : en coordonnées du monde, qui restent où elles tombent, avec
    `z_index` -5 (au sol, sous les objets).
- **Ciel couvert** : `DayNightController.set_overcast(0..1)` multiplie la teinte par
  `OVERCAST_TINT`. Il s'installe ou se dissipe en 2 s, et vaut 0,35 à l'intérieur.
- **Son** : `AudioManager.set_rain_ambience(active, muffled)`.
  - Utilise le slot **`bgs_rain`** s'il est rempli.
  - Sinon, un bruit de pluie **généré par le code** (`AudioStreamGenerator` : bruit filtré et
    gouttes) le remplace.
- **Notification au réveil** : seulement quand la pluie commence pendant le jeu, pas au
  chargement d'une sauvegarde (`_announce`).
- **Groupe `WEATHER_GROUP`** (`"weather_listeners"`) : reçoit `set_raining(raining)`.
  Membre : `AmbientLife`.
- **HUD** : `WeatherGlyph` (`HudGlyph`, sorte `"rain"`), visible quand il pleut.

**Tests**
- `run_tests.gd` : arrosage des seules parcelles labourées, pousse sans arrosoir,
  sauvegarde, fréquence de pluie par saison.
- `behaviour_test.gd` : pluie et ciel couvert dehors, rien à l'intérieur, papillons à l'abri,
  arrêt quand le temps se dégage.

## À savoir
- **Le son de pluie est généré par le code** : il fait l'affaire, mais un vrai enregistrement
  dans `bgs_rain` (sur `AudioManager.tscn`) sera bien meilleur. Prendre un fichier qui boucle
  sans coupure.
- **Pistes** : flaques qui persistent après la pluie, orages en pleine saison des pluies
  (éclairs, tonnerre), arc-en-ciel au retour du soleil, poules qui s'abritent, prévisions
  pour le lendemain (radio, villageois).
