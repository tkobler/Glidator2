# Test terrain du 22/10/2026 (Villeneuve) : marche et vol

Date de l'analyse : 2026-10-26. Branche : `claude/corrections-marche`.

## Question et données

Question : les valeurs affichées par la montre (photos) et enregistrées (TCX, GPX) en mode Marche puis en mode Vol correspondent-elles aux valeurs recalculées et à la trace SportsTrackLive ?

Verdict de l'utilisateur : boutons et enregistrement OK, valeurs de marche et de vol « semblent bonnes ».

Données (hors dépôt sauf le GPX de la montre) :
- GPX de la montre : `garmin_data/2026-10-22-villeneuve/activity_24813284437.gpx` (dans le dépôt, 3796 points).
- TCX de la montre : `activity_24813284437.tcx` (2 tours, 3799 points), lu hors dépôt.
- Trace SportsTrackLive : `2026-10-22-1572838-sportstracklive.gpx` (1196 points, 09:00:50Z à 10:42:43Z, sans FC), lue hors dépôt, et le GPX de la montre dans le dépôt.
- 17 photos de la montre (IMG_9371 à IMG_9388, sans 9379), lues hors dépôt. Photos, FIT, TCX et zip ne sont pas dans le dépôt.
- Montre : Fenix (affichage de type fenix 6). Heure locale des photos = UTC + 2 h (11:18 sur la montre = 09:18Z).

Fait important : les 17 photos montrent toutes le mode Marche (écrans altitude/D+/distance, FC/VS/allure, heure, carte, pause). Aucune photo du mode Vol : le vol ne peut être comparé qu'aux valeurs enregistrées et recalculées, pas à un affichage.

Précision sur la vitesse verticale (VS) : l'app n'enregistre aucune VS dans le fichier d'activité. Toutes les valeurs de VS « rejeu » de cette note sont rejouées par `tools/analyze_activity.py` (colonne « VS rejeu (HikeHistory) »). Voir `docs/recherches/2026-10-28-vs-enregistree.md`.

## Réponse courte (confiance : élevée pour la marche, moyenne pour le vol et le minuteur)

- Marche : altitude, D+, distance, FC et VS affichés sont conformes aux valeurs enregistrées (pour la VS : rejouée par `tools/analyze_activity.py`) et recalculées (écarts de 0 à 2 %). L'allure affichée est 1 à 5 % plus rapide que la fenêtre de 60 s de référence : écart acceptable.
- Vol : valeurs enregistrées cohérentes avec le recalcul ; la VS rejouée par `tools/analyze_activity.py` l'est aussi (médiane +1,6 %, p95 +1,0 %, p5 6,9 %). Pas de photo, donc pas de vérification de l'affichage.
- À revoir (mineur) : le minuteur affiché retarde d'environ 32 s sur l'horodatage des points avant la pause ; cause non localisée.
- À savoir : le décollage a eu lieu à 11:27 en mode Marche, le passage en Vol (tour 2) à 11:31:40, déjà en l'air.
- Écart d'altitude avec SportsTrackLive : la montre est plus haute de 104 m au départ et de 180 m à 1600 m (voir plus bas), cause non tranchée.

## Inventaire du fichier

Source : `python3 tools/analyze_activity.py <tcx>` (sortie du 2026-10-26).

| Tour | Début (UTC) | Durée timer | Étendue des points | Points | Intervalle moyen | Distance enregistrée | Distance GPS | D+ (seuil 1 m) |
|---|---|---|---|---|---|---|---|---|
| 1 (Marche) | 09:00:37 | 6329,9 s (1:45:30) | 9063 s | 2929 | 3,10 s (max 2698 s) | 9388,1 m | 10133,9 m (+7,9 %) | 1221,0 m |
| 2 (Vol) | 11:31:40 | 1045,9 s (0:17:26) | 1046 s | 870 | 1,20 s (max 13 s) | 9802,1 m | 9913,9 m (+1,1 %) | 237,8 m |

Champs : altitude, FC, position, vitesse présents dans le TCX ; le GPX ajoute la température (atemp). Aucun saut de position (règle > 50 m + 60 m/s x dt). Altitude du tour 1 : 476,8 à 1606,8 m ; tour 2 : de 1538,8 m à 495,2 m (perte de 1043,6 m en 17 min).

