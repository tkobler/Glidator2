# Glidator2 : spécification des 5 corrections du plan

*Note de cadrage, 29/09/2026. Entrées : `fiches/glidator2-plan-corrections.md` (le plan), `docs/recherches/veille-connectiq.md` (la veille, commit c51b919), le code de `source/` (branche `claude/cadrage-corrections`, identique à `hikeandfly` pour `source/`) et `garmin_data/activity_24346302742.tcx`.*

## Question

Pour chacun des 5 points du plan : la cause annoncée est-elle la bonne (code et données) ? Quelle solution retenir, compte tenu de la veille ? Et comment découper le travail en sous-tâches de moins de 3 h, prêtes à copier dans `TACHES.md` ?

Pour trancher, il faut : (1) une référence `fichier:ligne` pour chaque cause ; (2) des chiffres tirés du TCX ; (3) une solution qui ne touche pas au vario de vol.

## Réponse courte

**Confiance : élevée** pour les points 1, 2, 4 et 5 : les causes se lisent directement dans le code et le TCX les confirme. **Confiance : moyenne** pour le point 3 : la cause est plausible, mais le TCX ne peut pas la prouver.

| # | Cause du plan | Verdict | Correction apportée au plan |
|---|---|---|---|
| 1 | Vario instantané × 3600 | **Confirmée** | Alimenter le buffer depuis `FlyInstrumentApp.onSensor()` et **non** depuis `endMeasure()` (zone intouchable). |
| 2 | Clé `speed` à `null` + vitesse nulle 79 % du temps | **Confirmée** (code) ; 79,1 % recalculé | Le bug d'arrondi « 5:60 » est confirmé à `HikePaceView.mc:53`. |
| 3 | Points d'avant le fix qui écrasent la bbox | **Plausible, non prouvée** | Le TCX ne contient que des points valides (4311/4311). La cause est à confirmer au simulateur. Autre défaut trouvé : la carte affiche « Waiting for GPS » dès que la position courante manque, même si la trace existe. |
| 4 | SELECT met en pause et ouvre le menu | **Confirmée** | Autre défaut trouvé : BACK dans le menu **reprend** l'enregistrement. Les vibrations de pause et de reprise ne diffèrent que par l'intensité. |
| 5 | `onStop` jette la session | **Confirmée** (`FlyInstrumentApp.mc:191`) | Autre point : le TCX affiche `Sport="Other"`, car le format TCX ne connaît pas le vol. |

## Points à trancher (choix par défaut prudents)

Les sous-tâches ci-dessous appliquent déjà le **choix par défaut**. Si l'utilisateur tranche autrement, seule la sous-tâche indiquée change.

1. **Seuil de qualité GPS pour la carte** (veille, question 1). Par défaut : `accuracy >= Position.QUALITY_USABLE` (fix 3D), comme dans le plan, placé dans une constante unique. L'alternative GliderSK accepte `QUALITY_POOR` (2D) et remplit mieux la trace en forêt ou en falaise, mais au prix de points moins précis. Sous-tâche concernée : 3a.
2. **Buffer de marche pendant la pause** (veille, question 2). Par défaut : aucun échantillon pendant la pause, et le buffer se vide automatiquement s'il y a un trou de plus de 15 s. Après une reprise, on affiche donc `--` pendant environ 20 s, mais jamais une valeur fausse. Un gel du buffer mélangerait des temps d'avant et d'après la pause, car `Sys.getTimer()` continue de tourner. Sous-tâches concernées : 1a et 1b.
3. **Rejet des sauts GPS** (veille, question 3). Par défaut : un seuil **proportionnel au temps**, `50 m + 60 m/s × Δt` depuis le dernier point accepté. Un seuil fixe de 400 m, comme dans breadcrumb, bloquerait la trace pour toujours après une perte de GPS de quelques minutes en vol (le TCX montre 16,3 m/s en pointe). La sous-tâche est **optionnelle**, car le TCX ne montre aucun saut. Sous-tâche concernée : 3b.
4. **Licence** (veille, question 4). Par défaut : on ne copie aucun code des dépôts étudiés, on réimplémente les idées. Le choix d'une licence revient à l'utilisateur et ne fait l'objet d'aucune tâche ici.
5. **Bandeau PAUSE sur la vue vario** (`FlyInstrumentView`, zone intouchable). Par défaut : on **ne touche pas** `FlyInstrumentView.mc`. Le bandeau s'affiche sur les 5 autres vues. Pour l'ajouter aussi sur la vue vario, il suffirait d'une ligne d'overlay après `display.end()`, comme pour `recordingStartIcon()` (`FlyInstrumentView.mc:86-88`). Cela demande un accord explicite. Sous-tâche concernée : 4b.
6. **Point d'alimentation du buffer de marche.** Le plan propose `endMeasure()`, qui est une fonction intouchable. Par défaut : une nouvelle méthode `WatchData.recordHikeSample()`, appelée dans `FlyInstrumentApp.onSensor()` juste après `mainView.updateData()`. Le vario n'est pas touché, et le résultat est le même (1 appel par tick). Sous-tâche concernée : 1b.
7. **BACK dans le menu de pause.** Aujourd'hui, BACK dans ce menu reprend l'enregistrement (`FlyInstrumentDelegate.mc:34-38`). Par défaut : BACK ferme le menu et **reste en pause**. Pour reprendre, on utilise SELECT ou l'entrée « Resume ». Sous-tâche concernée : 4a.
8. **Préférence de fenêtre (1, 3 ou 5 min).** Par défaut : une fenêtre fixe de 60 s. La préférence est une sous-tâche optionnelle, à faire en dernier (1c).
9. **Sortie de compilation.** `bin/` est suivi par git (par exemple `bin/gen/.../UnitTests.mcgen`), et la fiche interdit de modifier ces fichiers. Par défaut : les agents compilent vers `bin/` avec la commande de la fiche, mais **ne commitent jamais `bin/`**. Il faut vérifier `git status` avant chaque commit. On peut aussi compiler hors du dépôt, avec `-o /tmp/glidator-build/Glidator.prg` ; je n'ai pas vérifié où `monkeyc` écrit alors `gen/`.

