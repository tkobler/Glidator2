# Étalon du tour de marche de Salvan et données de test du mode marche

- **Date** : 13/10/2026 (analyse faite le 12/10 au soir), branche `claude/corrections-marche`.
- **Données** : `garmin_data/activity_24346302742.gpx` et `.tcx` (sortie « Salvan Glide » du 13/09/2026, montre fenix 6 Pro Solar, firmware 28.2 : TCX lignes 73341-73349), journal du manageur `journal-diag-lecture-gpx.log` (diagnostic du simulateur du 12/10, chemin local retiré ; lecture du GPX au simulateur fenix6pro).
- **Outil** : `tools/etalon_marche.py` (Python stdlib, commit `39136c9`), qui réutilise `tools/analyze_activity.py`. Commande exacte en fin de note.
- **Fichiers produits** (dossier `docs/verifications/data/`) :
  - `2026-10-13-etalon-marche-minutes.csv` : table minute par minute du tour de marche (123 lignes) ;
  - `2026-10-13-etalon-marche-extrait-montee-reguliere.csv`, `-replat.csv`, `-montee-raide.csv` : 3 extraits de 40 points avec les valeurs attendues (colonnes `lat` et `lon` retirées le 29/10, voir « Colonnes des CSV »).

## Questions

1. Que valent, minute par minute sur le tour de marche (tour 1 du TCX), l'altitude, la FC, la distance, le D+ (brut et lissé), la vitesse verticale et le pace ? Les totaux recalculés correspondent-ils à ceux du TCX ?
2. Pour chaque champ des pages de marche (ALTITUDE, ELEV. GAIN, DISTANCE, Heart Rate, VERT. SPD., PACE, carte), dans quels cas l'app affiche-t-elle « -- » (ou « --:-- », ou « Waiting for GPS ») ? Lesquels viennent du simulateur, lesquels de l'app ?
3. Fournir 3 extraits (montée régulière, replat, montée raide) prêts à recopier dans un test Monkey C.

## Réponse courte

- **Totaux** : le recalcul colle au TCX (confiance **élevée**). Durée 7301 s pour 7302,217 s ; distance enregistrée identique, à 1,51 m près ; FC moyenne 130,7 (pondérée par le temps) pour 131 ; FC max 179 = 179 ; vitesse max 2,818 = 2,818 m/s. La distance GPS brute (haversine) est supérieure de 2,72 % (4010,6 m pour 3904,63 m) : écart normal, puisque Garmin lisse la distance enregistrée. Ni le TCX ni le GPX ne contiennent de D+ : recalcul brut 927,2 m, hystérésis 1 m 917,2 m, hystérésis 3 m (« lissé ») 908,6 m.
- **Simulateur** : le recoupement du journal avec le GPX donne une relation **exacte** : `altitude reçue = 0,2000 × ele GPX − 622,0 m` (R² = 1,0000, 226 couples, positions identiques au GPX à 0,1 m près). Le simulateur transforme donc l'altitude de façon déterministe. Elle ne revient dans la plage −100..6000 m qu'au-dessus de 2610 m de vraie altitude. Le « -- » d'ALTITUDE vient du simulateur, comme celui de Heart Rate (FC null sur 653 lignes sur 653). Le « D+ 5 m pour 30 m bruts » s'explique aussi par ce facteur : 0,2 × 28,8 m = 5,8 m (confiance **élevée**).
- **Carte** : accuracy = 2 sur 653 lignes sur 653. L'app exige 3, donc aucun point de trace et « Waiting for GPS » pendant toute la lecture. C'est un choix de l'app face au simulateur, déjà tranché par D6.
- **Défaut de l'app trouvé (latent, non observé au simulateur)** : **PACE dépend de l'altitude**. `HikeHistory.add()` jette tout l'échantillon quand l'altitude est null (`HikeHistory.mc:32-35`), distance comprise. Si `getAltitude()` renvoie null, PACE reste donc à « --:-- » même avec une distance valide (détail plus bas). Confiance **moyenne** sur l'impact réel : il faut une altitude null sur la montre, ce qui n'a pas été observé.
- **DISTANCE** : « 0.3 » affiché à 4:13 alors que le GPX donne 247 m (« 0.2 » attendu). Il manque au moins 3 m (+1,2 %). Écart faible à la résolution d'affichage, mais non expliqué : l'alignement entre le chronomètre et la trace est inconnu.

## Inventaire des fichiers

Source : sortie de la commande (section Méthode) et `python3 tools/analyze_activity.py garmin_data/activity_24346302742.tcx`.