Chronologie reconstituée (faits tirés du CSV 60 s et du tableau par minute) :
1. 09:00:37Z départ de la marche ; 10:40:19Z dernier point avant la pause.
2. Trou de 2698 s (10:40:19Z à 11:25:17Z) : la pause (photo IMG_9388 « Paused 1:39:10 », « START: resume »). Aucun point enregistré pendant la pause.
3. 11:25:17Z reprise ; 11:27:13Z début de la phase aérienne (vitesse 4 à 8,7 m/s, altitude qui descend) alors que l'activité est encore en mode Marche (tour 1).
4. 11:31:40Z passage au tour 2 (Vol), à 1538,8 m ; 11:49:06Z fin à 495,2 m.
Contrôle : timer après reprise = 5950 s (pause affichée) + 382 s (11:25:17 à 11:31:39) = 6332 s, pour 6329,9 s dans le TCX.

## Comparaison montre (photos) / recalcul

Méthode d'appariement : temps du tour t = valeur du minuteur affiché (photo), sauf mention. Références : colonnes du CSV 60 s (`--csv`), `--at` de l'étalon (D+ hystérésis 1 et 3 m, distance TCX). Les valeurs de VS « rejeu » viennent de la colonne « VS rejeu (HikeHistory) » de `tools/analyze_activity.py`.

| Photo | t (s) | Valeur | Affichée | Recalculée / enregistrée | Écart | Verdict |
|---|---|---|---|---|---|---|
| 9371 | 1079 | Altitude | 630 m | 630,2 m | -0,2 m | OK |
| 9371 | 1079 | D+ | 152 m | 153,4 m (h1 = h3) | -1,4 m (-0,9 %) | OK |
| 9371 | 1079 | Distance | 1,6 km | 1,641 km (TCX) ; 1,721 km (GPS) | -0,04 km | OK (suit la distance enregistrée) |
| 9372 | 1084 | FC | 117 | 117 (point t=1079) | 0 | OK |
| 9372 | 1084 | VS | +450 m/h | 445,3 (rejeu, t=1087) ; 455,3 (t=1079) ; réf. 448 | +1 % | OK |
| 9372 | 1084 | Allure | 10:13 | 10:34 (t=1081) ; 10:56 (t=1087) | environ -31 s (-5 %) | Écart acceptable |
| 9376 | 2605 | VS | +880 m/h | 874,6 (rejeu) ; réf. 879,3 | +0,6 % | OK |
| 9376 | 2605 | Allure | 17:02 | 17:41 (t=2605) | -39 s (-3,7 %) | Écart acceptable |
| 9376 | 2605 | FC | 96 | 97 (t=2612) | -1 | OK |
| 9377 | 2612 | Altitude | 946 m | 945,8 m | +0,2 m | OK |
| 9377 | 2612 | D+ | 461 m | 469,0 m (h1 = h3) | -8,0 m (-1,7 %) | OK |
| 9377 | 2612 | Distance | 3,2 km | 3,175 km (TCX) ; 3,426 km (GPS) | 0 (arrondi) | OK |
| 9380 | 4020 | Altitude | 1239 m | 1238,8 m | +0,2 m | OK |
| 9380 | 4020 | D+ | 758 m | 762,0 m | -4,0 m (-0,5 %) | OK |
| 9380 | 4020 | Distance | 4,6 km | 4,608 km (TCX) ; 5,072 km (GPS) | 0 (arrondi) | OK |
| 9381 | 4025 | FC | 101 | 102 (t=4020) | -1 | OK |
| 9381 | 4025 | VS | +600 m/h | 597,1 (rejeu, t=4024) | +0,5 % | OK |
| 9381 | 4025 | Allure | 16:57 | 17:07 (t=4024) | -10 s (-1 %) | OK |
| 9384 | 5932 | Altitude | 1607 m | 1601,8 m (t=5932) ; 1606,8 m (t=5963) | +5,2 m à t=5932 ; +0,2 m à t=5963 | OK avec le décalage du minuteur (voir ci-dessous) |
| 9384 | 5932 | D+ | 1118 m | 1125,0 m (t=5932) ; 1130,0 m (t=5966) | -7 m (-0,6 %) ; -12 m (-1,1 %) | OK |
| 9384 | 5932 | Distance | 7,2 km | 7,178 km (TCX) ; 7,197 km (t=5963) | 0 (arrondi) | OK |
| 9385 | 5937 | FC | 106 | 111 (t=5932) ; 105 (t=5966) | -5 ; +1 | OK avec décalage |
| 9385 | 5937 | VS | +590 m/h | 643,6 (rejeu, t=5934) ; 620,0 (t=5963) ; réf. interpolée vers t=5969 : environ 584 | -8 % (sans décalage) ; +1 % (avec) | OK avec décalage |
| 9385 | 5937 | Allure | 18:20 | 12:06 (t=5938) ; 14:18 (t=5957) ; 16:13 (t=5963) ; 31:11 (t=5980) | -34 % sans décalage ; cohérent vers t=5969 | OK avec décalage |
| 9388 | - | Pause | « Paused 1:39:10 », « START: resume » | Trou de 2698 s dans les points | - | OK |
| 9373, 9382, 9386 | - | Heure locale | 11:18, 12:07, 12:40 | 09:18Z, 10:07Z, 10:40Z | - | OK (UTC + 2 h) |

