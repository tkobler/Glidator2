# Plan de test approfondi : Glidator2 (marche et vol)

*Testeur Connect IQ, 06/10/2026. Branche `claude/corrections-marche`, HEAD `d07ba5d`. Ce plan a été rédigé **avant** tout nouveau test. Aucun test n'a été écrit ni lancé pour le produire. Les valeurs attendues viennent de la lecture du code actuel (`source/`), de `garmin_data/activity_24346302742.tcx` (via `python3 tools/analyze_activity.py ... --csv /dev/stdout`), puis de calculs refaits à la main.*

Le plan sert de base à trois tâches qui doivent pouvoir s'exécuter telles quelles :
- **(a)** tests fonctionnels de l'axe 1, en Monkey C (`(:test)`, `Toybox.Test`) : 30 tests, § 3.1 (écrits le 06/10, `source/TestsChain.mc`) ;
- **(b)** banc d'affichage de l'axe 2, avec un faux Dc : 39 tests, § 3.2 ;
- **(c)** exécution finale sur les 62 montres : procédure et contrôles des zones sensibles, § 4.

---

## 0. Périmètre et sources

| Élément | Valeur |
|---|---|
| Code lu | `source/*.mc` à `d07ba5d` : WatchData, HikeHistory, Utils, BreadcrumbTrail, WatchDisplay, les 7 vues (HikePosition, HikePace, HikeMap, Time, FlyInstrument, Position, **Paused**), FlyInstrumentApp (règles de session, pause, capteurs), FlyInstrumentDelegate (menu Paused) |
| Tests existants | `source/Tests.mc` : 67 fonctions `test*` à `d07ba5d`, **76** depuis la préférence de fenêtre VS (06/10, +9) |
| Données réelles | `garmin_data/activity_24346302742.tcx` : 2 tours, 4311 points. Tour 1 (montée) : 10:18:43 → 12:20:25 UTC, 2211 points, D+ 908 m. Tour 2 (vol) : 12:20:25 → 13:14:35, 2100 points |
| Profils des montres | `~/Library/Application Support/Garmin/ConnectIQ/Devices/<id>/compiler.json` (résolution, `deviceFamily`, `displayType`, `bitsPerPixel`) et `simulator.json` (`isTouch`, emplacement de la sous-fenêtre) |
| SDK | `monkeyc`, `monkeydo` et `connectiq` présents dans `/Users/sam/.local/bin/` (non utilisés pour ce plan) |

### Nouveautés du round à couvrir
- L'écran **PausedView** (`source/PausedView.mc`) affiche « Paused », le chrono figé et « START: resume ». SELECT reprend l'activité ; BACK ne fait rien.
- Le **menu Paused** (Menu2 : Resume / Pause / Save / Ignore) reprend l'activité tout seul au bout de 30 s, et BACK y vaut Resume.
- **Capteurs coupés en pause** : `Sensor.setEnabledSensors([])` (FC et température), le GPS reste actif, et le tick `onSensor()` à 1 Hz continue.
- Des **vibrations distinctes** signalent la pause (2 × 150 ms) et la reprise (600 ms).

---

## 1. Axe 1 : fonctionnel (mesures cohérentes, capteurs reçus et traités)

### 1.1 Chaîne de traitement (lue dans le code)

```
onSensor() 1 Hz (FlyInstrumentApp.mc:445)
  └─ mainView.updateData() (FlyInstrumentView.mc:109)
       startMeasure → updateInfo(Position.getInfo())
                    → updateActivityInfo(Activity.getActivityInfo())
                    → updateSensorInfo(Sensor.getInfo())
       endMeasure()   ← vario de vol (zone sensible)
  ├─ si shouldRecordHikeSample(session, recording) : data.recordHikeSample()  → HikeHistory (1 échantillon / 5 s, fenêtre 60 s)
  └─ feedBreadcrumbTrail(trail, data)  → seulement si hasUsableFix() (accuracy ≥ QUALITY_USABLE et position valide)
Vues (onUpdate(dc)) : lisent app.mainView.data et app.breadcrumbTrail, puis formatent :
  ALTITUDE = Math.round(getAltitude())          ELEV. GAIN = formatHikeAscent(totalAscent)   (si session)
  DISTANCE = distance/1000 "%.1f"  (si session) TIMER = formatDuration(timerTime)        (si session)
  Heart Rate = getHeartRate().toString()         VERT. SPD. = formatVerticalSpeed(HikeHistory 60 s)
  PACE = formatPace(HikeHistory 60 s, distance)  Vol : vitesse = getSpeed()*3.6 "%.0f", vario = alt - oldAlt "%.1f"
```

Priorités des sources (WatchData) :
- altitude : Activity → Sensor → GPS ;
- vitesse : Sensor → GPS → Activity ;
- FC : Activity → Sensor ;
- D+, distance et chrono : Activity seulement ;
- lat/lon et cap : GPS seulement.

### 1.2 Grandeurs et cas à couvrir

| Grandeur | Cas normaux | Valeurs absurdes ou absentes | Tests (§ 3.1) |
|---|---|---|---|
| Altitude | priorité des sources, extrait réel | null (une source, toutes), négative, 8849 m, 1e10, NaN | F01–F05 |
| Vitesse verticale (marche) | montée réelle +944,6 m/h ; spirale réelle −14 419,8 m/h ; tick 1 Hz réel | saut d'altitude de +1000 m, NaN | F06–F10 |
| Vitesse / pace / distance | pace sur la distance quand la vitesse instantanée vaut 0 ; km/h en vol | distance négative, vitesse négative, 1000 m/s, null | F11–F15 |
| Cardio | priorité Activity → Sensor | null, 0, 255, −1 ; coupé en pause | F16, F17, F27 |
| Chrono | 32:45, h:mm:ss | 99:59:59, 100:00:00, négatif, null | F18, F19 |
| GPS / carte / boussole | trace Salvan, barre d'échelle, coordonnées | pas de fix, cap null, hémisphères S/W, secondes arrondies à 60 | F20–F25 |
| Pause | PausedView, capteurs coupés, GPS actif | pas de session | F26, F27 |
| Vario de vol (lecture seule) | séquence de ticks, seuils de couleur | altitude null sur un tick | F28, F29 |

### 1.3 Défauts relevés à la lecture

**Décisions de l'utilisateur (06/10)** :
- **Défauts connus, non corrigés** (aucun test rouge) : **D1**, **D2 côté FlyInstrumentView**, **D4**. FlyInstrumentView.mc et le vario restent intacts. D1 et D4 sont verrouillés par des tests qui passent (`testKnownDefectD1…`, `testKnownDefectD4…`) : s'ils échouent, le comportement a changé (pour D1, c'est la source du vario qui aurait changé). D2 côté vol n'a pas de test (l'affichage de 1e10 ou NaN n'est pas un comportement à figer).
- **À corriger par la tâche suivante** (tests rouges `testDefect*`) : D2 côté HikePositionView, D3, D5, D6, D7, D8, D9.
- **Bornes d'affichage décidées** : altitude valide de **−100 à 6000 m** (HikePositionView), FC valide de **25 à 250 bpm** (HikePaceView) ; hors bornes ou non finie → `--`. La borne porte sur la valeur brute : −100,1 et 6000,1 donnent `--`, −99,6 donne `-100`.
- **Garde du D+ de la page Position (décision du 07/10)** : ELEV. GAIN valide de **0 à 20 000 m** (bornes incluses), sinon (négatif, au-delà de 20 000 m, NaN, ±Inf, null) → `--`, par `formatHikeAscent()` (Utils.mc). La borne porte sur la valeur brute : −0,1 et 20 000,1 donnent `--` ; −0,0 donne `0`. Le D+ n'est affiché que par HikePositionView.

Valeurs « actuelles » ci-dessous : celles relevées à l'exécution des tests le 06/10 (fenix6pro et fenix5, identiques).

