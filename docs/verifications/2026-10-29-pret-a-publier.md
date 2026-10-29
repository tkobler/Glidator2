# Bilan : peut-on publier Glidator2 2.1.2 ?

- **Date** : 2026-10-29. Branche `claude/corrections-marche`, HEAD `307ed9e`, SDK Connect IQ 9.2.0.
- **Périmètre** : état du dépôt, compilation et export, cohérence version / CHANGELOG / description du Store, permissions, licence, README, fichiers à ne pas publier, ordre des merges. Aucun fichier modifié hors cette note.

## Verdict : NON, pas encore

Le code compile sur les 62 montres et l'export `.iq` réussit. Mais quatre points bloquent : la suite de tests complète n'a pas été relancée depuis le 14/10, le CHANGELOG et la description du Store décrivent encore l'écran Pause avec un minuteur figé (l'écran affiche l'heure), six commits ne sont pas poussés, et la clé de signature est toujours publique dans le dépôt.

## Points bloquants

1. **Tests Monkey C non rejoués sur les 62 montres depuis le 14/10** (dernier résultat : 223 tests, 223 passés, `docs/verifications/2026-10-14-essai-marche.md`, base `bf2c76a`). Depuis, le code a changé : page carte masquée (`27a8d12`), sorties enregistrées en Randonnée (`bdc4bc6`), écran Pause avec l'heure (`e0d45ed`), menu « Climb rate avg » (`33e2304`), nettoyages des tests (`bf6fde6`, `cdcf2bd`). La décision du projet est de publier seulement après des tests complets verts. Cette vérification n'a pas lancé `monkeydo -t` (compilation seule demandée). À faire : `zsh tools/run-watches.zsh` (sans `--release`) sur les 62 montres, environ 20 min, simulateur ouvert.
2. **CHANGELOG et description du Store en désaccord avec le code sur l'écran Pause.** Le code (`source/PausedView.mc`) affiche l'heure courante, le README le dit correctement (ligne 31). Mais :
   - `CHANGELOG.md` ligne 14 : « opens a Paused screen with the frozen timer » ;
   - `garmin_description.md` ligne 8 : « with the frozen timer on screen » ; ligne 35 : « Pause shows the frozen timer ».
   Le commit `01baba7` n'a corrigé que README et plan. Correctif pour le dev : remplacer par « the current time ».
3. **Six commits locaux non poussés.** `claude/corrections-marche` est en avance de 6 sur `origin/claude/corrections-marche` (qui s'arrête à `f9e3a7d`). La PR #2 ne contient donc pas `8ea037a`, `bf6fde6`, `cdcf2bd`, `d21f461`, `10207e1`, `307ed9e`. Le push est à faire (par l'utilisateur ou le manageur) avant de merger.
4. **Clé de signature dans le dépôt public.** `developer_key` est suivi par git (`git ls-files` le confirme), avec `bin/` (environ 100 fichiers dont des `.prg`), `.DS_Store`, `.vscode/settings.json` et les paquets `glidator2_export/*.iq`. Le `.gitignore` ne les retire pas du suivi. `git rm -r --cached bin/` est refusé par la garde : c'est donc à l'utilisateur de le faire. Voir `docs/recherches/2026-10-06-preparer-publication.md` section 3.4 (décision sur la clé, sécurisation du compte Garmin).

## Contrôles

### Compilation et export
- `zsh tools/run-watches.zsh --release <62 montres du manifest>` : **62 / 62 « build OK »** (sortie dans `/tmp/glidator-build/full.out`, une ligne par montre, 3 à 4 s chacune). Aucune ligne KO, BLOCKED ou SILENT.
- Export : `monkeyc -e -f monkey.jungle -o /tmp/glidator-build/Glidator2.iq -y developer_key` : **BUILD SUCCESSFUL**. Le compteur du SDK affiche « 101 OUT OF 101 DEVICES BUILT » alors que le manifest en liste 62 (`grep -c '<iq:product '` = 62). Écart non expliqué, sans conséquence visible ; je n'ai pas pu lister le fichier produit (lecture hors du dossier autorisé), la réussite repose sur la sortie du compilateur.
- `git status` après compilation et export : propre, aucun fichier suivi modifié.
- Tests Monkey C (`-t` + `monkeydo`) : **non lancés** (voir bloquant 1).
- Tests Python : `python3 -m unittest discover -s tools -p 'test_*.py'` : **116 tests, OK**.