Remarques sur la table :
- Distance : l'affichage suit la distance enregistrée (TCX), pas le calcul haversine du GPX, qui est supérieur de 7,9 % sur le tour de marche (gigue GPS à basse vitesse : 28,3 % des points à vitesse 0) et de 1,1 % en vol. Les écarts à 1 m près n'ont pas de sens pour une valeur affichée à 0,1 km.
- Batterie : 97 % à 11:18, 93 % à 12:07, 91 % à 12:40. Pas de référence : consommation observée d'environ 4 % en 49 min puis 2 % en 33 min. Non jugé.
- Carte (photos 9374, 9378, 9383, 9387) : le tracé s'affiche avec l'échelle 500 m et le marqueur de position. La forme n'a pas été comparée numériquement. Verdict : OK visuel.

### Décalage du minuteur (à revoir)

Les photos 9384 et 9385 (minuteur 1:38:52 et 1:38:57) montrent une altitude (1607 m), une FC (106), une VS (+590) et une allure (18:20) qui correspondent au fichier vers t = 5963 à 5969 s, soit environ 32 s plus tard que le minuteur. Quatre grandeurs indépendantes vont dans le même sens. Trois autres éléments concordent :
- la pause s'affiche à 1:39:10 (5950 s) alors que le dernier point avant la pause est à t = 5982 s (écart 32 s) ;
- TotalTimeSeconds du tour 1 vaut 6329,9 s, alors que l'étendue des points moins le trou vaut 9062 - 2698 = 6364 s (écart 34 s) ;
- aux photos 9380 et 9381 (t = 4020 à 4025) le minuteur et le fichier concordent encore à quelques secondes près.

Donc environ 32 s de temps de fichier ne sont pas comptées par le minuteur quelque part entre t = 4025 s et t = 5932 s. Le tableau par minute (colonne `t_point_s` contre `t_s`, minutes 66 à 97) ne montre aucun trou de points dans cette plage ; l'outil signale 8 intervalles > 15 s au total, mais ne les liste pas. Hypothèses (non vérifiées) : une pause courte avec reprise automatique (30 s, comme prévu par la spec de pause) pendant laquelle les points auraient continué d'être écrits, ou un arrêt de minuteur au niveau de l'activité. Confiance moyenne sur l'existence du décalage (4 indicateurs concordants), faible sur la cause.

### Trace SportsTrackLive

La trace SportsTrackLive couvre uniquement la marche (09:00:50Z à 10:42:43Z, 1196 points, pas de FC, pas de vol, pas de tour 2).
- Position : même sentier, écart de l'ordre de 5 m au même instant (10:39:28Z contre 10:39:29Z). Verdict : OK.
- Altitude : la montre est plus haute que SportsTrackLive, d'un écart qui croît.

