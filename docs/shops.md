# Boutiques : `Shop`, `ShopProfile`, `ShopUI`

## Ce que voit le joueur
Deux endroits pour acheter et vendre, chacun avec ses rayons, ses prix et ses horaires :

| Boutique | Où | Quand | Ce qu'on y trouve |
|---|---|---|---|
| **Marché du village** | l'étal du village, près de la place | tous les jours, à toute heure | les graines de tous les jours (cultures vivrières et de rente : maïs, manioc, riz, tomates…), les outils (dont la charrue à zébus), la nourriture, les poules. On y vend ces récoltes et les œufs |
| **Tsena du zoma** | l'étal du collecteur (Rabe), sur la place du marché du bourg | **le zoma seulement** (vendredi), de 6:00 à 17:00 | **toutes** les graines, dont les **cultures d'export** (vanille, girofle, café, litchi), et la nourriture. Pas d'outils ni d'animaux. **Tout s'y vend 25 % plus cher** |

- La vanille, le girofle, le café et les litchis **ne s'achètent et ne se vendent qu'au tsena
  du zoma** : c'est le collecteur qui les prend. Les graines restent verrouillées jusqu'à leur
  jour de déblocage (`unlock_day`, entre le 45e et le 60e jour).
- Au-dessus de l'étal, l'action indique « Acheter et vendre », ou « Fermé ». Fermé, l'étal
  rappelle quand revenir : « Le tsena n'ouvre que le zoma, de 6:00 à 17:00. »
- La fenêtre porte le nom de la boutique, et seuls les onglets qui ont quelque chose sont
  affichés. Les prix de vente des cartes sont ceux de la boutique (« Vendre 1 (1 500 Ar) »).

**Boucle de jeu visée** : la semaine prend un rythme. On récolte au fil des jours, et on garde
ses meilleures récoltes pour le zoma, où elles rapportent plus. Les cultures d'export, chères
et lentes, poussent le joueur à descendre au bourg ; le village reste le ravitaillement de
tous les jours.

## Détails techniques
- **`ShopProfile`** (`core/data/shop_profile.gd`, `Resource`) :
  - `title` : le nom de la fenêtre (clé de traduction) ;
  - `seeds` (`SeedRange`) : `LOCAL` (vivrières et de rente), `EXPORT`, `ALL`, selon
    `CropData.category` ;
  - `sells_tools`, `sells_food`, `sells_animals` : les autres rayons ;
  - `sell_multiplier` : ce que paie la boutique, en part du prix de vente (1,25 = +25 %) ;
  - `open_days` (cases à cocher, bits de `GameClock.Weekday` ; aucune = tous les jours),
    `opens_at`, `closes_at` (minutes du jour) ;
  - `closed_message` : affiché (toast) si le joueur vient quand c'est fermé ;
  - `is_open(weekday, minute)`, `sells(item, item_db)`, `filter_catalog(catalog, item_db)`,
    `sell_price(base_price)`.
- **Profils** (`data/shops/`, écrits par `tools/build_market_town.gd` depuis sa table `SHOPS`) :
  `village_shop.tres` (`LOCAL`, tout le reste, toujours ouvert), `weekly_market.tres`.
- **`Shop`** (`structures/shop/shop.gd`, `StaticBody2D` + `InteractableComponent`) :
  - export `profile` (vide = `village_shop.tres`) et `reach` (taille de la zone d'interaction,
    posée en code ; zéro = celle de la scène) ;
  - suit l'heure et le jour (`CLOCK_GROUP`, `CALENDAR_GROUP`) pour son action et son
    ouverture ; ouvert, il émet `UIEvents.shop_requested(self)`.
  - Scènes : `structures/shop/shop.tscn` (le marché du village) et
    `structures/shop/market_stall_shop.tscn` (l'étal du collecteur, profil du zoma, construit
    par `build_market_town.gd`).
- **`ShopUI`** (`ui/shop_ui.gd`, une seule fenêtre pour toutes les boutiques) :
  - `open(profile)` : filtre le catalogue (`ItemDatabase.get_shop_catalog()`) par le profil,
    met le titre, cache les onglets vides et vide le panier quand on change de boutique ;
  - vente : `FarmSimulation.sell(crop_id, qty, price_multiplier)` pour les récoltes,
    `sell_item(id, profile.sell_price(prix), qty)` pour le reste. Les achats ne changent pas de
    prix ;
  - `ItemCard.setup(..., sell_price)` affiche le prix de vente de la boutique.
- **Tests** : `behaviour_test.gd` (étal fermé un Talata, ouvert le zoma avec les graines
  d'export et sans outils, maïs vendu 25 % plus cher, pas de vanille au village).

## À savoir
- Le prix d'achat est le même partout : seul le prix de vente change. Une remise d'achat le
  zoma serait un autre levier.
- L'ouverture ne dépend que du profil, pas de la présence du marchand : l'étal ouvre à 6:00
  le zoma même si Rabe n'est pas encore arrivé.
- Le **marché aux zébus** n'est pas un `Shop` (on y vend des bêtes une à une, pas des objets) :
  il a sa propre fenêtre (voir `zebus.md`), mais ses horaires viennent aussi d'un
  `ShopProfile` (`zebu_market.tres`).
- Pistes : des prix qui varient d'une semaine à l'autre, un vendeur de graines rares ambulant.
- Ajouter une boutique : un nouveau `ShopProfile` dans `data/shops/`, et une instance de
  `shop.tscn` (ou d'une scène qui utilise `shop.gd`) avec ce profil.
