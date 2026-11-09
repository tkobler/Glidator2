# Protocole de test manuel avant publication (Glidator2 2.1.2)

*Rédigé le 30/10/2026 d'après la lecture du code (`source/FlyInstrumentApp.mc`, `FlyInstrumentDelegate.mc`, `PausedView.mc`, `HikePages.mc`, `Preferences.mc`), de `manifest.xml`, de `CHANGELOG.md` et de `docs/tests/plan-test-approfondi.md`. Aucun test n'a été lancé pour rédiger ce protocole : les résultats attendus sont ceux que le code doit produire, à confirmer sur la montre.*

Ce protocole complète les tests automatiques (banc sur 62 montres) : il couvre ce que le simulateur et le banc ne voient pas (rendu du menu système, Garmin Connect, installation).

## Préparation

- Montres conseillées :
  - **fenix 6 Pro** : référence (boutons UP / DOWN / START / BACK, GPS, cardio) ;
  - **fenix 5** : la plus ancienne (CIQ 3.1.6), cas du sport « Randonnée » possiblement inconnu ;
  - **Instinct 2** : écran 1 bit, sous-fenêtre ronde, menu système étroit ;
  - une **Forerunner** (255 ou 245) en renfort pour le menu et l'écran Pause.
- Installer la version à publier (2.1.2, nom « Glidator2 »), compilée hors de `bin/` (`monkeyc ... -o /tmp/...`), ou le paquet `.iq` via Garmin Connect IQ.
- Réglage de l'heure de la montre : tester une fois en 24 h, une fois en 12 h (Système > Format de l'heure).
- Pour les cases GPS : sortir à l'extérieur (ciel dégagé) ou rejouer une trace avec le simulateur (Playback d'un GPX, fichier non versionné).
- Cocher chaque case seulement si le résultat attendu est observé tel quel ; sinon noter l'écart sous la case (montre, firmware, texte exact).

Boutons (noms Garmin) : START = SELECT (haut droit), UP / DOWN = flèches du milieu gauche, BACK / LAP = bas droit, MENU = appui long sur UP (Instinct : bouton MENU dédié).

---

## 1. Navigation des 3 pages de marche

Contexte : l'app démarre en mode **Marche** (Hiking), page d'indice 0. La page Carte est masquée (`HikePages.MAP_ENABLED = false`) : il y a exactement **3 pages**, en boucle. Les boutons UP / DOWN changent de page même pendant l'enregistrement.

Montres conseillées : fenix 6 Pro, puis Instinct 2 (sous-fenêtre) et fenix 5.

