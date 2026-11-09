# Fond de carte sous le tracé en mode Marche

Date : 2026-10-27. Branche : `claude/recherche-fond-carte`. Aucun code de l'app modifié.
Légende : **[S]** = sourcé (doc, forum, fichier du SDK local), **[D]** = déduit par moi, **[?]** = incertain / non vérifié.

## Question

Aujourd'hui la page carte du mode Marche (`source/HikeMapView.mc`, `WatchDisplay.map()`, `BreadcrumbTrail.mc`) dessine seulement le tracé (anneau de 250 points, un point tous les 15 m) et une flèche de cap, sur fond blanc. Peut-on afficher la carte topo déjà installée sur la montre sous ce tracé, sur quelles montres du `manifest.xml`, avec quelles limites, quel coût, et faut-il le faire ?

Ce qui permet de trancher : (1) la liste exacte des montres du manifest qui ont des cartes, (2) la compatibilité avec l'architecture actuelle (navigation par `switchToView`, touches HAUT/BAS prises par l'app), (3) le risque de régression sur les autres montres.

## Réponse courte / recommandation

**Faire, mais en option et après un essai sur montre réelle (spike), pas avant la publication de la 2.1.2.** Niveau de confiance : **moyen** sur la faisabilité technique, **faible** sur le coût batterie/mémoire (aucune mesure publique trouvée).

- 31 des 58 montres du manifest ont des cartes embarquées et l'API `WatchUi.MapView` / `MapTrackView` (API 3.0.0, sans permission). Les 27 autres gardent le tracé actuel. [S]
- La voie native (`MapTrackView`) est la seule sérieuse : l'app n'a rien à télécharger, la carte est dessinée par le système de la montre. [S]
- Ce qu'on perd : le contrôle du dessin. On ne peut pas dessiner soi-même le tracé en coordonnées écran par-dessus, car l'app ne connaît pas la zone réellement affichée ; il faut passer par les objets `MapPolyline` et `MapMarker`. [S]
- Risques principaux : `switchToView` avec une MapView (non confirmé sur montre), conflit des touches, écart de zoom entre familles de montres (fenix 6 / 7 / Epix 2). [S] pour les rapports de bugs, [?] pour leur état actuel.

## 1. Montres du manifest avec cartes et API nécessaire

**Constat de chiffres** : le `manifest.xml` contient **58** `<iq:product>`, pas 62 (la fiche de contexte dit 62 ; à corriger côté mémoire). [S, lecture du fichier]

**Méthode** : trois sources croisées.
1. Page API officielle `MapView` : liste des appareils pris en charge. [S] (URL en fin de note)
2. Doc locale du SDK 9.2.0 (`.../Sdks/connectiq-sdk-mac-9.2.0-.../doc/Toybox/WatchUi/MapView.html`) : elle cite 5 Forerunner, cohérent avec la page web (945, 945 LTE, 955, 965, 970). [S]
3. Fichiers `Devices/<montre>/simulator.json` du SDK local : une clé `"map"` (boutons de carte du simulateur) est présente pour 85 des 173 appareils installés. Pour les 58 montres du manifest, elle est présente exactement pour les 31 montres de la liste officielle et absente pour les 27 autres. [S pour le constat, D pour l'usage comme indicateur de capacité : ce n'est pas un champ documenté "capacité carte"]

Le SDK local (9.2.0 du 2026-06-09) contient bien les `compiler.json`, `simulator.json` et `*.api.debug.xml` de tous les appareils. Il n'existe pas de champ explicite `map` dans `compiler.json`. Le fichier `api.debug.xml` cite `MapView` pour les 173 appareils, y compris sans carte : **il ne prouve rien** sur la capacité. [S]

### Montres AVEC cartes (31) — par groupe d'API (valeur `deviceGroup` du `compiler.json`)