| | Tour 1 (marche) | Tour 2 (vol) | Ensemble |
|---|---|---|---|
| Début → fin (UTC) | 10:18:43 → 12:20:25 | 12:20:25 → 13:14:36 | |
| Durée TCX (`TotalTimeSeconds`) | 7302,217 s (TCX l. 13) | 3250,432 s (l. 37621) | |
| Distance TCX (`DistanceMeters` du tour) | 3904,63 m (l. 14) | 22756,35 m (l. 37622) | |
| Points TCX | 2211 | 2100 | 4311 |
| Points GPX | 2210 (index 0..2209, lignes 17..22107) | 2100 (index 2210..4309) | 4310 |
| Intervalle moyen / max | 3,31 s / 37 s | 1,55 s / 38 s | 2,45 s |
| Intervalles > 15 s (remise à zéro de HikeHistory) | 25 | | |
| Altitude min..max | 1815,0..2677,8 m | | 1120,0..2677,8 m |
| Champs | position, ele, FC, temps ; TCX en plus : distance, vitesse | idem | |

- La différence de 1 point entre le TCX et le GPX vient de l'instant 12:20:25, présent dans les deux tours du TCX (fin du tour 1 et début du tour 2). Les 4310 points GPX ont tous un point TCX au même horodatage, avec la même altitude et la même FC (0 écart).
- Correction du contexte : il n'y a pas « un point toutes les 4 s ». L'enregistrement est intelligent, avec 2,45 s en moyenne (3,31 s en marche, 1,55 s en vol), entre 1 et 38 s.

## Totaux du TCX et recalcul (tour 1)

| Indicateur | TCX | Recalcul | Écart | Verdict |
|---|---|---|---|---|
| Durée | 7302,217 s | 7301 s entre le 1er et le dernier point GPX du tour (7302 s avec le point limite 12:20:25) | −1,2 s (−0,02 %) | conforme |
| Distance | 3904,63 m | 3903,12 m (dernier − premier `DistanceMeters`, le 1er point est à 1,51 m) | −1,51 m | conforme |
| Distance GPS (haversine des points) | 3904,63 m | 4010,6 m | +106,0 m (+2,72 %) | écart acceptable (lissage Garmin) |
| FC moyenne | 131 (l. 18) | 130,7 pondérée par le temps ; 133,5 en moyenne des points | −0,3 / +2,5 | conforme (Garmin pondère par le temps) |
| FC max | 179 (l. 21) | 179 | 0 | conforme |
| FC min | — | 83 | | |
| Vitesse max | 2,818 m/s (l. 15) | 2,818 m/s (maximum du champ `Speed`) | 0 | conforme |
| Vitesse moyenne | 0,5350 m/s (`AvgSpeed`, l. 37616) | 3904,63 / 7302,217 = 0,5347 m/s | −0,0003 | conforme |
| D+ | absent du TCX et du GPX | brut 927,2 ; h1 917,2 ; h3 908,6 ; h5 892,2 m | — | non comparable |
| Altitude début → fin | — | 1815,0 → 2652,6 m (+837,6), max 2677,8 m | | |

Recoupement : le D+ h1 (917,2 m) et la VS 60 s médiane (+635 m/h) sont identiques à ceux de `analyze_activity.py`. Le « 908 m » cité dans `Utils.mc:159` et les tests vient d'une version antérieure de ce calcul (`tools/test_analyze_activity.py:863`), pas de Garmin.

### Lissage du D+ choisi

- **Brut** : somme de toutes les hausses d'un point au suivant. L'altitude barométrique est au pas de 0,2 m, donc chaque oscillation compte.
- **h1** : hystérésis symétrique de 1 m (`elevation_gain_m` de `analyze_activity.py`, référence du dépôt). Une hausse ne compte qu'après plus de 1 m au-dessus du dernier minimum, une descente ne commence qu'après plus de 1 m sous le dernier maximum.
- **h3 = « lissé façon Garmin »** : même hystérésis avec 3 m. **C'est une hypothèse, pas un étalonnage.** Garmin ne publie pas le filtre de `totalAscent`, et aucun des deux fichiers ne contient le D+ de la montre. Sur ce tour, le choix pèse peu : 908,6 m (h3) contre 917,2 m (h1), soit −0,9 %, et 892,2 m avec 5 m. Pour étalonner : relever le « Total Ascent » du tour 1 dans Garmin Connect, ou lire `total_ascent` dans le FIT d'origine.

## Table minute par minute

Fichier : `docs/verifications/data/2026-10-13-etalon-marche-minutes.csv`, une ligne par minute de 0 à 121, plus la fin du tour à 7302 s.