- [ ] **N1. Page de départ**
  - Action : lancer Glidator2 depuis la liste des activités.
  - Attendu : page **Position** avec les quatre champs `ALTITUDE`, `ELEV. GAIN`, `DISTANCE`, `TIMER`. Sans enregistrement : `ELEV. GAIN` = `--`, `DISTANCE` = `--`, `TIMER` = `--:--`. Altitude en mètres (ou `--` tant que la montre n'en donne pas).
  - Montre : fenix 6 Pro.
- [ ] **N2. Page suivante (DOWN)**
  - Action : appuyer une fois sur DOWN.
  - Attendu : page **Pace** avec `Heart Rate` (avec le coeur), `VERT. SPD.`, `PACE`, `TIMER`. Sans capteur cardio ou hors 25 à 250 bpm : `--`. `VERT. SPD.` = `--` les ~20 premières secondes, `PACE` = `--:--` à l'arrêt.
  - Montre : fenix 6 Pro.
- [ ] **N3. Troisième page (DOWN)**
  - Action : DOWN une deuxième fois.
  - Attendu : page **Heure** : l'heure `HH:MM` (toujours 24 h sur cette page) et la batterie en pourcentage sous l'heure, sans chevauchement.
  - Montre : fenix 6 Pro.
- [ ] **N4. Bouclage vers le bas**
  - Action : DOWN une troisième fois.
  - Attendu : retour à **Position**. Il n'y a **aucune page Carte** (pas de 4e page).
  - Montre : fenix 6 Pro.
- [ ] **N5. Bouclage vers le haut**
  - Action : depuis Position, appuyer sur UP.
  - Attendu : **Heure** ; UP encore : **Pace** ; UP encore : **Position**.
  - Montre : fenix 6 Pro.
- [ ] **N6. Navigation pendant l'enregistrement**
  - Action : START (démarrage : icône de confirmation brève, ton et vibration de départ), attendre 1 min en marchant, parcourir les 3 pages avec DOWN.
  - Attendu : le `TIMER` est le même sur Position et Pace (ex. `01:05` puis `01:06` ...) et continue d'avancer ; `DISTANCE` en km avec une décimale ; `ELEV. GAIN` en mètres, `0` au départ ; l'icône d'enregistrement n'apparaît qu'au démarrage ; aucun redémarrage ni arrêt de l'activité en changeant de page.
  - Montre : fenix 6 Pro.
- [ ] **N7. BACK court pendant l'enregistrement**
  - Action : appui bref sur BACK pendant l'enregistrement.
  - Attendu : **rien** (l'app ne quitte pas, l'enregistrement continue). BACK court sans enregistrement (avant START) : l'app se ferme.
  - Montre : fenix 6 Pro.
- [ ] **N8. Mode Vol et retour**
  - Action : maintenir BACK 1,5 s environ (relâcher dès le changement de page).
  - Attendu : bascule en mode **Vol** (page Instrument de vol en premier, puis Heure, puis Boussole/Position en boucle, 3 pages). Pendant un enregistrement, la bascule ajoute un tour (lap). Un nouvel appui long BACK revient à la page Position de la marche. L'app ne se ferme pas à la relâche de l'appui long.
  - Montre : fenix 6 Pro.
- [ ] **N9. Instinct 2 : lisibilité**
  - Action : parcourir les 3 pages de marche avec UP / DOWN.
  - Attendu : sur Position et Pace, les champs sont placés autour de la sous-fenêtre ronde (en haut à droite), sans qu'aucun texte ne passe dessous ; tous les textes sont lisibles (écran 1 bit).
  - Montre : Instinct 2.
- [ ] **N10. fenix 5 : navigation**
  - Action : reprendre N1 à N5.
  - Attendu : mêmes pages, même ordre, aucun plantage ni message « Symbol Not Found ».
  - Montre : fenix 5.

---

## 2. Menu START : Resume / Pause / Save / Ignore, reprise auto 30 s

Contexte : START pendant l'enregistrement **met en pause** l'activité (chrono arrêté) et ouvre le menu « Paused » (Menu2 système) avec 4 entrées dans l'ordre **Resume, Pause, Save, Ignore**. Vibration de pause : 2 impulsions courtes (150 ms, intervalle 150 ms). Vibration de reprise : 1 impulsion longue (600 ms). Le cardio et la température sont coupés en pause ; le GPS reste actif.

Montre : fenix 6 Pro (puis Instinct 2 pour M5).

- [ ] **M1. Ouverture du menu**
  - Action : enregistrer 1 min, noter le `TIMER`, appuyer sur START.
  - Attendu : 2 impulsions courtes ; menu titré `Paused` avec `Resume`, `Pause`, `Save`, `Ignore`. Le chrono est figé.
- [ ] **M2. Resume**
  - Action : dans le menu, choisir `Resume`.
  - Attendu : 1 impulsion longue ; retour à la page d'activité ; le `TIMER` repart de la valeur figée (pas de saut du temps passé en pause).
- [ ] **M3. BACK = Resume**
  - Action : START, puis BACK dans le menu.
  - Attendu : même effet que Resume (vibration longue, reprise).
- [ ] **M4. Reprise automatique à 30 s**
  - Action : START, ne toucher à rien, chronométrer.
  - Attendu : sans aucun choix, au bout de **30 s** (à 1 s près) : impulsion longue, menu fermé, activité reprise, `TIMER` reparti. Le délai court depuis l'ouverture du menu ; naviguer dans le menu (UP / DOWN) ne le remet pas à zéro.
- [ ] **M5. Pause : pas de reprise automatique ensuite**
  - Action : START, choisir `Pause` (voir section 3), attendre plus de 30 s.
  - Attendu : toujours en pause (aucune vibration de reprise tardive).
- [ ] **M6. Save**
  - Action : enregistrer au moins 1 min, START puis `Save`.
  - Attendu : ton et vibration d'arrêt, l'app se ferme, l'activité est enregistrée (visible dans Connect après synchronisation, section 4).
- [ ] **M7. Ignore**
  - Action : nouvelle activité, START puis `Ignore`.
  - Attendu : l'app se ferme, l'activité est **supprimée** (rien de nouveau dans Connect).
- [ ] **M8. Pas de reprise tardive après Save ou Ignore**
  - Attendu : après M6 / M7, aucune vibration de reprise 30 s plus tard.
- [ ] **M9. Capteurs en pause**
  - Action : avec une ceinture ou le cardio au poignet, noter la FC sur la page Pace, START (menu), puis Resume.
  - Attendu : la FC se rallume après la reprise (valeur valide dans les ~10 s, sinon `--` un court instant) ; le GPS n'est pas perdu (pas de retour à `--` prolongé de l'altitude ou de la vitesse).