## Méthode et limites

- **Code** : lecture intégrale de `source/*.mc`. Les références `fichier:ligne` correspondent au commit `c51b919`.
- **TCX** : je n'ai pas pu exécuter Python dans cette session (autorisation refusée). Les chiffres viennent de comptages exacts par recherche de motifs dans le fichier (`Grep`) et de la lecture d'extraits. Tous les points de trace ont le même format (17 lignes), ce qui permet d'en déduire les index. **Je n'ai pas pu recalculer** la distance GPS (4011 m) ni la médiane de +636 m/h annoncées par le plan. Je les reprends telles quelles, et le script de la sous-tâche 5b devra les recalculer.
- **Doc Garmin** consultée le 29/09/2026 (liens en fin de note).

## Chiffres tirés du TCX (faits)

| Mesure | Valeur | Comment |
|---|---|---|
| Laps | 2 : montée à 10:18:43 (7302 s, 3904,6 m), vol à 12:20:25 (3250 s, 22 756 m) | Balises `<Lap>`, l. 12 et 37620 |
| Points de trace | 4311 au total ; **2211** pour la montée (l. 26 à 37612) et 2100 pour le vol | Comptage de `<Trackpoint>` |
| Intervalle moyen | montée : 7302 / 2211 = **3,3 s** ; vol : 3250 / 2100 = 1,5 s | Calcul |
| Vitesse nulle, montée | **1748 / 2211 = 79,1 %** | Comptage de `<ns3:Speed>0.0` ; le 1748ᵉ est à la l. 37609, dernier point du lap 1 |
| Vitesse nulle, vol | 130 / 2100 = 6,2 %, surtout au décollage | 1878 − 1748 |
| Positions | 4311 / 4311 présentes, toutes en lat. 46.x et lon. 6.x ou 7.x | Comptages |
| Vitesse moyenne de la montée | 0,535 m/s (1,9 km/h, arrêts compris) | `AvgSpeed` du lap 1 |
| Sport | `Activity Sport="Other"` | l. 10 |

**Extrait représentatif** (l. 17027 à 17526, 11:07:41 → 11:08:48, soit 67 s) :
- L'altitude monte de 2253,0 à 2262,6 m, soit **+9,6 m, donc +516 m/h**. Elle évolue par pas de 0,2 m, avec des retours en arrière : 2255,4 puis 2255,2 puis 2255,4.
- La distance enregistrée passe de 2254,5 à 2324,05 m, soit **69,5 m, donc 1,04 m/s, soit un pace de 16:04/km**.
- Pendant ce temps, **14 points sur 29 ont une vitesse instantanée nulle**, alors que la distance progresse. Exemple : de 11:08:21 à 11:08:27, +2,4 m, avec une vitesse à 0 aux deux points.
- Un seul pas de 0,2 m en 1 s (11:07:53 → 11:07:54) vaut 0,2 × 3600 = **720 m/h**. C'est l'amplitude du saut observé sur la montre.

**Conclusion (avis)** : Δaltitude/Δt et Δ`elapsedDistance`/Δt sur 60 s donnent des valeurs lisibles et cohérentes avec la pente. La vitesse instantanée, elle, est inutilisable en marche raide.

---

## 1. Vitesse verticale de marche

### Cause : confirmée
- `HikePaceView.mc:45-46` : `data.getVario()` × 3600.
- `getVario()` renvoie `alt - oldAlt` d'un seul tick (`WatchData.mc:38`, tick d'environ 1 Hz via `FlyInstrumentApp.onSensor()`, `FlyInstrumentApp.mc:207-211`).
- L'altitude est quantifiée à 0,2 m (TCX). Chaque pas vaut donc ±720 m/h, alors que le signal utile tourne autour de 500 à 650 m/h.

### Solution
- **Nouvelle classe pure `HikeHistory`** (`source/HikeHistory.mc`, fichier nouveau). C'est un buffer circulaire de 60 échantillons `(tMs, alt, dist)`, avec un échantillon au plus toutes les 5 s, soit 5 min d'historique.
  - `add(tMs, alt, dist)` ignore l'échantillon si `alt == null` ou si moins de 5000 ms se sont écoulées depuis le précédent. Il appelle `reset()` si plus de 15 000 ms se sont écoulées (trou ou pause). `dist` peut valoir `null` : sans session, il n'y a pas d'`elapsedDistance`.
  - `verticalSpeedMh(nowMs, windowMs)` fait une **régression linéaire** de l'altitude en fonction du temps, sur les échantillons de la fenêtre (`t >= nowMs - windowMs`), en temps relatif en secondes. Les valeurs sont centrées sur les moyennes, parce que les `Float` Monkey C sont en 32 bits. La fonction renvoie `null` si la fenêtre compte moins de 3 points ou couvre moins de 20 s.
  - `speedMps(nowMs, windowMs)` renvoie (dist_fin − dist_début) / Δt sur la même fenêtre, en ne prenant que les échantillons dont `dist` n'est pas `null`. Mêmes règles pour renvoyer `null`. Elle sert au point 2.
  - Avis : la régression est préférable à une différence entre deux points, parce que les points sont irréguliers et quantifiés. D'après la veille, une SMA des dérivées revient à une différence entre deux points. Coût : environ 12 points par fenêtre de 60 s, ce qui est négligeable.