Définitions :
- `t_s` est compté depuis le début du tour (10:18:43). Les valeurs ponctuelles sont celles du **dernier point GPX à ou avant** ce temps (`i_gpx`, `ligne_gpx`, `t_point_s`), comme une montre qui garde la dernière valeur.
- `dist_tcx_m` est le `DistanceMeters` du TCX, cumulé depuis le début de l'activité : c'est ce que donnerait `elapsedDistance`. `dist_gps_m` est l'haversine cumulée des points GPX.
- `vs_min_mh` est (altitude − altitude de la minute précédente) / Δt. `vs60_reg_mh` est la régression sur 60 s glissantes des points enregistrés (méthode de `analyze_activity.py`).
- `vs_app_1hz_mh` et `pace_app_1hz` rejouent `HikeHistory.mc` alimenté chaque seconde, comme `onSensor()`, avec l'altitude et la distance du TCX interpolées linéairement : c'est la meilleure estimation de ce qu'aurait montré l'app.
- `pace60_tcx` : Δ distance TCX / Δt sur 60 s. `pace_min_gps` : distance GPS sur la minute écoulée.
- Les colonnes `aff_*` sont les chaînes que l'app afficherait selon `Utils.mc` (altitude, D+ h3, distance, FC, VS, pace).

Extrait (toutes les 10 min, plus les minutes remarquables) :

| min | alt. (m) | FC | dist. TCX (m) | dist. GPS (m) | D+ brut / h1 / h3 (m) | VS min / 60 s / app (m/h) | pace 60 s TCX / app | affichage app : ALT, D+, DIST, FC, VS, PACE |
|---|---|---|---|---|---|---|---|---|
| 0 | 1815,0 | 83 | 1,5 | 0,0 | 0 / 0 / 0 | — | — | 1815, 0, 0.0, 83, --, --:-- |
| 1 | 1826,0 | 90 | 58,7 | 61,2 | 11,0 / 11,0 / 11,0 | +671 / +752 / +736 | 17:11 / 17:22 | 1826, 11, 0.1, 90, +740, 17:22 |
| 5 | 1848,2 | 109 | 284,1 | 290,2 | 37,6 / 36,8 / 36,8 | +644 / +661 / +658 | 16:14 / 16:05 | 1848, 37, 0.3, 109, +660, 16:05 |
| 10 | 1905,4 | 131 | 534,9 | 543,8 | 94,8 / 94,0 / 94,0 | +635 / +596 / +588 | 15:41 / 15:34 | 1905, 94, 0.5, 131, +590, 15:34 |
| 20 | 2005,8 | 128 | 1143,1 | 1159,6 | 195,2 / 194,4 / 194,4 | +637 / +620 / +609 | 15:53 / 15:49 | 2006, 194, 1.1, 128, +610, 15:49 |
| 30 | 2121,8 | 162 | 1621,9 | 1640,7 | 311,6 / 310,4 / 310,4 | +661 / +709 / +707 | 42:55 / 42:27 | 2122, 310, 1.6, 162, +710, 42:27 |
| 31 (arrêt) | 2122,4 | 128 | 1626,3 | 1645,1 | 312,8 / 311,6 / 311,6 | +47 / +39 / +28 | --:-- / --:-- | 2122, 312, 1.6, 128, +30, --:-- |
| 40 | 2215,6 | 148 | 2051,5 | 2073,9 | 407,6 / 405,8 / 405,8 | −59 / −79 / −79 | --:-- / --:-- | 2216, 406, 2.1, 148, -80, --:-- |
| 50 | 2261,4 | 100 | 2318,7 | 2344,0 | 456,2 / 453,0 / 450,0 | +488 / +464 / +455 | 15:57 / 16:00 | 2261, 450, 2.3, 100, +450, 16:00 |
| 60 | 2382,8 | 163 | 2729,1 | 2777,9 | 577,8 / 574,4 / 571,4 | +615 / +694 / +666 | 33:36 / 34:07 | 2383, 571, 2.7, 163, +670, 34:07 |
| 69 (raide) | 2508,2 | 178 | 3051,4 | 3123,9 | 703,4 / 699,8 / 696,8 | +1245 / +1237 / +1238 | 24:11 / 24:33 | 2508, 697, 3.1, 178, +1240, 24:33 |
| 70 (arrêt) | 2509,6 | 136 | 3062,1 | 3137,4 | 706,0 / 702,0 / 699,0 | +88 / +84 / +14 | --:-- / --:-- | 2510, 699, 3.1, 136, +10, --:-- |
| 80 | 2539,2 | 112 | 3215,7 | 3298,1 | 746,4 / 740,6 / 737,6 | +670 / +744 / +713 | 31:51 / 32:52 | 2539, 738, 3.2, 112, +710, 32:52 |
| 86 (descente) | 2530,6 | 118 | 3261,6 | 3347,7 | 751,6 / 745,6 / 741,0 | −662 / −900 / −842 | 26:43 / 28:19 | 2531, 741, 3.3, 118, -840, 28:19 |
| 90 | 2527,4 | 136 | 3383,0 | 3471,5 | 766,8 / 759,6 / 755,0 | +403 / +312 / +310 | 46:56 / 47:51 | 2527, 755, 3.4, 136, +310, 47:51 |
| 100 | 2633,2 | 126 | 3645,1 | 3748,5 | 873,2 / 865,6 / 861,0 | +372 / +368 / +361 | 43:14 / 46:11 | 2633, 861, 3.6, 126, +360, 46:11 |
| 104 (sommet) | 2677,6 | 120 | 3778,2 | 3879,6 | 917,8 / 910,0 / 905,4 | +546 / +632 / +577 | 25:15 / 25:50 | 2678, 905, 3.8, 120, +580, 25:50 |
| 110 | 2672,8 | 113 | 3835,0 | 3936,8 | 922,4 / 914,0 / 905,4 | −46 / −130 / −68 | --:-- / --:-- | 2673, 905, 3.8, 113, -70, --:-- |
| 120 | 2654,2 | 119 | 3897,6 | 4003,5 | 926,4 / 917,2 / 908,6 | −732 / −940 / −888 | 38:45 / 38:45 | 2654, 909, 3.9, 119, -890, 38:45 |
| 121,70 (fin) | 2652,6 | 126 | 3904,6 | 4010,6 | 927,2 / 917,2 / 908,6 | −92 / −82 / −82 | --:-- / --:-- | 2653, 909, 3.9, 126, -80, --:-- |