| Groupe | Montres du manifest | Écran | Mémoire app (watchApp) |
|---|---|---|---|
| API 3.1 | fenix5x | MIP | 1,25 Mo |
| API 3.3 | fenix5plus, fenix5xplus, fr945 | MIP | 1,25 Mo |
| API 3.4 | fenix6pro, fenix6spro, fenix6xpro, fr945lte | MIP | 1,25 Mo (fenix6pro et fr945 vérifiés ; les autres : non relevé) |
| API 5.2 | fenix7, fenix7s, fenix7x, fenix7pro, fenix7spro, fenix7xpro, fenix7pronowifi, fenix7xpronowifi, fr955 | MIP | 768 Ko (fenix7, fr955 vérifiés) |
| API 5.2 | fr965 | AMOLED | 768 Ko |
| API 6.0 | fenix843mm, fenix847mm, fenix8pro47mm, fenix943mm, fenix947mm, fenix9pro43mm, fenix9pro47mm, fenix9pro51mm, fr970 | AMOLED | 768 Ko (fenix843mm, fenix9pro47mm, fr970 vérifiés) |
| API 6.0 | fenix8solar47mm, fenix8solar51mm, fenix9prosolar47mm, fenix9prosolar51mm | MIP | 768 Ko |

Total : 1 + 3 + 4 + 9 + 1 + 9 + 4 = 31. [S pour les groupes et l'écran, lus dans les `compiler.json`]

Toutes sont au-dessus du `minSdkVersion="3.0.0"` de l'app : la classe est "Since API Level 3.0.0". [S]

### Montres SANS cartes (27) — repli sur le tracé actuel

- fenix5, fenix6, fenix6s (3). La page officielle liste explicitement "fenix 6 Pro / Sapphire / ..." mais pas les fenix 6 / 6S de base. [S]
- Forerunner : fr165, fr165m, fr170, fr170m, fr245, fr255, fr255m, fr255s, fr255sm, fr265, fr265s, fr55, fr57042mm, fr57047mm, fr70, fr745 (16). [S]
- Instinct : instinct2, instinct2s, instinct2x, instinct3amoled45mm, instinct3amoled50mm, instinct3solar45mm, instincte40mm, instincte45mm (8). [S]

Piège de lecture : l'exemple `samples/MapSample/manifest.xml` du SDK liste `fenix5` (non Plus) parmi ses produits (minSdk 2.4.0, sans permission). C'est une liste de compilation de 2018, pas une preuve de capacité : la page officielle et le simulateur local excluent la fenix5. Un fil du forum dit aussi que la fenix 5 n'a pas les cartes. [S]

### Permission et niveau d'API

- Aucune permission listée sur les pages `MapView`, `MapTrackView`, `MapPolyline`, `MapMarker`. L'exemple `MapSample` du SDK déclare `<iq:permissions/>` vide. Les 4 permissions actuelles (Fit, Positioning, Sensor, SensorHistory) suffisent. [S]
- `minSdkVersion` : la classe existe depuis 3.0.0, donc 3.0.0 convient. [S]
- Types d'app autorisés : watch app (le nôtre), data field, widget, watch face, glance. [S]
- Détection à l'exécution : **piège**. Comme `MapView` apparaît dans les tables de symboles de tous les appareils, un test `WatchUi has :MapView` risque de répondre vrai sur une montre sans carte. [D, non testé] Le plus sûr est une liste fermée de montres (exclusion à la compilation via le `monkey.jungle`, ou liste des `partNumber`), validée par un test de banc qui parcourt les 58 montres. Le `monkey.jungle` actuel ne contient qu'une ligne (`project.manifest = manifest.xml`), donc rien n'est prévu aujourd'hui pour des sources par montre.

## 2. Ce qu'on peut dessiner par-dessus, et les limites

### Principe [S]

La carte est dessinée par le module cartographique natif de la montre, **derrière** l'interface de l'app. La méthode `onUpdate(dc)` de l'app dessine par-dessus (Garmin, fil "CIQ 3.0 MapView requestUpdate" : le `dc` reçu est "propre"). L'app ne contrôle ni l'échelle ni le rendu : elle passe des paramètres (réponse d'un employé Garmin dans le fil sur le bug de zoom fenix 7).

### Deux classes