- **`WatchData`** : ajouter un champ `hikeHistory = new HikeHistory()` et trois méthodes : `recordHikeSample()`, `getHikeVerticalSpeed()` et `getHikeSpeed()`. `recordHikeSample()` **lit** `getAltitude()` et `getDistance()` sans les modifier. **Aucune modification** de `endMeasure()`, `getVario()`, `oldAlt` ni `getAltitude()`.
- **`FlyInstrumentApp.onSensor()`** : après `mainView.updateData()`, appeler `mainView.data.recordHikeSample()` **sauf si la session est en pause** (`$.hasActiveSession() && !$.isRecording()`). Le reset après un trou de 15 s traite la reprise (point à trancher n° 2).
- **`HikePaceView`** : remplacer `getVario()` par `getHikeVerticalSpeed()`. L'affichage passe par `formatVerticalSpeed(mh)` dans `Utils.mc` : `--` si `null`, sinon valeur arrondie à 10 m/h avec son signe (`+640`, `-130`, `0`). L'arrondi à 10 m/h est un choix fait seul, pour limiter le scintillement ; il est facile à changer.

### Sous-tâches

```
- [codeur] Marche 1a : classe HikeHistory (vitesse verticale par régression sur 60 s) + tests
  Objectif : créer source/HikeHistory.mc, une classe pure sans accès capteur : buffer circulaire de 60 échantillons
  (tMs, alt, dist), 1 échantillon / 5 s au plus, reset() automatique si trou > 15 s ; méthodes add(tMs, alt, dist),
  reset(), verticalSpeedMh(nowMs, windowMs) par régression linéaire (null si < 3 points ou < 20 s couverts),
  speedMps(nowMs, windowMs) par Δdist/Δt (null si dist absente ou fenêtre trop courte).
  Fichiers : source/HikeHistory.mc (nouveau), source/Tests.mc.
  Tests (Tests.mc, séries synthétiques avec timestamps injectés, 1 point / 5 s) :
    montée constante 600 m/h sur 120 s -> 600 ± 1 ; même montée quantifiée à 0,2 m avec bruit alterné ±0,2 m -> 600 ± 30 ;
    altitude constante -> 0 ± 5 ; descente 1200 m/h -> -1200 ± 5 ; 60 s de montée puis 60 s à plat -> |v| < 30 (fenêtre) ;
    un seul point ou 15 s de données -> null ; trou de 20 s -> null juste après (reset) ;
    speedMps : distance +1,04 m/s -> 1,04 ± 0,01 ; distance constante -> 0 ; dist null -> null.
  Commandes : monkeyc -f monkey.jungle -o bin/Glidator.prg -d fenix6pro -y developer_key -t
  puis monkeydo bin/Glidator.prg fenix6pro -t (SDK pas encore installé : sinon, laisser les commandes dans la PR).
  Critère de fin : HikeHistory.mc et ses tests commités ; tests verts si le SDK est disponible ; aucun fichier existant
  modifié hors Tests.mc ; bin/ non commité.
  Taille estimée : 2 h.
  Hors périmètre : WatchData, vues, vario de vol.
- [codeur] Marche 1b : brancher la vitesse verticale de marche dans WatchData et HikePaceView
  Objectif : WatchData gagne un champ hikeHistory et les méthodes recordHikeSample() (lit getAltitude() et getDistance(),
  horodate avec Sys.getTimer()), getHikeVerticalSpeed() (fenêtre 60 s) et getHikeSpeed() (fenêtre 60 s).
  FlyInstrumentApp.onSensor() appelle mainView.data.recordHikeSample() après mainView.updateData(), sauf en pause
  ($.hasActiveSession() && !$.isRecording()). HikePaceView.onUpdate() affiche getHikeVerticalSpeed() via une nouvelle
  fonction formatVerticalSpeed(mh) de Utils.mc ("--" si null, arrondi à 10 m/h, signe "+" si > 0).
  Fichiers : source/WatchData.mc (ajouts uniquement), source/FlyInstrumentApp.mc (onSensor), source/HikePaceView.mc
  (lignes 43-46), source/Utils.mc, source/Tests.mc.
  Tests : formatVerticalSpeed(null) = "--", (636.4) = "+640", (-129.0) = "-130", (0.0) = "0" ;
  WatchData.recordHikeSample() avec activityData simulé (même technique que testWatchDataAccessorsFallBackToActivityData).
  Critère de fin : tests verts si SDK dispo ; `git diff origin/hikeandfly -- source/FlyInstrumentView.mc` vide ;
  endMeasure(), getVario(), oldAlt et getAltitude() identiques à hikeandfly (diff relu) ; vérification manuelle par
  l'utilisateur au simulateur (Playback du GPX) : VERT. SPD. stable autour de 500-650 m/h en montée, vario de vol inchangé.
  Taille estimée : 1 h 30.
  Hors périmètre : pace (tâche 2b), préférences, vario de vol.
- [codeur] Marche 1c (optionnel) : préférence de fenêtre 1 / 3 / 5 min
  Objectif : entrée « Fenêtre VS » dans le menu MENU (onMenu, FlyInstrumentDelegate.mc:213-227) avec 3 choix, stockée
  comme la préférence beep (Preferences.mc) ; getHikeVerticalSpeed() lit la fenêtre (défaut 60 s ; 5 min = capacité max
  du buffer).
  Fichiers : source/Preferences.mc, source/FlyInstrumentDelegate.mc (onMenu, MyMenu2PreferencesDelegate), source/WatchData.mc,
  resources/strings/strings.xml si libellés.
  Tests : Preferences : valeur par défaut 60000 ms quand rien n'est stocké ; HikeHistory.verticalSpeedMh avec fenêtre 300 s.
  Critère de fin : tests verts si SDK dispo ; choix visible et persistant au simulateur (vérif. utilisateur).
  Taille estimée : 2 h.
  Hors périmètre : autres préférences, vario de vol.
```