| Heure (UTC) | Montre | SportsTrackLive | Écart |
|---|---|---|---|
| 09:00:37 à 09:00:50 | 479,2 m | 375,3 m | +103,9 m |
| 09:18:39 | 630,9 m (point proche) | 513,0 m | environ +118 m |
| 09:44:08 | 945,4 m | 807,6 m | +137,8 m |
| 10:07:41 à 10:07:46 | 1239,0 m | 1091,4 m | environ +148 m |
| 10:39:29 | 1601,8 m | 1422,1 m (10:39:28) | +179,8 m |

Gain net début à 10:39:29 : montre +1122,6 m, SportsTrackLive +1046,8 m, soit +7,2 % pour la montre. Le D+ affiché (1118 m, photo 9384) est donc proche du D+ recalculé de la montre (1125 m) mais environ 7 % au-dessus du gain net de SportsTrackLive. Sans MNT de référence, on ne sait pas quelle altitude est juste : le départ est près d'un lac dont l'altitude ne dépasse pas 380 m environ, ce qui rend plausible le 375 m de SportsTrackLive et suggère une montre non calibrée au départ (+104 m). Verdict : à revoir (hors périmètre du code de l'app si c'est le capteur ; l'app lit l'altitude Garmin). Le D+ final de SportsTrackLive n'a pas pu être calculé (voir plus bas).

### Mode Vol (tour 2) : valeurs de la montre contre recalcul

Source : `python3 tools/analyze_activity.py <tcx>` (colonne « VS rejeu (HikeHistory) » : VS rejouée par `tools/analyze_activity.py` à partir de HikeHistory, l'app n'enregistre aucune VS, voir `docs/recherches/2026-10-28-vs-enregistree.md` ; n = 196 ; référence = régression sur 60 s, n = 853).

| Indicateur | Montre (VS : rejeu ; autres : enregistré) | Recalcul | Écart | Verdict |
|---|---|---|---|---|
| VS médiane | -5121 m/h | -5205 m/h (régression) ; -5244 (dalt/dt) | +84 m/h (+1,6 %) | OK |
| VS p95 | +4508 m/h | +4463 m/h | +45 m/h (+1,0 %) | OK |
| VS p5 | -10547 m/h | -11326 m/h | +779 m/h (6,9 % moins négatif) | Écart acceptable (le rejeu a moins de points, 196 contre 853, et lisse) |
| Distance enregistrée / GPS | 9802,1 m | 9913,9 m | -1,1 % | OK |
| Vitesse médiane | 8,76 m/s (31,5 km/h) | - | - | Plausible |
| FC | 81 à 114 bpm | - | - | Plausible |
| Altitude (début, fin) | 1538,8 m, 495,2 m | - | - | Dans les bornes de vol (-500 à 9000 m) |

Sur le tour 1, 20 valeurs de VS rejouée dépassent ±3000 m/h (minimum -4737,6 m/h), toutes après 11:25Z, c'est-à-dire pendant la phase aérienne enregistrée en mode Marche ; aucune pendant la marche (compte Grep sur le CSV 60 s). Sur le tour 2, 163 des 196 valeurs de VS rejouée dépassent ±3000 m/h, ce qui est normal en vol. La borne de ±3000 m/h est une borne d'affichage de la Marche : le rejeu de HikeHistory n'est pas borné (l'app n'enregistre aucune VS, donc rien à borner dans le fichier). Verdict : OK, à confirmer par la spec si l'affichage doit aussi être borné en phase aérienne.

Le D+ du tour 1 (1221,0 m) inclut les 91 m environ gagnés ou comptés pendant la phase aérienne en mode Marche (D+ étalon à t=5982 : 1130,0 m ; thermiques et turbulences après 11:25Z). Ce n'est pas une anomalie de l'app, c'est une conséquence du décollage en mode Marche.

## Méthode de calcul