Constats sur ces données réelles (faits) :
- **PACE affiche « --:-- » à 34 relevés sur 123** (28 %), d'après le décompte de `,--:--$` dans le CSV. Cela arrive aux arrêts et aux passages plus lents que 60:00/km (moins de 0,278 m/s). C'est le comportement voulu de `formatPace()` (`Utils.mc:551-554`), mais il sera fréquent en montée raide ou lente.
- VERT. SPD. n'affiche « -- » qu'à la minute 0 : avant 20 s couvertes et 3 échantillons, `HikeHistory.mc:128-131`. Son maximum sur le tour est d'environ 1240 m/h, sous le plafond de 3000 m/h.
- D+ : l'écart brut − h1 atteint 10,0 m en fin de tour. Un peu plus de la moitié (5,6 m) se forme pendant les arrêts et les passages lents : minutes 40-50 (+1,4 m), 70-85 (+2,0 m) et 104-fin (+2,2 m). Le brut y monte de 0,2 m en 0,2 m, le D+ h1 presque pas.

### Point de contrôle 4:13 (relevé de l'utilisateur au simulateur)

À t = 253 s (10:22:56), point GPX 94 (ligne 957) : altitude 1840,2 m, distance TCX 241,0 m, distance GPS 247,0 m, D+ brut 29,6 m, h1 et h3 28,8 m, FC 104.

| Champ | Simulateur (utilisateur) | Attendu sur montre (GPX) | Attendu au simulateur (transformation mesurée) | Verdict |
|---|---|---|---|---|
| DISTANCE | 0.3 | 0.2 (247 m GPS, 241 m TCX) | ≥ 0,247 km si le simulateur cumule l'haversine | écart de +3 m au moins (+1,2 %), visible à l'arrondi ; cause non établie (voir Incertain) |
| ELEV. GAIN | 5 | 29 (h1/h3 28,8 m ; brut 29,6) | 0,2 × 28,8 = 5,8 m, avant le filtre propre au simulateur | cohérent avec le simulateur, pas un défaut de l'app |
| ALTITUDE | -- | 1840 | 0,2 × 1840,2 − 622 = −253,96 m, donc hors plage, d'où « -- » | simulateur |
| Heart Rate | -- | 104 | null | simulateur |

## Diagnostic du simulateur : résumé et recoupement

Conclusions du manageur (`conclusions.md`) et recoupement fait ici avec `--sim-log` :

| Donnée | Journal (653 lignes `DIAG`) | Recoupement avec le GPX | Verdict |
|---|---|---|---|
| Position | suit la trace | 226 couples (position, altitude) distincts, chacun à 0,0 m (médiane) et 0,1 m (max) d'un point GPX | conforme |
| `Position.accuracy` | 2 sur 653 lignes | — | QUALITY_POOR constant, d'où « Waiting for GPS » (choix de l'app × simulateur, D6) |
| Altitude (Position = Activity = Sensor) | −256,8 .. −237,8 m | GPX 1826,0 .. 1921,0 m aux mêmes positions ; **alt_sim = 0,2000 × ele − 622,0 (R² = 1,0000)** | transformation du simulateur, exacte et linéaire |
| FC (Activity et Sensor) | null sur 653 lignes | GPX : FC sur 4310 points sur 4310 | le simulateur ne transmet pas la FC |
| Distance, D+ d'Activity | null sur 653 lignes | — | normal : aucune session démarrée pendant la mesure |