---

## 2. Pace de marche vide

### Cause : confirmée, avec une précision
- **`speed` à `null`** : `updateSensorInfo()` enregistre `data["speed"] = info.speed` dès que le champ existe (`WatchData.mc:193-196`). Or `Sensor.Info.speed` peut être `null` (doc Garmin). `getSpeed()` teste d'abord `sensorData.hasKey("speed")` (`WatchData.mc:234-237`) : la clé existe, donc la fonction renvoie `null` sans passer au GPS. C'est confirmé par la lecture du code. Que la valeur soit **réellement** `null` sans capteur au pied est très probable, mais reste à vérifier au simulateur. `updateInfo()` (l. 88-91) et `updateActivityInfo()` (l. 136-139) ont le même motif.
- **Même corrigée**, la vitesse instantanée vaut 0 sur **79,1 %** des points de la montée (TCX), et le calcul `HikePaceView.mc:50` affiche alors `--:--`.
- **Bug d'arrondi confirmé** : `HikePaceView.mc:52-54`. On tronque les minutes, puis on arrondit les secondes : pour 5,995 min/km, on obtient `5:60`.

### Solution
- N'enregistrer la clé `speed` que si la valeur n'est pas `null`, dans les trois fonctions `update*`. Les clés d'altitude ne changent pas. Le test existant `testWatchDataAccessorsFallBackToActivityData` (`Tests.mc:68-101`) reste valable : il utilise des valeurs non nulles.
  - **Effet de bord à vérifier** : la vitesse de la vue vol (`FlyInstrumentView.mc:71-77`) passera d'absente à la vitesse GPS. Le code de la vue ne change pas, seule la source de donnée change. C'est l'effet voulu par le plan.
- Le **pace de marche** vient de `getHikeSpeed()` (buffer du point 1, Δ`elapsedDistance`/Δt sur 60 s). `elapsedDistance` progresse même quand la vitesse vaut 0 (TCX, extrait ci-dessus).
- `formatPace(speedMps)` dans `Utils.mc` : `--:--` si `null`, ou si la vitesse est inférieure à 1000/3600 m/s (pace au-delà de 60 min/km). Sinon, on arrondit **le total en secondes** avant de découper : `s = round(1000/v)`, puis `m = s / 60` et `s % 60`. Sans session, `elapsedDistance` n'existe pas : le pace affiche `--:--`, comme le chrono aujourd'hui.

### Sous-tâches

```
- [codeur] Marche 2a : ne plus masquer la vitesse GPS par une clé speed nulle
  Objectif : dans WatchData.updateInfo (l. 88-91), updateActivityInfo (l. 136-139) et updateSensorInfo (l. 193-196),
  n'écrire data["speed"] que si la valeur n'est pas null. Aucune autre clé modifiée (altitude en particulier).
  Fichiers : source/WatchData.mc, source/Tests.mc.
  Tests : nouveau test : sensorData = {} (clé absente) + gpsData = {"speed" => 1.5} -> getSpeed() = 1.5 ;
  test existant testWatchDataAccessorsFallBackToActivityData toujours vert. Test d'intégration des update*() impossible
  sans objet Info réel : relecture du diff + vérif. simulateur.
  Critère de fin : tests verts si SDK dispo ; diff limité aux 3 blocs speed ; vérif. utilisateur au simulateur : la vitesse
  (km/h) s'affiche sur la vue vol ; vario inchangé.
  Taille estimée : 1 h.
  Hors périmètre : ordre de priorité de getSpeed(), vario de vol, getAltitude().
- [codeur] Marche 2b : pace sur 60 s + formatPace testé (fin du « 5:60 »)
  Objectif : ajouter formatPace(speedMps) dans Utils.mc (arrondi du total en secondes, "--:--" si null ou pace > 60 min/km) ;
  HikePaceView.onUpdate (l. 48-55) utilise data.getHikeSpeed() (tâche 1b) + formatPace() à la place de getSpeed().
  Fichiers : source/Utils.mc, source/HikePaceView.mc, source/Tests.mc.
  Tests : formatPace(null) = "--:--" ; formatPace(0.0) = "--:--" ; formatPace(0.25) = "--:--" (66:40/km) ;
  formatPace(1000.0/300.0) = "5:00" ; formatPace(1000.0/359.6) = "6:00" (cas 5:60) ; formatPace(1.04) = "16:02" ;
  formatPace(1000.0/3600.0) = "60:00" (borne incluse).
  Critère de fin : tests verts si SDK dispo ; HikePaceView n'appelle plus getSpeed() ni getVario() ; vérif. utilisateur
  au simulateur : PACE affiché en montée (ordre de 15-20 min/km sur le GPX de Salvan).
  Taille estimée : 1 h 30.
  Dépend de : 1a, 1b.
  Hors périmètre : pace moyen, vue vol.
```

---

## 3. La carte n'affiche rien

