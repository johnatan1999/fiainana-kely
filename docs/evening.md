# Le repas du soir : `EveningManager`, `EveningPanel`, `DayLog`

## Ce que voit le joueur
- **Se coucher ouvre le repas du soir** (*sakafo hariva*). La famille dîne sur la natte, à
  la lumière de la lampe à huile, et **parle de la journée**. Ce n'est pas un tableau de
  chiffres, c'est une conversation.
  - **Une quête finie dans la journée** passe d'abord : la famille la raconte (« Rakoto a
    raconté à toute la gargote que tu as retrouvé Volamena. »), voir `quests.md`.
  - **Les voleurs de poules** (voir `chicken_thieves.md`) : Dada parle de la poule volée, du
    cadenas qui a tenu ou du chien qui les a chassés ; pendant une alerte, Neny conseille un
    cadenas, ou de remplir la gamelle du chien.
  - **Le chien** (voir `dog.md`) : si sa gamelle est restée vide, Fara remarque qu'il est
    parti chercher à manger chez les voisins.
  - **Dada** parle des champs et de l'argent : « Tu as récolté 6 haricots et 3 maïs
    aujourd'hui. Bon travail. », « La journée a rapporté 9 400 Ar, et on a dépensé
    3 000 Ar. ». Les jours calmes : « Une journée calme. La terre aussi a besoin de
    repos. »
  - **Neny** parle du village : les commandes livrées (« Ravao te remercie pour sa
    commande. »), un villageois qui t'apprécie plus (« on me l'a dit au point d'eau »),
    l'écolage payé. Et d'abord, **les cases oubliées** : « Tu as oublié d'arroser 3
    case(s)... Il est encore temps, avant de dormir. »
  - **Fara** parle d'abord de ce qu'elle a dessiné dans ton carnet aujourd'hui (voir
    `forest.md`), puis de l'école (l'écolage bientôt dû, ou son envie d'y retourner si elle
    est renvoyée), du coq (nourri ou pas, le tournoi du jour) et des œufs ramassés.
  - **Demain** : le changement de saison, un chantier qui finit (voir `family_projects.md`),
    le dernier jour d'une commande, les cases mûres
    au matin, l'Alahady et son tournoi, ou le zoma.
  - Les répliques arrivent une par une, comme quand on parle. Une touche les montre toutes.
    Une personne qui enchaîne garde la parole : une seule bulle.
  - Au plus 6 répliques, dont 2 sur demain : l'essentiel, pas un rapport.
- **Le plat du soir dépend de la journée** : ce que tu as cuisiné à la cuisine, sinon le riz
  et ce qu'on a le plus récolté.
  - Haricots → *vary sy tsaramaso* ; manioc → *vary sy mangahazo* ; riz → *vary vaovao*
    (le riz nouveau) ; mangues → *vary amin'anana sy manga* ; œufs → *vary sy atody*...
  - Par défaut, *vary amin'anana* (riz aux brèdes).
  - Après une **grosse journée** (20 000 Ar gagnés ou plus) : *vary sy akoho*, du poulet
    pour fêter ça.
- En petit, l'argent du jour (« +9 400 Ar · −3 000 Ar »).
- **« Pas encore »** (ou Échap) ramène à la soirée, par exemple pour arroser une case
  oubliée. **« Dormir »** lance la nuit : le jour suivant commence et la partie est
  sauvegardée (voir `save.md`).

Côté game design :
- **Original et ancré** : le bilan passe par la famille et le repas, au cœur de la vie
  malgache, au lieu d'un tableau de ventes. Les chiffres sont là, mais dans la bouche de
  quelqu'un.
- **Les systèmes deviennent visibles** : commandes, amitié, écolage, coq, saisons. Le soir,
  la famille les relie entre eux.
- **Une dernière chance utile** : Neny rappelle les cases sèches pendant qu'il est encore
  temps.
- **Préparer demain** : on se réveille avec un plan.
- **Le plat** est une petite récompense sans valeur économique : on voit sa journée dans
  l'assiette.