---

## 3. Écran Pause (avec l'heure)

Contexte : choix `Pause` dans le menu START remplace le menu par l'écran **Paused**. Contenu (de haut en bas) : `Paused`, l'**heure courante**, puis `START: resume` en gris. L'heure suit le réglage 12/24 h de la montre : `14:05` (24 h) ou `2:05 PM` (12 h, `12:xx AM` pour minuit, `12:xx PM` pour midi). Pas de reprise automatique. BACK et MENU n'ont aucun effet. Rafraîchi chaque seconde.

Montres : fenix 6 Pro, Forerunner, Instinct 2 (et fenix 5).

- [ ] **P1. Affichage en 24 h**
  - Action : montre en 24 h ; enregistrer, START, `Pause`.
  - Attendu : écran blanc avec `Paused`, l'heure à deux chiffres (ex. `09:07`), `START: resume`. Les trois lignes sont lisibles et séparées.
- [ ] **P2. Affichage en 12 h**
  - Action : régler la montre en 12 h ; recommencer.
  - Attendu : `9:07 AM` ou `2:05 PM` (heure sans zéro initial, suffixe AM/PM). Le texte tient dans l'écran, y compris pour `12:58 PM` (le plus long ; police réduite si besoin).
- [ ] **P3. L'heure avance**
  - Action : laisser l'écran affiché jusqu'au changement de minute.
  - Attendu : l'heure passe à la minute suivante sans action de l'utilisateur.
- [ ] **P4. Pas de reprise auto**
  - Action : attendre 2 min sur l'écran.
  - Attendu : toujours `Paused`, le chrono de l'activité reste figé (à vérifier en P6).
- [ ] **P5. BACK et MENU sans effet**
  - Action : appui bref sur BACK, puis MENU.
  - Attendu : l'écran reste affiché ; l'app ne se ferme pas, aucun menu Préférences n'apparaît.
- [ ] **P6. Reprise par START**
  - Action : START sur l'écran Pause.
  - Attendu : 1 impulsion longue, retour à la page d'activité d'où le menu avait été lancé, `TIMER` repris à la valeur d'avant la pause, plus de décalage.
