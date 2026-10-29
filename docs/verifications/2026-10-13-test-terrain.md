# Protocole de test terrain (montre réelle) - mode marche corrigé

- **Date** : 13/10/2026, branche `claude/corrections-marche`.
- **Pour qui** : l'utilisateur, sur le terrain cette semaine, avec sa montre.
- **Durée** : la sortie elle-même, plus 15 minutes avant le départ et 15 minutes au retour.
- **Pourquoi un test terrain** : le simulateur ne transmet ni la FC ni l'altitude réelle (voir `2026-10-13-essai-marche.md`). Seule une montre réelle montre ALTITUDE, FC, VERT. SPD. et PACE avec de vraies valeurs.
- **Règle** : cocher chaque case, et noter la valeur lue quand une ligne a un espace `_____`. Ne rien deviner : écrire « pas vu » si on n'a pas regardé.
- **Comparaison** : garder la montre Garmin habituelle (ou l'appli native Marche / Randonnée de la même montre) à l'autre poignet ou dans le sac pour comparer. Les écarts attendus sont donnés plus bas ; au-delà, le noter.

## 0. À savoir avant de partir

- Pages du mode marche (touches HAUT / BAS) : **ALTITUDE / ELEV. GAIN / DISTANCE / TIMER**, puis **Heart Rate / VERT. SPD. / PACE / TIMER**, puis **Heure et batterie**, puis **Carte**.
- Pages du mode vol : instrument de vol (altitude, vario, vitesse sol, cap), heure et batterie, boussole avec coordonnées.
- Nouveauté de cette nuit (décision D3 A) : si l'enregistrement ne démarre pas (la montre répond « non » à `Session.start()`), l'app n'émet **ni son ni vibration**, n'affiche pas d'écran « en pause » et montre quelques secondes le message **« Recording failed »** (encadré blanc à bord rouge sombre). Il faut alors rappuyer sur START.
- Nouveauté de cette nuit (décision D6) : la carte accepte aussi un fix GPS 2D. La trace se remplit donc plus vite, mais des points peu précis peuvent apparaître sous les arbres ou contre une falaise.
- Valeurs « plausibles » : ALTITUDE entre -100 et 6000 m, FC entre 25 et 250 bpm, VERT. SPD. jamais au-delà de ±3000 m/h (sinon « -- »), PACE « --:-- » à l'arrêt ou au-dessus de 60:00/km. Hors de ces plages l'app écrit « -- » exprès.
- Rappel : « -- » est normal pendant environ 20 à 25 s après le démarrage ou une reprise pour VERT. SPD. et PACE.

## 1. Avant le départ (à la maison)

- [ ] **Clé développeur** : suivre la section « Installing on the watch » du `README.md`. **Attention : ne pas écraser le fichier `developer_key` existant** (la clé qui a signé la version du store). Pour une nouvelle clé, utiliser un autre nom de fichier, comme le README l'indique (`-out ~/garmin-keys/glidator_key.der`). Un agent ne lit jamais cette clé.
- [ ] **Identifier la montre** : relever l'id exact de la montre dans `manifest.xml` (ex. `fenix6pro`, `fenix7`, `fr265`). Modèle : `__________` id : `__________`.
- [ ] **Compiler** vers un dossier hors du dépôt : `monkeyc -f monkey.jungle -o /tmp/glidator-build/Glidator2.prg -d <id> -y developer_key` (sans `-t`). Attendu : `BUILD SUCCESSFUL`.
- [ ] **Copier le `.prg`** (pas le `.iq`) dans `GARMIN/Apps` de la montre par USB. Sur Mac, une montre en MTP demande un outil comme OpenMTP ; fermer Garmin Express au besoin.
- [ ] **Débrancher** proprement, attendre quelques secondes.
- [ ] **Version du store déjà installée ?** La retirer d'abord (app Connect IQ du téléphone), pour ne pas avoir deux Glidator2. Noter : `__________`.
- [ ] **Retrouver l'app** sur la montre : START, liste des activités, ou liste des applications Connect IQ (menu exact selon le modèle). Noté : `__________`.
- [ ] **Lancer l'app** : elle démarre sur la page ALTITUDE (mode marche). Noter les « -- » éventuels : `__________`.
- [ ] **Réglages (MENU)** : bips audio activés pour le vario ; fenêtre « Climb rate avg » (ex-« VS window ») à « over 1 min » (valeur par défaut) pour comparer avec la montre. Noter les autres choix : `__________`.
- [ ] **Batterie** : au moins 80 %. Noter : `____ %`. Noter aussi l'état GPS réglé sur la montre (GPS seul, multi-bandes, etc.) : `__________`.
- [ ] **Appli de comparaison** : démarrer la montre Garmin (ou l'activité native) en même temps que Glidator2, au même point de départ, et noter l'heure : `__:__`.

## 2. Au départ, dehors

- [ ] Attendre le fix GPS : page **Carte**. « Waiting for GPS » doit disparaître en moins de 1 à 2 minutes à ciel ouvert. Temps mesuré : `____ s`.
- [ ] Relever l'altitude de départ et la comparer à l'altitude connue du lieu ou à la montre de comparaison : Glidator2 `____ m`, référence `____ m`. Écart attendu : quelques mètres (la montre étalonne l'altimètre par GPS).
- [ ] **Appuyer sur SELECT (START)** : un cercle vert avec un triangle blanc s'affiche quelques secondes, avec un bip et une vibration. Noter :
  - [ ] l'icône verte apparaît, son et vibration : oui / non
  - [ ] ou bien le message **« Recording failed »**, sans son ni vibration : oui / non. Dans ce cas, noter l'heure, rappuyer sur SELECT et noter si cela marche au 2e essai : `__________`.
- [ ] Le TIMER avance (page ALTITUDE ou Pace) : oui / non.

## 3. En marche (relevés toutes les 10 à 15 minutes)

Noter chaque relevé dans le tableau. Regarder les deux montres presque en même temps. Faire 3 relevés au minimum : en montée régulière, à plat, en descente.

| Heure | Terrain | ALTITUDE (m) | Réf. (m) | ELEV. GAIN / D+ (m) | Réf. | DISTANCE (km) | Réf. | VERT. SPD. (m/h) | Réf. | PACE | Réf. | FC | Réf. |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | | | |
| | | | | | | | | | | | | | |
| | | | | | | | | | | | | | |
| | | | | | | | | | | | | | |

Ce qu'il faut vérifier (et ce qui est attendu d'après l'étalon de Salvan, 13/09, `2026-10-13-etalon-marche.md`) :

- [ ] **ALTITUDE** : valeur entière en mètres, proche de la montre de comparaison (quelques mètres). Jamais « -- » sauf avant le fix ou hors de -100..6000 m.
- [ ] **ELEV. GAIN (D+)** : n'augmente que dans les montées. Sur le tour de Salvan, l'étalon donne environ 909 m de D+ en 2 h pour 837 m de dénivelé net : un D+ légèrement supérieur au dénivelé net est normal (replats, petites bosses). À comparer au D+ de la montre de comparaison : écart attendu de quelques pour cent. Comparer en fin de sortie surtout. Écart `____ %`.
- [ ] **DISTANCE** : en km avec une décimale. Sur Salvan, la distance GPS brute est environ 2,7 % au-dessus de la distance enregistrée par Garmin. Un écart de quelques pour cent avec la montre de comparaison est donc possible. Noter l'écart de fin de sortie : `____ %`.
- [ ] **VERT. SPD.** : en m/h avec signe (« +660 »). Valeurs de l'étalon pour une montée soutenue : +590 à +740 m/h (montée régulière), +1240 m/h au plus raide, environ -840 à -890 m/h en descente raide. À l'arrêt : proche de 0 (« +10 », « -80 »). « -- » 20 à 25 s après le départ puis seulement au-delà de ±3000 m/h.
- [ ] **PACE** : min:s par km. Sur Salvan : 15:30 à 17:30 au meilleur de la montée, 25 à 45 min/km en montée lente. « --:-- » à l'arrêt, ou plus lent que 60:00/km : normal. Environ 28 % des minutes du tour de Salvan étaient en « --:-- » : ne pas s'en étonner.
- [ ] **FC** (page Pace, « Heart Rate ») : valeur proche de la montre de comparaison (à quelques bpm). « -- » seulement si le capteur optique ne lit pas (montre mal serrée) ou pendant une pause (capteur coupé). Noter la FC max vue : `____`.
- [ ] **Carte** : la trace se dessine derrière le marqueur de position, qui est orienté dans le sens de la marche. Vérifier : la trace suit le chemin parcouru, pas de lignes droites aberrantes ni de sauts sous les arbres ou près de falaises (D6 : fix 2D accepté) ; le message « Waiting for GPS » n'apparaît que sans position ni trace. Noter les sauts vus et leur lieu : `__________`.
- [ ] **Autres pages** : Heure et batterie correctes (comparer à la montre).
- [ ] **Lisibilité** : toutes les valeurs de la grille sont lisibles, sans chevauchement, en plein soleil. Noter les défauts d'affichage : `__________`.

## 4. Passage en vol (BACK/LAP 1,5 s)

À faire une fois au sol, au décollage ou sur la zone (sans risque), puis lors du vol réel si l'utilisateur vole.

- [ ] **Passage marche vers vol** : maintenir BACK/LAP environ 1,5 s. La page d'instrument de vol s'affiche. Une courte pression de BACK ne fait rien pendant une session. Si l'enregistrement tourne, un tour (lap) est ajouté : noter `oui / non / ne sait pas`.
- [ ] **Instrument de vol** : altitude, vario (m/s), vitesse sol (km/h) et cap sont affichés. Rien de nouveau n'a été changé sur ces pages cette nuit : toute différence avec la dernière fois est un défaut à noter.
- [ ] **Vario et bips** : en montée de plus de 0,3 m/s, la valeur est verte et les bips montent ; en descente forte (plus de -2,0 m/s) elle est rouge ; sinon grise. À vérifier en marche rapide en montée (valeurs faibles) ou en vol. Bips actifs : oui / non. Noter la cohérence avec la montre de comparaison : `__________`.
- [ ] **Boussole** (HAUT / BAS depuis le vol, 3e page) : la rose tourne avec la montre ; le cap correspond à celui d'une autre boussole (téléphone) à quelques degrés ; les coordonnées GPS sont affichées. Écart de cap mesuré : `____ °`.
- [ ] **Heure et batterie** : OK / pas OK.
- [ ] **Retour vers la marche** : maintenir BACK/LAP 1,5 s à nouveau. La page ALTITUDE revient (en mode marche, VERT. SPD. et PACE montrent « -- » environ 20 à 25 s : normal). Noter si un tour supplémentaire est enregistré.

## 5. Pause, reprise, enregistrement

- [ ] **Pause** : pendant la marche, appuyer sur SELECT. Le TIMER s'arrête, deux courtes vibrations, le menu **Paused** s'ouvre (Resume, Pause, Save, Ignore).
- [ ] **Reprise par BACK** dans ce menu : le chronomètre repart, une longue vibration. Même chose après 30 s sans choix (reprise automatique).
- [ ] **Pause longue** : choisir « Pause » dans le menu. L'écran Paused (heure actuelle) reste jusqu'à SELECT. BACK ne fait rien. SELECT reprend. Durée de l'essai : `____ min`.
- [ ] **Capteurs en pause** : pendant la pause, FC « -- » (capteur coupé, déduit du code, non encore vu sur montre) : noter ce qu'on voit : `__________`. Après reprise : FC revient en quelques secondes, VERT. SPD. et PACE en « -- » environ 20 à 25 s.
- [ ] **Fin** : SELECT, puis **Save**. L'app se ferme. Vérifier sur la montre que l'activité apparaît dans l'historique, nom « Glide » : oui / non.
- [ ] **Si l'app est fermée par la montre** pendant une session (manque de batterie, etc.) : l'activité doit être sauvegardée, pas perdue. Noter tout arrêt inattendu : `__________`.
- [ ] **Batterie à l'arrivée** : `____ %` après `____ h`. Consommation : `____ % / h`.

## 6. À noter et à ramener

Pendant la sortie, noter sur papier ou dans le téléphone, avec l'heure :
- toute valeur « -- » inattendue (quelle page, quelle heure, ce que l'on faisait) ;
- toute valeur absurde (altitude fausse, D+ qui monte à plat, PACE aberrant, FC à zéro) ;
- tout défaut d'affichage (texte coupé, valeurs qui se chevauchent) avec le modèle de montre ;
- tout redémarrage, gel ou fermeture de l'app ;
- le message « Recording failed » s'il apparaît, avec les circonstances.

Au retour :
- [ ] **Fichier FIT de la sortie** : brancher la montre en USB, copier le fichier `.fit` le plus récent du dossier `GARMIN/Activity` (nom du type `2026-10-xx-xx-xx-xx.fit`). Sur Mac, une montre MTP demande un outil comme OpenMTP. Synchroniser aussi avec Garmin Connect (même sortie) pour avoir le **Total Ascent** officiel de la montre.
- [ ] **Ramener** : le fichier FIT de Glidator2, celui de la montre de comparaison (ou l'export Garmin Connect de l'activité), le tableau de la section 3, les notes ci-dessus, le **modèle exact de la montre** et la **version du firmware** (Réglages > Système > À propos).
- [ ] Noter dans Garmin Connect le **D+ (Total Ascent)** et la **distance** de l'activité de comparaison : `____ m` / `____ km`.
- [ ] Donner le tout à `analyste-activite` : il rejoue la sortie sur l'étalon (D+ lissé, PACE, VERT. SPD.) et compare à Garmin Connect. Le seuil de lissage du D+ (3 m, hypothèse) sera calibré avec le Total Ascent relevé.
