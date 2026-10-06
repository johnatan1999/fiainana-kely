# Villageois : `VillagerVisual`, `VillagerLook`

> Pour l'instant, c'est le **squelette visuel** des villageois : un corps de base animé dans
> les 4 directions et un système de calques pour l'apparence. Aucun villageois n'est encore
> placé dans le monde, et il n'y a ni déplacement ni dialogue.

## Ce que voit le joueur
- Rien en jeu pour l'instant.
- Dans l'éditeur, un nœud `VillagerVisual` montre le villageois animé. Les cases `facing` et
  `walking` de l'inspecteur permettent de vérifier chaque direction.

## Détails techniques
**La planche de base** : `assets/sprites/characters/villager/base_body.png`
- Un **mannequin neutre**, sans vêtements ni cheveux, dessiné clair pour être teinté par la
  couleur de peau.
- Densité 2× (affichée à l'échelle 0,5), **cases de 128×256**, 6 colonnes × 4 rangées
  (768×1024).
- Une rangée par direction : **0 bas** (face), **1 gauche**, **2 droite**, **3 haut** (dos).
- Par rangée :
  - colonnes **0–1** : repos (respiration) ;
  - colonnes **2–5** : marche (contact, passage, contact, passage).
- **Pieds sur y = 252**, centrés sur x = 64. Environ 95 px de haut à l'écran, soit la taille
  du joueur.
- Lignes de repère (y, en pixels de la case) : sommet de la tête 62, yeux 80, menton 98,
  épaules 106, hanches 168, genoux 210, sol 252.

**Le guide de dessin** : `villager_guide.png`
- Même grille, avec les bords des cases, l'axe central et les lignes de repère.
- À mettre en calque sous le dessin, dans Krita, Aseprite ou Photoshop.

**Les calques d'exemple** : `example_shorts.png`, `example_shirt.png`, `example_hair.png`
- Générés à partir des mêmes poses que le corps.
- Ils montrent les deux règles d'un calque :
  - il est **un peu plus large** que le corps ;
  - il est **troué** là où le corps passe devant lui (l'avant-bras devant la chemise, de
    profil).

**`VillagerLayer`** (Resource) : un calque.
- `texture` : une planche sur la même grille.
- `color` : sa teinte.

**`VillagerLook`** (Resource) : l'apparence complète.
- `skin_color` : la couleur de peau.
- `body` : vide = `base_body.png`. Une autre silhouette (enfant, personne âgée) est une
  autre planche sur la même grille.
- `layers` : dessinés dans l'ordre, du premier au dernier (par exemple pantalon, chemise,
  lamba, cheveux, chapeau).
- À enregistrer en `.tres`, par exemple dans `data/villagers/looks/`. Plusieurs villageois
  peuvent partager des calques et ne changer que les couleurs.

**`VillagerVisual`** (`@tool`, Node2D)
- Construit un `Sprite2D` pour le corps, puis un par calque, tous sur **la même image**.
- Les sprites sont créés par le code et ne sont jamais enregistrés dans la scène.
- `play(direction, moving)` : même règle que `CharacterAnimator`, l'axe dominant l'emporte.
- `get_frame()` donne l'image courante.
- Exports : `look`, `facing`, `walking`, `idle_fps`, `walk_fps`.
- L'origine est entre les pieds : le placer sous un nœud y-sorté.
- Modifier le look ou un calque reconstruit l'affichage, dans l'éditeur comme en jeu.

**Générateur** : `tools/placeholder_art/gen_villager_base.gd` écrit le corps, le guide et les
calques d'exemple. Ajouter une entrée à sa table `SHEETS` (parties couvertes, épaisseur)
suffit pour générer un nouveau calque simple.

**Test** : `tests/behaviour_test.gd` vérifie :
- la teinte du corps et des calques ;
- que tous les calques sont sur la même image de la bonne rangée ;
- la mise à jour quand le look change.

## À savoir
**Dessiner un vêtement**
1. Ouvrir `base_body.png` et `villager_guide.png` en calques de référence, sur une toile de
   768×1024.
2. Dessiner le vêtement **dans chacune des 24 cases**, sur un calque transparent.
3. Le dessiner **clair** (blanc, gris clair) pour qu'il puisse être teint en jeu. Pour un
   motif à garder tel quel (lamba rayé, broderie), le dessiner en couleur et laisser
   `color` en blanc.
4. Exporter seulement le vêtement en PNG, sur la même grille, puis activer les mipmaps à
   l'import (comme pour le reste de l'art).

**Points d'attention**
- La rangée **droite est le miroir de la gauche** dans les planches générées. Un vêtement
  asymétrique (lamba sur une épaule) doit être dessiné à la main dans les deux rangées.
- Ce qui passe **devant** un vêtement (bras de profil, mains) doit être **effacé** du calque,
  sinon le vêtement le recouvre. Un vêtement qui passe devant un bras (manche longue)
  dessine aussi l'avant-bras.
- Pour remplacer le mannequin par un vrai dessin, garder la grille, les rangées, les
  colonnes et la ligne des pieds. Les calques existants restent alors valables.
- 4 images de marche suffisent pour des villageois qui marchent lentement. Pour plus de
  fluidité, passer à 6 ou 8 colonnes et mettre à jour `COLUMNS` et `WALK_FRAMES`.

**Pistes**
- Le villageois lui-même (`Villager`) : déplacements entre maison, champ et marché selon
  l'heure, comme les zébus et les poules, avec `play()` à chaque image.
- Animations de travail (piler le riz, porter sur la tête, bêcher) : nouvelles colonnes
  sur la même grille.
- Dialogues et commandes.