| | `MapView` | `MapTrackView` (sous-classe, aucune méthode en plus) |
|---|---|---|
| Comportement | carte statique sur une zone choisie (`setMapVisibleArea`) | carte dynamique centrée sur la position courante, icône de navigation par défaut [S] |
| Pour le mode Marche | il faut poser soi-même un `MapMarker` pour la position | la position est gérée par le système [S]; adapté à "se situer dans le paysage" [D] |
| Défauts rapportés | zoom différent fenix 6 / fenix 7 / Epix 2 [S] | recentre toujours : le déplacement manuel et le zoom sont perdus [S] |

### Éléments dessinables

- **Tracé** : `MapPolyline` (couleur `Graphics.COLOR_*`, épaisseur en pixels, `addLocation` unitaire ou par tableau de `Position.Location`). Aucun maximum de points documenté. [S]
- **Position / repères** : `MapMarker` (icône bitmap avec point d'ancrage, icône prédéfinie `MAP_MARKER_ICON_PIN`, libellé texte). **La doc ne mentionne aucune rotation** : une flèche de cap tournante via marqueur n'est pas prévue. [S pour l'absence dans la doc, D pour la conclusion]
- **Flèche de cap** : avec `MapTrackView` le système affiche déjà l'icône de navigation ; notre flèche actuelle (`WatchDisplay.map()`) ne peut pas être réutilisée telle quelle car on ne connaît pas la zone réellement affichée à l'écran. Le cap peut en revanche s'afficher en texte ou en flèche dessinée au centre de l'écran (la position y est centrée, par construction de `MapTrackView`). [D]
- **Données texte** (altitude, D+, pace, heure) : dessinées normalement avec `dc.drawText` dans `onUpdate`, après `MapView.onUpdate(dc)`. L'exemple `MapSample` fait exactement ça ("Hello World" sur la carte). [S] Lisibilité sur fond topo : il faut un fond/contour pour le texte [D].
- **Réserver une zone pour le texte** : `setScreenVisibleArea(x1, y1, x2, y2)` (en pixels, lève `InvalidPointException` hors écran) limite la zone où la carte est cadrée ; l'exemple du SDK met la carte sur la moitié haute. [S]

### Limites officielles et rapportées

- **`MapView` ne peut pas être la vue initiale** (diapos du Developer Summit 2019, fil du forum). Chez nous la carte est la 4e page de la liste Marche, donc ce point ne bloque pas. [S]
- **`switchToView`** : en bêta CIQ 3, la `MapView` ne s'affichait pas avec `switchToView`, seulement avec `pushView` ; un autre message dit que c'était limité au simulateur. **Non tranché.** Notre app change de page uniquement par `WatchUi.switchToView` (`FlyInstrumentApp.switchToView`). [S pour les rapports, ? pour l'état actuel sur montre]
- **ViewLoop** : bug "acknowledged" (mai 2023, fenix 6, SDK 4.2.4, encore signalé sur SDK 6.2.0 en simulateur fenix 6S Pro) : la carte n'est pas dessinée dans un `ViewLoop`. L'app n'utilise pas de `ViewLoop` (elle gère elle-même les pages), donc non concerné. [S, D pour la conclusion]
- **Modifier la zone** : appeler `setMapVisibleArea` dans `onUpdate()` est déconseillé par la doc (redessine la carte, scintillement). Appeler `Ui.requestUpdate()` rappelle `onUpdate`, mais la carte ne se redessine que si son contenu change (marqueur, polyligne, zone). [S]
- **Polyligne posée après coup** : sur `MapTrackView`, une polyligne ajoutée dans `onUpdate()` n'apparaissait pas dans le simulateur (non confirmé sur montre). Prévoir `clear()` puis re-pose ; `clear()` efface tout, pas de suppression unitaire. [S]
- **Zone réelle affichée inconnue** : `setMapVisibleArea` n'est qu'une suggestion, l'app ne peut pas lire la zone ni le facteur de zoom. Donc pas de dessin "à la main" aligné sur la carte. [S, fil MapTrackView issues]
- **Zoom fenix 6 vs fenix 7** : même appel, zoom différent (bug signalé sept. 2022 sur fenix 6X / 7X, puis Epix 2 ; statut "Acknowledged"). Contournement : réglage par famille de montre. [S]
- **Boutons** : en mode `MAP_MODE_BROWSE`, le système utilise les boutons pour déplacer/zoomer la carte ; le déplacement n'est pas mémorisé (la carte revient à sa position précédente). En mode `MAP_MODE_PREVIEW`, l'exemple SDK reçoit SELECT (passe en BROWSE) et BACK (quitte, ou revient en PREVIEW). [S] Sur D2 Charlie en bêta, un menu poussé sur une MapTrackView perdait ses événements (contournement : dépiler la carte avant le menu). [S, ancien]
- **Fenix 8 tactile** : en BROWSE, pas de déplacement/zoom au toucher sur une `MapTrackView` (bug "Acknowledged", oct. 2024). Hors sujet pour nous (pas de tactile), mais confirme que BROWSE est fragile. [S]
- **Simulateur ≠ montre** : le simulateur récupère les tuiles par le réseau, n'affiche pas la transparence correctement (texte avec boîte blanche, déclaré propre au simulateur par Garmin en 2018), n'a pas les réglages de carte. Tout se valide sur montre réelle. [S]
- **Rafraîchissement** : pas de cadence documentée. `onUpdate` est appelé souvent ; limiter le travail qu'on y fait. [S]

### Conflit avec notre navigation [D]

`BaseInputDelegate.onKey` utilise HAUT/BAS pour changer de page. Sur la page carte, si on active BROWSE, HAUT/BAS seraient pris par le déplacement/zoom du système. Il faut donc rester en PREVIEW (aucun pan/zoom manuel au départ) ou accepter un geste spécifique. À vérifier sur montre : quelles touches arrivent réellement à notre delegate en PREVIEW (le fil du forum précise que `onNextPage`/`onPreviousPage` sont les événements HAUT/BAS sur la plupart des appareils ; nous traitons `onKey` directement).

## 3. Coût mémoire et batterie

### Mémoire

- Aucun chiffre officiel ni mesure publique trouvés sur le coût en mémoire d'une `MapView`. [?]
- Raisonnement : la carte étant rendue par le module natif (réponse Garmin), les données cartographiques ne comptent vraisemblablement pas dans le tas de l'app ; ce qui compte : les objets `Position.Location` de la polyligne et les marqueurs/icônes. [D]
- Marge disponible : 768 Ko à 1,25 Mo pour les montres à cartes (relevé dans les `compiler.json`), contre 128 Ko sur la fenix5 et 96 Ko sur l'instinct2 (qui n'ont pas de carte). Le tracé actuel (2 tableaux de 250 valeurs) est négligeable à cette échelle. [S pour les limites, D pour la conclusion]
- Gestion : la `MapView` empile des vues en mémoire si on utilise `pushView` ; il faut dépiler en quittant (conseil du fil CIQ 3). [S]
- À mesurer : `System.getSystemStats().usedMemory` avant/après affichage de la carte, sur fenix 6 Pro et fenix 7, avec 250 points. [?]

### Batterie

- Aucune mesure publique de la page carte vs page données. [?]
- Indice : les notes de version Garmin (fenix 8 / fenix E / Enduro 3, mise à jour 11.89) citent une "consommation améliorée sur la page carte", ce qui suggère que le rendu de carte pèse sur la batterie, sans chiffre (Notebookcheck). [S, indirect]
- Le GPS est déjà allumé en permanence en mode Marche (décision "GPS gardé allumé"), donc le surcoût est le rendu carte + le rafraîchissement de l'écran. [D]
- Cadence : n'actualiser la polyligne que lorsqu'un nouveau point est ajouté (tous les 15 m), pas à chaque seconde. [D]
- Protocole proposé : 2 sorties identiques (ou 30 min de marche à plat) sur la même montre, GPS et rétroéclairage fixes, une page carte native affichée en continu vs la page carte actuelle ; relever `System.getSystemStats().battery` toutes les 5 min dans les logs et la perte de % en 30 min. Aucun fichier privé dans le dépôt.

## 4. Repli sur les montres sans carte

- Les 27 montres sans carte gardent **exactement** `HikeMapView` + `WatchDisplay.map()` actuels. [recommandation]
- Même page, même place dans la liste `hikingViews` ; seule la classe de la vue diffère selon la montre. [D]
- Séparer proprement : un fichier `HikeNativeMapView.mc` marqué par une annotation (ex. `(:nativeMap)`) exclue à la compilation pour les 27 montres, via le `monkey.jungle`, plutôt qu'un test à l'exécution. Effet de bord utile : les montres sans carte, qui ont 96 à 512 Ko de mémoire, ne portent pas le code en plus. [D, à valider par compilation sur les 58 montres]
- Dégradation sur une montre à carte : si le positionnement n'est pas prêt, garder le message "Waiting for GPS" actuel ; si la carte native n'est pas affichée (cartes absentes de la montre, ou carte effacée par l'utilisateur), on ne sait pas détecter proprement. [?] Prévoir un bouton/réglage "Carte topo : oui/non" (Preferences) qui rebascule sur le tracé.
- Les tests de banc existants (faux `Dc`, 62 montres) ne peuvent pas instancier une `MapView`; ils continueront de tester le tracé et la logique pure. [D]

## Options comparées

| Option | Maturité / maintenance | Perfs / batterie | Licence / dépendance | Effort | Verdict |
|---|---|---|---|---|---|
| A. `MapTrackView` natif (carte centrée, polyligne + texte) | API Garmin stable depuis 3.0 ; bugs "Acknowledged" non corrigés (zoom fenix 7, `switchToView`) | rendu natif ; coût inconnu | aucune permission, aucun réseau | moyen (4 à 5 tâches) | **Recommandé** |
| B. `MapView` natif (zone fixe autour du tracé, marqueur position) | idem ; position non suivie automatiquement | idem | idem | moyen, un peu plus (marqueur, recalage zone) | Variante si on veut voir tout le parcours (cadrage sur le tracé) |
| C. Garder le tracé seul (statu quo) | déjà testé (223 tests) | léger | n/a | 0 | Repli obligatoire pour 27 montres |
| D. Tuiles téléchargées (`makeImageRequest`, téléphone requis) | un fil cite ~20 s par tuile PNG 240x240 sur Forerunner 935 (ancien) | lourd, BLE + Internet, hors-réseau en montagne | politique d'usage des tuiles OSM à respecter ; non vérifiée | élevé | Rejeté |
| E. Image statique prédécoupée (type MapOfflineGPS, data field GitHub) | projet de hobby, licence non indiquée dans la page | léger, mais carte figée 2 couleurs | à vérifier | élevé par parcours | Rejeté |
| F. Moteur de tuiles vectorielles maison (le développeur de l'app komoot dit en avoir un, source non trouvée) | non vérifiable | inconnu | inconnu | très élevé | Rejeté |

Autres apps open source : je n'ai trouvé **aucun dépôt open source** qui utilise `MapTrackView` ou `MapView`. WormNav (GPL-3.0) fait de la navigation sur trace avec zoom/recentrage mais la page ne dit pas comment il dessine ; de toute façon la politique du projet interdit de copier du GPLv3. [S pour la recherche, D pour la conclusion] La seule référence de code fiable est l'exemple officiel `samples/MapSample` du SDK (propriété Garmin, licence du SDK ; on s'en inspire, on ne le copie pas).

## 5. Recommandation argumentée et étapes

### Pourquoi faire

- Le besoin est réel : se situer par rapport aux sentiers, crêtes et rivières, ce que le tracé seul ne donne pas.
- Le coût d'intégration est faible côté API (pas de permission, pas de réseau, classe stable depuis 3.0).
- L'app cible la Fenix (6 Pro de référence pour l'affichage) : la fenix 6 Pro, 7 et 8 sont toutes dans le groupe avec cartes.

### Pourquoi pas tout de suite

- Le développement est figé, l'objectif est de passer aux tests et de publier la 2.1.2 (décision du manageur).
- Trois inconnues ne se lèvent que sur montre réelle : `switchToView` avec la MapView, les touches reçues en PREVIEW, le zoom par famille.
- Aucune mesure batterie/mémoire publique : à mesurer avant de promettre quoi que ce soit.

### Étapes proposées (chaque tâche < 2-3 h, un projet par round, branche `claude/<sujet-court>` neuve)

1. **Spike sur montre (2 h, humain + codeur)** : un `HikeNativeMapView extends WatchUi.MapTrackView` minimal, `setMapMode(PREVIEW)`, texte en surcouche. Critère : sur fenix 6 Pro réelle, la carte topo s'affiche sous le texte via `switchToView` ; sinon via `pushView`. Résultat noté (oui/non) pour `switchToView`, touches reçues, zoom obtenu. **Go / no-go ici.** Ne pas fusionner.
2. **Garde par montre (1,5 h)** : annotation `(:nativeMap)` et exclusion dans `monkey.jungle` pour les 27 montres sans carte ; page Marche choisit la vue native ou `HikeMapView`. Critère : compilation verte sur les 58 montres (`tools/run-watches.zsh --release`), tests existants verts. Le test de banc vérifie la liste des 31 montres.
3. **Navigation et touches (2 h)** : si `switchToView` ne marche pas, passer la page carte en `pushView`/`popView` avec un delegate dédié ; HAUT/BAS pour quitter la page carte ; BACK ne doit pas casser le menu Pause/Save/Ignore ni l'enregistrement. Critère : parcours des 4 pages dans les deux sens, retour et menu pause fonctionnent sur montre.
4. **Tracé + position + données (2,5 h)** : conversion de l'anneau `BreadcrumbTrail` en `MapPolyline` (sous-échantillonner à ~100 points, `clear()` puis re-pose seulement quand un point est ajouté), cadrage `setScreenVisibleArea`, texte sur fond lisible (altitude, D+, cap). Tests Monkey C sur la logique pure (sous-échantillonnage, ordre de l'anneau) dans un module `(:test)`. Critère : tracé visible sur la carte pendant un trajet de 20 min.
5. **Réglage et repli (1,5 h)** : préférence "Topo map" activable/désactivable (`Preferences`), message si pas de GPS. Critère : bascule sans redémarrage, retour au tracé actuel.
6. **Mesures (1 h)** : mémoire (`usedMemory`) et batterie (protocole ci-dessus) sur fenix 6 Pro et fenix 7. Critère : deux chiffres dans un rapport `docs/verifications/`.

Tâches 2 à 6 seulement si la tâche 1 est positive. Dépendances : 1 → 2 → 3 → 4 → 5 ; 6 après 4.

### Ce qui reste sous la barre de 2-3 h
Rien d'inférieur à 1 h ; la tâche 4 est la plus grosse. Si elle déborde : séparer "polyligne" et "texte".

## Ce qui reste incertain

- `switchToView` + MapView sur montre réelle (rapports contradictoires, bêta CIQ 3). [?]
- Touches reçues par l'app en PREVIEW, et usage de SELECT par le système.
- Orientation de la carte (nord en haut ou cap en haut) en `MapTrackView` : non trouvée dans la doc. [?]
- Coût batterie et mémoire : aucune mesure publique. [?]
- Bug de zoom fenix 6 vs 7 : "Acknowledged", correction non confirmée. [?]
- Le champ `"map"` du `simulator.json` comme preuve de capacité : cohérent avec la liste officielle pour nos 58 montres, mais non documenté. [D]
- `has :MapView` fiable ou non sur une montre sans carte : non testé. [?]
- La fenix 6 / 6S de base et la fenix 5 (non Plus) : classées sans carte d'après la page officielle ; aucune confirmation sur montre.
- Pas de liste officielle "cartes installées" côté utilisateur : si l'utilisateur n'a pas téléchargé la carte de sa région, le comportement de la MapView n'est pas documenté. [?]

## Pièges / à savoir

- Le manifest compte 58 montres, pas 62.
- Le SDK local est en lecture seule et contient bien les appareils ; la capacité carte n'y est pas un champ officiel.
- Ne pas se fier au simulateur pour la carte (réseau, transparence, zoom différents).
- Ne pas copier le code de `samples/MapSample` ni de WormNav (GPL-3.0) : réimplémenter les idées.
- Les tests de banc (faux `Dc`) ne couvrent pas la MapView.

## Sources

Officielles Garmin
- Classe `WatchUi.MapView` (version, types d'app, liste des appareils, avertissement `setMapVisibleArea`) : https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/MapView.html
- `WatchUi.MapTrackView` : https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/MapTrackView.html
- `WatchUi.MapPolyline` : https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/MapPolyline.html
- `WatchUi.MapMarker` : https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/MapMarker.html
- FAQ "How do I use a MapView" (page non lisible par mon outil : contenu non utilisé) : https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-use-a-mapview/
- Diaporama Developer Summit 2019 "Making the Most of Maps in Your Connect IQ Apps" : https://www.slideshare.net/slideshow/making-the-most-of-maps-in-your-connect-iq-apps-garmin-connect-iq-developer-summit-kansas-city-2019/142141579

Forum développeurs Garmin
- CIQ 3 MapView and MapTrackView Observations : https://forums.garmin.com/developer/connect-iq/f/discussion/7040/ciq-3-mapview-and-maptrackview-observations
- MapView (setScreenVisibleArea, vue initiale, appareils sans cartes) : https://forums.garmin.com/developer/connect-iq/f/discussion/7014/mapview
- CIQ 3.0 MapView, `Ui.requestUpdate` : https://forums.garmin.com/developer/connect-iq/f/discussion/7054/ciq-3-0---mapview---ui-requestupdate
- MapTrackView issues, simulateur ou conception : https://forums.garmin.com/developer/connect-iq/f/discussion/7181/maptrackview-issues---just-the-simulator-or-is-it-the-design/48746
- Map implementation Fenix 6 : https://forums.garmin.com/developer/connect-iq/f/discussion/264165/map-implementation-fenix-6
- setMapVisibleArea plusieurs fois, mode BROWSE : https://forums.garmin.com/developer/connect-iq/f/discussion/234694/setmapvisiblearea-multiple-times
- Bug fenix 7 : zoom différent de la fenix 6 : https://forums.garmin.com/developer/connect-iq/i/bug-reports/fenix-7-series---mapview-setmapvisiblearea-doesn-t-zoom-to-the-same-map-view-like-fenix-6-series
- Bug : MapView ne marche pas dans un ViewLoop : https://forums.garmin.com/developer/connect-iq/i/bug-reports/mapview-does-not-work-within-viewloop
- Bug : MAP_MODE_BROWSE sur MapTrackView, fenix 8 : https://forums.garmin.com/developer/connect-iq/i/bug-reports/map_mode_browse-for-maptrackview-of-fenix-8
- Petites cartes / tuiles par `makeImageRequest` : https://forums.garmin.com/developer/connect-iq/f/discussion/103/small-maps-possible-with-connect-iq

Dépôts
- WormNav (GPL-3.0, navigation sur trace) : https://github.com/andan67/wormnav
- MapOfflineGPS (image statique, data field) : https://github.com/tskf/MapOfflineGPS

Presse (indice batterie)
- Notebookcheck, mise à jour 11.89 fenix 8 / fenix E / Enduro 3 : https://www.notebookcheck.com/Garmin-Fenix-8-Fenix-E-und-Enduro-3-erhalten-Update-11-89-mit-11-neuen-Features-und-vielen-Verbesserungen.900252.0.html

Fichiers locaux (lecture seule)
- SDK 9.2.0 : `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2/` (`doc/Toybox/WatchUi/MapView.html`, `samples/MapSample/`)
- Appareils : `~/Library/Application Support/Garmin/ConnectIQ/Devices/<montre>/{compiler.json,simulator.json}`
- Code de l'app lu : `manifest.xml`, `monkey.jungle`, `source/HikeMapView.mc`, `source/BreadcrumbTrail.mc`, `source/WatchDisplay.mc` (`map()`), `source/FlyInstrumentApp.mc`, `source/FlyInstrumentDelegate.mc`