### Cause : plausible, non prouvée par le TCX
- **Fait (code)** : `BreadcrumbTrail.update()` ne rejette que `null` (`BreadcrumbTrail.mc:25-28`). La trace est alimentée **dès le lancement de l'app**, session ou pas, et sans condition de qualité (`FlyInstrumentApp.mc:210`). `accuracy` est bien lu (`WatchData.mc:75-78`), mais aucune méthode ne le lit ensuite.
- **Fait (forum Garmin)** : sans fix, `Position.getInfo().position` peut renvoyer lat./lon. = 180°. Le premier point enregistré serait alors (180, 180). Le premier vrai point est à plus de 15 m de celui-ci, donc il est accepté, comme tous les suivants.
- **Conséquence (avis, raisonnement sur `WatchDisplay.map`, l. 548-580)** : la bbox couvre de 46° à 180°. Toute la montée, environ 4 km, tient alors dans moins d'un pixel, et on ne voit qu'un trait vers le bord. Avec 250 points et 15 m minimum entre deux points, le point aberrant n'est évincé du buffer qu'après au moins 3,75 km, soit presque toute la montée. C'est cohérent avec « la carte n'affiche rien » en marche.
- **Ce que le TCX ne peut pas montrer** : il ne contient que les points de la **session**, et ils sont tous valides (4311/4311, en 46.x / 6-7.x). Le premier point, à 10:18:43, a déjà un fix et une vitesse de 1,2 m/s. Les positions lues par l'app **avant** le démarrage de la session ne sont pas enregistrées. D'où la vérification au simulateur (sous-tâche 3a).
- **Défaut secondaire confirmé** : `map()` affiche « Waiting for GPS » dès que la position courante est `null` (`WatchDisplay.mc:534-540`), même si une trace existe. Une fois le filtrage de qualité en place, une perte de fix passagère effacerait donc toute la carte.
- **Limite, pas un bug** : 250 points à 15 m minimum couvrent au moins 3,75 km. En vol (22,7 km), seule la fin est visible.

### Solution
- `WatchData` : `getAccuracy()` et `hasUsableFix()`. Cette dernière exige `accuracy >= MIN_MAP_QUALITY` (constante, par défaut `Position.QUALITY_USABLE`, point à trancher n° 1), des lat./lon. non nulles et dans les bornes (−90 < lat < 90, −180 < lon < 180, bornes exclues, ce qui écarte 180), et l'absence de (0, 0).
- `BreadcrumbTrail.update()` : contrôle de bornes interne, via une fonction pure `isValidLatLon(lat, lon)`. On se protège ainsi même si l'appelant oublie le filtre.
- `FlyInstrumentApp.onSensor()` : n'appeler `breadcrumbTrail.update(...)` que si `hasUsableFix()` est vrai.
- `HikeMapView` : ne passer la position courante à `map()` que si `hasUsableFix()` est vrai, sinon `null`.
- `WatchDisplay.map()` : si la position courante est `null` mais que `count > 0`, dessiner la trace sans marqueur. « Waiting for GPS » ne s'affiche que si `count == 0` et que la position courante est `null`. `map()` n'est pas dans la zone sensible.
- Optionnel (3b) : rejet des sauts, proportionnel au temps (point à trancher n° 3).
- Bonus (3c) : une barre d'échelle.

### Sous-tâches

```
- [codeur] Carte 3a : filtrer les positions invalides et garder la trace visible sans fix courant
  Objectif : WatchData.getAccuracy() et hasUsableFix() (accuracy >= constante MIN_MAP_QUALITY = Position.QUALITY_USABLE,
  lat/lon non null, |lat| < 90, |lon| < 180, pas (0,0)) ; fonction pure isValidLatLon(lat, lon) utilisée dans
  BreadcrumbTrail.update() ; FlyInstrumentApp.onSensor() n'alimente la trace que si hasUsableFix() ; HikeMapView passe
  null comme position courante sinon ; WatchDisplay.map() dessine la trace sans marqueur quand la position courante est
  null et count > 0 (« Waiting for GPS » seulement si count == 0).
  Fichiers : source/WatchData.mc (ajouts), source/BreadcrumbTrail.mc (update), source/FlyInstrumentApp.mc (onSensor),
  source/HikeMapView.mc (onUpdate), source/WatchDisplay.mc (map uniquement, l. 532-636), source/Tests.mc.
  Tests : BreadcrumbTrail : update(180.0, 180.0) et update(0.0, 0.0) ignorés (count = 0), puis update(46.118, 6.993)
  accepté ; isValidLatLon sur bornes (90, 180, -180, 0/0, 46/7) ; hasUsableFix() avec gpsData simulé pour accuracy 0,1,2,3,4
  (true seulement pour 3 et 4) ; les tests existants de décimation et de ring buffer restent verts.
  Vérif. manuelle (utilisateur) : au simulateur, avant de charger le GPX, noter via Sys.println ce que renvoie
  Position.getInfo() (lat, lon, accuracy) pour confirmer la cause ; puis Playback du GPX : la carte dessine le tracé.
  Critère de fin : tests verts si SDK dispo ; aucune modification des fonctions vario()/beep()/start()/end() de WatchDisplay
  (diff relu) ; la PR indique si la cause « 180/180 » est confirmée ou non au simulateur (ou demande à l'utilisateur de le faire).
  Taille estimée : 2 h 30.
  Hors périmètre : rendu de la carte (couleurs, rotation), capacité du buffer, vario de vol.
- [codeur] Carte 3b (optionnel) : rejet des sauts GPS proportionnel au temps
  Objectif : BreadcrumbTrail.update(lat, lon, tMs) rejette un point si sa distance au dernier point accepté dépasse
  50 m + 60 m/s × Δt (Δt en s depuis le dernier point accepté) ; tMs optionnel (null = pas de contrôle) pour garder
  les tests existants ; appel dans onSensor avec Sys.getTimer().
  Fichiers : source/BreadcrumbTrail.mc, source/FlyInstrumentApp.mc (onSensor), source/Tests.mc.
  Tests : saut de 10 km en 1 s rejeté ; même saut 300 s plus tard accepté ; point à 30 m en 1 s accepté ;
  vol simulé à 16 m/s (1 point/s) entièrement accepté ; tests existants verts.
  Critère de fin : tests verts si SDK dispo ; aucun changement de comportement pour des points à < 50 m.
  Taille estimée : 1 h.
  Dépend de : 3a.
  Hors périmètre : « mode redémarrage » avec retrait rétroactif (breadcrumb-garmin).
- [codeur] Carte 3c (bonus) : barre d'échelle sur la carte
  Objectif : dans WatchDisplay.map(), dessiner en bas une barre de longueur « ronde » (50/100/200/500 m, 1/2/5 km) choisie
  d'après scale ; fonction pure pickScaleBar(metersPerPixel, maxPixels) -> [mètres, pixels] dans Utils.mc.
  Fichiers : source/WatchDisplay.mc (map), source/Utils.mc, source/Tests.mc.
  Tests : pickScaleBar pour 3 échelles (ex. 2 m/px et 80 px max -> 100 m / 50 px).
  Critère de fin : tests verts si SDK dispo ; barre lisible sur fenix6pro et un Forerunner au simulateur (vérif. utilisateur).
  Taille estimée : 1 h 30.
  Dépend de : 3a.
  Hors périmètre : fond de carte, zoom manuel.
```