## Détails techniques
**Le carnet du jour : `DayLog`** (`systems/simulation/day_log.gd`, dans
`FarmSimulation.day_log`)
- `earned` et `spent` : tout mouvement d'argent, lu une seule fois par
  `FarmSimulation._on_money_changed` (pas d'appel à ajouter quand une dépense est créée).
- `harvested` (récoltes et fruits), `products` (œufs), `neighbour_tufts`,
  `orders_delivered`, `friendship` (points gagnés), `new_hearts` (cœurs atteints),
  `cockfight` (`bouts`, `wins`), `school_paid`.
- `get_main_harvest()`, `is_quiet()`.
- Remis à zéro à chaque nouveau jour (`advance_day`) et au chargement. **Pas sauvegardé** :
  on sauvegarde au coucher, quand le jour qui commence est vide, et quitter en pleine
  journée ramène à ce matin vide.

**Demain** (`simulation.fields` et `simulation.orders`)
- `get_ripening_tomorrow()` : cultures arrosées aujourd'hui (ou en rizière) à un jour de
  la maturité, `crop_id` → nombre de cases.
- `get_unwatered_plots()` : cultures en pousse non arrosées (hors rizière).
- `get_orders_due_tomorrow()` : commandes acceptées dont le dernier jour est demain.

**Le repas : `EveningManager`** (`systems/family/`, `Gameplay/EveningManager`)
- Écoute `WorldManager.bedtime_requested`. Le lit (`SleepSpot`) ne fait plus dormir
  directement : `WorldManager.sleep()` (le jour suivant, le réveil, `slept`, la sauvegarde)
  n'est appelé que par « Dormir ». Sans `EveningManager`, `WorldManager` dort tout de
  suite.
- `get_lines()` : les répliques (cases sèches, puis Dada, Neny, Fara, puis demain), au plus
  `MAX_LINES`. Les répliques consécutives d'une même personne sont fusionnées.
- `get_dish()` : `DISHES` (récolte principale → [malgache, en clair]), `FEAST_DISH` à
  partir de `FEAST_EARNINGS`, `DEFAULT_DISH`.
- `plural(nom, nombre)` : le pluriel français des noms d'objets (« haricots », « patates
  douces », « pommes de terre », « maïs » et « riz » inchangés).
- Portraits : `VillagerPortrait` des fiches `mother`, `father`, `fara`.

**Le panneau : `EveningPanel`** (`ui/evening/evening_panel.gd`, `UI/EveningPanel`)
- Construit en code, avec un style de nuit (bois sombre, lumière de lampe) différent des
  panneaux de jour. L'en-tête dessine la natte tressée (*tsihy*), la lueur de la lampe qui
  vacille et le bol de riz.
- `open(date, plat, répliques, gagné, dépensé)`, `show_all()`. Signaux `sleep_confirmed` et
  `cancelled`. Il met le jeu en pause.

**Tests**
- `run_tests.gd` :
  - le carnet compte l'argent, les récoltes, les œufs et les cœurs ;
  - il repart à zéro le matin et au chargement ;
  - demain : les cultures mûres, les cases sèches, les commandes ;
  - les pluriels.
- `behaviour_test.gd` : se coucher ouvre le repas (le plat de la journée, Dada parle des
  haricots). « Pas encore » revient à la soirée sans changer de jour ; « Dormir » dort.

## À savoir
- **Ajouter un plat** : une entrée dans `DISHES` (id de la culture → [nom malgache, en
  clair]).
- **Ajouter un sujet de conversation** : une ligne dans la fonction de la personne qui en
  parle (`_field_lines`, `_village_lines`, `_sister_lines`, `_tomorrow_lines`), et au
  besoin un compteur dans `DayLog`, rempli là où la chose arrive dans `FarmSimulation`.
- **Le joueur ne parle pas** : la famille lui parle. C'est voulu, le joueur écoute sa
  journée.
- **Pistes** :
  - les prévisions météo de demain par Dada (« le ciel est rouge, il pleuvra demain »), le
    jour où la météo sera tirée la veille ;
  - des répliques qui changent avec les années et l'histoire de Fara ;
  - un invité au repas les jours de fête ;
  - le récit d'un *angano* (conte) par Neny Soa certains soirs.
- Les textes ne sont pas encore traduits (`translations.csv`).
