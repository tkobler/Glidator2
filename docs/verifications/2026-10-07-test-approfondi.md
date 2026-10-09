# Vérification : test approfondi et commits des nuits du 06 et du 07/10

*Testeur Connect IQ, round 2 du 07/10 (exécuté dans la nuit du 07 au 08/10). Branche `claude/corrections-marche`. SDK Connect IQ 9.2.0, simulateur ouvert.*

## Périmètre
- **Commits vérifiés** : les 79 commits de `75fe170` à `f306659`, c'est-à-dire tout ce qui suit `a078d7d` (dernière vérification, rounds 1 et 2 du 05/10). **Base de comparaison** : `a078d7d`.
- **Plan de test** relu et corrigé dans un commit séparé : `9d78dd2` (`docs: fix inconsistencies in the deep test plan`).
- **Code testé** : `f306659` (le commit du plan ne touche que `docs/`).

## Verdict : **OK avec réserves**
- **Fonctionnel : OK.** Sur les **17 montres** où la suite a tourné (les 15 représentatives des groupes d'écran, plus fenix7 et fenix843mm), **tous les tests non liés à l'affichage passent** (127 sur 127 par montre : `Tests.mc`, `TestsFormat.mc`, `TestsChain.mc`, auto-tests B01 à B04 du banc). Les 8 `testDefect*` passent, et les 2 `testKnownDefect*` verrouillent toujours D1 et D4. Les tests Python passent (106 sur 106).
- **Zones sensibles : intactes.** Vario, `FlyInstrumentView.mc`, `bin/` et `developer_key` sont intacts ; `manifest.xml` n'a reçu que les 4 epix.
- **Compilation : 62 sur 62**, en release comme en test.
- **Réserves (affichage)** : le banc trouve des défauts de mise en page sur toutes les familles sauf G1 (fr55) et G3 (fenix5). Ce sont des défauts **connus et attendus** (aucun correctif d'affichage n'a été fait), mais certains touchent l'usage normal :
  - **pages Pace et Position sur les ronds AMOLED de 360 et 454 px** (fr265s, et fr965 avec tout son groupe G9 : fenix 8 47 mm, fenix 9 47 mm, epix 2 pro 51 mm…) ;
  - page Time et boussole sur les grands AMOLED ;
  - « W » de la boussole sur fenix 7X ;
  - sous-fenêtre des Instinct.

## Contrôles statiques

| Point | Commande | Résultat |
|---|---|---|
| `FlyInstrumentView.mc` | `git diff a078d7d HEAD -- source/FlyInstrumentView.mc` | **vide** |
| `WatchDisplay.vario()` (l. 193) et `beep()` (l. 167) | `git diff a078d7d HEAD -- source/WatchDisplay.mc` | 4 hunks, tous dans `compass()` (rotation null-safe, `formatLatLon`) et `map()` (mode de dessin, projection, barre d'échelle). **Aucun dans `vario()` ni `beep()`** |
| `WatchData` : `oldAlt` (l. 12), `endMeasure()` (l. 26), `getVario()` (l. 46), `getAltitude()` (l. 213) | `git diff a078d7d HEAD -- source/WatchData.mc` | **aucun hunk dans ces fonctions**. Changements : FC null non stockée (`updateActivityInfo`, `updateSensorInfo`, la clé `altitude` n'est pas touchée : D1 reste tel quel), `getAccuracy()` / `hasUsableFix()`, fenêtre VS (`hikeVsWindowMs`) |
| `manifest.xml` | `git log --name-status a078d7d..HEAD -- manifest.xml` | un seul commit, `0f31666`, +4 lignes (`epix2`, `epix2pro42mm`, `epix2pro47mm`, `epix2pro51mm`) ; 62 produits |
| `bin/`, `developer_key`, `.DS_Store` | `git log --name-status a078d7d..HEAD -- bin developer_key .DS_Store ':(glob)**/.DS_Store'` et `git log --name-only` | **aucun commit** ne touche ces chemins |
| Tests non affaiblis | `git diff -U0 a078d7d HEAD -- source/Tests.mc` (+2228 / −44) | Lignes retirées : commentaires, renommage `SpeedTestHelper` → `WatchDataTestHelper`, constructeurs de faux objets réécrits. **Une seule modification d'assertions** : `testFormatVerticalSpeed`, où 1e6, −1e6 et 1e10 attendent `--` au lieu de `+1000000`… C'est la conséquence voulue du plafond ±3000 m/h (`7328587` puis `108ab40`, décision du 07/10 (plafond VS)), pas un affaiblissement |
| Tests désactivés | recherche des tests `test*` sans `(:test)` | aucun ; 166 fonctions `test*` = 166 tests exécutés |
| Tests écrits avant le code | ordre des commits | respecté : chaque `fix`/`feat` est précédé de son commit `test` (ex. `7328587` → `108ab40`, `755cb2b` → `6b7aa77`/`fcc3397`, `421100c` → `370c2bf`, `dbffd38` → `54e025b`, `b8be0b0` → `b708a60`). Seul l'écran Paused (`950c5f1`) s'appuie sur des stubs épinglés plus tôt (`8ed3dc0`) |
| `git status` après chaque compilation | `git status --short` | **vide** à chaque contrôle (rien n'est écrit dans `bin/`) |

**Ce qu'aucun test ne couvre** (inchangé depuis le plan, § 6) :
- le branchement réel de `onSensor()` / `onStop()` ;
- les délégués (minuteur de 30 s du menu, `System.exit()`, BACK de l'écran Paused) ;
- le dessin des traits de la carte et de la barre (seul le libellé est vérifié) ;
- la migration réelle vers `Application.Storage` sur une montre qui a déjà des préférences ;
- les couleurs réellement visibles (1 bit, AMOLED), les vibrations ;
- la sous-fenêtre des instinct3amoled : `WatchUi.getSubscreen()` y renvoie `null` (« available: false »), donc le banc ne la contrôle pas.

## Compilation
Commandes, une par montre : `monkeyc -f monkey.jungle -o /tmp/glidator-build/Glidator-<id>-release.prg -d <id> -y developer_key` (release) et `... -o /tmp/glidator-build/Glidator-<id>.prg ... -t` (test).
- **Release : 62 sur 62 `BUILD SUCCESSFUL`.**
- **Test (`-t`) : 62 sur 62 `BUILD SUCCESSFUL`.**
- Aucune erreur affichée. `git status` est resté vide.

## Tests
- **Suite : 166 tests par montre** (88 `Tests.mc` + 7 `TestsFormat.mc` + 32 `TestsChain.mc` + 39 `TestsLayout.mc`).
- Commande : `monkeydo /tmp/glidator-build/Glidator-<id>.prg <id> -t`. Elle rend toujours le code 1 : les résultats viennent du bloc `RESULTS`.
- **Montres testées** : 17, soit les 15 représentatives du § 2.2 du plan, plus fenix7 et fenix843mm.
- **Montres non testées** : 45, compilées seulement, par manque de budget de tours de l'agent. Chaque suite prend environ 2 min et la sortie doit être relue montre par montre : le script de boucle `/tmp/glidator-build/run-all.sh` et la redirection vers `/tmp` ont été refusés.
- fr965 : le premier lancement est resté sans aucune sortie pendant plus de 10 min ; le second a tourné normalement.
- `python3 tools/test_analyze_activity.py` : `Ran 106 tests` → `OK`.

### Tableau montre → compilation, tests, défauts d'affichage

| Montre | Groupe (écran) | Release | Test `-t` | Résultat `monkeydo -t` | Défauts d'affichage (tests `testLayout_*` en échec) |
|---|---|---|---|---|---|
| fenix6pro | G4 rond 260, MIP | OK | OK | 166 : 164 PASS, 2 FAIL | HikePosition/HikePace **Extreme** : `99:59:59` hors du cercle (= liste attendue du plan) |
| fenix7 | G4 rond 260, MIP | OK | OK | 166 : 164 PASS, 2 FAIL | idem fenix6pro (= liste attendue) |
| fenix5 | G3 rond 240, MIP, CIQ 3.1.6 | OK | OK | **166 : 166 PASS** | aucun (= liste attendue) |
| fr55 | G1 rond 208, MIP 4 bits | OK | OK | **166 : 166 PASS** | aucun |
| fr255s | G2 rond 218, MIP | OK | OK | 166 : 164 PASS, 2 FAIL | Extreme : `99:59:59` hors du cercle (Position, Pace) |
| fenix7x | G5 rond 280, MIP | OK | OK | 166 : 160 PASS, 6 FAIL | Extreme : `99:59:59` (Position, Pace) ; **Compass Normal/Extreme/Paused/Recording : « W » hors du cercle** (cap 0.785) |
| fr265s | G6 rond 360, AMOLED | OK | OK | 166 : 147 PASS, 19 FAIL | **Position Normal/Paused/Recording : chrono `32:45` hors du cercle ; Pace Normal/Paused/Recording : `+940` × `26:48` se chevauchent (13 px)** ; Extreme : `20000` × `999.9`, `20000` et `99:59:59` hors du cercle, `-3000` × `60:00` ; Map Empty : `Waiting for` × `GPS` ; Time ×5 : heure × batterie ; Compass ×5 : N/S/E/W hors du cercle, latitude × longitude, `Waiting for` × `GPS` |
| epix2pro42mm | G7 rond 390, AMOLED | OK | OK | 166 : 154 PASS, 12 FAIL | Extreme : `99:59:59` (Position, Pace) ; Time ×5 : heure × batterie ; Compass ×5 : N/S/E/W hors du cercle |
| epix2 | G8 rond 416, AMOLED | OK | OK | 166 : 153 PASS, 13 FAIL | même liste que fenix843mm |
| fenix843mm | G8 rond 416, AMOLED | OK | OK | 166 : 153 PASS, 13 FAIL | **= liste attendue du plan** : Extreme Position (`20000` × `999.9`, `99:59:59`), Extreme Pace (`99:59:59`), Map Empty, Time ×5, Compass ×5 |
| fr965 | G9 rond 454, AMOLED | OK | OK | 166 : 145 PASS, 21 FAIL | **Position ×5 et Pace ×5, y compris Empty et Normal** : `TIMER` × chrono (`--:--` ou `32:45`, 1 px), chrono `32:45` hors du cercle, **Pace Normal : `+940` × `26:48` (6 px)** ; Map Empty ; Time ×5 ; Compass ×5 |
| fenix9pro51mm | G10 rond 466, AMOLED | OK | OK | 166 : 153 PASS, 13 FAIL | même liste que fenix843mm |
| instinct2 | G11 semi-octogone 176, 1 bit, sous-fenêtre | OK | OK | 166 : 143 PASS, 23 FAIL | **= liste attendue du plan** : Position ×5 et Pace ×5 (chevauchements libellé × valeur, `TIMER` × chrono, sous-fenêtre *disk*), Fly ×4 (`" km/h"` dans la sous-fenêtre, zone sensible), Compass ×4 (`E` dans la sous-fenêtre), Paused ×5 (*corner*) |
| instincte40mm | G12 semi-octogone 166, 1 bit, sous-fenêtre | OK | OK | 166 : 156 PASS, 10 FAIL | Position ×5 : `ALTITUDE` dans la sous-fenêtre (*disk*) ; Fly Extreme : `" km/h"` dans la sous-fenêtre ; Compass Normal/Extreme/Paused/Recording : `E` dans la sous-fenêtre |
| instinct2s | G13 semi-octogone 163×156, 1 bit, sous-fenêtre | OK | OK | 166 : 156 PASS, 10 FAIL | mêmes 10 noms qu'instincte40mm (ex. `ALTITUDE`(52,18,110,31) dans (108,0,162,54)) |
| instinct3amoled45mm | G14 rond 390, AMOLED | OK | OK | 166 : 156 PASS, 10 FAIL | Time ×5 ; Compass ×5. Sous-fenêtre non contrôlée (`getSubscreen` null) |
| instinct3amoled50mm | G15 rond 416, AMOLED | OK | OK | 166 : 156 PASS, 10 FAIL | Time ×5 ; Compass ×5. Sous-fenêtre non contrôlée (`getSubscreen` null) |
| 45 autres montres\* | G2 à G11 | OK | OK | non lancé (budget de tours) | — (attendu : comme la représentative du groupe, à polices près) |

\* epix2pro47mm, epix2pro51mm, fenix5plus, fenix5x, fenix5xplus, fenix6, fenix6s, fenix6spro, fenix6xpro, fenix7pro, fenix7pronowifi, fenix7s, fenix7spro, fenix7xpro, fenix7xpronowifi, fenix847mm, fenix8pro47mm, fenix8solar47mm, fenix8solar51mm, fenix943mm, fenix947mm, fenix9pro43mm, fenix9pro47mm, fenix9prosolar47mm, fenix9prosolar51mm, fr165, fr165m, fr170, fr170m, fr245, fr255, fr255m, fr255sm, fr265, fr57042mm, fr57047mm, fr70, fr745, fr945, fr945lte, fr955, fr970, instinct2x, instinct3solar45mm, instincte45mm.

Sur les 17 montres testées, **les seuls échecs sont des `LayoutBenchTests.testLayout_*`**. Aucun ERROR, aucun manque de mémoire, y compris sur fenix5, fr55, instinct2, instinct2s et instincte40mm (96 à 128 Ko). Les 4 listes de référence du plan (fenix6pro, instinct2, fenix5, fenix843mm) sont retrouvées **nom pour nom**.

## Analyse par famille d'écran
- **MIP 208 à 260 (G1 à G4 : fr55, fr255s, fenix5, fenix6pro, fenix7)** : rien en usage normal. Le seul défaut est le chrono `99:59:59` (au-delà de 100 h d'activité) qui sort du cercle en bas des pages Position et Pace sur 218 et 260 px. Il est sans conséquence pratique. C'est la famille de référence (cible principale : Fenix 5 à 7).
- **MIP 280 (G5 : fenix6xpro, fenix7x…)** : en plus du chrono extrême, le **« W » de la boussole** (page Position du mode Vol, `FONT_LARGE` à 18 px du bord) sort du cercle dès que le cadran tourne (cap 45°). Défaut léger, mais sur des Fenix.
- **AMOLED 360 (G6 : fr265s) et 454 (G9 : fr965, et par extension fenix847mm, fenix8pro47mm, fenix947mm, fenix9pro47mm, fr57047mm, fr970, epix2pro51mm)** : **les plus touchées**. En usage normal, VERT. SPD. et PACE se chevauchent sur la page Pace (13 px sur 360, 6 px sur 454), et le chrono `32:45` dépasse le cercle en bas des pages Position et Pace. Sur 454, « TIMER » touche aussi le chrono, même vide (`--:--`). Les polices numériques de ces deux tailles sont proportionnellement plus grosses que la grille `hikeGrid`. Bizarrement, 390, 416 et 466 px passent en usage normal : le rapport entre police et écran ne suit pas la taille. **Les 7 autres montres de G9 n'ont pas été lancées** : leurs polices peuvent différer de celles du fr965.
- **AMOLED 390 à 466 (G7 à G10)** : trois défauts récurrents :
  - page **Time** : batterie placée à `h/2 + 50` px fixes, sous une heure en `FONT_NUMBER_HOT` plus haute que 100 px ;
  - **boussole** : N/S/E/W à 18 px fixes du bord, hors du cercle ; latitude et longitude à `h/2 ± 15` px qui se chevauchent sur 416 et plus ;
  - **« Waiting for » / « GPS »** de la carte qui se chevauchent sur 416 et plus.
  
  En Extreme, `20000` × `999.9` sur 416 et plus. Ces trois défauts avaient été prévus au § 2.4 du plan.
- **Instinct MIP 1 bit (G11 à G13)** : la **sous-fenêtre** ronde en haut à droite est touchée par `ALTITUDE` (Position), `E` (boussole) et `" km/h"` (vol, zone sensible : on ne corrige pas). Sur instinct2 (176 px) s'y ajoutent des chevauchements libellé × valeur sur Position et Pace, et « Paused » qui touche les coins du carré de la sous-fenêtre. instincte40mm et instinct2s, malgré un écran plus petit, s'en tirent mieux (10 échecs contre 23) : leurs polices sont plus petites.
- **Instinct 3 AMOLED (G14/G15)** : mêmes défauts que les AMOLED de même taille (Time, boussole), mais ni Map Empty ni Extreme (polices plus petites). Le simulateur ne renvoie pas leur sous-fenêtre (`getSubscreen` null) : **à vérifier à l'œil** (étape 8).

## Montres types à regarder à l'œil (8)
1. **fenix6pro** : référence de la mise en page (G4), protocole complet.
2. **fenix5** : CIQ 3.1.6, sport « generic », mémoire 128 Ko.
3. **fenix7x** : G5, « W » de la boussole.
4. **fenix843mm** : G8, Fenix AMOLED (Time, boussole, carte vide).
5. **fr965** (ou **fenix847mm**) : G9, pages Pace et Position en usage normal ; fenix847mm pour savoir si une Fenix de ce groupe a le même défaut.
6. **fr265s** : G6, le pire cas (Pace et chrono en usage normal).
7. **instinct2** : G11, sous-fenêtre et écran 1 bit.
8. **instinct3amoled45mm** : G14, sous-fenêtre non contrôlée par le banc.

À défaut de temps, fr55 (G1, sans baromètre ni boussole) peut remplacer instinct3amoled45mm : ses tests passent tous, seule l'étape 8 le concerne.

## Protocole manuel pour l'utilisateur
Préparation : `monkeyc -f monkey.jungle -o /tmp/glidator-build/Glidator-<id>-release.prg -d <id> -y developer_key`, puis `monkeydo /tmp/glidator-build/Glidator-<id>-release.prg <id>`. Charger `garmin_data/activity_24346302742.gpx` dans *Simulation > Activity Data* (ou *Data Playback*). La distance du simulateur est calculée sur le GPX : environ +2,7 % par rapport au TCX. Fenêtre VS à 1 min (défaut), sauf à l'étape 7.

**1. Pace (fenix6pro, puis fr265s et fr965)**
- [ ] SELECT démarre l'enregistrement. Page Pace au passage de **10:51:28** : VERT. SPD. entre **+900 et +1000** (code : `+950`), PACE entre **25:00 et 27:00** (code : `26:00` sur le TCX, un peu plus rapide sur le GPX), Heart Rate `139` si la FC du GPX est jouée.
- [ ] La vitesse instantanée vaut 0 sur ce point du TCX : PACE ne doit **pas** passer à `--:--` ni afficher `5:60`.
- [ ] Spirale à **13:01:47** : VERT. SPD. lit `--` (−14 420 m/h, au-delà de ±3000) ; PACE environ `1:52`.
- [ ] fr265s et fr965 : noter si VERT. SPD. et PACE (ex. `+940` et `26:48`) se touchent ou se chevauchent, si « TIMER » touche le chrono, et si le chrono du bas est coupé par le cercle. Banc : chevauchement de 13 px sur fr265s et de 6 px sur fr965, chrono hors du cercle sur les deux.

**2. Carte et cause 180/180 (fenix6pro)**
- [ ] Avant tout fix (*Simulation > GPS Quality* : Not available), page carte : « Waiting for » / « GPS ». Aucun trait vers un coin de l'écran.
- [ ] Lancer la lecture du GPX : la trace apparaît dès le fix (accuracy ≥ Usable), avec le marqueur orienté. **Aucun point (180, 180) ni (0, 0)** : la trace reste centrée sur Salvan et n'est pas écrasée dans un coin (avant correction, la bbox incluait le point de l'antimeridien).
- [ ] En cours de trace, repasser GPS Quality à « Not available » : la **trace reste affichée sans marqueur** (et non « Waiting for GPS ») ; au retour du fix, le marqueur revient et la trace continue sans saut.
- [ ] fenix843mm : carte sans trace ni fix, « Waiting for » et « GPS » se chevauchent-ils (banc : oui) ?

**3. Barre d'échelle (fenix6pro, puis fenix843mm et instinct2)**
- [ ] En bas de la carte, une barre noire avec deux taquets et un libellé `50 m`, `100 m`, `200 m`, `500 m`, `1 km`, `2 km` ou `5 km`, jamais plus large qu'un tiers de l'écran.
- [ ] Le libellé grandit avec la trace : environ `50 m` à `200 m` dans les premières minutes ; **`500 m` pour une trace d'environ 2 km de long** (fenix6pro : barre d'environ 46 px, 10,8 m/px) ; puis `1 km` ou plus sur la montée entière.
- [ ] Pas de barre quand la trace fait environ 50 m (premiers points) ; pas de barre ni de texte qui touche le bord du cercle.

**4. Menu de pause et écran Paused (fenix6pro, instinct2, instinct3amoled45mm)**
- [ ] SELECT pendant l'enregistrement : le chrono se fige, le menu « Paused » (Resume / Pause / Save / Ignore) s'ouvre, avec **2 vibrations courtes** (2 × 150 ms).
- [ ] BACK dans le menu → **reprise** (comportement voulu, décision du 07/10), 1 vibration longue (600 ms).
- [ ] Menu ouvert sans rien toucher : **reprise automatique 30 s après l'ouverture** (pas de remise à zéro si l'on navigue dans le menu, décision du 07/10).
- [ ] Choisir Pause → écran « Paused », chrono figé (ex. `32:45`), « START: resume ». BACK ne fait rien. Au bout de **60 s**, toujours en pause (pas de reprise automatique sur cet écran). SELECT → retour à la page, vibration longue, le chrono repart.
- [ ] instinct2 et instinct3amoled45mm : « Paused », le chrono et « START: resume » ne touchent ni la sous-fenêtre ronde (en haut à droite) ni les coins coupés.
- [ ] Save → l'app quitte et l'activité apparaît dans l'historique du simulateur ; Ignore → aucune activité.

**5. Cardio coupé en pause (fenix6pro)**
- [ ] *Simulation > Sensors* : FC 120 bpm. Page Pace : `120`.
- [ ] Pause (menu → Pause) : Heart Rate passe à `--` en moins de 3 s (capteurs coupés, `setEnabledSensors([])`), la carte continue de s'allonger si le GPX joue (GPS actif).
- [ ] Reprise : `120` revient en moins de 3 s.
- [ ] FC simulée à 20 puis 260 bpm : `--` (bornes 25 à 250) ; FC à 25 et 250 : affichées telles quelles.

**6. Sport « generic » sur fenix5**
- [ ] fenix5 : SELECT démarre l'enregistrement **sans plantage** (pas de « Symbol Not Found SPORT_FLYING »). Save crée une activité.
- [ ] Dans le FIT exporté (*File > Save FIT* ou dossier des activités du simulateur), le sport est **generic** (code 0), alors que sur fenix6pro il est **flying** (code 20).
- [ ] Même contrôle sur fenix5x si possible (décision du 06/10 : fenix5/5x restent en générique).

**7. Fenêtre VS 1/3/5 min (fenix6pro)**
- [ ] MENU (UP maintenu) → Preferences → « VS window », sous-libellé `1 min`. Chaque appui : `1 min` → `3 min` → `5 min` → `1 min`, sans sous-menu.
- [ ] La page Pace **n'affiche aucune indication de fenêtre** (décision du 07/10).
- [ ] Sur la montée raide (vers 10:51), passer de 1 à 5 min : VERT. SPD. **ne repasse pas par `--`** (l'historique n'est pas vidé) et devient plus lisse (sur 5 min, la valeur s'écarte moins d'un relevé à l'autre).
- [ ] Juste après le départ (moins de 20 s d'échantillons), `--` quelle que soit la fenêtre.
- [ ] Quitter et relancer l'app : le choix est conservé (`Application.Storage`).

**8. Contrôles par montre**
- [ ] **fenix7x** : page Position du mode Vol avec un cap d'environ 45° : le « W » est-il coupé par le cercle ?
- [ ] **fenix843mm** : page Time (heure et batterie superposées ?) ; boussole (N/S/E/W coupés, latitude et longitude superposées ?).
- [ ] **instinct2** : pages Position et Pace lisibles en 1 bit ; ALTITUDE, DISTANCE, PACE et « km/h » (vol) par rapport à la sous-fenêtre ; fond du vario visible ou non en 1 bit.
- [ ] **instinct3amoled45mm** : aucun texte dans la sous-fenêtre ronde (98 × 98 en haut à droite), sur les 7 pages et l'écran Paused.
- [ ] **fr55** (si le temps le permet) : ALTITUDE apparaît après le fix GPS (pas de baromètre) ; la page Position du mode Vol ne plante pas sans GPS.

Sur la montre (si disponible) : refaire les étapes 1, 4 et 5 pendant une vraie montée, en relevant 3 valeurs de VERT. SPD. avec chaque fenêtre et le D+ sur 5 min.

## Problèmes trouvés

### Majeur (usage normal, sur une montre du manifest)
1. **fr265s (360 px) et fr965 (454 px, groupe G9 avec 4 Fenix) : pages Pace et Position.**
   - VERT. SPD. × PACE se chevauchent : `+940`(20..182) × `26:48`(169..349), 13 px, sur fr265s ; `+940`(30..225) × `26:48`(219..434), 6 px, sur fr965.
   - Le chrono `32:45` sort du cercle.
   - Sur fr965, « TIMER » touche le chrono, même vide.
   
   Origine : `WatchDisplay.hikeGrid()`, qui garde des positions et des polices fixes pour toutes les tailles. Correctif à proposer au dev : choisir la police des valeurs selon la largeur de la demi-colonne et la hauteur restante, comme PausedView le fait pour le chrono (`FONT_NUMBER_MEDIUM` si le texte tient, sinon `FONT_NUMBER_MILD`).
2. **AMOLED 360 à 466 px (G6 à G10, G14, G15 : 25 montres, dont les fenix 8/9 AMOLED et les epix) : page Time, la batterie chevauche l'heure.** `WatchDisplay.time_and_battery()` place la batterie à `h/2 + 50` px fixes. Correctif : placer la batterie à `h/2 + hauteur(FONT_NUMBER_HOT)/2 + marge`.
3. **AMOLED 360 et plus : boussole (page Position du mode Vol)** : N/S/E/W hors du cercle ; sur 360 et 416 px et plus, latitude et longitude se chevauchent, ainsi que « Waiting for » / « GPS ». Cause dans `WatchDisplay.compass()` : 18 px fixes du bord et `h/2 ± 15` px. Correctif : des marges proportionnelles à `w` et à `getFontHeight(FONT_SMALL)`.
4. **Instinct 1 bit (G11 à G13)** : `ALTITUDE` (Position) et `E` (boussole) dans la sous-fenêtre ; sur instinct2, plus des chevauchements libellé × valeur sur Position et Pace. `" km/h"` de la page de vol aussi, mais `FlyInstrumentView` est une zone sensible : on n'y touche pas (défaut connu).

### Mineur
5. **fenix7x et G5 (Fenix 6X/7X/8 51 mm…)** : « W » de la boussole hors du cercle quand le cadran tourne (`WatchDisplay.compass()`).
6. **Carte vide sur 360, 416 px et plus** : « Waiting for » × « GPS » (`WatchDisplay.map()`, `h/2 ± 15` px).
7. **États extrêmes seulement** : chrono `99:59:59` (au-delà de 100 h d'activité) hors du cercle sur presque tous les ronds ; `20000` × `999.9` sur 360 et 416 px et plus.

### À noter (pas un défaut de l'app)
8. **Simulateur** : le premier `monkeydo -t` sur fr965 est resté plus de 10 min sans aucune sortie ; le second a tourné normalement. Une suite sans sortie n'est donc pas forcément un échec : la relancer.
9. **instinct3amoled45mm/50mm : `getSubscreen()` renvoie null au simulateur**, alors que le skin dessine une sous-fenêtre : le banc ne peut pas la contrôler (étape 8 du protocole).

Aucun défaut fonctionnel : les 127 tests hors affichage passent sur les 17 montres testées.

## Commandes refusées
- `zsh /tmp/glidator-build/run-all.sh fenix6pro fenix5` (script de boucle sur les montres) : « requires approval ». Contourné par un lancement montre par montre, comme le prévoit la consigne.
- `monkeydo ... -t > /tmp/glidator-build/fenix6pro-run.log 2>&1` : redirection hors des dossiers de travail refusée. Les sorties ont été lues dans les fichiers des tâches en arrière-plan.
- `git diff --stat origin/hikeandfly HEAD -- source/FlyInstrumentView.mc manifest.xml bin developer_key` : refusé. Le contrôle a été fait contre `a078d7d` (la base demandée).