| Id | Statut (06/10) | Fichier:ligne | Défaut | Valeur actuelle (mesurée) | Valeur correcte | Test |
|---|---|---|---|---|---|---|
| D1 | **défaut connu, non corrigé** | `WatchData.mc:119-122` (lu par `getAltitude()` l. 215-218) | `updateActivityInfo` enregistre `"altitude" => null` dès que le champ existe. `getAltitude()` renvoie alors null et masque l'altitude Sensor/GPS | `getAltitude()` = null, ALTITUDE `--`, vol `starting ...`, aucun échantillon de marche | (non corrigé : le correctif changerait la source du vario) | `testKnownDefectD1NullActivityAltitudeHidesSensor` : **verrouille** le comportement actuel, PASS |
| D2 marche | **à corriger** | `HikePositionView.mc:45` | `Math.round(alt).toNumber()` sans garde ni bornes | −100,1 → `-100` ; 6000,1 → `6000` ; 8848,6 → `8849` ; 1e10 et +Inf → `2147483647` ; −Inf → `-2147483648` ; NaN → `0` | `--` si l'altitude n'est pas finie ou sort de [−100 ; 6000] m | `testDefectAltitudeOutOfBounds`, `testDefectAltitudeNonFinite` : FAIL |
| D2 vol | **défaut connu, non corrigé** | `FlyInstrumentView.mc:69` | même calcul sans garde | idem | (FlyInstrumentView intact) | aucun test (comportement absurde non figé) ; `-432` et `8849` en vol épinglés dans `testChainAltitudeNegativeAndHigh` |
| D3 | **à corriger** | `HikePositionView.mc:53` | distance négative affichée | `-0.0` pour −5 m, `-1.0` pour −1000 m | `--` | `testDefectNegativeDistance` : FAIL |
| D4 | **défaut connu, non corrigé** | `FlyInstrumentView.mc:71-75` | vitesse négative affichée | `-4` pour −1 m/s | (FlyInstrumentView intact) | `testKnownDefectD4NegativeFlightSpeedShown` : **verrouille** `-4`, PASS |
| D5 | **à corriger** | `HikePaceView.mc:40` | FC hors bornes affichée telle quelle | `24`, `251`, `0`, `255`, `-1`, `300` (capteur) | `--` hors de [25 ; 250] bpm | `testDefectHeartRateOutOfBounds` : FAIL |
| D6 | **à corriger** | `Utils.mc:6-24` | `formatDuration` d'une valeur négative | −65 000 → `-1:-5` ; −1000 → `00:-1` ; −1 → `00:00` ; −3 600 000 → `00:00` | `--:--` pour toute valeur < 0 | `testDefectNegativeDuration` : FAIL |
| D7 | **à corriger** | `WatchDisplay.mc:315-323` | hémisphères S/W : signe moins **et** lettre S/W | `-22°57'6.8"S` / `-43°12'37.8"W` | `22°57'6.8"S` / `43°12'37.8"W` | `testDefectCompassSouthWestSign` : FAIL |
| D8 | **à corriger** | `WatchDisplay.mc:316-318, 321-323` | secondes arrondies par `%.1f` sans report | `45°59'60.0"N` / `6°59'60.0"E` ; `46°29'60.0"N` | `46°00'0.0"N` / `7°00'0.0"E` ; `46°30'0.0"N` | `testDefectCompassSecondsRoundTo60` : FAIL |
| D9 | **à corriger** | `WatchDisplay.mc:238`, appelé depuis `PositionView.mc:48-56` | `heading = -heading` sans test de null | exception « Unhandled Exception » à `WatchDisplay.mc:238` | dessin sans rotation : `N S E W` puis `Waiting for` / `GPS` (ou les coordonnées) | `testDefectCompassNullHeading` : **ERROR** (isolé : chaque test tourne dans une instance neuve de l'app) |

---

## 2. Axe 2 : compatibilité (fonctions, puis affichage)

### 2.1 Liste des montres : décompte

- `manifest.xml` (lecture seule) contient **58** produits (lignes 6 à 63).
- La tâche suivante du round ajoute 4 epix : `epix2`, `epix2pro42mm`, `epix2pro47mm`, `epix2pro51mm`. Leurs profils sont présents dans `Devices/`.
- **Total : 58 + 4 = 62. Aucun écart avec le chiffre annoncé.**

### 2.2 Les 62 montres regroupées par écran

Sources : `compiler.json` (`deviceFamily`, `displayType`, `bitsPerPixel`) et `simulator.json` (`isTouch`, `subscreen`). La sous-fenêtre est donnée **en coordonnées de l'écran de l'app**, c'est-à-dire l'emplacement de la sous-fenêtre moins celui de l'écran dans le skin du simulateur.

| Groupe | Écran | Type | Bits | Sous-fenêtre (x, y, l × h) | Montres | Nb | Représentative |
|---|---|---|---|---|---|---|---|
| G1 | rond 208×208 | MIP | 4 | non | fr55 | 1 | **fr55** (polices larges, pas de baromètre ni de boussole) |
| G2 | rond 218×218 | MIP | 8 | non | fr255s, fr255sm | 2 | **fr255s** |
| G3 | rond 240×240 | MIP | 8 | non | fenix5, fenix5plus, fenix5x, fenix5xplus, fenix6s, fenix6spro, fenix7s\*, fenix7spro\*, fr245, fr745, fr945, fr945lte | 12 | **fenix5** (CIQ 3.1.6, la plus ancienne) ; fr245 en second |
| G4 | rond 260×260 | MIP | 8 | non | fenix6, **fenix6pro**, fenix7\*, fenix7pro\*, fenix7pronowifi\*, fenix8solar47mm\*, fenix9prosolar47mm\*, fr255, fr255m, fr955\* | 10 | **fenix6pro** (référence de la mise en page) |
| G5 | rond 280×280 | MIP | 8 | non | fenix6xpro, fenix7x\*, fenix7xpro\*, fenix7xpronowifi\*, fenix8solar51mm\*, fenix9prosolar51mm\* | 6 | **fenix7x** |
| G6 | rond 360×360 | AMOLED | 16 | non | fr265s\* | 1 | **fr265s** |
| G7 | rond 390×390 | AMOLED | 16 | non | fr165\*, fr165m\*, fr170\*, fr170m\*, fr57042mm\*, fr70\*, epix2pro42mm\* | 7 | **epix2pro42mm** (nouvel epix) |
| G8 | rond 416×416 | AMOLED | 16 | non | fenix843mm\*, fenix943mm\*, fenix9pro43mm\*, fr265\*, epix2\*, epix2pro47mm\* | 6 | **epix2** |
| G9 | rond 454×454 | AMOLED | 16 | non | fenix847mm\*, fenix8pro47mm\*, fenix947mm\*, fenix9pro47mm\*, fr57047mm\*, fr965\*, fr970\*, epix2pro51mm\* | 8 | **fr965** |
| G10 | rond 466×466 | AMOLED | 16 | non | fenix9pro51mm\* | 1 | **fenix9pro51mm** (le plus grand) |
| G11 | semi-octogone 176×176 | MIP | 1 | (113, 0, 62 × 62) | instinct2, instinct2x, instinct3solar45mm, instincte45mm | 4 | **instinct2** |
| G12 | semi-octogone 166×166 | MIP | 1 | (113, 0, 52 × 52) | instincte40mm | 1 | **instincte40mm** |
| G13 | semi-octogone 163×156 | MIP | 1 | (108, 0, 54 × 54) | instinct2s | 1 | **instinct2s** (le plus petit, non carré) |
| G14 | rond 390×390 | AMOLED | 16 | (253, 48, 98 × 98) déclarée dans le skin | instinct3amoled45mm | 1 | **instinct3amoled45mm** |
| G15 | rond 416×416 | AMOLED | 16 | (273, 55, 98 × 98) déclarée dans le skin | instinct3amoled50mm | 1 | **instinct3amoled50mm** |
| | | | | | **Total** | **62** | 15 représentatives |

\* = écran tactile (`isTouch: true`) : 36 montres sur 62. Aucune Instinct n'est tactile.

Remarques :
- Le skin du simulateur déclare une sous-fenêtre pour **instinct3amoled45mm/50mm**. Ces deux montres sont donc isolées en G14/G15 ; le banc saura si `WatchUi.getSubscreen()` la renvoie réellement.
- À résolution égale, les polices peuvent changer d'une montre à l'autre (ex. G3 : fenix5, fr245 et fenix7s). C'est pourquoi le banc automatique tourne sur **les 62 montres**. Les représentatives servent aux vérifications manuelles.
- Mémoire des watch-apps (`compiler.json`) : 96 Ko sur instinct2 et instinct2s, 128 Ko sur fenix5, fr55, fr245 et instincte40mm, ≥ 768 Ko sur les AMOLED. Avec les 30 tests de l'axe 1 (106 tests), le .prg de test **tient et tourne sur fenix5** (06/10). Il grossira encore avec les 39 tests du banc, ce qui crée un **risque de mémoire insuffisante sur G11 à G13 et G1/G3**. Parade sans toucher au projet : voir § 4.3.

### 2.3 Compatibilité des fonctions (par groupe)

| Id | Vérification | Montres | Attendu |
|---|---|---|---|
| C01 | Compilation release `monkeyc ... -d <id>` | 62 | `BUILD SUCCESSFUL`, aucune erreur (les avertissements sont notés) |
| C02 | Compilation de test (`-t`) | 62 | `BUILD SUCCESSFUL` |
| C03 | Suite complète `monkeydo -t` | 62 | tous les tests PASS sauf les 8 `testDefect*` (§ 3.1) tant que la tâche de correction n'est pas faite, plus les défauts d'affichage que le banc trouvera (§ 3.2) |
| C04 | `testRecordingSportCodesMatchApi`, `testSessionStateMachine` | G3 (fenix5, 5plus, 5x, 5xplus), CIQ < 3.2 | PASS : le sport FIT est choisi à l'exécution (`pickRecordingSport`), pas d'erreur « Symbol Not Found SPORT_FLYING » |
| C05 | `testSensorsFollowPauseAndResume` | 62 | PASS : `setEnabledSensors([])` existe partout (≥ CIQ 3.0) |
| C06 | Sans baromètre ni boussole (fr55) : altitude venant du GPS, cap absent | G1 | manuel M12 : ALTITUDE affichée après le fix GPS, page Position sans plantage (voir D9) |
| C07 | Écrans tactiles : un tap ne doit ni démarrer ni mettre en pause l'enregistrement ; noter le comportement du swipe | 36 montres \* (représentatives fr265s, fenix7x, epix2) | manuel M06 |
| C08 | Couleurs sur écran 1 bit : fond du vario (vert / gris / rouge), libellés `DK_GRAY` | G11 à G13 | manuel M07 : tous les textes lisibles ; on note si les bandes de couleur du vario disparaissent |
| C09 | Menu Paused (Menu2 système) : 4 entrées et titre « Paused » | 15 représentatives | manuel M10 |

### 2.4 Compatibilité de l'affichage : le banc (faux Dc)

#### Faisabilité sans modifier le code de l'app : **oui**, avec 4 limites contournables

Ce que montre le code :
- Toutes les vues dessinent avec le **Dc passé en paramètre** : `onLayout(dc)` crée `new WatchDisplay(dc)` et `onUpdate(dc)` refait `display.dc = dc`. `PausedView` dessine directement sur `dc`.
- `WatchDisplay` ne fait que des appels de méthodes sur `dc`. Un objet de test qui expose les mêmes méthodes suffit, puisque Monkey C résout les appels à l'exécution.
- Méthodes à fournir (relevé exhaustif des appels `dc.*` dans `source/`) : `getWidth`, `getHeight`, `setColor`, `clear`, `drawText`, `getTextDimensions`, `getTextWidthInPixels`, `getFontHeight`, `drawLine`, `drawCircle`, `fillCircle`, `fillPolygon`, `drawRectangle`, `fillRectangle`, `setPenWidth`, `setClip`, `clearClip` (17).
- Les vues de marche lisent `app.mainView.data` et `app.breadcrumbTrail`. Une fausse app de test (classe `(:test)` avec ces deux champs) suffit. `FlyInstrumentView.data` est un champ public qu'on peut remplacer.
- La session est la variable globale `$.session`. `hasActiveSession()` teste seulement qu'elle est non nulle, et `isRecording()` appelle `$.session.isRecording()`. Une fausse session `(:test)` donne donc les états « pause » et « enregistrement » sans `ActivityRecording`. L'icône d'enregistrement s'obtient avec `$.recordFlashStartMs = System.getTimer()`.

Limites et contournements :
1. **PositionView** appelle `Position.getInfo()` elle-même, sans injection possible. Le banc appelle donc directement `display.compass(heading, lat, lon)` sur un `WatchDisplay(fauxDc)`. La vue n'est appelée telle quelle qu'à titre indicatif (position du simulateur).
2. **TimeView** lit l'horloge et la batterie. Le banc appelle `display.time_and_battery(timeStr, battery)` avec des valeurs choisies.
3. **Menu2** (menu Paused, préférences) est dessiné par le système et ne passe par aucun Dc de l'app. Il n'entre pas dans le banc : vérification manuelle M10.
4. **Vérificateur de types** : les vues attendent un `Graphics.Dc`. Le code du banc doit être annoté `(:test, :typecheck(false))`, comme plusieurs tests existants.

Point d'attention : `WatchDisplay.vario()` appelle `beep()`, qui lit `$.preferences.getBeep()`. Le banc initialise `$.preferences = new Preferences()` s'il est null. Il le fait dans le code de test, sans toucher à l'app.

#### Mesure des textes avec les vraies polices
- Créer un **petit** BufferedBitmap (16 × 16 suffit, il ne sert qu'à mesurer) :
  `Graphics has :createBufferedBitmap ? Graphics.createBufferedBitmap({:width=>16,:height=>16}).get().getDc() : new Graphics.BufferedBitmap({:width=>16,:height=>16}).getDc()`.
  La seconde forme sert sur fenix5 (CIQ 3.1.6). Le faux Dc délègue `getTextDimensions`, `getTextWidthInPixels` et `getFontHeight` à ce Dc.
- La taille et la forme de l'écran viennent de `System.getDeviceSettings()` (`screenWidth`, `screenHeight`, `screenShape`). Le banc s'exécute sur la montre choisie par `monkeydo`.
- La sous-fenêtre vient de `WatchUi.getSubscreen()` si `WatchUi has :getSubscreen` et que le résultat n'est pas null. Sinon, utiliser le tableau du § 2.2 (G11 à G15).

#### Squelette (indicatif, pour la tâche b)

```monkeyc
(:test, :typecheck(false))
class BenchDc {
    var w, h, m;            // m : Dc du BufferedBitmap de mesure
    var texts = [];         // [texte, police, x, y, justification, largeur, hauteur]
    var fg, bg, cleared;
    function initialize(width, height, measureDc) { w = width; h = height; m = measureDc; }
    function getWidth() { return w; }
    function getHeight() { return h; }
    function getTextDimensions(t, f) { return m.getTextDimensions(t, f); }
    function getTextWidthInPixels(t, f) { return m.getTextWidthInPixels(t, f); }
    function getFontHeight(f) { return m.getFontHeight(f); }
    function drawText(x, y, f, t, j) { var d = m.getTextDimensions(t, f); texts.add([t, f, x, y, j, d[0], d[1]]); }
    function setColor(a, b) { fg = a; bg = b; }
    function clear() { cleared = bg; }
    // sans effet : drawLine, drawCircle, fillCircle, fillPolygon, drawRectangle, fillRectangle, setPenWidth, setClip, clearClip
}
```

Les fonctions d'aide (boîtes, contrôles, états) vont dans une **classe `(:test)` à méthodes statiques**. Le lanceur exécuterait comme un test toute fonction globale annotée `(:test)` (remarque déjà faite dans `Tests.mc`).

#### Règles de contrôle
- **Boîte d'un texte** : justification horizontale `j & 3` (0 = RIGHT : `x0 = x - l` ; 1 = CENTER : `x0 = x - l/2` ; 2 = LEFT : `x0 = x`). Avec `TEXT_JUSTIFY_VCENTER` (bit 4) : `y0 = y - h/2`, sinon `y0 = y`.
- **Boîte d'encre** : la boîte rétrécie verticalement de `marge = floor(k × h)` en haut et en bas, horizontalement de 1 px. On part de `k = 0,15`, car les polices numériques ont beaucoup d'interligne vide. **Calibrage** : sur fenix6pro, état « normal », HikePositionView et HikePaceView doivent donner 0 défaut, puisque la mise en page y a été réglée à l'œil. Si ce n'est pas le cas, ajuster `k` sur fenix6pro seulement, l'écrire en constante, puis le garder pour toutes les montres. Journaliser `getFontHeight`, `Graphics.getFontAscent` et `getFontDescent` de chaque police utilisée (une ligne par montre).
- **Chevauchement** : pour chaque paire de textes d'une même image, l'intersection des boîtes d'encre doit avoir une largeur **et** une hauteur strictement positives. Deux boîtes qui se touchent ne sont pas un défaut (cas valeur + unité, `xOffset += dim[0]`).
- **Hors écran** : sur écran rond, les 4 coins de chaque boîte d'encre doivent vérifier `(x - w/2)² + (y - h/2)² ≤ (w/2 + 1)²`. Sur écran semi-octogone ou rectangle, la boîte doit tenir dans `[0, w] × [0, h]`. Les coins coupés des semi-octogones sont vérifiés à la main (M08).
- **Sous-fenêtre** : aucune boîte d'encre ne doit couper la sous-fenêtre, car rien dans l'app n'est prévu pour elle.
- **Message d'échec** (un seul `Test.assertMessage` par test, qui liste tous les défauts) :
  `LAYOUT <W>x<H> <forme> <Vue>/<état>: OVERLAP "ELEV. GAIN"(x0,y0,x1,y1) x "DISTANCE"(...); OFFSCREEN "N"(...); SUBSCREEN "Paused"(...)`.

#### Les 5 états (données injectées)

| État | Session | Icône | Données |
|---|---|---|---|
| **vide** | `$.session = null` | non | `new WatchData()` sans donnée, trace vide, pas de fix. Vario null. TimeView `"00:00"`, batterie 0. Boussole (0.0, null, null) : **cap 0.0** (le cap null relève de D9, testé en F25) |
| **normal** | enregistrement (fausse session, `isRecording() = true`) | non | Tick réel 10:51:28 (§ 3.1, F10) : altitude 2149.4, distance 1692.49, FC 139, D+ 335.0 (synthétique), chrono 1 965 000 ms, vitesse 0.0, cap 0.785 rad, fix (46.12446558661759, 6.985453460365534, accuracy 4), HikeHistory = extrait réel M (§ 3.1, F06) → `+940` / `26:48` (banc écrit le 07/10 ; le plan prévoyait l'extrait T, `+950` / `26:00`, de même largeur), trace = 20 points Salvan (`MapTestHelper`) avec le fix sur le dernier point, vario +0.4. TimeView `"10:51"`, 76 %. Boussole : mêmes coordonnées |
| **extrême** | enregistrement | non | altitude 8849 en vol, **6000** sur la page Position de marche (borne haute décidée le 06/10 ; 8849 y donnera `--` une fois D2 corrigé), D+ **20 000** (`20000`, borne haute de la garde du 07/10), distance 999 900 m (`999.9`), chrono 359 999 000 ms (`99:59:59`), FC **250** (`250`, borne haute), vitesse verticale −2998 m/h (12 échantillons sur 55 s → `-3000`, borne du plafond marche, décision D3 du 07/10 ; la spirale réelle −14 420 m/h lit `--`), pace `60:00` (0.2778 m/s). Vol : 33.3 m/s (`120` km/h), vario −10.0. TimeView `"23:59"`, 100 %. Boussole cap 0.785, (−89.999972, −179.999972) → `89°59'59.9"S` / `179°59'59.9"W` (chaînes les plus longues depuis la correction de D7/D8 : plus de signe moins ni de `60.0"`). Paused : 360 000 000 ms (`100:00:00`) |
| **pause** | fausse session, `isRecording() = false` | non | données « normal » ; pour PausedView : chrono `32:45` |
| **enregistrement** | enregistrement | oui (`$.recordFlashStartMs = System.getTimer()`) | données « normal ». En vol, `record = true` élargit l'unité de l'altitude (×1,5) |

Avant et après chaque test, remettre à zéro : `$.session = null`, `$.recordFlashStartMs = null`, `$.sensorsOffForPause = false`. Un test qui échoue en cours de route ne doit pas laisser une fausse session aux tests suivants : la fausse session implémente donc aussi `start`, `stop`, `save`, `discard` et `addLap`, sans effet.

#### Risques prévus par la lecture du code (à confirmer par le banc, non affirmés)
- **PositionView et HikeMapView** : les deux lignes « Waiting for » / « GPS » et les coordonnées sont à `h/2 ± 15` px, une valeur fixe. Sur G6 à G10 et G14/G15, si `FONT_SMALL` mesure plus de 30 px de haut, on aura un **chevauchement**.
- **PositionView** : N/S/E/W en `FONT_LARGE` à 18 px fixes du bord. Sur G6 à G10, ils risquent de sortir du cercle.
- **TimeView** : la batterie est à `h/2 + 50` px fixes sous l'heure en `FONT_NUMBER_HOT`. Chevauchement probable sur les grands écrans.
- **FlyInstrumentView** vide : « starting ... » en `FONT_LARGE` sur 176 px ou moins (G11 à G13) risque de sortir de l'écran.
- **PausedView** : « Paused » (`FONT_MEDIUM`, y = 35 % de h) sur G11 à G13 frôle la sous-fenêtre (x ≥ 113, y ≤ 62).
- **hikeGrid** : le champ du haut sur G11 à G13 (libellé vers y ≈ 27, valeur vers y ≈ 48 sur 176 px) frôle la sous-fenêtre. `-14420` en `FONT_NUMBER_MILD` dans une demi-colonne risquait de déborder sur G1/G2/G11 à G13 ; depuis D3 (07/10) la valeur la plus large est `-3000`.

---

## 3. Liste des tests à écrire (noms et résultats attendus chiffrés)

### 3.1 Tests fonctionnels (tâche a) : 30 tests, écrits dans `source/TestsChain.mc` en `(:test, :chaintest)` (commit `675ebeb`, 06/10)

**Outils de test créés** (classes `(:test, :chaintest)` dans `TestsChain.mc`) :
- `FakeFullActivityInfo` : `altitude, currentSpeed, currentHeartRate, currentHeading, totalAscent, elapsedDistance, timerTime`. Tous les champs existent, même null : c'est ce qui reproduit D1. `FakeActivityNoAltitude` : Activity.Info sans champ `altitude`.
- `FakeGpsInfo` : `position` (`FakeLocation`), `accuracy, altitude, speed, heading`.
- `FakeSession(recording)` : `isRecording()` renvoie `recording` ; `start/stop/save/discard/addLap` changent `recording` sans autre effet.
- `ChainApp` / `ChainMainView` (la « FakeApp ») : `mainView.data` et `breadcrumbTrail`.
- `ChainDc` : faux Dc qui enregistre les textes de `drawText` (et leur police) et mesure **à taille fixe** (10 px par caractère × 20 px), sans BufferedBitmap. Il suffit à l'axe 1 (seuls les textes comptent) ; le banc de l'axe 2 garde son `BenchDc` à mesures réelles (§ 2.4).
- `ChainHelper.render(view)`, `position(data)`, `pace(data)`, `fly(data)`, `map(data, trail)`, `paused(app)`, `compass(h, lat, lon)` : renvoient les textes dessinés, joints par `|` (pour Position et Pace : les 4 valeurs `haut|gauche|droite|bas`).
- Textes de hikeGrid, dans l'ordre de dessin : sans cœur (Position) : `[topLabel, topValue, leftLabel, rightLabel, leftValue, rightValue, bottomLabel, bottomValue]` ; avec cœur (Pace) : `[topValue, leftLabel, rightLabel, leftValue, rightValue, bottomLabel, bottomValue]`.
- Pour les vues qui appellent `System.getTimer()` (VERT. SPD. et PACE) : `end = System.getTimer() + 500` ; chaque échantillon réel d'heure T_i est enregistré à `end - (T_fin - T_i)`. **Correction** : il faut *avancer* de 500 ms (et non reculer) pour que le premier échantillon, 59,5 s avant `end`, reste dans la fenêtre de 60 s quand `onUpdate` relit l'horloge quelques ms plus tard. La régression ne dépend pas d'une translation des temps.
- `testDefect*` : **échec attendu** ; ces tests vérifient la valeur **correcte** et échouent tant que le défaut existe. Ils listent toutes les valeurs fausses dans le journal (`ERROR (hh:mm): …`) puis renvoient `false`, ce qui donne **FAIL** (une assertion ratée sort en ERROR, sans son message).
- `testKnownDefect*` : défaut que l'utilisateur garde (D1, D4) ; le test **verrouille le comportement actuel** et passe.

#### Extraits réels (TCX), utilisés tels quels

**Extrait M (montée raide, tour 1)** : échantillons que HikeHistory accepte (un toutes les ≥ 5 s) de 10:50:30 à 10:51:28 UTC, colonnes `AltitudeMeters` et `DistanceMeters`. L'horodatage 10:51:28 est à la ligne 11859 du TCX. Ce point a FC 139 bpm et `ns3:Speed` 0.0 alors que le randonneur avance.

| T (UTC) | s rel. | Altitude (m) | Distance (m) |
|---|---|---|---|
| 10:50:30 | −58 | 2134.2 | 1656.43 |
| 10:50:36 | −52 | 2136.0 | 1660.53 |
| 10:50:41 | −47 | 2137.0 | 1663.43 |
| 10:50:47 | −41 | 2138.6 | 1667.27 |
| 10:50:53 | −35 | 2140.4 | 1671.53 |
| 10:50:59 | −29 | 2142.2 | 1673.65 |
| 10:51:05 | −23 | 2143.6 | 1677.24 |
| 10:51:10 | −18 | 2144.8 | 1679.69 |
| 10:51:15 | −13 | 2146.0 | 1683.31 |
| 10:51:20 | −8 | 2147.4 | 1686.73 |
| 10:51:28 | 0 | 2149.4 | 1692.49 |

Valeurs : régression = **944,6 m/h**, calculée à la main et égale à la colonne `vs_watch_mh` de l'outil. Vitesse = 36,06 m / 58 s = 0,6217 m/s, soit 1608,4 s/km, affiché `26:48`.

**Extrait S (spirale, tour 2)** : échantillons acceptés de 13:00:50 à 13:01:47. L'horodatage 13:01:47 est à la ligne 64937 du TCX, avec FC 101 et `ns3:Speed` 9.844.

| T (UTC) | s rel. | Altitude (m) | Distance (m) |
|---|---|---|---|
| 13:00:50 | −57 | 1951.4 | 21538.03 |
| 13:00:55 | −52 | 1942.4 | 21589.81 |
| 13:01:00 | −47 | 1917.0 | 21626.31 |
| 13:01:06 | −41 | 1879.2 | 21687.91 |
| 13:01:11 | −36 | 1872.8 | 21737.70 |
| 13:01:16 | −31 | 1865.2 | 21778.32 |
| 13:01:21 | −26 | 1852.0 | 21826.32 |
| 13:01:26 | −21 | 1827.8 | 21861.61 |
| 13:01:31 | −16 | 1779.2 | 21900.24 |
| 13:01:37 | −10 | 1760.0 | 21946.63 |
| 13:01:42 | −5 | 1744.4 | 21998.51 |
| 13:01:47 | 0 | 1732.2 | 22048.72 |

Valeurs : régression = **−14 419,8 m/h** (sxy = −15 425,2, sxx = 3851 ; égale à `vs_watch_mh`). Vitesse = 510,69 m / 57 s = 8,9595 m/s, soit 111,6 s/km, affiché `1:52`.

**Extrait T (tick 1 Hz, tour 1)** : tous les points TCX de 10:50:26 à 10:51:28. On les rejoue à 1 Hz de 10:50:28 à 10:51:28, soit 61 ticks ; à chaque tick, la valeur est celle du dernier point TCX dont l'heure est ≤ celle du tick.

| T | Alt | Dist | | T | Alt | Dist | | T | Alt | Dist |
|---|---|---|---|---|---|---|---|---|---|---|
| 10:50:26 | 2133.2 | 1654.02 | | 10:50:45 | 2138.0 | 1666.47 | | 10:51:10 | 2144.8 | 1679.69 |
| 10:50:30 | 2134.2 | 1656.43 | | 10:50:47 | 2138.6 | 1667.27 | | 10:51:11 | 2144.8 | 1680.09 |
| 10:50:34 | 2135.4 | 1658.94 | | 10:50:49 | 2139.2 | 1669.32 | | 10:51:15 | 2146.0 | 1683.31 |
| 10:50:36 | 2136.0 | 1660.53 | | 10:50:53 | 2140.4 | 1671.53 | | 10:51:16 | 2146.2 | 1683.71 |
| 10:50:38 | 2136.4 | 1661.71 | | 10:50:57 | 2141.6 | 1672.86 | | 10:51:20 | 2147.4 | 1686.73 |
| 10:50:39 | 2136.6 | 1661.98 | | 10:50:59 | 2142.2 | 1673.65 | | 10:51:22 | 2148.0 | 1688.20 |
| 10:50:41 | 2137.0 | 1663.43 | | 10:51:01 | 2142.6 | 1675.06 | | 10:51:24 | 2148.6 | 1689.86 |
| | | | | 10:51:05 | 2143.6 | 1677.24 | | 10:51:28 | 2149.4 | 1692.49 |

HikeHistory accepte 13 échantillons, aux ticks 10:50:28 + 5k s. Altitudes retenues : 2133.2, 2134.2, 2136.4, 2137.0, 2138.6, 2140.4, 2141.6, 2142.6, 2143.6, 2144.8, 2146.2, 2148.0, 2149.4. Régression (t = −60 … 0, sxx = 4550, sxy = 1205) = **953,4 m/h**, affiché `+950`. Vitesse = (1692.49 − 1654.02) / 60 = 0,6412 m/s, soit 1559,7 s/km, affiché `26:00`.

#### Tableau des tests de l'axe 1

| Id | Nom | Entrées | Résultat attendu |
|---|---|---|---|
| F01 | `testChainAltitudeSourcePriority` | `feedTick` : Activity 2149.4, Sensor 2150.0, GPS 2155.0 ; puis Activity sans champ altitude (`FakeSensorInfo` 2150.0) ; puis GPS seul 2155.0 | `getAltitude()` = 2149.4, puis 2150.0, puis 2155.0. HikePositionView, valeur du haut : `2149`, puis `2150`, puis `2155` |
| F02 | `testKnownDefectD1NullActivityAltitudeHidesSensor` (**D1, défaut connu**) | `FakeFullActivityInfo` avec altitude **null**, `FakeSensorInfo(1500.0, null)` | **verrouille l'actuel** (décision 06/10, option prudente : la source du vario ne doit pas changer en douce) : `getAltitude()` null, ALTITUDE `--`, vol `starting ...`, 0 échantillon, vario et `oldAlt` null. PASS |
| F03 | `testChainAltitudeAbsent` | aucune altitude dans les 3 sources | `getAltitude()` null ; HikePositionView haut `--` ; FlyInstrumentView dessine seulement `starting ...` (aucun texte ` m`) ; `getVario()` reste null |
| F04 | `testChainAltitudeNegativeAndHigh` | Marche : −100.0, 6000.0, 0.0, −99.6, 5999.4 ; vol : −432.4, 8848.6 | Marche : `-100`, `6000`, `0`, `-100`, `5999` (bornes valides) ; vol (FlyInstrumentView intact, sans bornes) : `-432`, `8849`. PASS |
| F05a | `testDefectAltitudeOutOfBounds` (**D2 marche**) | −100.1, 6000.1, −432.4, 8848.6, −1000, 1e10, −1e10 | **correct** `--` partout. **Actuel** `-100`, `6000`, `-432`, `8849`, `-1000`, `2147483647`, `-2147483648`. FAIL |
| F05b | `testDefectAltitudeNonFinite` (**D2 marche**) | +Inf, −Inf, NaN | **correct** `--`. **Actuel** `2147483647`, `-2147483648`, `0`. FAIL |
| F06 | `testChainVerticalSpeedSalvanSteepClimb` | extrait M (11 échantillons) | `getHikeVerticalSpeedAt(T_fin)` = 944,6 ± 0,3 m/h ; `formatVerticalSpeed` → `+940` ; HikePaceView VERT. SPD. `+940` |
| F07 | `testChainVerticalSpeedSalvanSpiralDescent` | extrait S (12 échantillons) | −14 419,8 ± 1 m/h → `--` (au-delà du plafond marche de ±3000 m/h, décision D3 du 07/10) ; vitesse 8,9595 ± 0,001 m/s → PACE `1:52` ; HikePositionView DISTANCE `22.0` (avec session), ALTITUDE `1732` |
| F08 | `testChainVerticalSpeedAltitudeJump` | 13 échantillons toutes les 5 s à 2000.0, sauf le dernier à 3000.0 (+1000 m d'un coup) ; `now` = dernier | 23 736,3 ± 1 m/h (sxy = 30 000, sxx = 4550) → `--` (au-delà du plafond de ±3000 m/h, D3). Comportement actuel épinglé : pas de filtre de saut (amélioration possible, non exigée) |
| F09 | `testChainVerticalSpeedNaNAltitudeRecovers` | montée de 600 m/h (alt = 2000 + s/6), échantillon toutes les 5 s de 0 à 125 s ; NaN à s = 30 | `--` pour `now` ≤ t0 + 90 s (le NaN est dans la fenêtre) ; `+600` à t0 + 95 s puis à t0 + 125 s (599,9 à 600,1 m/h) |
| F10 | `testChainTickSalvanClimb1Hz` | extrait T, 61 ticks : `feedTick(FakeGpsInfo, FakeFullActivityInfo(alt, dist, FC 139, speed 0.0, timer), FakeSensorInfo)`, puis `endMeasure()`, puis `recordHikeSampleAt` si `shouldRecordHikeSample(true, true)`, puis `feedBreadcrumbTrail` | `hikeHistory.getCount()` = 13 ; vitesse verticale 953,4 ± 0,5 → `+950` ; vitesse 0,6412 ± 0,001 → `26:00` ; HikePaceView : `139` / `+950` / `26:00` |
| F11 | `testChainPaceWhenInstantSpeedZero` | extrait M avec, pour le dernier tick, Activity `currentSpeed` 0.0, Sensor et GPS sans vitesse | `getSpeed()` = 0.0 ; FlyInstrumentView vitesse `0` km/h ; HikePaceView PACE `26:48` (et non `--:--`) |
| F12 | `testChainPositionPageFields` | session en cours ; altitude 2149.4, `totalAscent` 335.0, distance 1692.49, chrono 1 965 000 ; puis sans session ; puis distance 0.0 ; puis 999 900.0 ; puis `totalAscent` null | `2149` / `335` / `1.7` / `32:45` ; sans session : `2149` / `--` / `--` / `--:--` ; `0.0` ; `999.9` ; D+ `--` |
| F12b | `testChainPositionAscentGuard` (garde du D+, décision du 07/10) | session ; altitude 2149.4, distance 1692.49, chrono 1 965 000 ; `totalAscent` −0.1, −1.0, 20 000.1, 20 000.4, 20 001.0, 1e10, NaN, +Inf, −Inf ; puis 20 000.0, −0.0, 908.0 (D+ de la montée de Salvan) ; puis sans session | ELEV. GAIN `--` pour les 9 premières valeurs (avant la garde, mesuré le 07/10 sur fenix6pro : `0`, `-1`, `20000`, `20000`, `20001`, `2147483647`, `0`, `2147483647`, `-2147483648`) ; `20000`, `0`, `908` ; sans session `--`. Fonction pure : `testFormatHikeAscent` (TestsFormat.mc) |
| F13 | `testDefectNegativeDistance` (**D3**) | session, distance −5.0 puis −1000.0 | **correct** `--` ; **actuel** `-0.0`, `-1.0`. FAIL |
| F14 | `testChainFlightSpeedKmh` | FlyInstrumentView, altitude 1732.2 : (a) Sensor null + GPS 9.844 ; (b) Sensor 2.0 ; (c) Activity 0.0 seule ; (d) aucune vitesse ; (e) GPS 1000.0 | (a) `35` ; (b) `7` ; (c) `0` ; (d) aucun texte ` km/h` ; (e) `3600` |
| F15 | `testKnownDefectD4NegativeFlightSpeedShown` (**D4, défaut connu**) | GPS −1.0 | **verrouille l'actuel** : `1732| m|-4| km/h`. PASS. FlyInstrumentView reste intact (décision 06/10) |
| F16 | `testChainHeartRateSources` | (a) Activity 139, Sensor 141 ; (b) Activity null, Sensor 141 ; (c) les deux null ; bornes valides 25 et 250 (Activity puis Sensor) | HikePaceView haut : `139`, `141`, `--`, `25`, `250`, `25`, `250`. PASS |
| F17 | `testDefectHeartRateOutOfBounds` (**D5**) | Activity 24, 251, 0, 255, −1 (Sensor null) ; Sensor 300 seul | **correct** `--` partout ; **actuel** `24`, `251`, `0`, `255`, `-1`, `300`. FAIL |
| F18 | `testChainTimerDisplay` | session ; `timerTime` 1 965 000, 359 999 000, 360 000 000 ; session avec `timerTime` null ; sans session avec 1 965 000 ; session en pause avec 1 965 000 | `32:45`, `99:59:59`, `100:00:00` ; `--:--` ; `--:--` ; en pause, `32:45` sur Position, Pace et PausedView |
| F19 | `testDefectNegativeDuration` (**D6**) | `formatDuration` de −65 000, −1000, −1, −3 600 000 ; `pausedScreenTimerText(true, -65000)` ; page Position, chrono −65 000 | **correct** `--:--` partout ; **actuel** `-1:-5`, `00:-1`, `00:00`, `00:00`, `-1:-5`, `-1:-5`. FAIL |
| F20 | `testChainMapWaitingAndTrailOnly` | HikeMapView : (a) trace vide, pas de fix ; (b) 20 points Salvan (`MapTestHelper.salvanLats/Lons`, accuracy 4) puis un tick sans fix (accuracy 0) ; (c) même trace avec un fix au dernier point | (a) textes `["Waiting for", "GPS"]` ; (b) aucun texte, `getCount()` = **3** (et non 20 : décimation à 15 m, comme dans `testFeedBreadcrumbTrailSkipsTicksWithoutFix`), inchangé par le tick sans fix ; (c) aucun texte : la trace fait environ 50 m, donc pas de barre d'échelle |
| F21 | `testChainMapScaleBarTwoKmTrail` | trace nord-sud de 2 km : lat 46.1000 + 0.0005·k (k = 0…35), puis 46.1179662 ; lon 7.0 (37 points) ; position courante = dernier point, cap 0.0 | `getCount()` = 37 ; le libellé dessiné est **`500 m`** sur les 62 montres (1000 m = 0,85·r px > w/3 et 500 m ≤ w/3 pour toutes les tailles). Sur fenix6pro : m/px = 10,79, barre de 46 px |
| F22 | `testChainCompassNorthEast` | `compass(0.0, 46.12446558661759d, 6.985453460365534d)` (Doubles, comme `toDegrees()`), la même en Float avec cap 0.785, puis `compass(0.0, null, null)` | `N S E W 46°07'28.1"N 6°59'7.6"E` (deux fois : `%02d` donne bien `07` sur Float et Double) ; puis `N S E W Waiting for GPS`. PASS |
| F23 | `testDefectCompassSouthWestSign` (**D7**) | `compass(0.0, -22.9519d, -43.2105d)` ; `compass(0.0, -0.5d, -0.5d)` | **correct** `22°57'6.8"S` / `43°12'37.8"W` ; `0°30'0.0"S` / `0°30'0.0"W` (déjà juste aujourd'hui : degré nul, pas de signe). **Actuel** `-22°57'6.8"S` / `-43°12'37.8"W`. FAIL |
| F24 | `testDefectCompassSecondsRoundTo60` (**D8**) | `compass(0.0, 45.99999d, 6.99999d)` ; `compass(0.0, 46.4999999d, 7.0d)` | **correct** `46°00'0.0"N` / `7°00'0.0"E` ; `46°30'0.0"N`. **Actuel** `45°59'60.0"N` / `6°59'60.0"E` ; `46°29'60.0"N`. FAIL |
| F25 | `testDefectCompassNullHeading` (**D9**) | `compass(null, null, null)` puis `compass(null, lat, lon)` (point réel) | **correct** : aucune exception, `N S E W Waiting for GPS`, puis les coordonnées. **Actuel** : exception à `WatchDisplay.mc:238`. **ERROR**, isolé (chaque test tourne dans une instance neuve de l'app, les suivants passent) |
| F26 | `testChainPausedViewTexts` | PausedView avec `FakeApp` ; fausse session en pause ; chrono 1 965 000 ; puis sans session | `["Paused", "32:45", "START: resume"]`, puis `["Paused", "--:--", "START: resume"]` ; police du chrono `FONT_NUMBER_MEDIUM` si `32:45` tient dans 80 % de la largeur, sinon `FONT_NUMBER_MILD` (valeur journalisée) |
| F27 | `testChainPauseSensorsOffKeepsGps` | session en pause : `sensorsForState(true, activeSensorList())` ; tick FC null (Activity et Sensor) ; 2 fix GPS (accuracy 4) à 20 m d'écart ; puis reprise avec FC 139 | `[]` (plus aucun capteur) ; HikePaceView haut `--` ; `getCount()` de la trace passe de 1 à 2 (le GPS continue) ; aucun échantillon HikeHistory pendant la pause ; après la reprise : `139` |
| F28 | `testVarioEndMeasureSequence` (lecture seule, zone sensible) | 4 ticks `startMeasure` / `feedTick` / `endMeasure` : altitude 1000.0, 1001.5, aucune source, 1000.5 | `getVario()` : null, 1.5, **1.5** (inchangé), −1.0 ; `oldAlt` : 1000.0, 1001.5, 1001.5, 1000.5 |
| F29 | `testVarioDisplayThresholdsAndText` (lecture seule) | `WatchDisplay(ChainDc)` : `start(v)` puis `vario(v)` pour v = 0.3, 0.29, −2.0, −1.99, 1.5, −1.0, 0.0 | couleur de fond du `clear()` : vert, gris clair, rouge, gris clair, vert, gris clair, gris clair ; textes `+0.3`, `+0.3`, `-2.0`, `-2.0`, `+1.5`, `-1.0`, `+0.0` (comportement actuel épinglé, sans jugement) |

Bilan de l'axe 1 (exécuté le 06/10 sur fenix6pro et fenix5, résultats identiques) : **30 tests** (F05 coupé en deux). **22** passent, dont 2 `testKnownDefect*` qui verrouillent D1 et D4 ; **8** sont en échec attendu jusqu'à la tâche de correction : 7 FAIL (`testDefectAltitudeOutOfBounds`, `testDefectAltitudeNonFinite`, `testDefectNegativeDistance`, `testDefectHeartRateOutOfBounds`, `testDefectNegativeDuration`, `testDefectCompassSouthWestSign`, `testDefectCompassSecondsRoundTo60`) et 1 ERROR (`testDefectCompassNullHeading`). Suite complète : `Ran 106 tests` → `FAILED (passed=98, failed=7, errors=1)`. Après correction : `PASSED (passed=106…)`.

### 3.2 Banc d'affichage (tâche b) : 39 tests, dans un nouveau `source/TestsLayout.mc` en `(:test)`

**Auto-tests du banc (4)**

| Id | Nom | Résultat attendu |
|---|---|---|
| B01 | `testBenchSelfTextBoxes` | `drawText(100, 50, FONT_XTINY, "ABC", CENTER\|VCENTER)` donne la boîte `(100 − l/2, 50 − h/2, 100 + l/2, 50 + h/2)`, avec (l, h) = `getTextDimensions` du Dc de mesure ; mêmes vérifications pour LEFT et RIGHT, avec et sans VCENTER |
| B02 | `testBenchSelfOverlapRule` | deux boîtes qui se recouvrent de 1 px → 1 défaut ; deux boîtes qui se touchent (x1 = x0') → 0 défaut |
| B03 | `testBenchSelfScreenShapeRule` | écran rond : la boîte centrée en (w/2, 2) de 2 × 2 px est dedans, la boîte en (0, 0) est dehors ; semi-octogone ou rectangle : (0, 0)–(2, 2) est dedans. Journalise `w, h, screenShape` |
| B04 | `testBenchSelfSubscreenSource` | journalise `WatchUi.getSubscreen()`. Sur G11 : (113, 0, 62, 62) ; G12 : (113, 0, 52, 52) ; G13 : (108, 0, 54, 54) ; ailleurs null, sauf peut-être G14/G15, dont on note la valeur. Échoue si getSubscreen et le tableau du § 2.2 ne concordent pas |

**Tests de mise en page (35)** : `testLayout_<Vue>_<État>`. Vues : `HikePosition`, `HikePace`, `HikeMap`, `Time`, `Fly`, `Compass` (`display.compass`), `Paused`. États : `Empty`, `Normal`, `Extreme`, `Paused`, `Recording`.

| Vue \ État | Empty | Normal | Extreme | Paused | Recording |
|---|---|---|---|---|---|
| HikePosition | `--` `--` `--` `--:--` | `2149` `335` `1.7` `32:45` | `6000` `20000` `999.9` `99:59:59` | comme Normal, session en pause | Normal + icône |
| HikePace | `--` `--` `--:--` `--:--` | `139` `+940` `26:48` `32:45` | `250` `-3000` `60:00` `99:59:59` | Normal en pause | Normal + icône |
| HikeMap | `Waiting for` `GPS` | trace 20 points + marqueur, aucun texte | trace F21 → `500 m` | Normal en pause | Normal + icône |
| Time | `00:00` `0%` | `10:51` `76%` | `23:59` `100%` | idem Normal | Normal + icône |
| Fly | `starting ...` | `2149` ` m` `0` ` km/h` `+0.4` ` m/s` | `8849` ` m` `120` ` km/h` `-10.0` ` m/s` | Normal, `record = false` | Normal, `record = true` + icône |
| Compass | `N S E W` `Waiting for` `GPS` (cap 0.0) | `46°07'28.1"N` `6°59'7.6"E` (cap 0.785) | `89°59'59.9"S` `179°59'59.9"W` (cap 0.785 ; les plus longues depuis D7/D8) | idem Normal | Normal + icône |
| Paused | `Paused` `--:--` `START: resume` | `Paused` `32:45` `START: resume` | `Paused` `100:00:00` `START: resume` | idem Normal | session en cours : `Paused` `32:45` (`pausedScreenTimerText` ne dépend pas de l'enregistrement) |

**Résultat attendu de chaque test de mise en page** : 0 chevauchement, 0 texte hors de l'écran, 0 texte dans la sous-fenêtre, sur chacune des 62 montres. Un défaut fait échouer le test avec le message normalisé (vue, état, textes en cause, boîtes). Sur fenix6pro, `testLayout_HikePosition_Normal` et `testLayout_HikePace_Normal` servent à calibrer la marge `k`. Ils **doivent** passer, sinon `k` est mal réglé.

Volume : 39 tests × 62 montres = 2418 résultats. Le rapport final les présente sous forme de matrice montre × test, avec la liste des défauts par groupe d'écran.

#### Échecs attendus du banc (relevés les 07 et 08/10, app inchangée)
Les rounds suivants **comparent la liste des noms**, pas leur nombre. Un nom en plus ou en moins signale un changement d'affichage, ou du banc. Tous les tests sont dans le module `LayoutBenchTests.` ; B01 à B04 passent partout.

**fenix6pro (260×260, rond)** : 166 tests, 164 PASS, 2 FAIL
- `testLayout_HikePosition_Extreme` : OFFSCREEN `"99:59:59"`
- `testLayout_HikePace_Extreme` : OFFSCREEN `"99:59:59"`

**instinct2 (176×176, semi-octogone, sous-fenêtre (113, 0, 62, 62))** : 166 tests, 143 PASS, 23 FAIL. *disk* = au moins un `SUBSCREEN disk` (le texte atteint la fenêtre ronde) ; *corner* = seulement des `SUBSCREEN corner` (coins du carré englobant).
- `testLayout_HikePosition_Empty`, `_Normal`, `_Extreme`, `_Paused`, `_Recording` (5) : *disk*. Aussi OVERLAP `"ALTITUDE"` × valeur du haut, `"ELEV. GAIN"` × `"DISTANCE"`, `"TIMER"` × chrono ; SUBSCREEN `"ALTITUDE"`, `"DISTANCE"`.
- `testLayout_HikePace_Empty`, `_Normal`, `_Extreme`, `_Paused`, `_Recording` (5) : *disk*. Aussi OVERLAP `"TIMER"` × chrono ; SUBSCREEN `"PACE"`, plus la FC hors état vide.
- `testLayout_Fly_Normal`, `_Extreme`, `_Paused`, `_Recording` (4) : *disk*, SUBSCREEN `" km/h"`. Zone sensible : signalé, non corrigé.
- `testLayout_Compass_Normal`, `_Extreme`, `_Paused`, `_Recording` (4) : *disk*, SUBSCREEN `"E"` (cap 0.785 rad).
- `testLayout_Paused_Empty`, `_Normal`, `_Extreme`, `_Paused`, `_Recording` (5) : *corner*, SUBSCREEN `"Paused"`.

**fenix5 (240×240, rond)** : 166 tests, **166 PASS**, aucun échec.

**fenix843mm (416×416, rond, AMOLED)** : 166 tests, 153 PASS, 13 FAIL. Relevé lors de la première passe (07/10), **avant** la distinction disk/corner (`hitsDisk`). Cette montre n'a pas de sous-fenêtre, donc la liste ne devrait pas changer ; elle n'a pas été relancée depuis.
- `testLayout_HikePosition_Extreme` : OVERLAP `"20000"` × `"999.9"` ; OFFSCREEN `"99:59:59"`
- `testLayout_HikePace_Extreme` : OFFSCREEN `"99:59:59"`
- `testLayout_HikeMap_Empty` : OVERLAP `"Waiting for"` × `"GPS"`
- `testLayout_Time_Empty`, `_Normal`, `_Extreme`, `_Paused`, `_Recording` (5) : OVERLAP heure × batterie
- `testLayout_Compass_Empty` : OVERLAP `"Waiting for"` × `"GPS"` ; OFFSCREEN `"N"`, `"S"`, `"W"`
- `testLayout_Compass_Normal`, `_Extreme`, `_Paused`, `_Recording` (4) : OVERLAP latitude × longitude ; OFFSCREEN `"N"`, `"S"`, `"E"`, `"W"`

**fenix7** (pour information, première passe) : 164 PASS, 2 FAIL, les mêmes que fenix6pro.

### 3.3 Totaux

| Axe | Tests à écrire | Attendu |
|---|---|---|
| 1. Fonctionnel (tâche a) | 30 (F01–F29, F05 en deux), **écrits** | 22 PASS (dont D1 et D4 verrouillés), 8 échecs attendus (D2 marche, D3, D5–D9) jusqu'à la tâche de correction |
| 2. Affichage (tâche b) | 39 (B01–B04, 35 `testLayout_*`), **écrits** (`source/TestsLayout.mc`, 07/10) | B01–B04 PASS ; échecs attendus = liste nominative du § 3.2 (fenix6pro 2, instinct2 23, fenix5 0, fenix843mm 13) jusqu'à une tâche de correction de l'affichage |
| 2. Fonctions (tâche c) | 9 vérifications C01–C09 sur 62 montres (procédure, pas de nouveau code) | voir § 2.3 |
| Manuel | 12 étapes M01–M12 (§ 5) | voir § 5 |
| **Total de tests Monkey C nouveaux** | **69** | suite finale : 76 + 69 = **145** tests par montre (76 = 67 du plan + 9 de la préférence de fenêtre VS) |

---

## 4. Procédure de la tâche finale d'exécution (tâche c)

### 4.1 Préalables
- La tâche epix est faite : `manifest.xml` liste 62 produits. Contrôle : `grep -c '<iq:product ' manifest.xml` → 62.
- Le simulateur est ouvert (`connectiq`), car `monkeydo -t` en a besoin.
- Lancer les commandes depuis la racine du worktree, en chemins absolus. Ne jamais écrire dans `bin/` : avec `-o /tmp/glidator-build/...`, monkeyc place `gen/` dans `/tmp/glidator-build/`.

### 4.2 Commandes, pour chaque `<id>` des 62 (une commande à la fois, puis `git status`)

```
monkeyc -f monkey.jungle -o /tmp/glidator-build/<id>.prg      -d <id> -y developer_key          # C01
monkeyc -f monkey.jungle -o /tmp/glidator-build/<id>-test.prg -d <id> -y developer_key -t       # C02
monkeydo /tmp/glidator-build/<id>-test.prg <id> -t                                             # C03
git status --short                                                                             # doit rester vide
```

Ordre conseillé : d'abord les 15 représentatives (§ 2.2), en commençant par fenix6pro pour calibrer `k`, puis les 47 autres. Compter environ 1 min par montre.

### 4.3 Si le .prg de test ne tient pas en mémoire (G11 à G13, G1, G3)
Ne pas modifier `monkey.jungle`. Écrire un jungle temporaire dans `/tmp/glidator-build/`, qui pointe vers le manifest et `source/` en chemins absolus, avec `base.excludeAnnotations = <annotation>`. Pour cela, la tâche b doit annoter le banc `(:test, :layoutbench)` ; la tâche a l'a fait : `(:test, :chaintest)` sur tout `TestsChain.mc` (les tests de chaîne s'appuient sur `WatchDataTestHelper` (ex-`SpeedTestHelper`), `FakeSensorInfo`, `FakeLocation` et `MapTestHelper` de `Tests.mc`, qui doit donc rester inclus). Le 06/10, fenix5 fait tourner les 106 tests sans exclusion. Compiler alors deux .prg de test par montre (sans le banc, puis sans les tests de chaîne), et le noter dans le rapport.

**Banc écrit (07/10, `source/TestsLayout.mc`)** : annotation `(:test, :layouttest)` (et non `:layoutbench`), tout le banc dans le module `LayoutBenchTests`, car le module `globals` est limité à 253 membres et les 39 tests n'y tenaient pas (274). Le lanceur trouve les tests du module (`LayoutBenchTests.testLayout_…`). Le banc ne dépend que de `Tests.mc` (`MapTestHelper`), pas de `TestsChain.mc`.

Deux jungles temporaires, **à créer dans `/tmp/glidator-build/` et à ne jamais versionner** (surtout pas à la racine, à côté de `monkey.jungle`). Chemins absolus du worktree ; les adapter si le dépôt est ailleurs.

`/tmp/glidator-build/no-layout.jungle` : la suite fonctionnelle seule (`Tests.mc`, `TestsFormat.mc`, `TestsChain.mc`), sans le banc :
```
project.manifest = /Users/sam/claude-hq/worktrees/glidator2/manifest.xml
base.sourcePath = /Users/sam/claude-hq/worktrees/glidator2/source
base.resourcePath = /Users/sam/claude-hq/worktrees/glidator2/resources
base.excludeAnnotations = layouttest
```

`/tmp/glidator-build/layout-only.jungle` : malgré son nom, ce n'est **pas** le banc seul. Il exclut seulement les tests de chaîne, et garde donc le banc **et** tous les tests de `Tests.mc` et `TestsFormat.mc` (non annotés). En toute rigueur, c'est un jungle « no-chain » :
```
project.manifest = /Users/sam/claude-hq/worktrees/glidator2/manifest.xml
base.sourcePath = /Users/sam/claude-hq/worktrees/glidator2/source
base.resourcePath = /Users/sam/claude-hq/worktrees/glidator2/resources
base.excludeAnnotations = chaintest
```

Commandes (une à la fois) :
```
monkeyc -f /tmp/glidator-build/no-layout.jungle   -o /tmp/glidator-build/<id>-nolayout.prg   -d <id> -y developer_key -t
monkeyc -f /tmp/glidator-build/layout-only.jungle -o /tmp/glidator-build/<id>-layoutonly.prg -d <id> -y developer_key -t
monkeydo /tmp/glidator-build/<id>-nolayout.prg <id> -t
```
Les deux jungles compilent sur fenix6pro (07/10). Le 07/10, le .prg complet (166 tests) tient en mémoire sur instinct2 et fenix5 : aucune exclusion n'a été nécessaire.

**Marge d'encre `k = 0,16`** (constante `LAYOUT_INK_K` de `TestsLayout.mc`). C'est la plus petite valeur, au centième, qui fait passer `testLayout_HikePosition_Normal` et `testLayout_HikePace_Normal` sur fenix6pro. Avec 0,15, ces deux tests trouvaient 1 px de recouvrement entre « TIMER » (`FONT_XTINY`, 19 px, marge floor(0,15 × 19) = 2) et le chrono (`FONT_NUMBER_MEDIUM`, 74 px, marge 11). À 0,16, la marge de XTINY passe à 3 et les deux boîtes ne font que se toucher ; le seuil exact est 3/19 ≈ 0,158.
- Portée : une seule valeur pour **toutes les polices et toutes les montres**.
- Par rapport à 0,15, elle retire 1 px de plus, en haut et en bas, pour les hauteurs où floor(0,16 × h) dépasse floor(0,15 × h) (sur fenix6pro : XTINY 19 px, NUMBER_HOT 100 px…). Elle ne change rien pour les autres hauteurs.
- Limite : sur fenix5, les polices numériques ont une hauteur égale à leur ascent (descent 0). La marge y rogne donc de l'encre réelle et peut masquer un défaut de 1 à 2 px.

### 4.4 Lire la sortie de `monkeydo -t`
- **`monkeydo` renvoie le code 1 même quand tout passe** (constaté le 05/10). Ne jamais se fier au code de retour.
- Lire le bloc de fin `RESULTS` : `Ran N tests`, puis `PASSED (passed=N, failed=0, errors=0)` ou `FAILED (passed=…, failed=…, errors=…)`.
- Chaque test affiche `PASS`, `FAIL` ou `ERROR` ; en cas d'ERROR, une pile `Error: … Stack: … at source/<fichier>:<ligne>` suit.
- Attendu par montre : N = 145. Avant la tâche de correction, les échecs sont **exactement** les 8 `testDefect*` (7 FAIL, `testDefectCompassNullHeading` en ERROR), plus d'éventuels `testLayout_*` ; après, aucun `testDefect*` ne doit échouer. Les `testKnownDefect*` doivent toujours passer. Tout autre FAIL ou ERROR est une régression à signaler. Si un `testDefect*` passe, le défaut a été corrigé ; vérifier alors par qui et dans quel commit.
- Les tests `testStopRecordingSaves*` enregistrent une activité dans le simulateur. Une ERROR isolée sur ces tests a déjà été vue (instable) : relancer une fois avant de conclure.

### 4.5 Contrôles des zones sensibles (base `origin/hikeandfly`)
| Contrôle | Commande | Attendu |
|---|---|---|
| FlyInstrumentView | `git diff origin/hikeandfly -- source/FlyInstrumentView.mc` | vide |
| `WatchDisplay.vario()` (l. 193-230) et `beep()` (l. 167-187) | `git diff origin/hikeandfly -- source/WatchDisplay.mc` | aucun hunk dans ces fonctions |
| `WatchData` : `oldAlt` (l. 12), `endMeasure()` (l. 26-44), `getVario()` (l. 46-49), `getAltitude()` (l. 211-232) | `git diff origin/hikeandfly -- source/WatchData.mc` | aucun hunk dans ces lignes. Si D1 a été corrigé dans `updateActivityInfo`, le signaler : cela change la source du vario, et l'utilisateur doit l'avoir accepté |
| manifest.xml | `git log --stat origin/hikeandfly..HEAD -- manifest.xml` | un seul commit (epix), +4 lignes `<iq:product>` |
| Fichiers interdits | `git show --stat <commit>` pour chaque commit du round | ni `bin/`, ni `.DS_Store`, ni `developer_key` |
| Tests non affaiblis | `git diff origin/hikeandfly -- source/Tests.mc` | aucune assertion existante supprimée ni modifiée |

---

## 5. Protocole manuel (simulateur, puis montre)

Préparation : compiler fenix6pro hors de `bin/`, lancer `monkeydo /tmp/glidator-build/fenix6pro.prg fenix6pro`, puis charger `garmin_data/activity_24346302742.gpx` dans *Simulation > Activity Data* (ou *Data Playback*). Le simulateur calcule la distance à partir des positions GPX : prévoir environ +2,7 % par rapport au TCX, donc un pace un peu plus rapide.

- [ ] **M01 Montée raide** : sur la page Pace, au passage de 10:51:28 dans la trace, VERT. SPD. lit entre **+900 et +1000** (attendu dans le code : +950), PACE entre **25:00 et 27:00**, et la vitesse instantanée en vol (BACK maintenu) vaut `0` à ce moment. Sur la page Position : ALTITUDE environ **2149**, DISTANCE environ **1.7** km.
- [ ] **M02 Spirale** : en mode Marche, au passage de 13:01:47, VERT. SPD. lit **`--`** (−14 420 m/h, au-delà du plafond marche de ±3000 m/h, décision D3 du 07/10) ; la valeur la plus large affichable est désormais `-3000`, à vérifier dans la demi-case sur fenix6pro, fr55, instinct2 et instinct2s.
- [ ] **M03 Menu de pause** : SELECT pendant l'enregistrement → menu « Paused » (Resume / Pause / Save / Ignore), 2 vibrations courtes. Choisir Pause → écran « Paused », chrono figé, « START: resume » ; BACK ne fait rien ; SELECT → retour à la page, 1 vibration longue (600 ms), le chrono repart.
- [ ] **M04 Reprise automatique** : menu ouvert sans rien toucher pendant **30 s** → reprise toute seule. Choisir Pause puis attendre 60 s → aucune reprise automatique depuis l'écran Paused.
- [ ] **M05 Capteurs en pause** : simuler une FC (Simulation > Sensors, 120 bpm). En pause, Heart Rate affiche `--`. Après la reprise, `120` revient en moins de 3 s. La trace de la carte continue de s'allonger pendant la pause.
- [ ] **M06 Écran tactile** (fr265s, fenix7x, epix2) : un tap sur l'écran ne démarre ni n'arrête l'enregistrement ; noter ce que font les swipes haut/bas, car l'app ne gère que `onKey` UP/DOWN.
- [ ] **M07 Écran 1 bit** (instinct2, instincte40mm, instinct2s) : tous les libellés sont lisibles ; noter si le fond vert/rouge du vario se voit en mode Vol.
- [ ] **M08 Instinct** : aucun texte dans la sous-fenêtre ronde (en haut à droite) ni dans les coins coupés, sur les 7 pages et l'écran Paused.
- [ ] **M09 AMOLED** (epix2pro42mm, fr965, fenix9pro51mm) : lisibilité des pages Position et Time (risques de chevauchement listés au § 2.4).
- [ ] **M10 Menu2** : menu Paused et menu Preferences complets et lisibles sur les 15 représentatives.
- [ ] **M11 fenix5** : SELECT démarre l'enregistrement sans plantage (sport générique) ; Save crée une activité.
- [ ] **M12 fr55** (pas de baromètre ni de boussole) : ALTITUDE apparaît après le fix GPS ; la page Position du mode Vol ne plante pas sans GPS (voir D9).

Sur la montre (si disponible) : refaire M01, M03 et M05 pendant une vraie montée, en relevant 3 valeurs de VERT. SPD. et le D+ sur 5 min.

---

## 6. Ce qui reste non couvert après ce plan
- `FlyInstrumentApp.onSensor()` et `onStop()` eux-mêmes : on n'appelle ni l'un ni l'autre. F10 rejoue leur séquence d'appels, mais ne vérifie pas qu'ils sont bien branchés : c'est le rôle de M01 et M05.
- Les délégués (`BaseInputDelegate`, `MyMenu2QuitDelegate`, `PausedDelegate`) : seules les règles pures sont testées (tests existants). Le minuteur de 30 s et `System.exit()` restent manuels (M03, M04).
- Les couleurs réellement visibles sur écran 1 bit et sur AMOLED : le banc ne regarde que la géométrie (M07, M09).
- Les vibrations et tonalités réelles : les motifs sont épinglés par les tests existants, le ressenti est manuel.

## 7. Choix faits sans validation (aucun humain disponible)
1. **15 groupes au lieu de 13** : instinct3amoled45mm et 50mm sont séparés des autres ronds AMOLED, parce que leur skin déclare une sous-fenêtre.
2. **Représentatives** : la plus ancienne ou la plus petite de chaque groupe quand ça compte (fenix5, instinct2s), sinon un nouvel epix (epix2pro42mm, epix2).
3. **Extraits réels différents de ceux déjà testés** (Salvan 11:07–11:09 et les 20 premiers points GPX) : une montée raide à FC connue (10:51:28) et une spirale à −14 420 m/h (13:01:47), qui sert aussi de valeur extrême d'affichage.
4. **Les défauts à corriger deviennent des tests `testDefect*` qui vérifient la valeur correcte**, donc en échec tant que le défaut existe. Seuils **décidés le 06/10** : FC 25 à 250 bpm, altitude −100 à 6000 m (et non −1000 à 10 000 m comme proposé).
5. **Banc limité aux textes**, comme demandé ; traits, cercles et icône ne sont pas contrôlés. Marge d'encre de `k = 0,15`, à calibrer sur fenix6pro.
6. D+ de l'état « normal » **synthétique** (335 m) : le TCX ne donne pas le `totalAscent` de la montre à 10:51:28.

## 8. Questions pour l'utilisateur (réponses du 06/10)
1. **D1** (altitude d'Activity null qui masque le capteur) : **non corrigé**, défaut connu ; verrouillé par `testKnownDefectD1NullActivityAltitudeHidesSensor`.
2. **D2 / D4** côté `FlyInstrumentView.mc` : **on n'y touche pas**, défauts connus. D2 côté HikePositionView : à corriger.
3. Seuils : altitude **−100 à 6000 m**, FC **25 à 250 bpm** ; hors bornes ou non finie → `--`.
4. Écrans tactiles : **pas de tactile** ; l'écran Paused reste inchangé.
