# Vérification — test complet des 62 montres (2026-10-09)

## Périmètre
- Branche `claude/corrections-marche`, HEAD `1967990`, base de comparaison `0c5e6c6` (36 commits, 21 fichiers, +2219 / -121).
- SDK Connect IQ 9.2.0 (`monkeyc`, `monkeydo`, `connectiq` présents dans ~/.local/bin).
- Outil : `zsh tools/run-watches.zsh` (journaux dans /tmp/glidator-build/<montre>.log). Sorties toujours dans /tmp/glidator-build/, jamais bin/.

## Verdict : Non vérifiable pour les tests (compilation OK sur 62/62)
- Compilation : 62/62 OK en release, 62/62 OK en version tests (`-t`).
- Tests : **non lancés**. Sur les 3 montres tentées (epix2, epix2pro42mm, fenix6pro), `monkeydo <prg> <montre> -t` n'a produit aucune sortie pendant 300 s (arrêté par le script : « tests BLOCKED (>300s) after 0 tests »). Le simulateur (processus `simulator` déjà ouvert) et le processus `shell` démarré par monkeydo sont présents mais ne répondent pas ; l'exécution depuis cette session ne dispose probablement pas d'une session graphique utilisable. Aucun test n'a donc été vu passer ni échouer. Les 59 autres montres n'ont pas été tentées (chaque tentative coûte 5 min pour le même résultat attendu) : « tests non lancés ».
- Conséquence : l'exigence D2 (suite verte, banc d'affichage compris) n'est PAS démontrée par cette vérification. Il n'y a aucun échec à nommer ; il n'y a aucune preuve de réussite non plus.

## Contrôles statiques
- **Vario intact** : `source/WatchData.mc` absent de `git diff --stat 0c5e6c6..HEAD` (aucun commit ne le touche). Dans `WatchDisplay.mc`, aucune hunk sur `start()`, `vario()`, `beep()`, `heading()`, `compass()`. OK.
- **FlyInstrumentView.mc** : 1 ligne changée (`display.altitude($.formatFlightAltitude(altitude), record)`, garde d'altitude −500..9000 m = V1b/V3). Dans `FlyInstrumentApp.mc` : `new Preferences(self)` (migration des préférences, hors zone sensible). OK.
- **WatchDisplay.altitude()** : unité " m" supprimée après « -- » (décision 09/10). **speed()** : `flySpeedLineX` décale la ligne sur Instinct (V1a). **time_and_battery()** : `timeBatteryLayout` (V2). Le reste des hunks concerne la grille Marche (`hikeGrid`, `hikeGridSubscreen`, commentaires de `pickFont`) et la carte (« Waiting for / GPS » via `HikeMapLayout.waitingLinesY`), hors zone sensible. OK, conforme aux points V1a, V1b, V2, V3a/V3b. Je n'ai pas relu le plan `glidator2-plan-affichage-vol.md` point par point : correspondance déduite des messages de commit.
- **manifest.xml** : le seul changement depuis la base est `version="0.0.1"` → `"2.1.2"`. L'ajout des epix n'apparaît pas dans ce diff (déjà présent à la base, `epix2*` sont dans la liste des 62). OK.
- **bin/, developer_key, .DS_Store** : aucun commit du round ne les touche (`git log 0c5e6c6..HEAD -- bin developer_key .DS_Store` vide). developer_key non lu. OK.
- **Arbre de travail** : `git status` propre après toutes les compilations (aucun fichier suivi modifié).
- **Tests ajoutés par les commits** : tests rouge-puis-fix présents pour chaque fix (Tests.mc, TestsChain.mc, TestsFormat.mc, TestsHikeGrid.mc, TestsHikeMap.mc, TestsLayout.mc : +1000 lignes environ). Pas de test désactivé repéré dans les diffs lus ; relecture exhaustive des tests non faite.
- **Non couvert / à confirmer** : le comportement réel d'affichage (polices, positions) ne peut être prouvé sans le banc ; le dessin de `hikeGridSubscreen` sur Instinct dépend de `WatchUi.getSubscreen()` (absent sur CIQ < 3.2.7, repli sur l'ancienne grille).

## Compilation et tests par montre

Légende : Rel = `monkeyc` release, -t = `monkeyc -t`. Tests : « non lancé » = pas de sortie du simulateur (voir verdict), ou « non tenté ».
Échecs nommés : aucun (pas de test exécuté).