---

## 4. Vraie pause du chrono

### Cause : confirmée
- `BaseInputDelegate.onSelect()` : une session active appelle `pauseRecording()` **puis** `showQuitMenu()` (`FlyInstrumentDelegate.mc:109-124`).
- `onBack()` ne fait rien pendant une session (`FlyInstrumentDelegate.mc:154-159`).
- **Autre défaut** : `MyMenu2QuitDelegate.onBack()` **reprend** l'enregistrement (`FlyInstrumentDelegate.mc:34-38`).
- **Vibrations** : pause `VibeProfile(50, 300)`, reprise `VibeProfile(100, 300)` (`FlyInstrumentApp.mc:86-90` et `103-107`). Elles ne diffèrent que par l'intensité, ce qui est peu distinguable au poignet (avis).
- L'API de pause (`session.stop()` / `session.start()`) est déjà en place et testée (`Tests.mc:103-133`). La veille la confirme : GliderSK et freeskating font de même.

### Solution
- **Logique pure et testable** dans `FlyInstrumentApp.mc` (avis : c'est la seule façon de tester sans simulateur) :
  - `isPaused()` : `hasActiveSession() && !isRecording()`.
  - `selectAction(hasSession, recording)` : renvoie `:start`, `:pause` ou `:resume`.
  - `backAction(hasSession, recording, justSwitchedMode)` : renvoie `:none` (anti-rebond après changement de mode), `:exit` (pas de session), `:menu` (en pause) ou `:none` (en enregistrement).
- **`onSelect()`** : applique `selectAction`, **sans menu**.
- **`onBack()`** : applique `backAction`. En pause, il ouvre le menu Resume / Save / Discard. Le maintien de BACK pendant 1,5 s (`onKeyReleased`) reste inchangé. La garde des 500 ms (l. 148-152) est conservée.
- **Menu** : titre « Paused », libellé « Discard » au lieu de « Ignore » (comme le README et le plan). BACK ferme le menu et reste en pause (point à trancher n° 7). Save et Discard restent inchangés.
- **Vibrations distinctes** : pause = deux impulsions courtes (100 %, 150 ms / pause 150 ms / 100 %, 150 ms) ; reprise = une impulsion longue (100 %, 600 ms). Motifs choisis seul, faciles à ajuster.
- **Bandeau « PAUSE »** : `WatchDisplay.pauseBanner()`, un bandeau horizontal contrasté au centre-bas. Il est appelé si `$.isPaused()` dans `HikePositionView`, `HikePaceView`, `HikeMapView`, `TimeView` et `PositionView`. **`FlyInstrumentView` n'est pas modifié** (point à trancher n° 5). `timerTime` se fige tout seul (`HikePositionView` / `HikePaceView` l'affichent déjà).
- **README**, section Usage (`README.md:25-30`) : documenter SELECT (start/pause/resume), BACK en pause (menu), BACK maintenu (mode), BACK sans session (quitter).

### Sous-tâches

```
- [codeur] Pause 4a : SELECT = start/pause/resume, BACK court en pause = menu
  Objectif : ajouter dans FlyInstrumentApp.mc les fonctions pures isPaused(), selectAction(hasSession, recording)
  (:start/:pause/:resume) et backAction(hasSession, recording, justSwitchedMode) (:none/:exit/:menu) ;
  BaseInputDelegate.onSelect() et onBack() les appliquent (plus de showQuitMenu() dans onSelect) ; menu renommé
  « Paused » avec Resume / Save / Discard ; MyMenu2QuitDelegate.onBack() ferme le menu sans reprendre.
  onKeyPressed/onKeyReleased (maintien 1,5 s) inchangés.
  Fichiers : source/FlyInstrumentApp.mc (fonctions pures), source/FlyInstrumentDelegate.mc (onSelect, onBack, showQuitMenu,
  MyMenu2QuitDelegate), source/Tests.mc.
  Tests : table complète de selectAction (3 cas) et backAction (session absente/active × recording × justSwitchedMode) ;
  testSessionStateMachine existant vert ; isPaused() vrai après pauseRecording(), faux après resumeRecording().
  Critère de fin : tests verts si SDK dispo ; vérif. utilisateur au simulateur : SELECT démarre, met en pause, reprend sans
  menu ; BACK court en pause ouvre le menu ; BACK court en enregistrement ne fait rien ; maintien 1,5 s change de mode dans
  tous les états sans ouvrir le menu ni quitter.
  Taille estimée : 2 h 30.
  Hors périmètre : bandeau, vibrations (4b), auto-pause, vario de vol.
- [codeur] Pause 4b : bandeau PAUSE, vibrations distinctes, README
  Objectif : WatchDisplay.pauseBanner() (nouvelle fonction) appelée si $.isPaused() dans les onUpdate de HikePositionView,
  HikePaceView, HikeMapView, TimeView et PositionView (pas FlyInstrumentView : zone intouchable, sauf accord explicite) ;
  pauseRecording() vibre en double impulsion courte, resumeRecording() en impulsion longue ; README section Usage à jour
  (SELECT start/pause/resume, BACK en pause = menu, BACK maintenu 1,5 s = mode, BACK sans session = quitter).
  Fichiers : source/WatchDisplay.mc (ajout pauseBanner uniquement), source/HikePositionView.mc, source/HikePaceView.mc,
  source/HikeMapView.mc, source/TimeView.mc, source/PositionView.mc, source/FlyInstrumentApp.mc (pauseRecording,
  resumeRecording), README.md.
  Tests : pas de test unitaire d'affichage possible ; testSessionStateMachine vert. Vérif. utilisateur au simulateur :
  bandeau visible sur les 5 vues en pause et absent sinon ; chrono figé en pause ; vibrations différentes (sur montre).
  Critère de fin : compilation fenix6pro + un Forerunner OK si SDK dispo ; `git diff origin/hikeandfly -- source/FlyInstrumentView.mc`
  vide ; README relu.
  Taille estimée : 1 h 30.
  Dépend de : 4a.
  Hors périmètre : vue vario, menu auto 5 s après pause (freeskating), vario de vol.
```