- [ ] **P7. Double START**
  - Action : deux appuis très rapprochés sur START.
  - Attendu : une seule reprise ; l'app ne se ferme pas et reste sur la page d'activité (le second appui ne quitte pas l'app).
- [ ] **P8. Instinct 2**
  - Attendu : `Paused` ne passe pas sous la sous-fenêtre ronde, l'heure et `START: resume` restent entièrement lisibles.

---

## 4. Type « Randonnée » dans Garmin Connect (fenix 5 comprise)

Contexte : depuis la 2.1.2, **toute sortie est enregistrée en Randonnée** (sport FIT 17), en mode Marche comme en mode Vol (un vol seul apparaît aussi en Randonnée). Si la montre ne connaît pas le type (`deviceKnowsHiking()` faux), l'enregistrement se replie sur **Générique** (FIT 0), sans erreur ni plantage. À noter pour chaque montre testée : Randonnée ou Générique.

Une activité enregistrée : au moins 2 min avec GPS, sauvegardée par `Save`, puis synchronisation avec Garmin Connect (application ou web).

- [ ] **R1. fenix 6 Pro, sortie à pied**
  - Action : mode Marche, 2 à 5 min, `Save`, synchroniser.
  - Attendu : l'activité s'affiche avec le type **Randonnée** (Hiking). Pas « Aviation », pas « Activité » générique.
- [ ] **R2. fenix 6 Pro, mode Vol**
  - Action : basculer en Vol (appui long BACK), enregistrer 2 min, `Save`.
  - Attendu : type **Randonnée** également. Si un tour a été ajouté à la bascule, il apparaît dans les tours.
- [ ] **R3. fenix 5 : démarrage**
  - Action : START sur fenix 5.
  - Attendu : l'enregistrement démarre (icône, ton, vibration), sans message « Symbol Not Found » ni fermeture inattendue de l'app.
- [ ] **R4. fenix 5 : type dans Connect**
  - Action : `Save`, synchroniser.
  - Attendu : type **Randonnée** si la montre connaît ce sport, sinon **Générique** (repli prévu). Noter le résultat obtenu : les deux sont acceptés, un plantage ou une absence d'activité ne l'est pas.
- [ ] **R5. Instinct 2 / Forerunner**
  - Action : même démonstration (sortie courte, `Save`).
  - Attendu : Randonnée ou Générique, noter lequel.
- [ ] **R6. Pause dans l'activité sauvegardée**
  - Action : dans une sortie, faire une pause de ~1 min via le menu (Resume après 30 s ou `Pause`), puis `Save`.
  - Attendu : la durée en mouvement dans Connect exclut le temps de pause.
- [ ] **R7. Fermeture par la montre**
  - Action : enregistrer, puis fermer l'app par le système (changement d'activité forcé, ou batterie critique selon la montre).
  - Attendu : l'activité en cours est **sauvegardée** au lieu d'être perdue (CHANGELOG 2.1.2). À essayer seulement si l'utilisateur sait le provoquer sans risque.

---

## 5. Menu « Climb rate avg » sur Instinct 2

Contexte : MENU (appui long UP, ou bouton MENU) ouvre le menu **Preferences** (Menu2 système) avec deux entrées : `Beep` (sous-libellé `Set audio on/off`, interrupteur) et **`Climb rate avg`** (14 caractères) dont le sous-libellé est `over 1 min`, `over 3 min` ou `over 5 min` (10 caractères). Valeur par défaut : 1 min. Chaque appui sur START passe à la valeur suivante : **1 -> 3 -> 5 -> 1**. Le menu reste ouvert, le sous-libellé change aussitôt, le choix est conservé au redémarrage. La vitesse verticale de la page Pace est une moyenne sur cette durée.

Montre : **Instinct 2** (puis Instinct 2S et fenix 6 Pro pour comparaison).

