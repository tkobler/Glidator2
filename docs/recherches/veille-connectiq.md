# Veille Connect IQ : comment les apps open source traitent vitesse verticale, pace, GPS invalide et pause

*Note de recherche, 29/09/2026. Contexte : plan des corrections Glidator2 après le test de Salvan (13/09/2026).*

## Question

Comment les applications Connect IQ open source (vario, rando/course, trace sur carte, enregistrement d'activité) :
1. calculent-elles une **vitesse verticale** lisible à faible taux de montée ;
2. calculent-elles le **pace** ;
3. **filtrent-elles les positions GPS invalides** (qualité, coordonnées aberrantes, sauts) ;
4. gèrent-elles la **pause / reprise** du chrono et de la session `ActivityRecording` ?

But : valider ou ajuster les choix du plan de corrections (tâches 1 à 5) avant de coder.

## Réponse courte / recommandation

**Confiance : moyenne à élevée** sur les principes. Elle est **moyenne** sur le détail des extraits : voir la méthode, plus bas.

- **Vitesse verticale de marche** : aucune des apps lues ne dérive la vitesse verticale d'un simple `alt - oldAlt` par tick sans lissage, sauf RunPowerWorkout. Toutes lissent sur une fenêtre : moyenne glissante jusqu'à 60 s (GliderSK), filtre de Kalman altitude/vitesse/accélération (My Vario), différence sur 20 échantillons de `totalAscent` (ActiveLook) ou différence sur 15 s (freeskating). **La régression sur 60 s prévue par le plan est cohérente avec ces pratiques.** Une différence simple entre deux points sur 60 s serait une alternative plus simple et presque équivalente. Le contre-exemple est RunPowerWorkout : fenêtre de 5 échantillons et altitude tronquée au mètre, ce qui donne des marches de 720 m/h. C'est exactement le problème de Glidator2.
- **Pace** : les datafields de course lissent `currentSpeed` (moyenne des 10 dernières valeurs dans RunnersField) et affichent un pace nul sous un seuil de vitesse (0,2 m/s). Sur la montée de Salvan, `currentSpeed` vaut 0 sur 79 % des points : **moyenner `currentSpeed` ne suffirait pas**. Le Δ`elapsedDistance`/Δt prévu par le plan reste le bon choix. C'est mon avis : aucune app lue ne le fait pour le pace, mais freeskating utilise un historique de distance pour la pente.
- **GPS invalide** : GliderSK et My Vario rejettent `QUALITY_NOT_AVAILABLE`, ainsi que `QUALITY_LAST_KNOWN` tant qu'aucun vrai fix n'a été reçu, et exigent un horodatage `when`. breadcrumb-garmin ne regarde pas la qualité. Il filtre par la géométrie : NaN, distance minimale, saut maximal de 400 m, et « mode redémarrage » après reprise, qui retire les points douteux. **Le seuil `>= QUALITY_USABLE` du plan est plus strict que GliderSK**, qui accepte `POOR`. C'est défendable pour une carte. Ajouter un rejet de saut serait peu coûteux et utile.
- **Pause** : **freeskating implémente presque exactement l'ergonomie visée par la tâche 4.** SELECT alterne démarrer, pause et reprise. BACK en pause ouvre le menu Resume/Save/Discard. Le menu s'ouvre aussi seul 5 s après la pause. Et surtout, `onStop()` **sauvegarde** une session en cours ou en pause (tâche 5). Côté API, GliderSK et freeskating font tous deux la pause par `session.stop()` et la reprise par `session.start()`, comme Glidator2 aujourd'hui.
- **Licences** : ne pas copier de code. Glidator2 n'a pas de fichier LICENSE. Les sources lues sont sous GPLv3, CC BY-NC-SA, MIT, Apache-2.0, ou sans licence (freeskating). Il faut réimplémenter les idées, pas coller le code.

## Méthode et limites de vérification

- Je n'ai pas pu cloner les dépôts ni utiliser `curl` ou `gh` : ces commandes n'étaient pas autorisées dans cette session. Le code a été lu par récupération web des fichiers bruts (`raw.githubusercontent.com`), via un outil qui restitue le contenu à travers un modèle de résumé. J'ai demandé des extraits **verbatim**, mais **ils peuvent différer à la marge du source réel** : indentation, ou un mot. À revérifier avant toute réutilisation.
- **Numéros de ligne non vérifiés** : les liens pointent vers le **fichier au commit indiqué** (permalien par SHA) et nomment la fonction. Ils ne donnent pas de numéro de ligne, car je ne pouvais pas les obtenir de façon fiable.
- Les SHA sont ceux du dernier commit de la branche par défaut, relevés le 29/09/2026 via l'API GitHub.

---

## Dépôts étudiés

| # | Dépôt | Type | Licence | Dernier commit lu |
|---|---|---|---|---|
| 1 | [cedric-dufour/connectiq-app-glidersk](https://github.com/cedric-dufour/connectiq-app-glidersk) | Watch-app vol à voile (vario, log, enregistrement) | GPLv3 | `d050287` (06/12/2022) |
| 2 | [ydutertre/myvario](https://github.com/ydutertre/myvario) | Watch-app vol libre (fork de GliderSK, Kalman, carte, livetrack) | GPLv3 | `7112cd6` (29/08/2026) |
| 3 | [pauljohnston2025/breadcrumb-garmin](https://github.com/pauljohnston2025/breadcrumb-garmin) | Datafield / app trace sur carte | CC BY-NC-SA 4.0 | `814bf1e` (28/09/2026) |
| 4 | [seriv/freeskating](https://github.com/seriv/freeskating) | Watch-app avec `ActivityRecording` et menu pause | **Aucune licence visible** | `2bc76fc` (14/09/2026) |
| 5 | [kopa/RunnersField](https://github.com/kopa/RunnersField) | Datafield course (pace) | MIT | `e970686` (02/10/2016) |
| 6 | [tommyvdz/RunPowerWorkout](https://github.com/tommyvdz/RunPowerWorkout) | Datafield course (VAM, pause) | GPLv3 | `edad087` (05/06/2023) |
| 7 | [ActiveLook/Garmin-Datafield-sample-code](https://github.com/ActiveLook/Garmin-Datafield-sample-code) | Datafield (vitesse d'ascension m/h) | Apache-2.0 | `6d43de2` (06/10/2025) |

---

### 1. GliderSK (cedric-dufour/connectiq-app-glidersk)

Fichiers : [`source/MyProcessing.mc`](https://github.com/cedric-dufour/connectiq-app-glidersk/blob/d050287eaab06e47ae7f2137258deb5bca598ede/source/MyProcessing.mc), [`source/MyFilter.mc`](https://github.com/cedric-dufour/connectiq-app-glidersk/blob/d050287eaab06e47ae7f2137258deb5bca598ede/source/MyFilter.mc), [`source/MyActivity.mc`](https://github.com/cedric-dufour/connectiq-app-glidersk/blob/d050287eaab06e47ae7f2137258deb5bca598ede/source/MyActivity.mc), [`source/MyApp.mc`](https://github.com/cedric-dufour/connectiq-app-glidersk/blob/d050287eaab06e47ae7f2137258deb5bca598ede/source/MyApp.mc)

**Vitesse verticale.** Dans `processSensorInfo()` (MyProcessing.mc), l'app calcule d'abord un vario brut Δalt/Δt, avec le temps en secondes epoch. Elle le passe ensuite dans une **moyenne glissante simple (SMA)**, dont la longueur est le réglage « Time Constant » (0 à 60 s, [USAGE](https://github.com/cedric-dufour/connectiq-app-glidersk/blob/d050287eaab06e47ae7f2137258deb5bca598ede/USAGE)). Un mode « énergétique » compense aussi la vitesse. Il n'est pas pertinent pour la marche.
```
self.fVariometer = (self.fAltitude-self.fPreviousAltitude) / (_iEpoch-self.iPreviousAltitudeEpoch);
self.fVariometer_filtered = $.oMyFilter.filterValue(MyFilter.VARIOMETER, self.fVariometer);
```
Dans `MyFilter.filterValue()`, la SMA est un tampon circulaire (`MAX_SIZE = 61`) avec une somme courante, qu'on incrémente et décrémente :
```
self.aaFilters[_F][3] += _fValue;
if(fValue_previous != null) { self.aaFilters[_F][3] -= fValue_previous; ... }
return (self.aaFilters[_F][3] as Float)/(iValues_quantity as Number);
```
Remarque (avis) : la moyenne de N dérivées successives se simplifie en (alt_fin − alt_début)/durée. C'est donc une différence entre deux points sur la fenêtre.

**Pace.** Non traité : c'est un planeur. La vitesse sol vient directement de `Position.Info.speed`, lissée par la même SMA (`MyFilter.GROUNDSPEED`).

**Filtrage GPS invalide.** Dans `processPositionInfo()` :
```
if(self.iAccuracy == Pos.QUALITY_NOT_AVAILABLE or (self.iAccuracy == Pos.QUALITY_LAST_KNOWN and self.iPositionEpoch < 0)) {
  self.iAccuracy = Pos.QUALITY_NOT_AVAILABLE;
  return;
}
```
La position est aussi rejetée si `:accuracy` ou `:when` sont absents ou `null`. Un commentaire signale que `when` est un temps GPS, pas un epoch UTC. `POOR` est accepté. Je n'ai vu aucun rejet de saut ni aucun contrôle de bornes lat/lon.

**Pause.** Dans `MyActivity.mc`, la pause est `session.stop()` et la reprise `session.start()`, chacune accompagnée d'un bip distinct :
```
function pause() as Void {
  if(!self.oSession.isRecording()) { return; }
  self.oSession.stop();
  if(Toybox.Attention has :playTone) { Attn.playTone(Attn.TONE_STOP); }
}
```
Une option d'**auto-pause par vitesse** existe dans `onLocationEvent()` (MyApp.mc) : pause sous `fActivityAutoSpeedStop`, puis `addLap()` et `resume()` au-dessus de `fActivityAutoSpeedStart`, avec hystérésis. `onStop()` arrête les timers et le GPS mais **ne sauvegarde pas** la session (source lue). Je n'ai pas vérifié ce qu'il advient alors du FIT.

### 2. My Vario (ydutertre/myvario)

Fichiers : [`source/MyKalmanFilter.mc`](https://github.com/ydutertre/myvario/blob/7112cd6ec7a73ee62ec621e965d7143d9e940db4/source/MyKalmanFilter.mc), [`source/MyProcessing.mc`](https://github.com/ydutertre/myvario/blob/7112cd6ec7a73ee62ec621e965d7143d9e940db4/source/MyProcessing.mc), [`source/MyApp.mc`](https://github.com/ydutertre/myvario/blob/7112cd6ec7a73ee62ec621e965d7143d9e940db4/source/MyApp.mc)

**Vitesse verticale.** Le calcul brut Δalt/Δt reste celui de GliderSK, mais le vario affiché vient d'un **filtre de Kalman** à trois états : altitude, vitesse verticale, accélération. Le bruit de processus vaut `ACCELERATION_VARIANCE = 0.36` et le bruit de mesure vaut `fVariometerSmoothing²`, un réglage utilisateur. Dans `processSensorInfo()` :
```
if($.oMyKalmanFilter.bFilterReady) {
  $.oMyKalmanFilter.update(fAltitude, 0, _iEpoch);
  self.fVariometer_filtered = $.oMyKalmanFilter.fVelocity;
  self.fAltitude = $.oMyKalmanFilter.fPosition;
}
```
Cœur de la correction, dans `MyKalmanFilter.update` :
```
var s = self.p11 + fAltitudeVariance;
var k11 = self.p11 / s;
var k12 = self.p12 / s;
var y = _fPosition - self.fPosition;
self.fPosition += k11 * y;
self.fVelocity += k12 * y;
```
**Pace.** Non traité. La vitesse sol est lue directement dans `Position.Info.speed`.

**Filtrage GPS invalide.** Même garde que GliderSK (`QUALITY_NOT_AVAILABLE` / `LAST_KNOWN` avant premier fix). La vue carte (`MyViewMap.mc`) existe, mais je ne l'ai pas lue : je ne sais pas si elle ajoute un filtrage.

**Pause.** L'auto-start par vitesse existe dans `onLocationEvent()`. Dans la version lue, je n'ai pas vu d'auto-pause. `onStop()` ne sauvegarde pas la session.

### 3. breadcrumb-garmin (pauljohnston2025/breadcrumb-garmin)

Fichiers : [`source/BreadcrumbTrack.mc`](https://github.com/pauljohnston2025/breadcrumb-garmin/blob/814bf1e5e84c48dea9dbc5d0181b2070fe85163f/source/BreadcrumbTrack.mc), [`source/PointArray.mc`](https://github.com/pauljohnston2025/breadcrumb-garmin/blob/814bf1e5e84c48dea9dbc5d0181b2070fe85163f/source/PointArray.mc), [`source/BreadcrumbView.mc`](https://github.com/pauljohnston2025/breadcrumb-garmin/blob/814bf1e5e84c48dea9dbc5d0181b2070fe85163f/source/BreadcrumbView.mc)

**Vitesse verticale.** Non traité, en dehors du min/max d'altitude pour un profil.

**Pace.** Non traité.

**Filtrage GPS invalide.** C'est le point fort de ce dépôt. Il ne regarde **pas** `accuracy`. Il procède par étapes :
1. `pointFromActivityInfo()` lit `Activity.Info.currentLocation` et retourne `null` si la position ou l'altitude sont `null`.
2. `latLon2xy()` projette en Mercator et rejette les points NaN (`point.valid()`). Il n'y a pas de contrôle de bornes lat/lon.
3. `onActivityInfo()` ignore les points pendant que le chrono est arrêté. Il ignore aussi les points trop proches (`minDistanceMScaled`, 5 m par défaut) et les **sauts trop grands** (`maxDistanceMScaled`, `STABILITY_MAX_DISTANCE_M = 400`) :
```
function onActivityInfo(newScaledPoint as RectangularPoint) as [Boolean, Boolean] {
    if (timerStopped) { return [false, false]; }
    if (inRestartMode) { return handlePointAddStartup(newScaledPoint); }
    ...
    if (distance < minDistanceMScaled) { return [false, false]; }
    if (distance > maxDistanceMScaled) { return [false, false]; }
    return [true, addPointRaw(newScaledPoint, distance)];
}
```
4. Après un (re)démarrage, `handlePointAddStartup()` compte `RESTART_STABILITY_POINT_COUNT = 10` points « suspects ». Si un saut de plus de 400 m survient pendant cette phase, il **retire rétroactivement** ces points (`coordinates.removeLastCountPoints(possibleBadPointsAdded)`).
5. La bounding box est mise à jour de façon incrémentale dans `updateBoundingBox()`, par min/max sur chaque point accepté.

**Pause.** `onTimerStop()` pose `timerStopped = true`. Ensuite, `onStartResume()` réinitialise les compteurs et passe en `inRestartMode` : la trace ne relie pas aveuglément le point d'avant la pause au premier point après.

### 4. freeskating (seriv/freeskating)

Fichiers : [`source/FreeskateDelegate.mc`](https://github.com/seriv/freeskating/blob/2bc76fcc902838da8f02104e604345e11337c811/source/FreeskateDelegate.mc), [`source/ActivityController.mc`](https://github.com/seriv/freeskating/blob/2bc76fcc902838da8f02104e604345e11337c811/source/ActivityController.mc), [`source/FreeskateApp.mc`](https://github.com/seriv/freeskating/blob/2bc76fcc902838da8f02104e604345e11337c811/source/FreeskateApp.mc)

**Vitesse verticale.** Pas de vitesse verticale. En revanche, la **pente** est calculée sur une fenêtre glissante de 15 s, avec des historiques de distance et d'altitude, et seulement si le déplacement horizontal dépasse 5 m. C'est le même schéma de buffer que `HikeHistory` :
```
if (mHistoryCount >= GRADE_WINDOW_SECONDS) {
    var distanceDelta = distance - oldestDistance;
    if (distanceDelta > 5.0) {
        mCurrentGradePercent = ((altitude - oldestAltitude) / distanceDelta) * 100.0;
    }
}
```
**Pace.** Pas de pace. La vitesse est `info.currentSpeed` brute.

**Filtrage GPS invalide.** `posInfo.accuracy` est stocké, mais je n'ai vu **aucun rejet** de point ni de saut.

**Pause.** C'est le modèle le plus proche de la tâche 4 du plan. Dans `onSelect()` :
```
} else if (state == ActivityController.STATE_RECORDING) {
    mController.pause();
    startPauseMenuCountdown();
} else if (state == ActivityController.STATE_PAUSED) {
    cancelPauseMenuCountdown();
    mController.resume();
}
```
Dans `onBack()`, en pause, `cancelPauseMenuCountdown(); showPauseMenu();` ouvre le menu Resume / Stance / Save / Discard. Pendant l'enregistrement, BACK sert de `addLap()`. Le menu s'ouvre aussi **automatiquement 5 s après la pause** (`PAUSE_MENU_DELAY_MS = 5000`). `pause()` fait `mSession.stop()` et passe à `STATE_PAUSED` ; `resume()` fait `mSession.start()`.

**Sauvegarde à la fermeture.** Dans `FreeskateApp.onStop()` :
```
// Don't silently lose a session if the app gets killed mid-recording.
if (currentState == ActivityController.STATE_RECORDING || currentState == ActivityController.STATE_PAUSED) {
    mController.stopAndSave();
}
```
Un commentaire indique qu'une option « Resume Later » a été testée et **ne fonctionne pas** sur Enduro 3 : le firmware finalise lui-même la session orpheline. Il faut donc sauvegarder ou jeter explicitement.

### 5. RunnersField (kopa/RunnersField)

Fichier : [`source/RunnersField.mc`](https://github.com/kopa/RunnersField/blob/e97068651a05605f1230ea0e556eb2353343132a/source/RunnersField.mc)

**Vitesse verticale.** Non traité.

**Pace.** Moyenne des **10 dernières valeurs** de `info.currentSpeed` (`new DataQueue(10)`, puis `computeAverageSpeed()`). Le formatage renvoie un pace nul si la vitesse est inférieure ou égale à 0,2 m/s :
```
if (speedMetersPerSecond != null && speedMetersPerSecond > 0.2) {
    var minutesPerKmOrMilesDecimal = kmOrMileInMeters / metersPerMinute;
    var minutesPerKmOrMilesFloor = minutesPerKmOrMilesDecimal.toNumber();
    var seconds = (minutesPerKmOrMilesDecimal - minutesPerKmOrMilesFloor) * 60;
    return minutesPerKmOrMilesDecimal.format("%2d") + ":" + seconds.format("%02d");
}
```
Il n'y a pas d'arrondi explicite. Les secondes sont formatées avec `%02d`, ce qui les tronque probablement (non vérifié dans la doc) : pas de « 5:60 », mais une erreur allant jusqu'à 1 s. Le pace moyen utilise directement `info.averageSpeed`.

**Filtrage GPS invalide.** `currentLocationAccuracy` sert **uniquement** à dessiner l'indicateur de signal GPS. Rien n'est filtré.

**Pause.** Non traité. Le chrono affiché est `info.timerTime`, qui se fige seul en pause.

### 6. RunPowerWorkout (tommyvdz/RunPowerWorkout)

Fichier : [`source/RunPowerWorkoutView.mc`](https://github.com/tommyvdz/RunPowerWorkout/blob/edad0875e5b3312d0672083369adc9f9f109c155/source/RunPowerWorkoutView.mc)

**Vitesse verticale (VAM).** C'est un **contre-exemple utile**. `processExtraData()` utilise un tampon circulaire de 5 altitudes **tronquées au mètre** et suppose 1 échantillon par seconde :
```
var calculatedAltitude = altitude.toNumber() - altitudeArray[index];
altitudeArray[index] = altitude.toNumber();
verticalSpeed = 25 * ((calculatedAltitude * 1.0 / arrayAltPrecision * 1.0) * 144).toNumber();
```
Comme 25 × 144 = 3600, un pas d'altitude de 1 m sur 5 s donne des sauts de 720 m/h. C'est l'ordre de grandeur du bruit observé sur Glidator2.

**Pace.** Moyennes cumulatives (step, lap, activité) de `currentSpeed`, sans fenêtre glissante.

**Filtrage GPS invalide.** Absent.

**Pause.** Callbacks de datafield `onTimerPause()`, `onTimerStop()`, `onTimerStart()` et `onTimerResume()`, qui basculent un booléen `paused`. `compute()` ne fait rien quand `paused == true` : **on gèle les calculs pendant la pause**.

### 7. ActiveLook Garmin Datafield (ActiveLook/Garmin-Datafield-sample-code)

Fichier : [`source/ActiveLookActivityInfo.mc`](https://github.com/ActiveLook/Garmin-Datafield-sample-code/blob/6d43de295b1d493457c58619942aaf98809d6410/source/ActiveLookActivityInfo.mc)

**Vitesse verticale.** Vitesse d'ascension calculée à partir de **`totalAscent`**, le D+ cumulé déjà filtré par le firmware Garmin, sur les 20 derniers échantillons, puis convertie en m/h (facteur 3600) :
```
__asSamples.add(info.totalAscent);
if (__asSamples.size() > 20) { __asSamples = __asSamples.slice(-20, null); }
...
averageAscentSpeed = (__asSamples[tmp] - __asSamples[0]).toFloat() / tmp;
```
Limites (avis) : la méthode suppose 1 Hz, divise par un nombre d'échantillons et non par un temps, et ne voit que la montée (0 en descente).

**Pace.** Pace = inverse de la vitesse, sans lissage propre.

**Filtrage GPS invalide.** Absent. **Pause** : absente.

---

## Synthèse : bonnes pratiques retenues

**Faits observés :**
1. **On lisse toujours la vitesse verticale sur une fenêtre temporelle**, de 15 à 60 s, ou avec un Kalman. Les apps qui s'en passent (RunPowerWorkout) produisent le bruit en marches d'escalier observé à Salvan.
2. **Les fenêtres sont indexées par le temps, pas par le nombre d'échantillons**, dans les apps les plus soignées : GliderSK divise par Δepoch. RunPowerWorkout et ActiveLook supposent 1 Hz.
3. **Le GPS est filtré à deux niveaux** : la qualité (GliderSK : rejet de `NOT_AVAILABLE` et de `LAST_KNOWN` avant premier fix), puis la géométrie (breadcrumb : NaN, distance minimale, saut maximal, période de stabilisation après reprise).
4. **La pause se fait par `session.stop()` et la reprise par `session.start()`**, avec un signal sonore ou vibrant distinct, et les calculs sont gelés pendant la pause (RunPowerWorkout, breadcrumb).
5. **`onStop()` doit sauvegarder** une session active ou en pause (freeskating). GliderSK et My Vario ne le font pas.

### Application aux tâches du plan de corrections

**Tâche 1, vitesse verticale de marche (`HikeHistory` + `getHikeVerticalSpeed()`).**
- Le plan est confirmé : buffer séparé, fenêtre de 60 s, horodatage par `Sys.getTimer()`, `null` sous environ 20 s de données.
- Option simple, équivalente à la SMA de GliderSK : (alt_fin − alt_début)/Δt sur 60 s. Option robuste, celle du plan : régression linéaire. Avis : la régression est préférable avec des points irréguliers (1 à 6 s) et un pas de 0,2 m. Son coût reste faible avec environ 60 entrées.
- Le Kalman de My Vario est intéressant pour le vol, mais le vol est hors périmètre. Pour la marche, il demande un réglage (variances) sans bénéfice évident par rapport à la fenêtre de 60 s.
- Alternative à évaluer : Δ(`totalAscent` − `totalDescent`)/Δt, à la manière d'ActiveLook, mais divisé par le temps. On profiterait du filtrage firmware du D+, mais son hystérésis est inconnue (non vérifié).
- Tests : reprendre le cas « altitude tronquée ou quantifiée » de RunPowerWorkout comme test négatif (bruit de ±0,2 m sur une montée de 600 m/h).

**Tâche 2, pace de marche.**
- Confirmé : ne pas lisser `currentSpeed`, qui vaut 0 sur 79 % des points. Calculer Δ`elapsedDistance`/Δt sur 60 s dans `HikeHistory`.
- Seuil d'affichage `--:--` : le plan prévoit plus de 60 min/km, soit moins de 0,278 m/s. RunnersField coupe à 0,2 m/s (83 min/km). Les deux sont raisonnables.
- Formatage : RunnersField évite « 5:60 » en tronquant. Avis : mieux vaut arrondir **le total en secondes** avant de découper (`s = round(pace_s); m = s / 60; s % 60`), puis tester dans `Utils.mc`.

**Tâche 3, carte vide.**
- Garde de qualité : GliderSK accepte `POOR` (2D) et rejette `LAST_KNOWN` avant le premier fix. Le plan exige `>= QUALITY_USABLE` (3D), ce qui est plus strict et adapté à une trace. **À trancher** (voir plus bas).
- Ajouter, en s'inspirant de breadcrumb : rejet des coordonnées hors bornes et NaN, puis **rejet des sauts** au-delà d'un seuil. Breadcrumb utilise 400 m ; en marche, un seuil lié au temps serait plus fin, par exemple 50 m/s × Δt. La décimation à 15 m existe déjà dans `BreadcrumbTrail`.
- Bbox : breadcrumb la met à jour de façon incrémentale sur les seuls points acceptés. Si `WatchDisplay.map()` recalcule la bbox sur le buffer, le filtrage à l'entrée suffit.
- Après une pause, adopter éventuellement le « mode redémarrage » de breadcrumb (quelques points de stabilisation). C'est optionnel.

**Tâche 4, vraie pause.**
- Reprendre l'ergonomie de freeskating : SELECT alterne démarrer, pause et reprise ; BACK court en pause ouvre le menu Resume/Save/Discard. **Ne pas** reprendre BACK = lap pendant l'enregistrement : BACK maintenu sert déjà au changement de mode dans Glidator2.
- API : `session.stop()` / `session.start()`, déjà utilisés par `pauseRecording()` / `resumeRecording()`.
- Signal distinct : GliderSK utilise `Attention.playTone(TONE_STOP)` et `TONE_START`. Le plan demande une vibration distincte (`Attention.vibrate` avec deux profils). Je n'ai vu aucun exemple de vibration dans les dépôts lus.
- Geler `HikeHistory` pendant la pause, à la manière de RunPowerWorkout et breadcrumb, **ou** laisser la fenêtre de 60 s se vider. **À trancher.**
- Option freeskating : ouverture automatique du menu 5 s après la pause. Elle n'est pas dans le plan ; je ne la recommande pas par défaut.

**Tâche 5, audit.**
- **`onStop` doit sauvegarder** (`stopRecording(true)`) si la session est active ou en pause : c'est le motif exact de freeskating. Le retour d'expérience de freeskating confirme qu'on ne peut pas compter sur une reprise ultérieure de la session.
- Le script `tools/analyze_activity.py` peut calculer la même régression sur 60 s et le même Δdistance/Δt pour comparer avec l'affichage de la montre.

## Ce qui reste incertain

- **Exactitude caractère par caractère des extraits** et **numéros de ligne** : non vérifiés (voir Méthode). Il faut rouvrir les permaliens avant toute réutilisation.
- La doc officielle de `ActivityRecording.Session` ne dit pas explicitement que `stop()` suivi de `start()` est une pause reprenable. Plusieurs apps l'utilisent ainsi (GliderSK, freeskating, et Glidator2 aujourd'hui) : c'est une pratique établie, pas une garantie documentée.
- Comportement d'une session non sauvegardée quand `onStop` ne fait rien (GliderSK, My Vario) : non vérifié.
- Le filtrage firmware de `totalAscent` / `totalDescent` (seuil, hystérésis) n'est pas documenté dans les pages consultées.
- `MyViewMap.mc` (My Vario) et le reste de breadcrumb (rendu, `BreadcrumbView`) n'ont pas été lus en détail.
- Je n'ai pas trouvé de watch-app de **randonnée** open source qui calcule à la fois vitesse verticale et pace sur fenêtre avec `ActivityRecording`. Les cas les plus proches sont des datafields.
- Le PR Boardsesh ([boardsesh#3466](https://github.com/boardsesh/boardsesh/pull/3466)) est présenté dans les résultats de recherche comme sauvegardant dans `onStop`. Je ne l'ai **pas lu** et ne le cite qu'à titre de piste.

## Décisions à trancher (pour l'utilisateur)

1. Seuil de qualité GPS pour la carte : `>= QUALITY_USABLE` (plan) ou `>= QUALITY_POOR` en rejetant `LAST_KNOWN` avant premier fix (GliderSK) ?
2. Pendant la pause, faut-il geler `HikeHistory` (reprise immédiate des valeurs) ou le laisser se vider (valeurs `null` pendant 20 s après la reprise) ?
3. Faut-il ajouter un rejet de sauts GPS, et avec quel seuil (fixe ou lié à Δt) ?
4. Glidator2 n'a pas de licence. S'il en adopte une, elle conditionne la possibilité de réutiliser du code GPL (GliderSK, My Vario, RunPowerWorkout). Aujourd'hui, seule la réimplémentation des idées est sûre.

## Sources

- GliderSK : [dépôt](https://github.com/cedric-dufour/connectiq-app-glidersk), [MyProcessing.mc](https://github.com/cedric-dufour/connectiq-app-glidersk/blob/d050287eaab06e47ae7f2137258deb5bca598ede/source/MyProcessing.mc), [MyFilter.mc](https://github.com/cedric-dufour/connectiq-app-glidersk/blob/d050287eaab06e47ae7f2137258deb5bca598ede/source/MyFilter.mc), [MyActivity.mc](https://github.com/cedric-dufour/connectiq-app-glidersk/blob/d050287eaab06e47ae7f2137258deb5bca598ede/source/MyActivity.mc), [MyApp.mc](https://github.com/cedric-dufour/connectiq-app-glidersk/blob/d050287eaab06e47ae7f2137258deb5bca598ede/source/MyApp.mc), [USAGE](https://github.com/cedric-dufour/connectiq-app-glidersk/blob/d050287eaab06e47ae7f2137258deb5bca598ede/USAGE)
- My Vario : [dépôt](https://github.com/ydutertre/myvario), [MyKalmanFilter.mc](https://github.com/ydutertre/myvario/blob/7112cd6ec7a73ee62ec621e965d7143d9e940db4/source/MyKalmanFilter.mc), [MyProcessing.mc](https://github.com/ydutertre/myvario/blob/7112cd6ec7a73ee62ec621e965d7143d9e940db4/source/MyProcessing.mc), [MyApp.mc](https://github.com/ydutertre/myvario/blob/7112cd6ec7a73ee62ec621e965d7143d9e940db4/source/MyApp.mc)
- breadcrumb-garmin : [dépôt](https://github.com/pauljohnston2025/breadcrumb-garmin), [BreadcrumbTrack.mc](https://github.com/pauljohnston2025/breadcrumb-garmin/blob/814bf1e5e84c48dea9dbc5d0181b2070fe85163f/source/BreadcrumbTrack.mc), [PointArray.mc](https://github.com/pauljohnston2025/breadcrumb-garmin/blob/814bf1e5e84c48dea9dbc5d0181b2070fe85163f/source/PointArray.mc), [LICENSE.txt](https://github.com/pauljohnston2025/breadcrumb-garmin/blob/814bf1e5e84c48dea9dbc5d0181b2070fe85163f/LICENSE.txt)
- freeskating : [dépôt](https://github.com/seriv/freeskating), [FreeskateDelegate.mc](https://github.com/seriv/freeskating/blob/2bc76fcc902838da8f02104e604345e11337c811/source/FreeskateDelegate.mc), [ActivityController.mc](https://github.com/seriv/freeskating/blob/2bc76fcc902838da8f02104e604345e11337c811/source/ActivityController.mc), [FreeskateApp.mc](https://github.com/seriv/freeskating/blob/2bc76fcc902838da8f02104e604345e11337c811/source/FreeskateApp.mc)
- RunnersField : [dépôt](https://github.com/kopa/RunnersField), [RunnersField.mc](https://github.com/kopa/RunnersField/blob/e97068651a05605f1230ea0e556eb2353343132a/source/RunnersField.mc)
- RunPowerWorkout : [dépôt](https://github.com/tommyvdz/RunPowerWorkout), [RunPowerWorkoutView.mc](https://github.com/tommyvdz/RunPowerWorkout/blob/edad0875e5b3312d0672083369adc9f9f109c155/source/RunPowerWorkoutView.mc)
- ActiveLook : [dépôt](https://github.com/ActiveLook/Garmin-Datafield-sample-code), [ActiveLookActivityInfo.mc](https://github.com/ActiveLook/Garmin-Datafield-sample-code/blob/6d43de295b1d493457c58619942aaf98809d6410/source/ActiveLookActivityInfo.mc)
- Doc Garmin : [Toybox.Position (constantes Quality)](https://developer.garmin.com/connect-iq/api-docs/Toybox/Position.html), [Toybox.Activity.Info](https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity/Info.html), [ActivityRecording.Session](https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording/Session.html)
- Pistes non lues : [boardsesh PR #3466](https://github.com/boardsesh/boardsesh/pull/3466), [fil forum Garmin sur le pace glissant](https://forums.garmin.com/developer/connect-iq/f/discussion/193445/info-timertime-and-info-elapseddistance)