| # | Montre | Rel | -t | Tests | Échecs nommés |
|---|--------|-----|----|-------|---------------|
| 1 | epix2 | OK | OK | non lancé (BLOCKED 300 s, 0 test) | - |
| 2 | epix2pro42mm | OK | OK | non lancé (BLOCKED 300 s, 0 test) | - |
| 3 | epix2pro47mm | OK | OK | non tenté | - |
| 4 | epix2pro51mm | OK | OK | non tenté | - |
| 5 | fenix5 | OK | OK | non tenté | - |
| 6 | fenix5plus | OK | OK | non tenté | - |
| 7 | fenix5x | OK | OK | non tenté | - |
| 8 | fenix5xplus | OK | OK | non tenté | - |
| 9 | fenix6 | OK | OK | non tenté | - |
| 10 | fenix6pro | OK | OK | non lancé (BLOCKED 300 s, 0 test) | - |
| 11 | fenix6s | OK | OK | non tenté | - |
| 12 | fenix6spro | OK | OK | non tenté | - |
| 13 | fenix6xpro | OK | OK | non tenté | - |
| 14 | fenix7 | OK | OK | non tenté | - |
| 15 | fenix7pro | OK | OK | non tenté | - |
| 16 | fenix7pronowifi | OK | OK | non tenté | - |
| 17 | fenix7s | OK | OK | non tenté | - |
| 18 | fenix7spro | OK | OK | non tenté | - |
| 19 | fenix7x | OK | OK | non tenté | - |
| 20 | fenix7xpro | OK | OK | non tenté | - |
| 21 | fenix7xpronowifi | OK | OK | non tenté | - |
| 22 | fenix843mm | OK | OK | non tenté | - |
| 23 | fenix847mm | OK | OK | non tenté | - |
| 24 | fenix8pro47mm | OK | OK | non tenté | - |
| 25 | fenix8solar47mm | OK | OK | non tenté | - |
| 26 | fenix8solar51mm | OK | OK | non tenté | - |
| 27 | fenix943mm | OK | OK | non tenté | - |
| 28 | fenix947mm | OK | OK | non tenté | - |
| 29 | fenix9pro43mm | OK | OK | non tenté | - |
| 30 | fenix9pro47mm | OK | OK | non tenté | - |
| 31 | fenix9pro51mm | OK | OK | non tenté | - |
| 32 | fenix9prosolar47mm | OK | OK | non tenté | - |
| 33 | fenix9prosolar51mm | OK | OK | non tenté | - |
| 34 | fr165 | OK | OK | non tenté | - |
| 35 | fr165m | OK | OK | non tenté | - |
| 36 | fr170 | OK | OK | non tenté | - |
| 37 | fr170m | OK | OK | non tenté | - |
| 38 | fr245 | OK | OK | non tenté | - |
| 39 | fr255 | OK | OK | non tenté | - |
| 40 | fr255m | OK | OK | non tenté | - |
| 41 | fr255s | OK | OK | non tenté | - |
| 42 | fr255sm | OK | OK | non tenté | - |
| 43 | fr265 | OK | OK | non tenté | - |
| 44 | fr265s | OK | OK | non tenté | - |
| 45 | fr55 | OK | OK | non tenté | - |
| 46 | fr57042mm | OK | OK | non tenté | - |
| 47 | fr57047mm | OK | OK | non tenté | - |
| 48 | fr70 | OK | OK | non tenté | - |
| 49 | fr745 | OK | OK | non tenté | - |
| 50 | fr945 | OK | OK | non tenté | - |
| 51 | fr945lte | OK | OK | non tenté | - |
| 52 | fr955 | OK | OK | non tenté | - |
| 53 | fr965 | OK | OK | non tenté | - |
| 54 | fr970 | OK | OK | non tenté | - |
| 55 | instinct2 | OK | OK | non tenté | - |
| 56 | instinct2s | OK | OK | non tenté | - |
| 57 | instinct2x | OK | OK | non tenté | - |
| 58 | instinct3amoled45mm | OK | OK | non tenté | - |
| 59 | instinct3amoled50mm | OK | OK | non tenté | - |
| 60 | instinct3solar45mm | OK | OK | non tenté | - |
| 61 | instincte40mm | OK | OK | non tenté | - |
| 62 | instincte45mm | OK | OK | non tenté | - |

Remarque : les compilations `-t` ont été faites avec `monkeyc ... -t` directement (sorties `/tmp/glidator-build/<montre>-t.prg`), pas avec le script, pour éviter 62 attentes de 300 s. Les journaux `<montre>.log` des 3 montres tentées contiennent « BUILD SUCCESSFUL » puis une sortie monkeydo vide.

## Problèmes trouvés
- **Bloquant (environnement, pas le code)** : le simulateur ne répond pas à `monkeydo -t` depuis cette session (0 ligne de sortie en 300 s sur 3 montres). À relancer depuis une session avec le simulateur actif : `zsh tools/run-watches.zsh <montre>...` (ouvrir le simulateur à la main, vérifier qu'une appli se charge, puis lots de 5-8 montres).
- Moyen : l'exigence D2 (62/62 vertes) reste non prouvée.
- Mineur : `RUN_WATCHES_TIMEOUT=60 zsh tools/run-watches.zsh ...` est refusé par les permissions du round (préfixe de variable d'environnement) ; le délai reste donc à 300 s par étape.

## Protocole manuel pour l'utilisateur

### A. Lancer la suite de tests
- [ ] Ouvrir le simulateur (`connectiq`), charger une montre (File > Load Device), confirmer qu'il répond.
- [ ] Depuis le dépôt : `zsh tools/run-watches.zsh fenix6pro fenix5 instinct2 fr965 fenix7x` puis les 62 par lots. Attendu : « N tests: N passed, 0 failed » (188 tests selon docs/tests/plan-test-approfondi.md), aucune ligne `MISMATCH`, `NOT RUN` ou `BLOCKED`.
- [ ] Pour tout échec : lire `/tmp/glidator-build/<montre>.log` (lignes `LAYOUT ...`) et le transmettre au dev.

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

### D. Validation de la 2.1.2
- [ ] Nom de l'application « Glidator2 » dans le menu de la montre et dans le simulateur (Settings > App).
- [ ] Version 2.1.2 (manifest) ; premier lancement après mise à jour : les anciennes préférences sont migrées, aucune erreur au démarrage (en cas de conflit, la valeur du Storage gagne).
- [ ] Fenix5/5x : l'appli démarre (sport générique) et affiche les pages sans sous-fenêtre (repli sans `getSubscreen`).
- [ ] CHANGELOG.md et garmin_description.md (moins de 4000 caractères) correspondent à ce qui est observé.
