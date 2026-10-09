# Planches provisoires

Générateurs des dessins provisoires du jeu, en attendant les vrais sprites. Chacun réécrit
sa planche :

```
godot --headless --path . --script res://tools/placeholder_art/gen_<nom>.gd
```

| Script | Planche écrite | Convention à garder si on la remplace |
|---|---|---|
| `gen_tall_grass.gd` | `assets/tileset/tall_grass_placeholder.png` | Une seule rangée, touffes posées sur le bord bas |
| `gen_rice.gd` | `assets/sprites/crops/rice.png` | 4 cases de 96×128, plants sur le bord bas, double densité |
| `gen_fence.gd` | `assets/tileset/fence_wood.png` | 16 tuiles de 48 px, index = N·1 + E·2 + S·4 + O·8 |
| `gen_props.gd` | `assets/sprites/props/village_props.png` | Cases de 160×112, objet posé sur le bord bas, double densité |
| `gen_zebu_cart.gd` | `assets/sprites/animals/zebu_cart.png` | Profil vers la droite, densité 2× : zébu en 4 cases de 128×96, puis caisse, roue (à part) et conducteur |
| `gen_zebu.gd` | `assets/sprites/animals/zebu.png` | Profil vers la droite, densité 2×, cases de 128×96 : 0–3 marche, 4–5 broute, 6 couché, 7 regarde. Robe claire (teintée en jeu) |
| `gen_villager_from_player.gd` | `assets/sprites/characters/villager/base_body.png`, `villager_guide.png`, `example_*.png` (shirt, shorts, trousers, skirt, hair, hair_bun, hat) | **Planches actuelles**, calquées sur `player2.png`. Cases de 128×256, densité 2×, 8 colonnes (0–1 repos, 2–5 marche, 6–7 travail accroupi) × 4 rangées (bas, gauche, droite, haut), pieds sur y = 252. Gris clair teinté en jeu |
| `gen_villager_base.gd` | Les mêmes fichiers | Ancien mannequin dessiné par code : le lancer remplace les planches calquées sur le joueur |
| `gen_village_center.gd` | `assets/sprites/props/village_center.png` | Cases de 192×192 (4×2), objet sur le bord bas, double densité : point d'eau, lavoir, kiosque, table de gargote, mât et drapeau, but de foot, panneau (vierge), foyer |
| `gen_market_town.gd` | `assets/sprites/props/market_town.png` | Cases de 192×192 (4×2), objet sur le bord bas : pont (vu de dessus, échelle 1), étal de légumes, étal de lambas, étal du collecteur, taxi-brousse (échelle 1), sacs de riz, roseaux, poules en cage |
| `gen_manure.gd` | `assets/sprites/props/manure.png` | Cases de 192×192 (4×1), objet sur le bord bas, double densité : petit tas, gros tas, panier de fumier (icône), fumier épandu vu de dessus (sans contour, affiché au quart pour couvrir une case) |
| `gen_zebu_market.gd` | `assets/sprites/props/zebu_market.png` | Cases de 192×192 (4×1), objet sur le bord bas, double densité : abreuvoir vide, abreuvoir plein (eau et foin), poteau du marchand de zébus, charrue à zébus (profil, tirée vers la droite) |
| `gen_water.gd` | `assets/tileset/water_placeholder.png` | Deux tuiles blanches : c'est le shader qui colore |

Ces scripts ne touchent **qu'aux images**. Les scènes (zones, champs, arbres, clôtures,
objets) s'éditent à la main dans l'éditeur : ce sont elles la référence.