---

## 5. Audit des données et autres bugs

### Constats
- **`onStop` jette la session : confirmé.** `FlyInstrumentApp.onStop()` appelle `$.stopRecording(false)` (`FlyInstrumentApp.mc:191`). Les chemins Save et Discard du menu remettent `session` à `null` avant `System.exit()` (`FlyInstrumentApp.mc:144`, `FlyInstrumentDelegate.mc:22-31`). Passer à `stopRecording(true)` ne touche donc **que** les fermetures non voulues (système, batterie, crash géré). C'est le motif de freeskating (veille).
- **Type d'activité** : `SPORT_FLYING` et nom « Glide » (`FlyInstrumentApp.mc:57-59`). Dans le TCX, on voit `Sport="Other"` : c'est une limite du format TCX, qui ne connaît que Running, Biking et Other. Les 2 laps manuels séparent bien la montée et le vol (TCX). On garde ce fonctionnement et on le documente.
- **Petits défauts relevés** (sans tâche dédiée, à corriger au passage si le fichier est touché) :
  - Le commentaire de `switchMode()` parle d'un « 3s hold » alors que la constante vaut 1500 ms (`FlyInstrumentApp.mc:257` vs `FlyInstrumentDelegate.mc:77`).
  - L'en-tête de `Tests.mc` (l. 4-5) donne une commande `fenix6` / `bin/tests.prg` différente de celle de la fiche.
  - En pause, un changement de mode n'ajoute pas de lap (`FlyInstrumentApp.mc:262-265`). C'est documenté dans le code et acceptable.
  - `getVario()` suppose un tick de 1 Hz. **Zone intouchable** : je le signale sans rien proposer.

### Sous-tâches

```
- [codeur] Audit 5a : sauvegarder la session si l'app est fermée par le système + documenter le type d'activité
  Objectif : FlyInstrumentApp.onStop() appelle $.stopRecording(true) au lieu de false (session active ou en pause) ;
  README : une phrase indiquant que toute la sortie est enregistrée en SPORT_FLYING (TCX : Sport="Other"), montée et vol
  séparés par un lap au changement de mode.
  Fichiers : source/FlyInstrumentApp.mc (onStop, l. 189-196), README.md.
  Tests : testSessionStateMachine vert ; pas de test unitaire de onStop possible. Vérif. utilisateur au simulateur :
  démarrer une session, la mettre en pause, fermer l'app par le simulateur -> une activité est sauvegardée ; chemins
  Save et Discard du menu inchangés (Discard ne crée pas d'activité).
  Critère de fin : diff d'une ligne dans onStop + README ; tests verts si SDK dispo.
  Taille estimée : 30 min.
  Hors périmètre : reprise d'une session après relance (non supportée par le firmware, cf. veille/freeskating).
- [codeur] Audit 5b : script tools/analyze_activity.py (hors build)
  Objectif : script Python 3 stdlib (xml.etree) qui lit un TCX et affiche, par lap : durée, nb de points, intervalle moyen,
  distance enregistrée, distance GPS (haversine), D+ (seuil d'hystérésis 1 m, paramétrable), part de vitesse à 0,
  sauts de position (> 50 m + 60 m/s × Δt, même règle que 3b), vitesse verticale sur 60 s (régression, médiane, p5, p95),
  pace sur 60 s (Δdistance/Δt, médiane), FC min/max. Option --csv pour exporter la série 60 s.
  Fichiers : tools/analyze_activity.py (nouveau), tools/test_analyze_activity.py (nouveau, mini TCX synthétique en chaîne).
  Tests : python3 -m unittest tools/test_analyze_activity.py (montée synthétique 600 m/h -> 600 ± 5 ; saut injecté détecté ;
  vitesse nulle comptée) ; sur garmin_data/activity_24346302742.tcx, lap 1 : 2211 points, 1748 vitesses nulles (79,1 %),
  distance enregistrée 3904,6 m, distance GPS ≈ 4011 m (± 2 %), médiane VS 60 s ≈ +636 m/h (± 5 %), 0 saut.
  Critère de fin : tests verts ; sortie sur le TCX de Salvan collée dans la PR ; tout écart aux chiffres du plan expliqué.
  Taille estimée : 2 h 30.
  Hors périmètre : lecture FIT, graphiques, code Monkey C.
- [chercheur] Audit 5c : comparer la montre et le script après la prochaine sortie terrain
  Objectif : quand l'utilisateur fournit une nouvelle activité (TCX + notes ou photos des valeurs affichées), lancer
  tools/analyze_activity.py et comparer VS 60 s, pace 60 s, D+ et carte avec ce que la montre affichait.
  Critère de fin : note docs/recherches/AAAA-MM-JJ-comparaison-terrain.md commitée, avec écarts chiffrés et verdict
  par correction (1 à 4).
  Taille estimée : 1 h 30.
  Dépend de : 1b, 2b, 3a, 4a, 5b et d'une sortie réelle faite par l'utilisateur.
  Note : un agent « analyste de données d'activité » (cf. docs/plan/agents-proposes.md) serait mieux indiqué ; tag
  [chercheur] gardé faute d'agent existant.
  Hors périmètre : modifier source/.
```

