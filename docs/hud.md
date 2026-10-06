# Interface en jeu : `HUD`, `HotbarUI`, retours visuels

## Ce que voit le joueur
- **En haut à gauche (`HUD`)** : saison, jour, année, **heure** (par pas de 10 minutes),
  **icône de pluie** les jours de pluie, progression de la saison et argent. Les gains et
  dépenses d'argent s'animent (+/−).
- **En bas au centre (`HotbarUI`)** : la barre d'outils et de graines (8 cases). Les récoltes
  n'y vont pas : elles vont dans le sac, qui s'ouvre depuis le menu pause.
- **En haut de l'écran (`Toast`)** : les messages courts (« Poulailler plein », « Manguier :
  fruits dans 3 jours »).
- **Dans le monde (`HarvestPopup`)** : « +3 Maïs » au-dessus de ce qui vient d'être récolté
  (voir `farming.md`).

## Détails techniques
- **`HUD.gd`** : `TimeLabel` est mis à jour par `time_changed` (voir `day_night.md`).
- **`Toast`** (`ui/notifications/toast.gd`) : alimenté par `UIEvents.notify()`. Un nouveau
  message remplace celui affiché.

## À savoir
- Un journal des objets reçus (« Maïs +3 (12) » en bas à gauche) a été essayé puis retiré :
  visuellement trop chargé. Le retour de récolte passe uniquement par `HarvestPopup`.