### Version et CHANGELOG
- `manifest.xml` : `version="2.1.2"` ; nom `Glidator2` (`resources/strings/strings.xml`). Cohérent avec l'en-tête `## 2.1.2` du CHANGELOG.
- Page carte masquée : `HikePages.MAP_ENABLED = false` (`source/HikePages.mc:8`) ; la vue carte n'est pas construite (`FlyInstrumentApp.mc:601`). Le CHANGELOG, le README et la description ne la mentionnent plus pour la 2.1.2 (la ligne « 2.1 » de l'historique parle encore de la carte, ce qui est exact pour cette version passée).
- Sorties en Randonnée : code (`FlyInstrumentApp.mc:61-76`, FIT 17 avec repli générique), CHANGELOG ligne 18 et README ligne 35 d'accord. Absent de la description du Store (facultatif). Dans le CHANGELOG, la phrase est isolée entre deux sections (ligne 18), sous « Recording » : à rattacher à la liste précédente.
- « Climb rate avg » : présent dans le CHANGELOG, la description et le README, libellé unique.
- Écran Pause : voir bloquant 2.

### Description du Store
- `garmin_description.md` : **3449 caractères** (`wc -m`), sous la limite de 4000. Aucune mention de la page carte. Avertissement aviation présent, crédits à l'auteur d'origine présents.

### Permissions du manifest
- Déclarées : Fit, Positioning, Sensor, SensorHistory.
- Fit (enregistrement d'activité), Positioning et Sensor sont utilisées.
- **SensorHistory : aucune référence dans `source/`** (recherche de `SensorHistory`, `Communications`, `FitContributor`, `Ant` : rien). Permission probablement inutile ; elle apparaît dans la liste des autorisations demandées à l'installation. À retirer si le manifest peut être modifié (action de l'utilisateur ou tâche dédiée), à confirmer par un build après retrait. Non bloquant.