Conséquences vérifiables au prochain essai au simulateur (prédictions, valables si la relation reste linéaire hors de la plage mesurée, 1826-1921 m) :
- ALTITUDE ne sort de « -- » que pour une vraie altitude ≥ 2610 m (0,2 × 2610 − 622 = −100). Sur le tour 1, cela arrive vers la minute 98 (11:56, 2614 m) : l'app affichera alors « -100 » à « -86 » (au sommet, 2677,8 m donne −86,4).
- VERT. SPD. ne sera pas « -- » (l'altitude n'est pas null), mais vaudra environ **0,2 × la vraie valeur** (+130 m/h au lieu de +660).
- ELEV. GAIN suivra environ 0,2 × le vrai D+ (environ 180 m en fin de tour au lieu d'environ 909 m), un peu moins à cause du filtre du simulateur.
- DISTANCE suivra la distance GPS plutôt que celle du TCX : environ 4,0 km en fin de tour au lieu de 3,9 km.
- La page vol affichera une altitude négative (« -254 m » à 1840 m, plage vol −500..9000).

Écart de comptage : la note du manageur parle de 624 lignes. Le fichier en compte 658, dont 653 lignes `DIAG` (Grep `^DIAG` en mode count). Ça ne change pas les conclusions.

## Cas « -- » par champ : chemin source → WatchData → vue

Les numéros de ligne renvoient à `source/` tel qu'il est sur la branche au commit `39136c9`, qui ne touche pas `source/`. Chaîne commune : `onSensor()` à 1 Hz (`FlyInstrumentApp.mc:445-455`) appelle `FlyInstrumentView.updateData()` (`FlyInstrumentView.mc:109-134`). Celui-ci remet les trois dictionnaires à null (`WatchData.startMeasure`, `WatchData.mc:18-23`), puis lit `Position.getInfo()`, `Activity.getActivityInfo()` et `Sensor.getInfo()` (`WatchData.updateInfo/updateActivityInfo/updateSensorInfo`).

| Champ (page) | Source → WatchData | Vue → format | Cas « -- » | Au simulateur |
|---|---|---|---|---|
| **ALTITUDE** (Position) | `Activity.altitude` stockée **même si null** (`WatchData.mc:119-122`), sinon `Sensor.altitude` (176-179), sinon `Position.altitude` (61-64). `getAltitude()` (213-232) prend Activity en premier dès que la clé existe (215-218), donc **une altitude Activity null masque Sensor et Position** | `HikePositionView.mc:44-45` → `formatHikeAltitude` (`Utils.mc:36-48`) | null ; NaN/±Inf ; hors −100..6000 m (`Utils.mc:43`). Pas de condition de session | « -- » car −256,8..−237,8 < −100 : **simulateur** |
| **ELEV. GAIN** (Position) | `Activity.totalAscent`, stocké même si null (`WatchData.mc:145-148`) → `getTotalAscent()` (275-283) | `HikePositionView.mc:49-50` → `formatHikeAscent` (`Utils.mc:168-180`) | **pas de session** (`hasActiveSession`) ; null ; < 0 ; > 20000 ; NaN/±Inf | affiché (5 m), mais calculé par le simulateur sur l'altitude × 0,2 |
| **DISTANCE** (Position) | `Activity.elapsedDistance` (`WatchData.mc:151-154`) → `getDistance()` (287-295) | `HikePositionView.mc:52-53` → `formatDistanceKm` (`Utils.mc:270-286`) | **pas de session** ; null ; < 0 ; NaN/±Inf | affiché (0.3 pour 0.2 attendu, voir plus haut) |
| **Heart Rate** (Pace) | `Activity.currentHeartRate` stockée seulement si non null (`WatchData.mc:126-129`), sinon `Sensor.heartRate` (190-193) → `getHeartRate()` (258-271) | `HikePaceView.mc:39-40` → `formatHeartRate` (`Utils.mc:192-204`) | les deux null ; hors 25..250 bpm (une valeur Activity hors plage masque une valeur Sensor valide, documenté) ; **pendant une pause**, capteurs coupés par `setEnabledSensors([])` (`FlyInstrumentApp.mc:93-99`, 293-297), d'où une FC probablement null (non vérifié) | « -- » car null sur 653 lignes : **simulateur** |
| **VERT. SPD.** (Pace) | `getAltitude()` → `recordHikeSampleAt()` (`WatchData.mc:436-440`) à chaque tick si `shouldRecordHikeSample` (`FlyInstrumentApp.mc:364-367`, pas pendant une pause) → `HikeHistory.add()` : **ignoré si altitude null** (`HikeHistory.mc:32-35`), remis à zéro après un trou > 15 s (44-47), 1 échantillon toutes les 5 s au plus (48-51) | `HikePaceView.mc:46` → `verticalSpeedMh` null si moins de 3 échantillons ou moins de 20 s (`HikeHistory.mc:128-131`) → `formatVerticalSpeed` (`Utils.mc:304-332`) | environ 20-25 s après le lancement ; environ 20-25 s après une reprise (trou > 15 s) ; altitude null ; \|VS\| > 3000 m/h ; NaN/±Inf | non « -- », mais environ 0,2 × la vraie valeur (altitude transformée) |
| **PACE** (Pace) | `getDistance()` dans le même échantillon `HikeHistory` → `speedMps()` (`HikeHistory.mc:163-197`) | `HikePaceView.mc:51` → `formatPace` (`Utils.mc:538-561`) | **pas de session** (distance null) ; moins de 3 échantillons avec distance ou moins de 20 s ; distance en baisse ; arrêt ou allure > 60:00/km (28 % des minutes sur ce tour) ; **altitude null : l'échantillon est jeté avec sa distance, donc « --:-- » même si la distance est valide** | affiché si une session tourne |
| **Carte** (Map) | `Position.position` et `accuracy` (`WatchData.mc:70-80`) → `hasUsableFix()` : accuracy ≥ `MIN_MAP_QUALITY = QUALITY_USABLE` (375, 392-400) et `isValidLatLon` (`BreadcrumbTrail.mc:8-19`) ; la trace n'est alimentée qu'avec un fix utilisable (`FlyInstrumentApp.mc:373-379`) | `HikeMapView.mc:46-49` (position courante seulement si fix utilisable) → `mapDrawMode` (`Utils.mc:340-351`) → « Waiting for GPS » (`WatchDisplay.mc:783-793`) | aucune position courante utilisable **et** trace vide : accuracy < 3 depuis le lancement, position null, (180,180) ou (0,0). Si le fix se perd une fois la trace commencée : la trace s'affiche seule, sans « Waiting » | accuracy 2 sur 653 lignes : jamais de point de trace, « Waiting for GPS » permanent. Choix de l'app × simulateur, **D6** |

### Classement des cas

- **Dus au simulateur** : ALTITUDE « -- » (transformation 0,2 × ele − 622) et Heart Rate « -- » (FC jamais transmise). À revérifier sur montre réelle ou avec le FIT d'origine.
- **Choix de l'app, déjà décidés** : plages d'affichage altitude, FC et D+ (06/10 et 07/10) ; plafond VS de 3000 m/h ; « --:-- » au-delà de 60:00/km ; « -- » sans session pour ELEV. GAIN, DISTANCE et PACE ; carte limitée à QUALITY_USABLE (changé par D6).
- **Défauts de l'app ou points à décider** (interprétation, non observés au simulateur) :
  1. **PACE couplé à l'altitude** (`HikeHistory.mc:32-35` avec `WatchData.mc:436-440`). Une altitude null fait perdre aussi la distance, donc PACE passe à « --:-- » en même temps que VERT. SPD., alors que DISTANCE avance. Avec la décision du 06/10 (« altitude null d'Activity : ne pas corriger »), une altitude Activity null masque aussi les altitudes Sensor et Position (`WatchData.mc:215-218`) et suffit à couper PACE. La décision visait l'affichage de l'altitude ; cette conséquence sur PACE ne semble pas avoir été examinée.
  2. **FC pendant la pause** : le capteur FC est coupé (`FlyInstrumentApp.mc:93-99`), donc Heart Rate devrait afficher « -- » sur la page Pace pendant toute la pause. Peut-être voulu (économie de batterie), à confirmer sur montre.