Commandes exactes (depuis la copie de travail, sorties hors dépôt dans `/tmp/glidator-build/`) :
```
python3 tools/analyze_activity.py garmin_data/2026-10-22-villeneuve/activity_24813284437.gpx      (refusé : « no <Lap> found », le script lit des TCX)
python3 tools/analyze_activity.py <dossier inbox>/activity_24813284437.tcx
python3 tools/analyze_activity.py <dossier inbox>/activity_24813284437.tcx --csv /tmp/glidator-build/villeneuve-60s.csv
python3 tools/etalon_marche.py garmin_data/2026-10-22-villeneuve/activity_24813284437.gpx <dossier inbox>/activity_24813284437.tcx --lap 1
python3 tools/etalon_marche.py <même GPX> <même TCX> --lap 1 --minutes-csv /tmp/glidator-build/villeneuve-minutes.csv
python3 tools/etalon_marche.py <même GPX> <même TCX> --lap 1 --at 1079   (puis 2612, 4020, 5932, 5966, 5982)
python3 tools/etalon_marche.py <GPX SportsTrackLive> <même TCX> --lap 1   (échec, voir plus bas)
```
- Fenêtre VS et allure : 60 s glissantes, au moins 3 points et 20 s couverts (sortie du script). D+ : hystérésis 1 m (script) ; l'étalon donne aussi 3 m.
- Appariement photo/fichier : minuteur affiché = t du tour, tolérance de lecture de 1 à 5 s. Les photos ne portent pas d'horodatage lu ici ; l'heure de la montre sur 9373, 9382 et 9386 sert de contrôle.
- Les comptes de VS rejouée hors ±3000 m/h : Grep avec expression régulière sur la 8e colonne du CSV 60 s.
- Les altitudes SportsTrackLive sont lues dans le fichier au même horodatage (Grep sur l'heure), sans interpolation.

## Ce qui reste incertain

- Cause du décalage de minuteur d'environ 32 s (avant la pause) : non localisée.
- Altitude : montre contre SportsTrackLive (104 m au départ, 180 m à 1600 m). Aucun MNT ni mesure de référence ici ; on ne peut pas dire laquelle est juste, ni si la dérive vient de la pression (météo) ou du capteur.
- Vol : aucune photo, donc l'affichage en mode Vol (vario, compas) n'est pas vérifié par cette sortie.
- D+, distance et durée de la trace SportsTrackLive : non calculés (l'outil `etalon_marche.py` plante sur ce fichier, voir ci-dessous).
- Allure : l'écart de 1 à 5 % avec la fenêtre de 60 s est probablement dû à la fenêtre de l'app, qui n'est pas connue pour ces photos ; non vérifié.
- Cartes : forme du tracé non comparée numériquement.

## Suggestions (tâches pour le codeur)

- [ ] `analyze_activity.py` : accepter un GPX (message clair actuellement : « no <Lap> found ») ou documenter qu'il faut le TCX. Critère : la commande avec un GPX donne une analyse ou un message d'usage.
- [ ] `etalon_marche.py` : ne plus planter (`ZeroDivisionError` dans `totals_report`, ligne 650) quand le GPX n'a aucune FC (cas SportsTrackLive). Critère : la commande sur la trace SportsTrackLive imprime distance, D+ et durée sans FC.
- [ ] `etalon_marche.py` ou `analyze_activity.py` : option qui liste les intervalles > N s (instant de début, durée), pour localiser le décalage de minuteur. Critère : la liste donne les 8 intervalles > 15 s du tour 1 de Villeneuve.
- [ ] Enquête sur le minuteur : relire la spec de pause (reprise auto après 30 s) et vérifier si une pause courte arrête le minuteur sans arrêter l'enregistrement des points. Critère : explication écrite et, si c'est un défaut, test de reproduction.
- [ ] Spec : trancher si la VS affichée (rejouée par `tools/analyze_activity.py` ; l'app n'en enregistre aucune, voir `docs/recherches/2026-10-28-vs-enregistree.md`) doit être bornée à ±3000 m/h en mode Marche, y compris en phase aérienne. Critère : décision notée dans la spec.
- [ ] Test terrain suivant : photographier les écrans du mode Vol (vario, altitude, vitesse, compas) et passer en Vol avant le décollage. Critère : au moins 3 photos du mode Vol avec le minuteur visible.
- [ ] Suivi altitude : relever l'altitude réelle du point de départ (carte) avant la sortie et la noter, pour trancher montre contre SportsTrackLive. Critère : une valeur de référence dans les notes du test.