### Licence
- `LICENSE` : MIT, « Copyright (c) 2026 Tim Kobler ». Les crédits à Gaetan Marti (projet d'origine) sont dans le README et la description. Rien à signaler.

### README
- À jour sur : Pause (heure affichée), Climb rate avg, enregistrement en Randonnée, carte absente de la liste des vues.
- Défauts mineurs : « Exporting .iq File » demande `-o bin/Glidator2.iq` (ligne 157) et la section Building `-o bin/Glidator2.prg` (ligne 83), alors que la consigne du projet est de ne jamais écrire dans `bin/` ; `git clone https://github.com/yourusername/glidator2.git` (ligne 78) ; la liste des fichiers ne cite pas `HikeHistory`, `Tests*.mc` en dehors de `Tests.mc`.

### Fichiers qui ne devraient pas être dans le dépôt public
- `developer_key`, `bin/` (dont `.prg` et `.debug.xml`), `.DS_Store` (racine et `glidator2_export/`), `.vscode/settings.json`, `glidator2_export/*.iq` : suivis (bloquant 4).
- Un fichier de configuration de l'outil d'agents à la racine, « CLAUDE.md — Exemple de configuration pour un projet.md », est suivi : sans rapport avec l'app, à retirer.
- **Données personnelles** : `garmin_data/` contient 4 traces GPX/TCX réelles suivies par git (sortie du 13/09 : GPX et TCX ; test du 22/10 : GPX de la montre de 3796 points avec FC et température, et la trace d'un site tiers). Elles révèlent des lieux et horaires de sorties. `data/` contient un vol de 2019. `docs/verifications/data/*.csv` contiennent des latitudes/longitudes de la marche de référence, et `docs/tests/plan-test-approfondi.md` cite aussi des coordonnées de cette trace (lignes 217 et 333). La consigne du projet interdit les coordonnées GPS dans le dépôt public : à retirer (et l'historique git les garde, voir décision de l'utilisateur).
- **Chemins locaux** dans `docs/` : `docs/tests/plan-test-approfondi.md` (lignes 21, 437-447), `docs/verifications/2026-10-05-corrections-marche.md` ligne 64, `docs/verifications/2026-10-13-etalon-marche.md` ligne 192 (nom d'utilisateur de la machine et dossier du lab). Pas de secret, mais à nettoyer.
- Pas d'adresse e-mail trouvée dans `docs/`, README, `tools/`.

### Ordre des merges
- `gh pr list` et `gh pr view` : **refusés** par la garde, donc l'état réel des PR (#2 en brouillon ?) n'est pas vérifié ici.
- Lecture avec `git log` : `origin/hikeandfly` a 6 commits que `origin/main` n'a pas, et `origin/main` n'a rien que `hikeandfly` n'ait pas (`git log origin/hikeandfly..origin/main` vide). Donc l'ordre est sans conflit d'historique : PR #2 (`claude/corrections-marche`) vers `hikeandfly`, puis `hikeandfly` vers `main`.
- Préalable : pousser les 6 commits locaux (bloquant 3). `claude/corrections-marche` contient environ 200 commits de plus que `hikeandfly`, dont `tools/` et `docs/` ; la PR sera grosse.
- Je n'ai pas pu lister le contenu de `origin/main` et `origin/hikeandfly` (`git ls-tree` refusé) : on ne sait pas si `developer_key` et `bin/` y sont déjà.

### Zones sensibles
- Vol (vario) : seul changement de `FlyInstrumentView.mc` par rapport à `origin/hikeandfly` : la ligne d'altitude utilise `formatFlightAltitude` (garde −500..9000 m, point V1 validé). Je n'ai pas comparé fonction par fonction `WatchData` et `WatchDisplay` (diff large, validé par les points V1 à V3 du plan) : à confirmer par les tests complets et le contrôle en vol.

## Ce qui reste à faire à la main par l'utilisateur

- [ ] Pousser la branche (6 commits) ; vérifier les PR avec `gh pr list` / `gh pr view` ; merger #2 vers `hikeandfly`, puis `hikeandfly` vers `main`.
- [ ] Faire corriger l'écran Pause (heure, pas minuteur figé) dans `CHANGELOG.md` et `garmin_description.md`, puis relire la description (limite 4000 caractères).
- [ ] Relancer la suite complète (`zsh tools/run-watches.zsh` avec les 62 montres, simulateur ouvert) et exiger 0 échec.
- [ ] Retirer du suivi git `bin/`, `developer_key`, `.DS_Store`, `.vscode/`, `glidator2_export/` (commande refusée à l'agent : `git rm -r --cached bin/` et équivalents). Décider du sort de la clé : vérifier quelle clé a signé la version publiée, sécuriser le compte Garmin, sauvegarder la clé hors du dépôt.
- [ ] Retirer les traces GPS réelles (`garmin_data/`, `data/`, CSV de `docs/verifications/data/`, coordonnées du plan de test) et les chemins locaux de `docs/` ; savoir que l'historique git les garde.
- [ ] Décider de la permission `SensorHistory` (inutile d'après le code).
- [ ] Produire le `.iq` définitif avec la bonne clé (hors du dépôt), l'envoyer au portail Garmin, ajouter captures d'écran par famille de montres et image principale 1440 x 720 ; soumettre.

### Contrôles visuels sur la montre (Fenix cible, puis Instinct 2 si possible)
- [ ] Mode Randonnée : 3 pages seulement (Position, Pace, Time), la page carte n'apparaît pas en montant ou descendant.
- [ ] SELECT en enregistrement : menu Paused (Resume, Pause, Save, Ignore) ; BACK ou 30 s sans choix reprend l'activité.
- [ ] Choix Pause : l'écran affiche l'heure courante, l'activité reste en pause jusqu'à SELECT (résultat attendu : reprise, retour aux pages).
- [ ] Menu MENU : « Climb rate avg » passe de « over 1 min » à « over 3 min » puis « over 5 min » puis revient à 1 ; titre et sous-libellés lisibles sur Instinct 2 (≤ 16 caractères).
- [ ] Page Pace : la vitesse verticale affiche « -- » les 20 premières secondes, puis une valeur arrondie à 10 m/h.
- [ ] Sauvegarde puis Garmin Connect : la sortie apparaît en Randonnée (y compris une sortie en mode Vol seul), tours séparés à chaque changement de mode.
- [ ] Mode Vol : vario, bips et altitude identiques à la version précédente (zone sensible).
- [ ] Sur un Forerunner et un Instinct si disponibles : aucune mise en page coupée sur les pages Position, Pace, Time et Compass.

## Commandes refusées ou limites rencontrées

- `gh pr list --repo tkobler/Glidator2 --state all` et `gh pr view 2 ...` : refusés.
- `git rev-list --left-right --count`, `git ls-tree --name-only` (sur `origin/main` et `origin/hikeandfly`) et `git merge-base` : refusés ou en attente d'approbation ; remplacés par `git log A..B`.
- Boucle d'attente `zselect` : refusée ; sortie de `run-watches.zsh` lue par `Read` sur `/tmp/glidator-build/full.out`.
- `ls` sur `/tmp/glidator-build` : refusé (hors dossiers autorisés).

## Pièges

- `python3 -m unittest discover -s tools -p test_*.py` sans guillemets échoue sous zsh (« no matches found ») : mettre le motif entre guillemets simples.
- `--release` ne lance aucun test : « 62 build OK » ne dit rien sur les tests.
- Le compteur « 101 devices » de l'export est celui du SDK, pas du manifest.
