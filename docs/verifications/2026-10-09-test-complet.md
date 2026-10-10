# Vérification — test complet des 62 montres (2026-10-09, tests lancés le 2026-10-10)

## Périmètre
- Branche `claude/corrections-marche`, HEAD testé le 2026-10-10 : `fdc85d9` (le 09/10 : `1967990`, base de comparaison `0c5e6c6`, 36 commits, 21 fichiers, +2219 / -121 ; les contrôles statiques ci-dessous datent du 09/10 et n'ont pas été refaits sur les commits ajoutés depuis).
- SDK Connect IQ 9.2.0 (`monkeyc`, `monkeydo`, `connectiq` présents dans ~/.local/bin).
- Outil : `zsh tools/run-watches.zsh <montres>` en lots (journaux dans /tmp/glidator-build/<montre>.log). Sorties toujours dans /tmp/glidator-build/, jamais bin/. Pas de `--release` (compilation release déjà vérifiée le 09/10, 62/62).
- Historique 09/10 : tests non lancés (simulateur muet, BLOCKED 300 s sur 3 montres), 59 non tentées.

## Verdict : OK pour les tests unitaires (62/62 montres vertes, suite stable à un aléa près)
- 62 montres sur 62 : build `-t` OK et **194 tests passés, 0 échec** à la fin (D2 : suite complète verte, banc d'affichage compris, aucune ligne MISMATCH / NOT RUN).
- Deux incidents d'exécution, non reproduits à la relance (voir « Problèmes trouvés ») :
  - fenix6s : 1 échec au premier passage (`testSensorsFollowPauseAndResume`, ERROR), vert (194/194) à la relance immédiate : test intermittent.
  - fr170 : `monkeydo` BLOCKED 300 s (0 test) au premier passage, au milieu du lot ; après un `relancer-simulateur` (une fois), 194/194 en 19 s.
- Ce verdict ne couvre que les tests unitaires du simulateur ; l'aspect visuel reste à valider à la main (protocole ci-dessous).

## Contrôles statiques (faits le 09/10, sur `1967990`)
- **Vario intact** : `source/WatchData.mc` absent de `git diff --stat 0c5e6c6..HEAD` (aucun commit ne le touche). Dans `WatchDisplay.mc`, aucune hunk sur `start()`, `vario()`, `beep()`, `heading()`, `compass()`. OK.
- **FlyInstrumentView.mc** : 1 ligne changée (`display.altitude($.formatFlightAltitude(altitude), record)`, garde d'altitude −500..9000 m = V1b/V3). Dans `FlyInstrumentApp.mc` : `new Preferences(self)` (migration des préférences, hors zone sensible). OK.
- **WatchDisplay.altitude()** : unité " m" supprimée après « -- » (décision 09/10). **speed()** : `flySpeedLineX` décale la ligne sur Instinct (V1a). **time_and_battery()** : `timeBatteryLayout` (V2). Le reste concerne la grille Marche et la carte, hors zone sensible. OK ; plan `glidator2-plan-affichage-vol.md` non relu point par point (correspondance déduite des messages de commit).
- **manifest.xml** : seul changement depuis la base : `version="0.0.1"` → `"2.1.2"`. OK.
- **bin/, developer_key, .DS_Store** : aucun commit du round ne les touche. developer_key non lu. OK.
- **Arbre de travail** : `git status` propre après toutes les compilations et tous les tests du 10/10.
- **Tests ajoutés** : tests rouge-puis-fix pour chaque fix (Tests.mc, TestsChain.mc, TestsFormat.mc, TestsHikeGrid.mc, TestsHikeMap.mc, TestsLayout.mc). Pas de test désactivé repéré dans les diffs lus.
- **Non couvert / à confirmer** : rendu réel (polices, positions) hors simulateur ; `hikeGridSubscreen` sur Instinct dépend de `WatchUi.getSubscreen()` (absent sur CIQ < 3.2.7, repli sur l'ancienne grille).

## Compilation et tests par montre

Légende : Rel = `monkeyc` release (vérifié le 09/10), -t = `monkeyc -t` (fait par le script le 10/10). Tests : « 194/194 » = 194 passés, 0 échec, sortie vue dans le journal.

| # | Montre | Rel | -t | Tests | Échecs nommés |
|---|--------|-----|----|-------|---------------|
| 1 | epix2 | OK | OK | 194/194 | - |
| 2 | epix2pro42mm | OK | OK | 194/194 | - |
| 3 | epix2pro47mm | OK | OK | 194/194 | - |
| 4 | epix2pro51mm | OK | OK | 194/194 | - |
| 5 | fenix5 | OK | OK | 194/194 | - |
| 6 | fenix5plus | OK | OK | 194/194 | - |
| 7 | fenix5x | OK | OK | 194/194 | - |
| 8 | fenix5xplus | OK | OK | 194/194 | - |
| 9 | fenix6 | OK | OK | 194/194 | - |
| 10 | fenix6pro | OK | OK | 194/194 | - |
| 11 | fenix6s | OK | OK | 194/194 à la relance (1er passage : 193/194) | 1er passage seulement : testSensorsFollowPauseAndResume (ERROR) |
| 12 | fenix6spro | OK | OK | 194/194 | - |
| 13 | fenix6xpro | OK | OK | 194/194 | - |
| 14 | fenix7 | OK | OK | 194/194 | - |
| 15 | fenix7pro | OK | OK | 194/194 | - |
| 16 | fenix7pronowifi | OK | OK | 194/194 | - |
| 17 | fenix7s | OK | OK | 194/194 | - |
| 18 | fenix7spro | OK | OK | 194/194 | - |
| 19 | fenix7x | OK | OK | 194/194 | - |
| 20 | fenix7xpro | OK | OK | 194/194 | - |
| 21 | fenix7xpronowifi | OK | OK | 194/194 | - |
| 22 | fenix843mm | OK | OK | 194/194 | - |
| 23 | fenix847mm | OK | OK | 194/194 | - |
| 24 | fenix8pro47mm | OK | OK | 194/194 | - |
| 25 | fenix8solar47mm | OK | OK | 194/194 | - |
| 26 | fenix8solar51mm | OK | OK | 194/194 | - |
| 27 | fenix943mm | OK | OK | 194/194 | - |
| 28 | fenix947mm | OK | OK | 194/194 | - |
| 29 | fenix9pro43mm | OK | OK | 194/194 | - |
| 30 | fenix9pro47mm | OK | OK | 194/194 | - |
| 31 | fenix9pro51mm | OK | OK | 194/194 | - |
| 32 | fenix9prosolar47mm | OK | OK | 194/194 | - |
| 33 | fenix9prosolar51mm | OK | OK | 194/194 | - |
| 34 | fr165 | OK | OK | 194/194 | - |
| 35 | fr165m | OK | OK | 194/194 | - |
| 36 | fr170 | OK | OK | 194/194 à la relance (1er passage : BLOCKED 300 s, 0 test) | - |
| 37 | fr170m | OK | OK | 194/194 | - |
| 38 | fr245 | OK | OK | 194/194 | - |
| 39 | fr255 | OK | OK | 194/194 | - |
| 40 | fr255m | OK | OK | 194/194 | - |
| 41 | fr255s | OK | OK | 194/194 | - |
| 42 | fr255sm | OK | OK | 194/194 | - |
| 43 | fr265 | OK | OK | 194/194 | - |
| 44 | fr265s | OK | OK | 194/194 | - |
| 45 | fr55 | OK | OK | 194/194 | - |
| 46 | fr57042mm | OK | OK | 194/194 | - |
| 47 | fr57047mm | OK | OK | 194/194 | - |
| 48 | fr70 | OK | OK | 194/194 | - |
| 49 | fr745 | OK | OK | 194/194 | - |
| 50 | fr945 | OK | OK | 194/194 | - |
| 51 | fr945lte | OK | OK | 194/194 | - |
| 52 | fr955 | OK | OK | 194/194 | - |
| 53 | fr965 | OK | OK | 194/194 | - |
| 54 | fr970 | OK | OK | 194/194 | - |
| 55 | instinct2 | OK | OK | 194/194 | - |
| 56 | instinct2s | OK | OK | 194/194 | - |
| 57 | instinct2x | OK | OK | 194/194 | - |
| 58 | instinct3amoled45mm | OK | OK | 194/194 | - |
| 59 | instinct3amoled50mm | OK | OK | 194/194 | - |
| 60 | instinct3solar45mm | OK | OK | 194/194 | - |
| 61 | instincte40mm | OK | OK | 194/194 | - |
| 62 | instincte45mm | OK | OK | 194/194 | - |

Totaux : 62 vertes, 0 en échec, 0 bloquée à l'état final. Lots lancés : 12 + 12 + 10 + 8 (fr170 bloquée dans ce lot) + 7 (dont fr170 relancée) + 14 + relance de fenix6s. Durée par montre : 20 à 70 s (plus lent en milieu de série, plus rapide après `relancer-simulateur`).

## Problèmes trouvés
- **Moyen — test intermittent** : `testSensorsFollowPauseAndResume` (ERROR) sur fenix6s au premier passage uniquement. Journal `/tmp/glidator-build/fenix6s.log` (écrasé par la relance verte ; extrait conservé ici) :
  `Exception: ASSERTION FAILED: paused -> sensors off` à `source/Tests.mc:462` (`Test.assertMessage($.sensorsOffForPause == true, ...)` après `$.startRecording()` puis `$.pauseRecording()`).
  Hypothèse (non vérifiée) : `pauseRecording()` (`source/FlyInstrumentApp.mc:93`) ne fait rien si `$.isRecording()` est faux ; si la session du simulateur n'est pas encore en état « enregistre » juste après `startRecording()` (course liée à la charge du simulateur, lot en cours), `applySensorsForState(true)` n'est jamais appelé et `sensorsOffForPause` reste faux. Cause commune : un seul échec, donc pas de regroupement. Correctif suggéré au dev : rendre le test déterministe (vérifier `$.isRecording()` avant `pauseRecording()` avec un message dédié, ou injecter la session), et à relire : l'état de `sensorsOffForPause` en début de test (voir `source/TestsChain.mc:151`). Le test n'est pas désactivé.
- **Moyen — simulateur** : `monkeydo` fr170 sans sortie pendant 300 s en milieu de lot, alors que les montres précédentes et suivantes répondaient ; résolu par `relancer-simulateur` (une fois). Cause inconnue (simulateur qui se fige après ~35 montres chargées ?). Conseil : lots de 10 montres maximum, relancer le simulateur entre deux lots.
- Mineur : `RUN_WATCHES_TIMEOUT=60 zsh tools/run-watches.zsh ...` refusé par les permissions du round (préfixe de variable d'environnement) ; le délai reste à 300 s par étape.
- Constat positif : plus aucun échec « attendu » ; aucune ligne `LAYOUT` / `MISMATCH` en échec dans les journaux des montres vertes.

## Protocole manuel pour l'utilisateur

### A. Relancer la suite de tests
- [ ] Ouvrir le simulateur (`connectiq`), confirmer qu'il répond.
- [ ] `zsh tools/run-watches.zsh fenix6s fr170 fenix6pro fenix5 instinct2 fr965 fenix7x`. Attendu : « 194 tests: 194 passed, 0 failed » partout, aucune ligne `MISMATCH`, `NOT RUN` ou `BLOCKED`. Répéter fenix6s 3 fois pour juger de l'intermittence.

### B. Mode vol (Playback d'un GPX, p. ex. garmin_data/activity_24346302742.gpx), montres fenix6pro, fenix7x, fr965, instinct2
Pour chaque montre, passer en mode vol :
- [ ] Page principale : altitude lisible en m (« 1234 m ») ; avec altitude invalide (hors −500..9000 m ou absente) : « -- » seul, sans « m ».
- [ ] Vitesse : ligne vitesse non coupée ; sur instinct2 elle est décalée à gauche et ne touche pas la sous-fenêtre ; une vitesse négative s'affiche telle quelle (« -4 »).
- [ ] Vario : bip et aiguille/valeur comme avant (rien n'a changé : à comparer à la 2.1.1).
- [ ] Page Heure : heure et batterie ne se chevauchent pas (surtout fr965 et fenix7x AMOLED : batterie sous l'heure).
- [ ] Page boussole : cap affiché, lettre cardinale lisible ; sur instinct2 la lettre peut toucher la sous-fenêtre (décision du 07/10, tolérée).
- [ ] Instinct (instinct2) : le coin coupé de la sous-fenêtre ne masque aucun texte.

### C. Mode Marche (carte)
- [ ] Sans GPS, carte : « Waiting for » puis « GPS » sur deux lignes distinctes, sans que le « g » de « Waiting » ne chevauche « GPS » (fr965, fenix7x, fr265s : grandes polices).
- [ ] Page minuteur sur fenix6pro : durée 99:59:59 entièrement visible dans l'écran rond, sans coupure ni recouvrement du libellé.
- [ ] Pages Position et Pace sur instinct2 : textes autour de la sous-fenêtre, sans recouvrement.
- [ ] Pause puis reprise de l'enregistrement : capteurs coupés en pause, rétablis à la reprise (lié au test intermittent).

### D. Validation de la 2.1.2
- [ ] Nom de l'application « Glidator2 » dans le menu de la montre et dans le simulateur (Settings > App).
- [ ] Version 2.1.2 (manifest) ; premier lancement après mise à jour : les anciennes préférences sont migrées, aucune erreur au démarrage (en cas de conflit, la valeur du Storage gagne).
- [ ] Fenix5/5x : l'appli démarre (sport générique) et affiche les pages sans sous-fenêtre (repli sans `getSubscreen`).
- [ ] CHANGELOG.md et garmin_description.md (moins de 4000 caractères) correspondent à ce qui est observé.
