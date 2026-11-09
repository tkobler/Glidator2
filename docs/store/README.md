# Captures pour la fiche du Store

Statut : aucune capture n'a été produite automatiquement. Une tentative de
`screencapture -x` depuis l'agent a été refusée (« This command requires approval »),
comme déjà noté pour ce projet. Aucune image n'a été inventée : ce dossier ne
contient donc que cette procédure. À faire à la main, une fois, sur le Mac.

Cible : 4 planches PNG au plus, rangées dans `docs/store/` :

| Fichier à produire | Contenu | Captures à assembler |
|---|---|---|
| `store-1-vol.png` | Mode Vol | Instrument de vol, Boussole (avec coordonnées), Heure, sur fenix6pro |
| `store-2-marche.png` | Mode Marche | Position, Allure, Heure, sur fenix6pro |
| `store-3-pause.png` | Pause | Menu Pause (Resume / Pause / Save / Ignore), écran Pause, sur fenix6pro |
| `store-4-montres.png` | Aperçu des 3 montres | La même page (Position en Marche) sur fenix847mm, fenix6pro, instinct2 |

## Règles (dépôt public)

- Aucune trace GPS réelle, aucune coordonnée réelle (la page Boussole et la page
  Position Marche affichent lat/lon). Utiliser uniquement une activité synthétique
  (voir plus bas), en un lieu inventé.
- Ne pas retoucher les captures (recadrage et assemblage seulement).
- Ne jamais compiler dans `bin/` ; ne pas lire ni copier `developer_key`.

## 1. Compiler (une fois par montre)

Depuis la racine du dépôt, après `mkdir -p /tmp/glidator-build` :

```
monkeyc -f monkey.jungle -o /tmp/glidator-build/fenix847mm.prg -d fenix847mm -y developer_key
monkeyc -f monkey.jungle -o /tmp/glidator-build/fenix6pro.prg -d fenix6pro -y developer_key
monkeyc -f monkey.jungle -o /tmp/glidator-build/instinct2.prg -d instinct2 -y developer_key
```

Une commande par appel (pas de `&&`). Ne pas ajouter `-t` : il faut l'app normale.

## 2. Activité synthétique

Créer hors dépôt (par exemple dans `/tmp/glidator-synth/`) un fichier GPX ou FIT
inventé : une montée régulière d'environ 300 m en 30 min, à vitesse de marche
(~4 km/h, allure ~15 min/km), dans un lieu fictif (par ex. latitude 45.000,
longitude 7.000 changée à la main, ou un point en mer), avec une fréquence
cardiaque inventée de 110 à 140 bpm. Ne jamais partir d'un fichier de
`garmin_data/` ou `data/`. Pour la page Vol, une seconde activité synthétique :
descente de 1 500 m en 10 min (vario d'environ -2,5 m/s), cap 270 degrés.

Valeurs attendues à l'écran, pour contrôle : en Marche, vitesse verticale
proche de +600 m/h, allure proche de 15 min/km ; en Vol, vario proche de -2,5 m/s.
Si une valeur affiche « -- », la donnée est hors bornes ou absente : refaire
la lecture.

## 3. Lancer le simulateur et rejouer l'activité

1. Avant tout, vérifier qu'aucun `monkeydo` ne traîne : `pgrep -fl monkeydo`. En
   cas de simulateur figé, `relancer-simulateur` (un seul essai).
2. Ouvrir le simulateur (Connect IQ Simulator, ou `connectiq`).
3. Lancer l'app : `monkeydo /tmp/glidator-build/fenix6pro.prg fenix6pro`.
4. Menu du simulateur : `Simulation > Activity` (ou `Simulation > FIT Data` selon
   la version) : charger le fichier synthétique, lancer la lecture (Playback),
   régler la vitesse de lecture au besoin.
5. Laisser tourner quelques dizaines de secondes pour que le GPS, l'altitude et
   la vitesse verticale se stabilisent (la fenêtre de vitesse verticale est de 60 s
   par défaut : attendre au moins 60 s avant de capturer).

## 4. Navigation et captures, par page

Touches du simulateur : START/STOP = SELECT, BACK/LAP, UP, DOWN
(boutons cliquables sur l'image de la montre, ou menu `Input`).
L'app démarre en mode Marche, page Position. UP/DOWN change de page (boucle).
Un appui long de 1,5 s sur BACK/LAP bascule Marche <-> Vol.
Pour chaque capture : `Fichier > Capture d'écran du simulateur` (File > Save
Screenshot selon la langue), puis enregistrer sous `/tmp/glidator-shots/<montre>-<page>.png`
(hors dépôt).

Mode Marche (démarrage par défaut) :
- [ ] Position : au démarrage. Appuyer sur START pour lancer l'enregistrement, laisser tourner l'activité. Capturer.
- [ ] Allure : DOWN une fois. Capturer.
- [ ] Heure : DOWN encore une fois (toujours en 24 h). Capturer.
La page Carte est masquée (`HikePages.MAP_ENABLED = false`) : ne pas la chercher.

Mode Vol (appui long 1,5 s sur BACK/LAP depuis le mode Marche) :
- [ ] Instrument de vol : première page du mode Vol. Charger l'activité de descente. Capturer.
- [ ] Heure : DOWN. Capturer.
- [ ] Boussole : DOWN encore (page avec cap et coordonnées ; vérifier que les
      coordonnées sont celles du fichier inventé). Capturer.
La bascule de mode pendant un enregistrement ajoute un tour (lap) : sans effet sur les captures.

Menu Pause et écran Pause (depuis une page de Marche, enregistrement en cours) :
- [ ] Appuyer sur START : l'enregistrement se met en pause et le menu « Paused »
      s'ouvre (Resume / Pause / Save / Ignore). Capturer tout de suite (il se referme
      seul après 30 s).
- [ ] Choisir « Pause » (ou laisser le menu se fermer) : l'écran Pause s'affiche.
      Capturer. Seul START reprend l'enregistrement (pas de reprise auto).
- [ ] Reprendre avec START avant de passer à la montre suivante.

## 5. Les trois montres

Répéter la section 3 et 4 pour chaque montre, en remplaçant le nom du `.prg` et
l'appareil :

- [ ] fenix6pro : toutes les pages ci-dessus (planches 1 à 3).
- [ ] fenix847mm : au minimum Position (Marche), pour la planche 4.
- [ ] instinct2 : au minimum Position (Marche) pour la planche 4. Écran
      monochrome : vérifier aussi que le menu Pause tient en largeur (titre et
      libellés <= 16 caractères) et noter tout texte coupé, c'est un défaut à signaler.

Avant chaque lancement, fermer le simulateur de la montre précédente.

## 6. Assembler les planches

Avec Aperçu (Preview) ou n'importe quel éditeur d'image, sans retouche des
captures :

1. Créer une image de fond neutre (blanc ou noir) d'environ 1600 x 900 px.
2. Placer les captures côte à côte (3 par planche), même hauteur, marge régulière.
3. Planche 4 : mettre la même page sur les trois montres, nommer chaque montre
   sous l'image (Fenix 8 47 mm, Fenix 6 Pro, Instinct 2).
4. Exporter en PNG dans `docs/store/` sous les noms du tableau ci-dessus.
5. Vérifier qu'aucune coordonnée réelle n'est lisible, puis lister dans le
   compte-rendu ce que montre chaque planche.

Pour l'import dans le Store : taille et format exacts des visuels à vérifier
dans l'interface du Connect IQ Store au moment de la publication.
