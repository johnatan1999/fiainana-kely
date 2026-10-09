# Écran d'accueil : `HomeScreen`, `Campfire`, `SaveSlotsPanel`, `SettingsPanel`

## Ce que voit le joueur
- **Au lancement**, un fondu depuis le noir sur **le village, la nuit**. Le joueur est
  accroupi près d'un **feu de camp**, sur la terre rouge entre la maison du marché et
  l'épicerie, à côté de la marmite sur ses trois pierres. Il se réchauffe et bouge un peu de
  temps en temps.
  - Le feu crépite : flammes, étincelles, un filet de fumée, et une lumière chaude qui
    vacille sur le sol et les maisons.
  - Les lanternes du village sont allumées, des lucioles volent, les villageois sont rentrés
    chez eux.
  - En fond, la musique douce de la maison (« Vorona o Barijaona »).
- **À gauche, le menu** sur une ombre dégradée : « Fiainana kely », « Une petite vie à
  Madagascar », puis :
  - **Continuer** : la liste des parties. Grisé s'il n'y en a aucune ;
  - **Nouveau jeu** : une nouvelle partie dans le premier emplacement libre. Si les trois
    sont pris, la liste s'ouvre avec un mot (« supprimes-en une pour en commencer une
    nouvelle ») ;
  - **Paramètres** ;
  - **Quitter**.
- **La liste des parties** (« Tes parties ») : pour chaque emplacement, la saison, le jour,
  l'année, l'argent, le temps de jeu et la date de sauvegarde, avec « Continuer » et
  « Supprimer » (second appui pour confirmer), ou « Nouvelle partie » s'il est libre.
  « Retour » ou Échap ramène au menu.
- **Les paramètres** : langue (Français → Malagasy → English), volume de la musique,
  volume des effets sonores (un clic au nouveau volume quand on lâche le curseur), plein
  écran. Ils s'appliquent tout de suite et sont gardés pour les prochaines fois.

Côté game design : la première image du jeu donne le ton. La nuit au village, le feu et le
personnage au repos annoncent un jeu cosy et chaleureux, ancré à Madagascar. C'est le même
monde que celui du jeu, pas une illustration à part.

## Détails techniques
**`HomeScreen`** (`ui/home/home_screen.gd`, scène principale `ui/home/home_screen.tscn`)
- La scène est écrite par `tools/build_home_screen.gd` (avec `--editor`) : un `Node2D` vide.
  Tout est construit en code.
- **Le décor** :
  - la vraie scène du village (`player_village.tscn`), plus un `Campfire` à `FIRE_AT` et un
    `FiresidePlayer` à `PLAYER_AT` ;
  - un `CanvasModulate` (`NIGHT`) et une `Camera2D` (`CAMERA_AT`, `ZOOM`) ;
  - on dit l'heure au village par ses groupes : `CALENDAR_GROUP` (samedi), `CLOCK_GROUP`
    (22:00) et `LIGHT_GROUP` (nuit complète). Lanternes, lucioles, villageois et poules
    réagissent comme en jeu.
- **Le menu** : un `CanvasLayer` (`UI`) avec les boutons `Continue`, `NewGame`, `Settings` et
  `Quit`, et les deux panneaux.
- `play(slot)` fixe `SaveSlots.current` et ouvre `world.tscn`. `first_free_slot()`,
  `has_any_save()`.
- Au démarrage : `SaveSlots.migrate_legacy()` (l'ancienne sauvegarde devient la partie 1)
  et `AudioManager.play_interior_bgm()`.
- Retour depuis le jeu : menu pause → « Menu principal » (`world.gd`, `HOME_SCREEN`).

**`Campfire`** (`environment/lighting/campfire.gd`) : un feu de camp réutilisable,
toujours allumé, dessiné en code.
- Pierres en anneau (celles de devant passent par-dessus le pied des flammes), bûches
  croisées et braises.
- Trois `CPUParticles2D` : flammes et étincelles (additives, non ombrées : elles brillent
  dans la nuit) et fumée.
- Un `PointLight2D` qui vacille (`light_radius`, `light_energy`).
- Son origine est le centre du feu, au sol.

**`FiresidePlayer`** (`ui/home/fireside_player.gd`) : le joueur accroupi, deux poses de
`player2.png` (64 × 128, tournées vers la droite) qui alternent, et une respiration lente.

**`SaveSlotsPanel`** (`ui/home/save_slots_panel.gd`) : la liste des parties.
`open(note)`, `close()`, signaux `play_requested(slot)` et `closed`. Voir `save.md`.

**`SettingsPanel`** (`ui/home/settings_panel.gd`) : `open()`, `close()`, signal `closed`. Il
passe par `GameSettings` :
- `get_volume` / `set_volume(bus, 0..1)` sur les bus `Music` et `SFX` d'`AudioManager`
  (muet à 0) ;
- `is_fullscreen` / `set_fullscreen` ;
- `cycle_locale`.
- Tout est gardé dans `user://settings.cfg` et réappliqué au démarrage (les volumes une fois
  les bus créés).

**Tests** (`behaviour_test.gd`, à la fin, car l'écran prend la caméra) :
- la nuit au village, le feu, le joueur, les lanternes allumées ;
- « Continuer » ouvre la liste, « Paramètres » ouvre les paramètres ;
- sans partie, « Continuer » est grisé.

## À savoir
- **Le village de l'écran d'accueil est la vraie zone** : si elle change dans l'éditeur, le
  décor change aussi. Après une retouche à cet endroit, vérifier que le feu
  (`FIRE_AT`, sur la terre entre la maison du marché et l'épicerie) reste dégagé. Pour
  regarder un coin de carte sans l'éditeur : `tools/zone_snapshot.gd` (voir
  `world_zones.md`).
- **Art provisoire** : le feu est dessiné en code, et le joueur n'a pas de vraie pose assise
  (il est accroupi). Une planche « assis sur une bûche » et un feu dessiné rendraient la
  scène plus belle, sans changer le code autour.
- **Pistes** :
  - un villageois au coin du feu (Neny Soa qui raconte des angano) ;
  - le décor qui suit la saison de la dernière partie (pluie en Asara) ;
  - le crépitement du feu en son d'ambiance ;
  - le feu de camp dans le village en jeu, pour les soirées de fête.