## Extraits de test

Trois fenêtres de **40 points GPX consécutifs** du tour 1, choisies par `pick_extracts()` (règles dans le code). Chaque fenêtre n'a aucun intervalle > 15 s (donc pas de remise à zéro de HikeHistory), a la FC sur chaque point et couvre au moins 60 s. Elles ne se chevauchent pas et diffèrent des extraits déjà utilisés dans les tests (11:07:11-11:09:21, `Tests.mc:1133-1141` ; extrait M, `TestsChain.mc:506-524`).

| Extrait | Index GPX | Lignes GPX (`<trkpt`) | UTC | t depuis le début du tour | Durée | Échantillons gardés par HikeHistory | Pente (régression) | Amplitude d'altitude | Vitesse | D+ brut / h1 | Fin d'extrait : VS / vitesse (affichage) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Montée régulière | 79..118 | 807..1197 | 10:22:30 → 10:24:02 | +227..+319 s | 92 s | 16 | +661 m/h (R² 0,999) | 16,6 m | 1,03 m/s | 16,6 / 16,6 m | 671,8 m/h (« +670 ») / 0,9553 m/s (« 17:27 ») |
| Replat | 934..973 | 9357..9747 | 11:02:33 → 11:05:10 | +2630..+2787 s | 157 s | 23 | +11 m/h (R² 0,038) | 3,4 m | 0,32 m/s | 4,0 / 3,4 m | 11,9 m/h (« +10 ») / 0,3425 m/s (« 48:40 ») |
| Montée raide | 1389..1428 | 13907..14297 | 11:26:03 → 11:27:18 | +4040..+4115 s | 75 s | 14 | +1309 m/h (R² 0,998) | 27,6 m | 0,84 m/s | 27,6 / 27,6 m | 1319,1 m/h (« +1320 ») / 0,9040 m/s (« 18:26 ») |

