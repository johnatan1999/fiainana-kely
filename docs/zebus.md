# Zébus en liberté : `GrazingZebu`

## Ce que voit le joueur
- De petits **troupeaux de zébus** paissent dans les prés : au nord-est du village (4 bêtes)
  et au bord des rizières (3 bêtes). Robes mélangées, comme à Madagascar : brun, fauve, gris,
  presque noir, blanc.
- La plupart du temps ils **broutent** (tête baissée, mâchoire qui bouge), font **quelques
  pas lents** de temps en temps, et parfois **se couchent** pour ruminer.
- Quand le joueur s'approche, le zébu **relève la tête et le regarde**. Il ne fuit pas.
- Ils sont **solides** : on les contourne.
- **La nuit** (de 20:00 à 5:45), tout le troupeau est couché.

## Détails techniques
- **`entities/zebu/grazing_zebu.tscn`** (`GrazingZebu`, un `CharacterBody2D` en
  `motion_mode` flottant) : `Sprite2D` (échelle 0,8, ancré en bas) et collision rectangulaire
  au sol (70×14).
- **Placement** : sous un nœud y-sorté `ZebuHerd` dans la scène de zone
  (`player_village.tscn`, `rice_fields.tscn`). Chaque zébu erre autour de l'endroit où il est
  posé, dans un rayon `wander_radius` (export, 110 px).
- **Exports** : `wander_radius`, `coat` (indice dans `COATS`, -1 = au hasard).
- **Comportement** : `Activity` `GRAZE` (4–10 s), `WALK` (vers un point au hasard autour du
  point de départ, abandonné s'il est bloqué ou trop long), `REST` (15–30 s).
  - Joueur à moins de `WATCH_DISTANCE` (72 px) : image « regarde », tourné vers lui.
  - Nuit : suit l'**horloge** (`DayNightController.CLOCK_GROUP`, `set_time_of_day`),
    `SLEEP_FROM` / `WAKE_AT`.
- **Ambiance pure** : aucun état de simulation, rien n'est sauvegardé.
- **Dessin** : `assets/sprites/animals/zebu.png`, généré par
  `tools/placeholder_art/gen_zebu.gd`. Profil vers la droite, densité 2×, cases de 128×96
  (`hframes = 4`, `vframes = 2`) :
  - 0–3 marche (0 = debout), 4–5 broute, 6 couché, 7 tête levée.
  - **Robe claire**, teintée par `self_modulate` : une seule planche pour tout le troupeau.
- **Test** : `tests/behaviour_test.gd` vérifie que le troupeau reste dans son pré, qu'un
  zébu regarde le joueur proche, qu'on ne le traverse pas, et que tous se couchent la nuit.

## À savoir
- Les zébus des **charrettes** (`zebu_cart.md`) ont leur propre planche. Une vraie planche
  pourra servir aux deux : garder le profil vers la droite et les cases de 128×96.
- Ne pas poser de troupeau sur un chemin étroit : un zébu bloque le passage.
- **Pistes** : un parc à zébus (vala) où ils rentrent le soir, un bouvier qui les mène,
  meuglements de temps en temps, zébus achetables et utiles (labour, charrette du joueur).
