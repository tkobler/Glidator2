# Suite complète sur les 62 montres, banc des colonnes et protocole simulateur

- **Date** : 14/10/2026 (nuit), branche `claude/corrections-marche`, HEAD `bf2c76a`, SDK Connect IQ 9.2.0.
- **Périmètre** : toutes les montres de `manifest.xml` (62), build `-t` puis `monkeydo <prg> <montre> -t`, par `zsh tools/run-watches.zsh`. Le commit `e9fbf59` (PACE ne dépend plus de l'altitude, D2 A) est dans la base testée.
- **Verdict** : **OK**. 62 montres sur 62 : build OK, 223 tests, 223 passés, 0 échec, 0 erreur. Aucune ligne `COLUMNS differs`.
- **Non fait dans cette note** : compilation release (sans `-t`), contrôle statique des zones sensibles (vario), simulateur avec lecture du GPX (manuel, section « Protocole »).

## Commandes lancées

```
zsh tools/run-watches.zsh --batch-size 7 fenix6pro fenix5 fenix7 fenix843mm fr245 fr255 instinct2
zsh tools/run-watches.zsh --batch-size 8 <les 55 autres montres, dans l'ordre du manifest>
```

- Deux appels, 8 lots au total (1 de 7 montres, 7 de 8 au plus). Chaque lot commence par un redémarrage du simulateur (`relancer-simulateur`), qui a répondu en 4 s à chaque fois.
- Aucun « retried after simulator restart », aucun BLOCKED, SILENT ou MISMATCH. Durée par montre : 9 à 26 s (la première de chaque lot est la plus longue, à cause du redémarrage).
- Logs complets : `/tmp/glidator-build/<montre>.log` (la ligne `FAILED (passed=0, failed=0, errors=1)` près du début des logs de fenix6pro, epix2, fenix6s, fenix7xpro, fenix9pro43mm, fr170m, fr57047mm et instinct2s est la sonde de redémarrage du script, dont le test n'existe pas exprès : attendu).

## Tableau montres × résultat

Colonnes : build `-t` / tests passés sur total / ligne `COLUMNS differs`. Toutes les lignes : build OK, **223/223**, **non**.

| Famille | Montres | Build | Tests | COLUMNS differs |
|---|---|---|---|---|
| Référence | fenix6pro, fenix5, fenix7, fenix843mm, fr245, fr255, instinct2 | OK | 223/223 | non |
| epix | epix2, epix2pro42mm, epix2pro47mm, epix2pro51mm | OK | 223/223 | non |
| fenix 5 | fenix5plus, fenix5x, fenix5xplus | OK | 223/223 | non |
| fenix 6 | fenix6, fenix6s, fenix6spro, fenix6xpro | OK | 223/223 | non |
| fenix 7 | fenix7pro, fenix7pronowifi, fenix7s, fenix7spro, fenix7x, fenix7xpro, fenix7xpronowifi | OK | 223/223 | non |
| fenix 8 | fenix847mm, fenix8pro47mm, fenix8solar47mm, fenix8solar51mm | OK | 223/223 | non |
| fenix 9 | fenix943mm, fenix947mm, fenix9pro43mm, fenix9pro47mm, fenix9pro51mm, fenix9prosolar47mm, fenix9prosolar51mm | OK | 223/223 | non |
| Forerunner 1xx | fr165, fr165m, fr170, fr170m | OK | 223/223 | non |
| Forerunner 2xx | fr255m, fr255s, fr255sm, fr265, fr265s | OK | 223/223 | non |
| Forerunner autres | fr55, fr57042mm, fr57047mm, fr70, fr745, fr945, fr945lte, fr955, fr965, fr970 | OK | 223/223 | non |
| Instinct | instinct2s, instinct2x, instinct3amoled45mm, instinct3amoled50mm, instinct3solar45mm, instincte40mm, instincte45mm | OK | 223/223 | non |

Total : 62 montres (7 de référence + 55 autres). `PASSED (passed=223, failed=0, errors=0)` lu dans chaque journal.

- **Montres non testées** : aucune. **Test désactivé ou affaibli** : non constaté (le nombre est le même sur les 62 montres).
- Les nouveaux tests du soir sont dans la sortie (fenix6pro) : `CoreTests.testHikeHistoryNullAltitudeKeepsDistance`, `testWatchDataRecordHikeSample`, `testWatchDataRecordHikeSampleWithoutDistance`, `testWatchDataRecordHikeSampleUsesTimer`, tous PASS.

## Banc des colonnes du milieu (D5 A)

- **Ce que compare le banc** : `LayoutBench.middleColumns()` (`source/TestsLayout.mc:782-861`). Pour chaque page de marche (HikePosition et HikePace) dans 5 états (Empty, Normal, Extreme, Paused, Recording), il redessine la page, recalcule l'appel `placeColumns()` de `WatchDisplay.hikeGrid()`, vérifie qu'il redonne exactement ce qui est dessiné, puis le compare au même appel **sans vérification des étiquettes** (`labels = null`, la mise en page d'avant le 08/10). Il écrit `COLUMNS same` ou `COLUMNS differs: now [police, xg, xd] before [police, xg, xd]`. Quand il y a `differs`, le banc exige que l'ancienne disposition ait eu un défaut d'étiquette réel (sinon il ajoute une erreur et le test échoue).
- **Résultat** : `COLUMNS differs` : **0 ligne sur les 62 journaux** (Grep sur `/tmp/glidator-build/*.log`). Décision D5 A respectée.
- `COLUMNS same` : 10 lignes (2 pages × 5 états) dans chacun des **56** journaux des montres à placement par colonnes, soit 560 lignes.
- `COLUMNS sub-window layout, placeColumns() not used` : 10 lignes dans chacun des **6** journaux des montres à sous-fenêtre, soit 60 lignes : instinct2, instinct2s, instinct2x, instinct3solar45mm, instincte40mm, instincte45mm. Le banc ne compare rien sur ces 6 montres (`hikeGridSubscreen()`), ce n'est pas un défaut.
- 56 + 6 = 62 : aucune montre sans ligne COLUMNS.
- Exemple fenix6pro : `[0, 73.00, 187.00]` avant et après, sur les 10 pages.

## Anomalies de l'environnement

- `git status` après les builds : les mêmes 4 fichiers suivis de `bin/` qu'au départ (`bin/gen/006-B3290-00/source/UnitTests.mcgen`, `bin/internal-mir/UnitTests.mir`, `bin/mir/source/Tests.mir`, `bin/mir/source/WatchData.mir`), aucun autre. Connu, laissé tel quel. Ils ne viennent pas des builds du script (sortie vers `/tmp/glidator-build/`), ils étaient déjà modifiés avant ce run.
- Les logs de `/tmp/glidator-build/` qui existaient avant (builds de nuits précédentes) ont été écrasés pour les 62 montres. Aucune ligne polluée par un autre `monkeydo` : tous les journaux montrent exactement 223 `Executing test`, un seul `PASSED`.
- La note `docs/verifications/2026-10-13-essai-marche.md` citée par le protocole terrain du 13/10 et par la tâche **n'existe pas** dans le dépôt (ni dans l'historique git). Les valeurs ci-dessous viennent donc de `2026-10-13-etalon-marche.md`, `2026-10-13-test-terrain.md` et du code.
- Commandes refusées : aucune dans cette tâche.

## Protocole simulateur pour l'utilisateur (environ 20 minutes)

**Préparation** (une fois)
- [ ] `monkeyc -f monkey.jungle -o /tmp/glidator-build/fenix6pro.prg -d fenix6pro -y developer_key` (sans `-t`, attendu : `BUILD SUCCESSFUL`), simulateur ouvert, puis `monkeydo /tmp/glidator-build/fenix6pro.prg fenix6pro`.
- [ ] Charger `garmin_data/activity_24346302742.gpx` dans le simulateur (*Simulation > Activity Data* ou *Data Playback* selon la version). Ne pas lancer la lecture tout de suite.
- [ ] Fenêtre VS laissée à 1 min (valeur par défaut).
- [ ] Page ALTITUDE affichée, puis **SELECT (START) avant de lancer la lecture** : le chronomètre de la session démarre à 0:00 en même temps que le GPX.

**Ce que le simulateur fait à l'app (donc « -- » normaux, voir l'étalon)**
- Heart Rate : « -- » toute la lecture (FC null, 653 lignes sur 653 au journal).
- ALTITUDE : « -- » jusqu'à environ la minute 98, parce que le simulateur envoie `0,2 × ele − 622 m`, soit -256 m vers 1840 m. Elle ne repasse dans -100..6000 m qu'au-dessus de 2610 m de vraie altitude.
- VERT. SPD. et ELEV. GAIN sont calculés sur cette altitude transformée : environ **0,2 ×** la valeur réelle de l'étalon. Un écart d'un facteur 5 avec les chiffres de l'étalon est normal.
- DISTANCE suit la distance GPS des positions (environ 2,7 % de plus que le TCX).
- Page vol (si ouverte) : altitude négative, par exemple « -254 m » à 1840 m.

**Minutes à regarder** (temps de session = temps depuis le début du GPX ; si la lecture est accélérée, relever la valeur au passage du temps de lecture indiqué). Pages Position (ALTITUDE / ELEV. GAIN / DISTANCE) et Pace (Heart Rate / VERT. SPD. / PACE).

| Minute | Étalon sur montre (D+ h3, VS, pace) | Attendu au simulateur |
|---|---|---|
| 0:00 à 0:20 | VS « -- » avant 20 s et 3 échantillons ; PACE « --:-- » | VERT. SPD. et PACE en « -- » / « --:-- » pendant environ 20 à 25 s, puis des valeurs |
| 1 | +740 m/h ; PACE 17:22 ; DIST 0.1 | VS environ +150 ; PACE environ 17:00 (5 % près) ; DIST 0.1 |
| 5 (4:13 déjà relevé : DIST « 0.3 », D+ « 5 ») | D+ 37 ; VS +660 ; PACE 16:05 ; DIST 0.3 | D+ environ 7 (0,2 × 37) ; VS environ +130 ; PACE entre 15:15 et 16:10 ; DIST 0.3 |
| 10 | D+ 94 ; VS +590 ; PACE 15:34 ; DIST 0.5 | D+ environ 19 ; VS environ +120 ; PACE entre 14:50 et 15:40 ; DIST 0.5 |
| 20 | D+ 194 ; VS +610 ; PACE 15:49 ; DIST 1.1 | D+ environ 39 ; VS environ +120 ; PACE entre 15:00 et 15:55 ; DIST 1.2 |
| 31 (arrêt) | PACE « --:-- » ; VS +30 | PACE « --:-- » ; VS proche de 0 (+10 environ) |
| 60 | D+ 571 ; VS +670 ; PACE 34:07 ; DIST 2.7 | D+ environ 114 ; VS environ +130 ; DIST 2.8 |
| 69 (raide) | VS +1240 ; PACE 24:33 | VS environ +250 ; PACE environ 24:00 |
| 70 (arrêt) | PACE « --:-- » | PACE « --:-- » |
| 98 à 104 (sommet) | ALTITUDE 2614 à 2678 | ALTITUDE passe de « -- » à « -100 » vers la minute 98, puis environ « -86 » au sommet (minute 104) |

Valeurs de l'étalon : `docs/verifications/data/2026-10-13-etalon-marche-minutes.csv` et tableau de `2026-10-13-etalon-marche.md`. Les colonnes « Attendu au simulateur » sont des **prédictions** (0,2 ×, distance GPS), pas des mesures : un écart de 10 à 20 % est possible (filtre du simulateur sur l'altitude, remises à zéro de l'historique sur les 25 trous de plus de 15 s). Noter la valeur lue si elle sort de la fourchette.

**Nouveauté du soir : PACE sans altitude (D2 A, `e9fbf59`)**
- [ ] PACE s'affiche sans altitude : **non observable de façon fiable au simulateur**, car le simulateur envoie une altitude (négative, mais non null) à `HikeHistory`. Ce qui est couvert : `testHikeHistoryNullAltitudeKeepsDistance` et `testWatchDataRecordHikeSample` (PASS sur 62 montres). Il faudrait une montre réelle ou un cas où `getAltitude()` est null (par exemple SELECT tout de suite après le lancement, avant tout fix : à essayer, résultat non garanti, noter ce qu'on voit).
- [ ] VERT. SPD. reste « -- » sans altitude (même couverture).
- [ ] Contre-vérification utile au simulateur : PACE et DIST ne doivent jamais être « -- » / « --:-- » en montée soutenue (minutes 1 à 30 hors arrêts), tant que la session tourne.