Notes :
- La montée régulière contient le point de contrôle 4:13 (point 94).
- **Le tour 1 n'a pas de vrai replat en marche**. Hors chevauchement avec les deux autres extraits, aucune fenêtre de 40 points n'a moins de 2 m d'amplitude à 0,4 m/s ou plus, ni moins de 3 m à 0,3 m/s ou plus. L'extrait retenu (critère de repli : plus petite amplitude à 0,3 m/s ou plus) est une marche lente, presque arrêtée pendant environ 1 min (11:03:37 → 11:04:38 : 5,4 m parcourus). Il est utile pour tester une VS proche de 0, puis un pace qui passe par « --:-- » (lignes avec allure > 60:00/km) avant de revenir.
- La montée raide est la plus raide du tour (FC 159 → 179, le maximum de la sortie). Le point 1402 fait un saut GPS de 10,5 m en 3 s.

Colonnes des CSV :
- `i_gpx`, `ligne_gpx` : index (base 0) et ligne du point dans le GPX.
- `t_s` : secondes depuis le 1er point de l'extrait ; `t_tour_s` : secondes depuis le début du tour.
- `ele`, `hr` : valeurs du GPX. Les colonnes `lat` et `lon` (positions GPS) existaient à l'origine ; elles ont été retirées de ces trois CSV le 29/10/2026 (dépôt public). L'outil les écrit encore si on le relance avec `--extracts-prefix` : ne pas recommiter ces colonnes.
- `dist_m` : distance TCX depuis le 1er point de l'extrait.
- `hh_garde` : 1 si `HikeHistory.add()` garde l'échantillon.
- `dplus_brut_m`, `dplus_h1_m` : D+ cumulé depuis le début de l'extrait.
- `hh_vs_mh`, `hh_vitesse_mps` : `verticalSpeedMh(t, 60000)` et `speedMps(t, 60000)` interrogés juste après l'ajout de la ligne.
- `aff_*` : chaînes attendues de `formatHikeAltitude`, `formatHeartRate`, `formatVerticalSpeed` et `formatPace`.

Pour un test Monkey C : appeler `h.add(t0 + t_s * 1000, ele, dist_m)` pour chaque ligne, puis comparer `verticalSpeedMh(t0 + t_s * 1000, 60000)` à `hh_vs_mh` (tolérance proposée ±0,5 m/h, car Float 32 bits côté montre) et `speedMps` à `hh_vitesse_mps` (±0,001 m/s). La VS peut changer sur une ligne non gardée : la fenêtre de 60 s avance avec `nowMs` et fait sortir un ancien échantillon (exemple : extrait raide, `t_s` 71 → 72).

## Méthode (reproductible)

```
python3 tools/etalon_marche.py garmin_data/activity_24346302742.gpx garmin_data/activity_24346302742.tcx --at 253 --minutes-csv docs/verifications/data/2026-10-13-etalon-marche-minutes.csv --extracts-prefix docs/verifications/data/2026-10-13-etalon-marche-extrait --sim-log <journal-diag-lecture-gpx.log>
python3 tools/analyze_activity.py garmin_data/activity_24346302742.tcx
python3 -m unittest tools/test_etalon_marche.py tools/test_analyze_activity.py   # 112 tests, OK
```

`<journal-diag-lecture-gpx.log>` : journal du diagnostic du simulateur du 12/10 (chemin local retiré de la note).