---

## Ordre d'exécution proposé

```
5a (quick win, isolé)
 └─ 1a → 1b → 2a → 2b        (même buffer ; HikePaceView et Tests.mc touchés en série)
      └─ 3a → 3b (opt.) → 3c (bonus)
           └─ 4a → 4b
5b en parallèle dès le début (Python, aucun fichier Monkey C commun) ; il sert à valider 1 et 2.
1c (optionnel) en dernier.
5c après la sortie terrain de l'utilisateur.
```

Justification (avis) :
- 5a est une ligne de code qui élimine un risque de perte de données. On le fait en premier.
- 1a doit précéder 1b et 2b : c'est le même buffer.
- 2a est indépendant, mais touche `WatchData.mc` comme 1b. On le place après 1b pour éviter les conflits.
- 3a, 4a et 4b touchent `FlyInstrumentApp.mc`, `WatchDisplay.mc` et `Tests.mc`. Les faire en série, sur une même branche (par exemple `claude/corrections-marche`, basée sur `hikeandfly`), évite les conflits.
- Pour 5 sous-tâches `[codeur]` par round, un découpage réaliste serait : round A = 5a, 1a, 1b, 2a, 2b, 5b ; round B = 3a, 3b, 4a, 4b.

## Impact concret sur le projet

- **Fichiers créés** : `source/HikeHistory.mc`, `tools/analyze_activity.py`, `tools/test_analyze_activity.py`.
- **Fichiers modifiés** : `WatchData.mc` (ajouts, et les 3 blocs `speed`), `FlyInstrumentApp.mc` (`onSensor`, `onStop`, pause, fonctions pures), `FlyInstrumentDelegate.mc`, `HikePaceView.mc`, `HikeMapView.mc`, `HikePositionView.mc`, `TimeView.mc`, `PositionView.mc`, `BreadcrumbTrail.mc`, `WatchDisplay.mc` (`map()` et `pauseBanner()` seulement), `Utils.mc`, `Tests.mc`, `README.md`.
- **Jamais modifiés** : `FlyInstrumentView.mc`, `WatchData.endMeasure()`, `getVario()`, `oldAlt`, `getAltitude()`, `WatchDisplay.vario()`, `beep()`, `start()`, `end()`, `manifest.xml`, `bin/`, `developer_key`.
- **Risques** :
  1. Aucune vérification possible sans le SDK. Tous les critères « tests verts » sont conditionnels, et la validation réelle repose sur l'utilisateur (simulateur et terrain).
  2. Avec 2a, la vitesse de la vue vol change de source. C'est voulu, mais visible.
  3. Avec 3a et le seuil `USABLE`, la trace peut avoir des trous sous un fix 2D.
  4. Mémoire : environ 60 × 3 valeurs en plus, ce qui est négligeable à côté des 2 × 250 de la trace (avis, non mesuré).

## Ce qui reste incertain

- **Cause de la carte vide** : l'hypothèse « 180/180 avant le fix » vient du forum Garmin et d'un raisonnement sur le code. Elle n'a été observée ni sur la montre ni au simulateur. Si la carte reste vide après 3a, il faut instrumenter `map()` (count, bbox, scale), comme le prévoit le plan.
- **`Sensor.Info.speed` réellement `null`** sans capteur au pied sur fenix6pro : la doc dit « peut être null », sans préciser quand.
- **Chiffres du plan non recalculés ici** (distance GPS de 4011 m, médiane de +636 m/h, p5/p95) : Python n'était pas autorisé dans cette session. La sous-tâche 5b doit les reproduire.
- **Seuils choisis seul** (5 s, 60 entrées, 15 s de trou, 20 s minimum, arrondi à 10 m/h, 60 m/s pour les sauts, motifs de vibration) : raisonnables mais non validés sur le terrain.
- **Emplacement de `gen/`** quand `monkeyc -o` pointe hors de `bin/` : non vérifié.
- **Compatibilité `Attention.VibeProfile` avec plusieurs segments** sur les Instinct de la liste : non vérifiée.

## Sources

- Code : `source/*.mc` au commit `c51b919` (références `fichier:ligne` dans le texte).
- Données : `garmin_data/activity_24346302742.tcx` (lignes citées).
- Veille : `docs/recherches/veille-connectiq.md` (GliderSK, My Vario, breadcrumb-garmin, freeskating, RunnersField, RunPowerWorkout, ActiveLook).
- Doc Garmin : [Toybox.Sensor.Info](https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor/Info.html) (`speed` : Float ou null), [Toybox.Position.Info](https://developer.garmin.com/connect-iq/api-docs/Toybox/Position/Info.html) (`accuracy` jamais null, `position` extrapolée entre deux fix), [Toybox.Position](https://developer.garmin.com/connect-iq/api-docs/Toybox/Position.html) (constantes `QUALITY_*`, 0 à 4), [Toybox.Lang.Float](https://developer.garmin.com/connect-iq/api-docs/Toybox/Lang/Float.html) (`abs()` depuis l'API 1.0.0).
- Forum Garmin, positions à 180° sans fix : [When the Lat and Lon location is at 180.0000…](https://forums.garmin.com/developer/connect-iq/f/discussion/356644/when-the-lat-and-lon-location-is-at-180-0000-no-error-message-is-displayed), [GPS not firing up?](https://forums.garmin.com/developer/connect-iq/f/discussion/316181/gps-not-firing-up).