- [ ] **C1. Ouverture**
  - Action : sur la page Position ou Pace, ouvrir MENU.
  - Attendu : menu titré `Preferences` avec `Beep` et `Climb rate avg`. Le titre et le sous-libellé `over 1 min` sont **entiers** (pas de troncature en `...`, pas de coupure sur le bord de l'écran semi-octogonal).
- [ ] **C2. Libellés complets sur chaque position**
  - Action : placer la sélection sur `Climb rate avg` (DOWN / UP).
  - Attendu : le libellé `Climb rate avg` et son sous-libellé sont lisibles sans chevauchement avec l'indicateur de défilement ni avec la sous-fenêtre.
- [ ] **C3. Cycle de la valeur**
  - Action : START sur `Climb rate avg`, trois fois de suite.
  - Attendu : `over 3 min`, puis `over 5 min`, puis `over 1 min`. Le menu reste ouvert à chaque appui.
- [ ] **C4. Mémorisation**
  - Action : régler `over 5 min`, BACK pour fermer, rouvrir MENU.
  - Attendu : `over 5 min` affiché. Fermer l'app, la relancer, rouvrir MENU : `over 5 min` toujours.
- [ ] **C5. Effet sur la page Pace**
  - Action : marcher en montée régulière (ou rejouer un GPX en montée), observer `VERT. SPD.` avec 1 min puis 5 min.
  - Attendu : la valeur est arrondie à 10 m/h (ex. `+940`) ; avec 5 min elle est plus stable qu'avec 1 min. Changer de fenêtre ne vide pas l'historique : la valeur reste affichée (pas de retour à `--` d'au moins 20 s).
- [ ] **C6. Beep non perturbé**
  - Action : basculer `Beep`, BACK, rouvrir MENU.
  - Attendu : l'état de `Beep` est conservé, `Climb rate avg` garde sa valeur.
- [ ] **C7. BACK**
  - Attendu : BACK ferme le menu et revient à la page d'avant, sans plantage.

---

## 6. Permission retirée à l'installation

Contexte : `manifest.xml` ne déclare plus que trois permissions : **Fit** (enregistrement d'activité), **Positioning** (GPS), **Sensor** (cardio, température). La permission **SensorHistory** (historique des capteurs), inutilisée, a été retirée (commit `8a2103b`).

À faire avec le paquet `.iq` / la version réellement destinée au Store, installé par Garmin Connect IQ (mobile ou Garmin Express).

- [ ] **I1. Liste des permissions**
  - Action : installer Glidator2 depuis l'application Connect IQ (ou Garmin Express) et lire l'écran de permissions avant de valider.
  - Attendu : seules les trois permissions suivantes (formulations Garmin) : enregistrement d'activité / données de fitness, position, capteurs. **Aucune** mention de l'historique des capteurs (« Sensor history »).
- [ ] **I2. Détails de l'app dans Connect IQ**
  - Action : ouvrir la fiche de l'app installée > Permissions.
  - Attendu : même liste qu'en I1.
- [ ] **I3. Fonctionnement après installation neuve**
  - Action : supprimer l'app de la montre, la réinstaller, la lancer.
  - Attendu : l'app démarre en mode Marche, page Position, sans plantage. Altitude, cardio (page Pace) et GPS fonctionnent comme avant : aucune fonction ne dépend de l'historique des capteurs.
- [ ] **I4. Mise à jour depuis une version précédente**
  - Action : installer par-dessus une ancienne version (si disponible).
  - Attendu : la mise à jour se fait sans message d'erreur ; la préférence de bip est conservée (reprise automatique des anciens réglages au premier lancement, CHANGELOG 2.1.2).

---

## Récapitulatif à renvoyer

Pour chaque montre testée, noter : modèle, firmware, version de l'app (2.1.2), cases cochées, écarts avec texte exact, type d'activité vu dans Connect (Randonnée / Générique), format d'heure (12 / 24 h) pour la section 3.

| Montre | Sections faites | Écarts |
|---|---|---|
| fenix 6 Pro | | |
| fenix 5 | | |
| Instinct 2 | | |
| Forerunner | | |
