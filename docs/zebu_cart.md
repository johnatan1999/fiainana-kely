# Charrettes à zébus : `ZebuCart`

## Ce que voit le joueur
- Une **charrette à zébus (sarety)** traverse le village : une paire de zébus sous le joug qui
  marchent, des roues qui tournent, un conducteur au chapeau de paille.
- Elle arrive par la **sortie est**, contourne la maison de l'est par le sud et va jusqu'au
  **marché**. Elle s'y arrête un moment (livraison), puis repart et disparaît par l'est, avant
  de revenir plus tard.
- Elle **s'arrête quand le joueur lui barre la route**, sans le pousser, et repart quand il
  s'écarte. On ne peut pas la traverser.
- Elle ne part **que de jour** (de 6:30 à 18:30). Si elle est encore en route à la tombée de
  la nuit, sa **lanterne** s'allume.

## Détails techniques
- **`entities/zebu_cart/zebu_cart.tscn`** (`ZebuCart`, un `PathFollow2D`) : à placer comme
  enfant d'un `Path2D` tracé sur un chemin. Le `Path2D` doit être y-sorté.
  - Dans le village : `CartRoute_Est`, de la sortie est (hors écran) au marché.
  - Trajet : `OUT` (début → fin), `STOPPED` (pause à la fin), `BACK` (retour), `AWAY` (caché
    hors écran, puis nouveau départ).
  - **Approche hors champ** : au démarrage, la charrette ajoute au début de sa route un point
    `LEAD_IN × art_scale` plus loin (environ 210 px), dans le prolongement du premier tronçon.
    Elle arrive ainsi entière depuis l'extérieur, au lieu d'apparaître avec ses zébus déjà
    sur la carte. Cet ajout se fait sur une copie de la courbe : la scène n'est pas
    modifiée.
  - Exports : `away_time`, `stop_time`, `first_delay`, **`art_scale`** (taille de l'ensemble :
    dessin, collision et zone de détection).
  - Horaires de départ : `FIRST_DEPARTURE` et `LAST_DEPARTURE`. Elle suit l'**horloge**
    (`DayNightController.CLOCK_GROUP`), pas la lumière.
  - **Collision** : un `AnimatableBody2D` (`Body`) au sol. **Détection** : une `Area2D`
    (`Ahead`) devant les zébus. Les deux sont **déplacées** plutôt que retournées quand la
    charrette change de sens (pas d'échelle négative sur la physique). Leurs formes sont
    `resource_local_to_scene`, mises à l'échelle à `_ready()`.
  - **Animation** : 4 images de marche des zébus, réglées sur la distance parcourue
    (`STEP_DISTANCE`), et roues qui tournent selon le rayon (`WHEEL_RADIUS`).
- **Dessin** : `assets/sprites/animals/zebu_cart.png`, généré par
  `tools/placeholder_art/gen_zebu_cart.gd`. Vue de profil vers la droite, densité 2× :
  - rangée 1 : zébu, 4 images de 128×96 (`hframes = 4`, `vframes = 2`) ;
  - rangée 2 : caisse 160×96, roue 80×80, conducteur 64×96.

  Le tout est assemblé dans `Visual` (zébu de derrière assombri, joug en `Line2D`, roues
  séparées).
- **Test** : `tests/behaviour_test.gd` vérifie qu'elle ne part pas la nuit, qu'elle part de
  jour depuis l'extérieur de la carte (aucune partie visible au départ), qu'elle attend si le joueur barre la route et qu'elle repart ensuite.

## À savoir
- **Tracer une route** : faire commencer le `Path2D` au bord de la carte (ou juste après),
  avec un premier tronçon orienté vers l'extérieur. L'approche hors champ le prolonge
  d'elle-même.
- **Vue de profil seulement** : les routes doivent être surtout horizontales. Sur une portion
  verticale, la charrette resterait de profil. Avec des dessins de face et de dos, on pourra
  choisir l'image selon la direction.
- **Remplacer le dessin** : garder la disposition de la planche (ou ajuster les régions dans
  la scène). Les roues doivent rester un sprite à part pour tourner.
- **Ajouter une route** : un `Path2D` y-sorté avec une instance de `zebu_cart.tscn` en enfant.
  Tracer la route en évitant les troncs, les clôtures et les objets : la charrette ne
  contourne rien, elle suit sa courbe.
- **Pistes** : zébus en liberté qui paissent ; enclos et zébus du joueur ; labour de la
  rizière ; transport entre les zones et les villages.