- Le tour 1 regroupe les points dont l'heure est ≥ 10:18:43 (`StartTime` du tour 1) et < 12:20:25 (`StartTime` du tour 2).
- VS 60 s : régression des moindres carrés sur les points des 60 s précédentes, avec au moins 3 points et 20 s couvertes. Pace 60 s : Δ distance / Δt sur la même fenêtre.
- Rejeu de HikeHistory : mêmes constantes que `HikeHistory.mc:10-14` (60 échantillons, 5 s, 15 s, 3 points, 20 s), fenêtre de 60 s (`VS_WINDOW_DEFAULT_MS`, `HIKE_WINDOW_MS`), calcul en double précision.
- Journal du simulateur : pour chaque couple distinct (position, altitude reçue), on cherche le point GPX le plus proche, puis on fait une régression linéaire de l'altitude reçue sur l'ele GPX.
- `python3 -I tools/...` est refusé par les permissions de la session ; les commandes ont été lancées sans `-I`. Elles ne lisent que les fichiers du dépôt et le journal du manageur.
- Recensement des cas « -- » : lecture du code (`WatchData.mc`, `HikeHistory.mc`, `HikePositionView.mc`, `HikePaceView.mc`, `HikeMapView.mc`, `FlyInstrumentApp.mc`, `FlyInstrumentView.mc`, `BreadcrumbTrail.mc`, `Utils.mc`, `WatchDisplay.mc`), sans exécution au simulateur.

## Ce qui reste incertain

- **D+ « façon Garmin »** : h3 est une hypothèse, faute de D+ de la montre dans les fichiers.
- **Transformation de l'altitude par le simulateur** : mesurée seulement entre 1826 et 1921 m. Les prédictions au-dessus de 2610 m supposent qu'elle reste linéaire. Origine inconnue (`ele = 5 × alt_sim + 3110`).
- **DISTANCE 0.3 contre 0.2** : on ne sait pas si « 4 min 13 » était le chronomètre de session ou la position dans la lecture du GPX, ni quand la session a démarré. Une session démarrée après le début de la lecture donnerait **moins** que 247 m, donc l'écart reste inexpliqué.
- **Rejeu à 1 Hz** : il interpole linéairement à travers les trous de l'enregistrement intelligent (jusqu'à 37 s). Une vraie montre aurait mesuré l'altitude réelle pendant ces trous ; `vs_app_1hz` et `pace_app_1hz` sont des estimations.
- **FC pendant la pause** : déduite du code, non observée.
- **Arrondi de `format("%.1f")` en Monkey C** sur les demi-dixièmes (0,25 km) : supposé identique à Python (« 0.2 »), non vérifié.

## Suggestions (tâches)

- **[dev-monkeyc] Découpler PACE de l'altitude dans HikeHistory**
  Objectif : un échantillon sans altitude garde sa distance, pour que PACE reste calculé quand `getAltitude()` est null. La VS ignore les échantillons sans altitude, et le vario de vol n'est pas touché.
  Critère de fin : test Monkey C où l'altitude est null et la distance avance de 0,5 m/s pendant 60 s ; PACE affiche « 33:20 » et VERT. SPD. « -- ». Les tests HikeHistory existants passent toujours.
  À décider d'abord par l'utilisateur, à cause de la décision du 06/10 sur l'altitude null d'Activity.
- **[dev-monkeyc] Tests sur les 3 extraits du 13/10**
  Objectif : recopier `docs/verifications/data/2026-10-13-etalon-marche-extrait-*.csv` (colonnes `t_s`, `ele`, `dist_m`) dans un module de test, par exemple `TestsSalvanExtracts`, pour ne pas consommer de membres de `globals`.
  Critère de fin : sur chaque ligne, VS et vitesse dans les tolérances de la note ; affichage final « +670 / 17:27 », « +10 / 48:40 », « +1320 / 18:26 ».
- **[testeur-connectiq] Vérifier les prédictions au simulateur**
  Objectif : rejouer le GPX avec une session au-delà de 11:56 de trace.
  Critère de fin : ALTITUDE passe de « -- » à « -100 », puis à environ « -86 » au sommet ; VERT. SPD. ≈ 0,2 × la colonne `vs_app_1hz_mh` ; relever le chronomètre et DISTANCE à 2 instants pour éclaircir l'écart 0.3 / 0.2.
- **[analyste-activite] Étalonner le D+ Garmin**
  Objectif : obtenir de l'utilisateur le « Total Ascent » du tour 1 dans Garmin Connect, ou le FIT d'origine, puis choisir le seuil d'hystérésis qui le reproduit.
  Critère de fin : seuil documenté et colonne `dplus_h3_m` renommée ou recalculée.
- **[testeur-connectiq] FC pendant la pause sur montre réelle**
  Objectif : constater si Heart Rate passe à « -- » pendant une pause, puis faire décider l'utilisateur.
  Critère de fin : constat consigné, décision demandée à l'utilisateur.
- **[dev-python] Ne plus écrire lat/lon dans les CSV d'extraits**
  Objectif : `tools/etalon_marche.py` ne doit plus écrire `lat` et `lon` avec `--extracts-prefix`.
  Critère de fin : un test vérifie l'absence de ces colonnes ; les CSV régénérés sont identiques à ceux du dépôt.
