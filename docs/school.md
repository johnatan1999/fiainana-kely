# Écolage de Fara : `SchoolManager`, `SchoolPanel`

## Ce que voit le joueur
- **Fara va à l'école du village** les matins de semaine. Ses parents ont payé la première
  saison ; ensuite, **chaque saison**, le joueur paie **sa part de l'écolage : 10 000 Ar**.
- **La facture arrive une semaine avant la saison** (24e jour) :
  - notification : « Écolage de Fara : 10 000 Ar à payer à Ramatoa Hanta, à l'école du
    village, d'ici 14 jours. » ;
  - en haut à droite, sous les commandes : « Écolage de Fara : 10 000 Ar — 14 j » (en rouge
    le dernier jour et en retard) ;
  - la dernière semaine, Neny le rappelle quand on passe près d'elle.
- **Payer, à l'école** : on parle à **Ramatoa Hanta**, la directrice (action « Payer
  l'écolage de Fara »). Elle est devant l'école en semaine dès 7:00, et tous les jours de
  13:30 à 17:30. Un panneau s'ouvre :
  - **en ariary** : tout ce qu'on peut, jusqu'à ce qui reste dû ; **le paiement partiel est
    accepté** ;
  - **en riz** : l'école prend le riz **au prix du zoma** (5 000 Ar), seulement ce qu'il
    faut. La monnaie est rendue en ariary.
- **Une semaine de grâce** : la facture est due le 7e jour de la saison. Le lendemain, si
  tout n'est pas payé :
  - notification : « L'écolage n'est pas payé : Fara est renvoyée à la maison jusqu'au
    paiement. » ;
  - **Fara reste à la ferme** les matins de semaine, penchée au **mortier à côté de Neny**,
    au lieu d'aller à l'école ;
  - la famille en parle : Neny, Dada (« Une enfant doit être à l'école, pas au mortier. »),
    Fara elle-même ;
  - **rien d'autre n'est perdu**. Dès que c'est payé, Fara retourne à l'école, même en
    pleine matinée.
- **Une dette s'ajoute à la facture suivante**, sans nouveau délai : la date limite reste
  celle de la première facture impayée.

Côté game design :
- C'est la **première dépense récurrente** du jeu, et la première raison de garder de
  l'argent de côté.
- Le montant reste modeste face aux revenus d'une saison : c'est une échéance à prévoir,
  pas un mur.
- Le paiement en riz donne au riz une utilité hors de la vente, et évite un aller-retour au
  marché.
- La conséquence est **visible et réversible** : on voit Fara au mortier chaque matin, ce
  qui pèse plus qu'une pénalité chiffrée.

## Détails techniques
**Règles : `FarmSimulation`** (testables, sauvegardées)
- Constantes :
  - `SCHOOL_FEE` (10 000), `SCHOOL_NOTICE_DAYS` (7, avance de la facture),
    `SCHOOL_GRACE_DAYS` (7, délai dans la saison) ;
  - `SCHOOL_RICE_ITEM` (`"rice"`), `SCHOOL_RICE_PRICE_MULTIPLIER` (1,25 = prix du zoma) ;
  - `CONDITION_SCHOOL_FEES_OVERDUE` (`"school_fees_overdue"`).
- `_advance_school_fees()`, chaque matin dans `advance_day()` :
  - facture la saison qui commence dans `SCHOOL_NOTICE_DAYS` jours si elle ne l'est pas
    encore ;
  - échéance : jour 1 de la saison + `SCHOOL_GRACE_DAYS` − 1, au moins une semaine après la
    facture. Elle est gardée si une dette court déjà.
- Lecture :
  - `get_school_debt()`, `is_school_fee_due()`, `is_school_fees_overdue()` ;
  - `get_school_days_left()` (1 = dernier jour, 0 ou moins = en retard) ;
  - `get_school_rice_price()`, `get_school_rice_needed()`.
- Paiement :
  - `pay_school_fees(amount)` : plafonné à la dette et à l'argent ;
  - `pay_school_fees_in_rice(count)` : plafonné au stock et au besoin, monnaie rendue.
- Signal `school_fees_changed` : facture, paiement, passage en retard, chargement.
- **`get_conditions()`** : les conditions d'histoire du jour (`{"school_fees_overdue": true}`),
  lues par les étapes des villageois (`VillagerStop.only_if` / `unless`, voir
  `villagers.md`) et par l'onglet Villageois de l'inventaire.
- **Sauvegarde** : `FarmState.school_debt`, `school_due_day`, `school_billed_season`.
  Une sauvegarde plus ancienne considère la saison en cours comme payée.

**Lien avec le jeu : `SchoolManager`** (`systems/family/`, `Gameplay/SchoolManager`)
- Ne décide rien : il lit la simulation et l'affiche.
- La directrice (`TEACHER_ID` = `hanta`) : quand une dette court, son `talk_prompt` devient
  « Payer l'écolage de Fara », son `call_out` « Tu viens pour l'écolage de Fara ? », et lui
  parler ouvre le `SchoolPanel`. Branché après `OrderManager`, qui la fait d'abord saluer.
- Les nouvelles du matin (`UIEvents.notify`) : nouvelle facture, dernier jour, Fara renvoyée.
  Pas d'annonce au chargement d'une sauvegarde.
- `OrdersTracker.show_reminders()` : la ligne de rappel.
- Les `call_out` de la famille (`mother`, `father`, `fara`), selon la dette et le retard.
- Passe `get_conditions()` à chaque `Villager` (`set_conditions()`) au chargement d'une zone,
  chaque matin et à chaque changement.

**Affichage : `SchoolPanel`** (`ui/school/school_panel.gd`, `UI/SchoolPanel`)
- Construit en code, comme `OrderPanel`. Il met le jeu en pause.
- `show_fees(...)` ouvre ou rafraîchit le panneau. Signaux `pay_money_requested`,
  `pay_rice_requested`.

**Villageois**
- `data/villagers/hanta.tres` : Ramatoa Hanta. Elle habite le logement de l'école (`home` =
  `School`).
