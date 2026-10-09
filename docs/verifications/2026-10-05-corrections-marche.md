# Vérification : corrections marche (rounds 1 et 2)

*Testeur Connect IQ, 05/10/2026. Branche `claude/corrections-marche`. Aucun fichier du projet n'a été modifié ; seule cette note est commitée.*

## Périmètre

- Base de comparaison : `origin/hikeandfly`.
- Commits vérifiés : `git log --oneline origin/hikeandfly..HEAD`, soit 20 commits, de `eeed1ae` à `2c07208`.
  - Round 1 : `.gitignore` + LICENSE (`eeed1ae`) ; sauvegarde de la session à la fermeture par le système, tâche Audit 5a (`d74bb91`..`369a9b2`) ; Marche 1a, classe HikeHistory (`09e7b3f`..`9dddbd2`).
  - Round 2 : Marche 1b, vitesse verticale de marche affichée (`6aa2e3f`..`9b63327`) ; Marche 2a, clé `speed` nulle (`f0dba5d`, `2c07208`).
- Spec : `origin/claude/cadrage-corrections:docs/plan/specs-corrections.md`.
- Fichiers touchés par le round : `.gitignore`, `LICENSE`, `README.md`, `source/FlyInstrumentApp.mc`, `source/HikeHistory.mc` (nouveau), `source/HikePaceView.mc`, `source/Tests.mc`, `source/Utils.mc`, `source/WatchData.mc`.

## Verdict : OK avec réserves

Le travail des deux rounds est conforme à la spec. Les zones sensibles sont intactes et les 6 compilations réussissent. Les 37 tests passent sur fenix6pro (5 exécutions sur 5), fenix7, fenix843mm, fr245 et instinct2.

Réserves :
1. **Sur fenix5, 3 tests sur 37 sont en ERROR** à cause d'un défaut **antérieur au round** : `Activity.SPORT_FLYING` est introuvable sur ce modèle (`FlyInstrumentApp.mc:57`, dans `startRecording()`, ligne non modifiée par le round). Sur une vraie fenix5, appuyer sur SELECT pour démarrer l'enregistrement ferait probablement planter l'app. Détails dans « Problèmes trouvés ».
2. Les vérifications visuelles (affichage VERT. SPD., vitesse en km/h sur la vue vol, sauvegarde à la fermeture) restent à faire au simulateur par l'utilisateur. Le protocole est plus bas.
3. Le `.gitignore` ajouté ne retire pas `bin/`, `.DS_Store` ni `developer_key` du suivi git. Ce n'est pas caché : le commit ne prétend pas le contraire. Mais le fichier peut laisser croire que ces fichiers ne sont plus publiés.

## Contrôles statiques

