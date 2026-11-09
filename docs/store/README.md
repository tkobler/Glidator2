# Captures pour la fiche du Store

Statut (2026-11-09) : les planches sont faites à partir des **photos du test terrain**
(fenix 6 Pro Solar au poignet) et d'une capture du simulateur, plus de captures
automatiques : `screencapture` échoue depuis l'agent et le simulateur ne peut pas être
piloté. Les photos brutes restent hors dépôt (dossier de dépôt du lab, lecture seule) ;
seules les planches assemblées sont dans `docs/store/`.

Une seule montre : fenix 6 Pro Solar (produit `fenix6pro` dans le simulateur).

Planches produites par `swift tools/make_store_boards.swift` (relançable ; argument
facultatif : dossier des photos) :

| Fichier | Contenu |
|---|---|
| `store-marche.png` (2900 x 1000) | Mode Marche, trois photos côte à côte : Altitude / D+ / Distance / Timer ; FC / Vitesse verticale / Allure / Timer ; Heure et batterie |
| `store-reglages.png` (521 x 671) | Capture du simulateur : menu Preferences (Beep, VS window) |

Photos redressées selon l'EXIF, recadrées sur la montre, même hauteur, fond gris
neutre, sans retouche. Aucune coordonnée visible.

Hors planches, volontairement : pas de page Carte (masquée dans l'app) ni d'ancien écran
Pause (l'écran Pause a changé, plus représentatif). Le mode Vol est déjà sur le store.

## Procédure manuelle d'origine (si de nouvelles captures du simulateur sont voulues)

## Règles (dépôt public)

- Aucune trace GPS réelle, aucune coordonnée réelle (la page Boussole et la page
  Position Marche affichent lat/lon). Utiliser uniquement une activité synthétique
  (voir plus bas), en un lieu inventé.
- Ne pas retoucher les captures (recadrage et assemblage seulement).
- Ne jamais compiler dans `bin/` ; ne pas lire ni copier `developer_key`.
- Captures intermédiaires hors dépôt (`/tmp/glidator-shots/`), jamais commitées.

## 1. Compiler

Depuis la racine du dépôt, après `mkdir -p /tmp/glidator-build` :

```
monkeyc -f monkey.jungle -o /tmp/glidator-build/fenix6pro.prg -d fenix6pro -y developer_key
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
5. Laisser tourner au moins 60 s (fenêtre de la vitesse verticale) avant de capturer.

## 4. Navigation et captures, par page

Touches du simulateur : START/STOP = SELECT, BACK/LAP, UP, DOWN
(boutons cliquables sur l'image de la montre, ou menu `Input`).
L'app démarre en mode Marche, page Position. UP/DOWN change de page (boucle).
Un appui long de 1,5 s sur BACK/LAP bascule Marche <-> Vol.
Pour chaque capture : `File > Save Screenshot` du simulateur (ou `screencapture`
si l'accès à l'écran est accordé), vers `/tmp/glidator-shots/fenix6pro-<page>.png`.

Mode Marche (démarrage par défaut) :
- [ ] Position : au démarrage. START pour lancer l'enregistrement. Capturer.
- [ ] Allure : DOWN une fois. Capturer.
- [ ] Heure : DOWN encore une fois (toujours en 24 h). Capturer.
La page Carte est masquée (`HikePages.MAP_ENABLED = false`) : ne pas la chercher.

Mode Vol (appui long 1,5 s sur BACK/LAP depuis le mode Marche) :
- [ ] Instrument de vol : première page du mode Vol. Charger l'activité de descente. Capturer.
- [ ] Boussole : DOWN deux fois (Heure entre les deux ; page avec cap et coordonnées,
      vérifier que ce sont celles du fichier inventé). Capturer.
La bascule de mode pendant un enregistrement ajoute un tour (lap) : sans effet sur les captures.

Menu Pause et écran Pause (depuis une page de Marche, enregistrement en cours) :
- [ ] START : le menu « Paused » s'ouvre (Resume / Pause / Save / Ignore). Capturer
      tout de suite (il se referme seul après 30 s).
- [ ] Choisir « Pause » : l'écran Pause s'affiche. Capturer. Seul START reprend.
- [ ] Reprendre avec START.

## 5. Assembler les planches

Avec Aperçu (Preview) ou n'importe quel éditeur d'image, sans retouche des captures :

1. Fond neutre (blanc ou noir) d'environ 1600 x 900 px.
2. Captures côte à côte, même hauteur, marge régulière.
3. Exporter en PNG dans `docs/store/` sous les noms du tableau ci-dessus.
4. Vérifier qu'aucune coordonnée réelle n'est lisible.

Pour l'import dans le Store : taille et format exacts des visuels à vérifier
dans l'interface du Connect IQ Store au moment de la publication.