- `data/villagers/fara.tres` : l'étape d'école (7:15, en semaine) est `unless`
  `school_fees_overdue` ; une étape au `Mortar` (`WORK`) à la même heure est `only_if`.
- Tous deux sont aussi dans la table de `tools/place_villagers.gd`.

**Tests**
- `run_tests.gd` :
  - la facture une semaine avant, l'échéance et le retard ;
  - le paiement partiel, le paiement en riz avec la monnaie ;
  - la dette qui s'ajoute en gardant son échéance ;
  - la sauvegarde, et une sauvegarde plus ancienne ;
  - les étapes conditionnelles.
- `behaviour_test.gd` : en retard, Fara est au mortier un mercredi matin, la famille en
  parle et le rappel s'affiche. Ramatoa Hanta ouvre le panneau, le paiement solde la dette,
  et Fara retourne à l'école.

## À savoir
- **Équilibrage** : 10 000 Ar par saison, c'est la moitié d'une récolte de riz sur une case
  (5 × 4 000 Ar), ou 3 à 4 cases de maïs. Le montant est volontairement doux pour ce premier
  palier. Il faudra le revoir après avoir mesuré les revenus réels d'une première saison.
- **Paliers suivants prévus** :
  - redoublement si Fara manque trop de jours sur l'année (compter les jours au mortier) ;
  - frais de rentrée (fournitures, tablier) et d'examen (CEPE) ;
  - collège au bourg, avec un écolage plus élevé ;
  - aide des parents ou emprunt à un ami ;
  - ce que Fara apprend à l'école et qui profite à la ferme (cahier de comptes, compost…).
- **Volontairement absent** : Fara ne rapporte rien à la ferme quand elle reste à la maison.
  Le jeu ne doit pas récompenser le fait de la garder.
- Les conditions d'histoire (`get_conditions()`) sont génériques : un futur événement peut en
  ajouter une et changer la journée de n'importe quel villageois sans nouveau code.