| Contrôle | Résultat |
|---|---|
| `git diff --stat origin/hikeandfly -- source/FlyInstrumentView.mc source/WatchDisplay.mc manifest.xml bin/` | **Vide.** OK |
| `WatchData.mc` : `endMeasure()`, `getVario()`, `oldAlt`, `getAltitude()` | **Inchangés.** Dans le diff, ces noms n'apparaissent que dans un commentaire et dans un appel en lecture (`hikeHistory.add(tMs, getAltitude(), getDistance())`). Hunks du diff : les 3 blocs `speed` de `updateInfo` / `updateActivityInfo` / `updateSensorInfo`, et un ajout en fin de classe. OK |
| `WatchDisplay.vario()` / `beep()`, `FlyInstrumentView` | Fichiers non modifiés. OK |
| developer_key | Absent de `git diff --stat origin/hikeandfly..HEAD` (global) et du `git show --stat` de chacun des 20 commits. La commande dédiée `git diff --stat origin/hikeandfly -- developer_key` / `git log ... -- developer_key` a été **refusée par les permissions** ; le contrôle repose donc sur les stats globales et par commit. Contenu jamais lu. OK |
| bin/, .DS_Store, manifest.xml dans les commits | Aucun des 20 commits ne les contient (`git log --stat`). OK |
| `.gitignore` (`bin/`, `.DS_Store`, `developer_key`) | Aucun fichier sorti du suivi : `git ls-files` liste toujours `developer_key`, `manifest.xml`, `.DS_Store`, `glidator2_export/.DS_Store` et ~100 fichiers sous `bin/`. `git ls-files -i -c --exclude-standard` les montre « suivis et ignorés ». Pas de retrait silencieux. Voir réserve 3. |
| Tests désactivés ou affaiblis | Aucune ligne supprimée dans `Tests.mc` (`git diff` : seulement des ajouts). Les 5 tests existants sont intacts ; `testSessionStateMachine` gagne une assertion. OK |
| `git status` après chaque compilation et chaque exécution de tests | Propre à chaque fois. Avec `-o /tmp/glidator-build/...`, `monkeyc` écrit `gen/` dans `/tmp/glidator-build/gen/` (vu dans les piles d'erreur) et ne touche pas `bin/`. Cela répond au point 9 de la spec. |
| Diff 2a limité aux 3 blocs `speed` | `2c07208` : 7 lignes ajoutées, 6 supprimées, uniquement les 3 conditions `speed` et leurs commentaires. OK |
| Critère 1a « aucun fichier existant modifié hors Tests.mc » | Respecté pour `09e7b3f`..`9dddbd2`. |

### Tableau tâche → tests ajoutés

| Tâche | Tests demandés par la spec | Tests ajoutés | Conforme |
|---|---|---|---|
| .gitignore + LICENSE | aucun | aucun | oui |
| Audit 5a (onStop) | « testSessionStateMachine vert ; pas de test unitaire de onStop possible » | `testShouldSaveOnStop`, `testStopRecordingSaveWithoutSessionIsNoOp`, `testStopRecordingSavesPausedSession`, `testStopRecordingSavesRecordingSession` (+ 1 assertion dans `testSessionStateMachine`) | oui, au-delà de la spec |
| Marche 1a (HikeHistory) | montée 600 m/h ±1 ; bruitée ±30 ; plat ; descente 1200 ; montée puis plat ; 1 point / 15 s → null ; trou 20 s → null ; speedMps 1,04 / 0 / null | `testHikeHistoryConstantClimb`, `NoisyClimb`, `Flat`, `Descent`, `ClimbThenFlat`, `NotEnoughData`, `MinimumCoverageEdges`, `GapResets`, `SampleSpacing`, `Reset`, `Speed`, `MixedNullDistance`, `TimerWrapAround`, `WindowStartWouldOverflow`, `DistanceDecreases`, `RingBufferOverflow`, `Window300s`, `SalvanRealClimb` (18) | oui |
| Marche 1b (branchement) | `formatVerticalSpeed` null / 636.4 / -129.0 / 0.0 ; `recordHikeSample()` avec activityData simulé | `testFormatVerticalSpeed`, `testShouldRecordHikeSample`, `testWatchDataRecordHikeSample`, `testWatchDataRecordHikeSampleWithoutDistance`, `testWatchDataHikeSamplingAcrossPause`, `testWatchDataRecordHikeSampleUsesTimer`, `testWatchDataHikeSalvanRealClimb` (7) | oui |
| Marche 2a (speed nulle) | sensorData = {} + gpsData speed 1.5 → 1.5 ; test existant vert | `testWatchDataSpeedFallsBackToGpsWhenSensorSpeedNull`, `testWatchDataUpdatesSkipNullSpeedOnly`, `testWatchDataSpeedRecoversAfterNullSensorSpeed` (3, avec de faux objets Info qui passent par les vraies fonctions `update*()`) | oui, au-delà de la spec |

Total : 5 tests existants + 32 nouveaux = 37.

### Ce qui n'est testé nulle part

- **`FlyInstrumentApp.onStop()` lui-même** : seule la règle pure `shouldSaveOnStop()` et `stopRecording(true)` sont testées, pas l'appel dans `onStop()` ni l'ordre avec la coupure des capteurs. Vérification manuelle (étape C).
- **`FlyInstrumentApp.onSensor()`** : seule la règle `shouldRecordHikeSample()` est testée. Rien ne vérifie que `onSensor()` appelle bien `recordHikeSample()` à chaque tick. Vérification manuelle (étape A).
- **`HikePaceView.onUpdate()`** : aucun test d'affichage. Ni le branchement de `getHikeVerticalSpeed()`, ni la largeur du champ pour `-1200` ou `+1000000`.
- **Vue vol, vitesse km/h** (`FlyInstrumentView.mc:71-75`) : le changement de source (GPS au lieu d'une clé nulle) n'est vérifiable qu'au simulateur.
- **Vario de vol** (`endMeasure()`, `getVario()`) : aucun test, ni avant ni après le round. `testWatchDataRecordHikeSample` vérifie seulement que l'échantillonnage de marche laisse `oldAlt` et `getVario()` à `null`.
- **Pace de marche** (`HikePaceView.mc:48-55`) : il utilise toujours `getSpeed()` instantané, et l'arrondi « 5:60 » est toujours là. Cela relève de la tâche 2b, qui n'est pas dans ce round. `getHikeSpeed()` est testé mais pas encore affiché.
- **Wrappers `System.getTimer()`** (`recordHikeSample()`, `getHikeVerticalSpeed()`, `getHikeSpeed()`) : couverts par un seul test à 1 échantillon (résultat `null`). Le calcul n'est testé qu'avec les variantes `*At(ms)`.
- **`startRecording()` sur les modèles sans `SPORT_FLYING`** : aucun test ne protège contre ce cas. On ne le voit qu'en lançant la suite sur fenix5.
- **Effets de bord de `stopRecording(true)` à la fermeture** (bip et vibration pendant que l'app se ferme) : non testés.

## Compilation

SDK présent : `/Users/sam/.local/bin/monkeyc`, `monkeydo`, `connectiq`. Toutes les sorties vont dans `/tmp/glidator-build/`.

| Appareil | Commande | Résultat |
|---|---|---|
| fenix6pro (référence) | `monkeyc -f monkey.jungle -o /tmp/glidator-build/fenix6pro.prg -d fenix6pro -y developer_key` | BUILD SUCCESSFUL |
| fenix5 (plus ancien modèle du manifest) | idem `-d fenix5` | BUILD SUCCESSFUL |
| fenix7 | idem `-d fenix7` | BUILD SUCCESSFUL |
| fenix843mm | idem `-d fenix843mm` | BUILD SUCCESSFUL |
| fr245 (Forerunner) | idem `-d fr245` | BUILD SUCCESSFUL |
| instinct2 (Instinct) | idem `-d instinct2` | BUILD SUCCESSFUL |
| Versions de test (`-t`) | fenix6pro (`Glidator.prg`), fenix5, fenix7, fenix843mm, fr245, instinct2 | BUILD SUCCESSFUL (6/6) |

Aucun avertissement affiché. `git status` est resté propre après chaque commande.

## Tests

Simulateur ouvert. `monkeydo` renvoie 1 même quand tout passe : le résultat ci-dessous vient de la ligne `RESULTS` de la sortie.

| Commande | Exécution | Résultat |
|---|---|---|
| `monkeydo /tmp/glidator-build/Glidator.prg fenix6pro -t` | 1 | Ran 37 tests, PASSED (passed=37, failed=0, errors=0) |
| idem | 2 | 37/37 PASSED |
| idem | 3 | 37/37 PASSED |
| idem | 4 | 37/37 PASSED |
| idem | 5 | 37/37 PASSED |
| `monkeydo /tmp/glidator-build/fenix7-test.prg fenix7 -t` | 1 | 37/37 PASSED |
| `monkeydo /tmp/glidator-build/fenix843mm-test.prg fenix843mm -t` | 1 | 37/37 PASSED |
| `monkeydo /tmp/glidator-build/fr245-test.prg fr245 -t` | 1 | 37/37 PASSED |
| `monkeydo /tmp/glidator-build/instinct2-test.prg instinct2 -t` | 1 | 37/37 PASSED |
| `monkeydo /tmp/glidator-build/fenix5-test.prg fenix5 -t` | 2 (même résultat) | **FAILED (passed=34, failed=0, errors=3)** : `testSessionStateMachine`, `testStopRecordingSavesPausedSession`, `testStopRecordingSavesRecordingSession` |

Message exact sur fenix5 (identique pour les 3 tests) :

```
Error: Symbol Not Found Error
Details: Could not find symbol 'SPORT_FLYING'
Stack:
  - startRecording() at source/FlyInstrumentApp.mc:57
  - testSessionStateMachine() at source/Tests.mc:115   (resp. :187, :210)
```

**Test instable `testStopRecordingSavesRecordingSession`** : 9 PASS sur 9 exécutions sur les montres où `SPORT_FLYING` existe (5 sur fenix6pro, 1 chacune sur fenix7, fenix843mm, fr245 et instinct2). L'ERROR du round 2 (1 sur 4) ne s'est pas reproduit. Sur fenix5, l'erreur est systématique et a une autre cause (symbole absent). Remarque : ce test et `testStopRecordingSavesPausedSession` enregistrent chacun une activité courte dans le simulateur à chaque exécution, ce qui peut expliquer une instabilité ponctuelle (écriture du fichier FIT).

Les valeurs affichées par les tests correspondent à la spec : montée de 600 m/h → 599,999 ; montée bruitée → 597,36 ; descente → -1199,999 ; extrait réel de Salvan via WatchData → 471,27 m/h, affiché `+470`, vitesse 1,096 m/s.

## Protocole manuel pour l'utilisateur (simulateur)

Préparation :
- [ ] Compiler hors de `bin/` : `monkeyc -f monkey.jungle -o /tmp/glidator-build/fenix6pro.prg -d fenix6pro -y developer_key`, puis `monkeydo /tmp/glidator-build/fenix6pro.prg fenix6pro`.
- [ ] Dans le simulateur, charger `garmin_data/activity_24346302742.gpx` dans *Simulation > Activity Data* (ou *Data Playback* selon la version du SDK), sans encore lancer la lecture.

**A. Vitesse verticale de marche (Marche 1b)**
- [ ] L'app démarre en mode Marche (vue Position). Appuyer sur DOWN pour aller à la page Pace (cases Heart Rate / VERT. SPD. / PACE / TIMER).
- [ ] Avant la lecture du GPX : VERT. SPD. affiche `--`.
- [ ] Appuyer sur SELECT pour démarrer l'enregistrement, puis lancer la lecture du GPX (vitesse x1).
- [ ] Pendant environ 20 s : `--` (il faut au moins 3 échantillons espacés de 5 s et 20 s couverts).
- [ ] Ensuite, en montée (première partie de la trace, Salvan vers le décollage) : valeur positive, arrondie à 10 m/h, **entre +500 et +650 m/h**, qui change par paliers de 10 et ne saute plus de ±720 d'une seconde à l'autre. Sur le passage de 11:07 à 11:09 de la trace, on attend environ **+470 à +530**.
- [ ] Sur un replat : valeur proche de `0` (jamais `+0` ni `-0`).
- [ ] Le signe `+` n'apparaît que si la valeur est positive ; une descente s'affiche `-xxx`.

**B. Pause et reprise (règle « -- environ 20 s après une reprise »)**
- [ ] En montée, appuyer sur SELECT : l'enregistrement se met en pause et le menu Resume/Save/Discard s'ouvre. Attendre au moins **20 s** dans le menu.
- [ ] Choisir Resume. Sur la page Pace, VERT. SPD. affiche **`--` pendant environ 20 s**, puis une valeur de montée revient (500 à 650 m/h). À aucun moment une valeur aberrante (mélange avant/après pause) ne doit s'afficher.
- [ ] Variante : une pause de moins de 15 s ne remet pas le buffer à zéro, mais aucun échantillon n'est pris pendant la pause ; la valeur peut retomber à `--` brièvement si la fenêtre de 60 s se vide trop.

**C. Sauvegarde de la session à la fermeture par le système (Audit 5a)**
- [ ] Démarrer un enregistrement (SELECT), attendre environ 30 s, puis fermer l'app par le simulateur (*File > Kill App* ou fermeture de l'app depuis le simulateur), **sans passer par le menu**. Une activité « Glide » doit être sauvegardée (vérifier dans le dossier des activités du simulateur ou dans le journal : bip/vibration de stop).
- [ ] Même chose avec une session **en pause** (SELECT, laisser le menu ouvert, puis fermer) : une activité est sauvegardée.
- [ ] Chemin Save du menu : une seule activité sauvegardée (pas de doublon à la fermeture).
- [ ] Chemin Discard du menu : **aucune** activité créée.
- [ ] Sans session (app ouverte puis BACK) : aucune activité créée.

**D. Vitesse km/h sur la vue vol avec le GPS seul (Marche 2a)**
- [ ] Maintenir BACK 1,5 s pour passer en mode Vol (vue instrument).
- [ ] GPX en lecture, sans capteur de vitesse (pas de capteur au pied) : la vitesse en **km/h s'affiche** (avant le correctif, ce champ restait vide). Ordre de grandeur sur la trace : 3 à 5 km/h en montée, davantage en vol.
- [ ] Le **vario de vol** (m/s, vert au-dessus de +0,3, rouge en dessous de -2,0, gris sinon) et ses bips se comportent exactement comme avant : mêmes valeurs à chaque seconde, mêmes couleurs. À comparer si possible avec une compilation de `origin/hikeandfly` sur le même passage du GPX.

**E. Largeur du champ VERT. SPD.**
- [ ] Sur la partie en descente de la trace, ou en simulant une descente rapide : `-1200` tient dans la case VERT. SPD. sans déborder sur PACE, sur **fenix6pro**, **instinct2** (petit écran monochrome), **fr245** et **fenix843mm**.
- [ ] Si possible, provoquer un saut d'altitude (altitude modifiée à la main dans le simulateur) : la valeur reste lisible et l'app ne plante pas (le formatage gère les valeurs jusqu'à 1e10 sans dépassement d'entier).

**F. fenix5 (réserve 1)**
- [ ] Lancer l'app sur fenix5 au simulateur et appuyer sur SELECT. On s'attend à un plantage « Could not find symbol 'SPORT_FLYING' ». À confirmer, puis à corriger dans une tâche dédiée.

Sur la montre (si elle est disponible) : refaire A, B et D pendant une vraie montée, en notant 3 relevés VERT. SPD. et le D+ correspondant sur 5 min.

## Problèmes trouvés

### Majeur (antérieur au round, révélé par les tests)
- `source/FlyInstrumentApp.mc:57-59` : `ActivityRecording.createSession({:sport => Activity.SPORT_FLYING})` lève « Could not find symbol 'SPORT_FLYING' » sur fenix5. Le démarrage d'un enregistrement plante donc sur ce modèle, et probablement sur les autres fenix 5 (5plus, 5x, 5xplus), qui n'ont pas été testés ici. Ligne inchangée par le round ; seul le test l'a mise au jour.
  Correctif suggéré au dev : choisir le sport à l'exécution, par exemple `(Activity has :SPORT_FLYING) ? Activity.SPORT_FLYING : Activity.SPORT_GENERIC`. Il faut vérifier que `has` fonctionne sur cette constante de module. Sinon, retirer ces modèles du manifest (décision de l'utilisateur, car manifest.xml est une zone sensible). Ajouter un test qui lance `startRecording()` sur fenix5.

### Mineur
- `.gitignore` (commit `eeed1ae`) : `bin/`, `.DS_Store`, `developer_key` (et `glidator2_export/.DS_Store`) restent suivis ; le fichier n'a d'effet que sur les nouveaux fichiers. Les retirer du suivi (`git rm --cached`) et faire tourner la clé, puisque le dépôt est public, restent des décisions de l'utilisateur.
- `source/Tests.mc:4-5` : l'en-tête donne toujours `-d fenix6 -o bin/tests.prg`, une commande différente de celle de la fiche, qui compile en plus dans `bin/` (petit défaut déjà relevé par la spec, non corrigé).
- `source/Tests.mc:179-219` : `testStopRecordingSavesPausedSession` et `testStopRecordingSavesRecordingSession` créent chacun une activité réelle à chaque exécution des tests dans le simulateur (c'est indiqué en commentaire). Ce sont des pistes pour l'instabilité vue au round 2.
- `source/FlyInstrumentApp.mc:216-219` : à la fermeture par le système, `stopRecording(true)` joue la tonalité et la vibration de stop. C'est sans gravité, mais à surveiller sur la montre.
- `source/HikeHistory.mc:146` : espacement `var dt =(` (cosmétique).

### Hors périmètre, rappel
- `source/HikePaceView.mc:48-55` : le pace utilise toujours `getSpeed()` instantané, avec l'arrondi « 5:60 » ; c'est le rôle de la tâche 2b.