**Carte**
- [ ] Depuis D6, la carte accepte `QUALITY_POOR` (`WatchData.mc:378`) et le simulateur donne accuracy 2 : la trace devrait se dessiner et « Waiting for GPS » disparaître dès la première position. C'est un changement par rapport à l'essai du 13/10 (« Waiting for GPS » permanent), non encore revu au simulateur. Noter : trace visible oui / non, saut ou ligne droite aberrante, marqueur orienté dans le sens de la marche.

**Aussi à regarder**
- [ ] DISTANCE à 4:13 : le 13/10 elle valait « 0.3 » pour 247 m (« 0.2 » attendu). Relever en même temps le chronomètre de session et DISTANCE à 2 instants (par exemple 2:00 et 4:13) pour éclaircir l'écart. Note de l'étalon, point resté ouvert.
- [ ] Pause (SELECT, menu Paused) : Heart Rate déjà « -- » (inchangé), la carte continue de s'allonger si le GPX joue.

## Problèmes trouvés

- **Gravité bloquante** : aucune.
- **Mineur** : la note `2026-10-13-essai-marche.md` est citée (protocole terrain, tâche du soir) mais absente du dépôt. Soit elle n'a jamais été écrite, soit elle est sur une autre branche. À corriger dans les références de `2026-10-13-test-terrain.md` (ligne 6) si elle n'existe pas.
- **Limite de cette vérification** : les tests ne couvrent pas l'affichage réel au simulateur (valeurs « -- » ci-dessus) ni les montres réelles ; le build release n'a pas été relancé dans cette tâche.
