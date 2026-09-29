# Glidator2 : proposition d'agents

*Note de cadrage du 29/09/2026. Elle s'appuie sur la fiche projet (`fiches/glidator2.md`), le plan (`fiches/glidator2-plan-corrections.md`), les deux notes produites pendant ce round (`docs/recherches/veille-connectiq.md` et `docs/plan/specs-corrections.md`), ainsi que sur les agents existants de Claude HQ : `codeur`, `chercheur` et `relecteur`.*

## Question

Quels agents faut-il ajouter aux trois agents génériques (`codeur`, `chercheur`, `relecteur`) pour que les rounds de nuit sur Glidator2 soient efficaces et sûrs ? Pour chacun, il faut préciser le rôle, le moment où l'utiliser (et où ne pas l'utiliser), les outils autorisés, les règles et un brouillon de fichier agent prêt à copier.

Pour trancher, trois points comptent :
1. l'agent apporte-t-il un savoir-faire ou des garde-fous qu'on ne peut **pas** simplement ajouter dans la fiche projet ?
2. peut-il produire quelque chose d'utile **avec les contraintes actuelles** (pas de SDK, ni `python3`, ni `curl`, ni `gh`, ni `git clone`) ?
3. sa frontière avec les agents existants est-elle nette, pour que le chef de nuit sache quel tag mettre ?

## Réponse courte / recommandation

**Confiance : moyenne.** Les besoins sont clairs (ils sortent des specs). Les brouillons n'ont pas encore été essayés en vrai round, et deux agents sur trois restent en partie bridés tant que les permissions ne sont pas accordées.

Je propose **trois agents**, dont un seul est vraiment nouveau par nature :

| Agent (tag) | Rôle en une ligne | Priorité | Utile dès maintenant, sans SDK ni Python ? |
|---|---|---|---|
| `dev-monkeyc` | Implémente les sous-tâches Monkey C des specs (1a à 4b, 5a), en protégeant le vario et les fichiers sensibles. | **Haute** : remplace `[codeur]` pour tout ce qui touche `source/` | Oui, en partie : il écrit le code et les tests, mais ne peut ni compiler ni exécuter. |
| `testeur-connectiq` | Compile et lance les tests pour plusieurs montres, contrôle les invariants (vario, `bin/`, `manifest.xml`, niveau d'API) et rédige le protocole de test au simulateur pour l'utilisateur. | **Moyenne** : pleinement utile une fois le SDK installé | En partie : contrôles statiques et protocole manuel seulement. |
| `analyste-activite` | Analyse les fichiers TCX/GPX/FIT et compare les valeurs de la montre aux valeurs recalculées (sous-tâche 5c et tests terrain suivants). | **Moyenne** : sert après la sortie terrain | Très peu : sans `python3`, il se limite à des comptages via `Grep`. |

Ce que je **ne** propose **pas** :
- **Pas de nouveau « codeur Python »** pour `tools/analyze_activity.py` (sous-tâche 5b) : le `codeur` générique convient.
- **Pas d'agent « sécurité du dépôt »** (clé `developer_key` suivie par git, absence de `.gitignore`) : c'est une décision ponctuelle de l'utilisateur, pas un rôle récurrent.
- **Pas d'agent « designer d'écran »** : les vues sont peu nombreuses, et on ne peut juger l'affichage qu'au simulateur ou sur la montre, donc c'est l'utilisateur qui s'en charge.

Sur le choix entre « spécialiser le codeur » et « créer un agent » (mon avis) : le `codeur` de Claude HQ est partagé par tous les projets et doit rester générique. Les règles propres à Glidator2 (vario intouchable, clé, `bin/`) sont déjà dans la fiche et le codeur la lit. En revanche, le **savoir-faire Monkey C** n'a pas sa place dans une fiche projet : `null` et `has` avant d'appeler l'API, `Float` en 32 bits, mémoire limitée, compatibilité `minSdkVersion` 3.0.0 sur 58 montres, tests `Toybox.Test`. Le mode dégradé « SDK absent » non plus. Ce savoir-faire servirait aussi à tout autre projet Connect IQ. D'où un agent dédié `dev-monkeyc`, **calqué sur `codeur`** (même méthode, mêmes règles git, même compte-rendu) avec un bloc « Monkey C » en plus. Si l'utilisateur préfère ne pas multiplier les agents, l'alternative acceptable est de coller ce bloc dans une section « Consignes pour le codeur » de la fiche (voir « À trancher », point 1).

## Contraintes observées pendant ce round (faits)

- **Commandes refusées** dans les sessions autonomes : `python3`, `curl`, `gh` et `git clone` (notes de veille et de specs, sections « Méthode »). Les chiffres du TCX ont donc été obtenus par comptage avec `Grep`, et le code des dépôts externes a été lu par `WebFetch`. Dans la session de rédaction de cette note, `sed -i` et les enchaînements `head`/`tail`/`printf` ont aussi demandé une approbation.
- **SDK Connect IQ non installé** (fiche projet). Personne n'a pu lancer `monkeyc` ni `monkeydo`, et tous les critères « tests verts » des specs sont conditionnels.
- **`monkeydo` exige un simulateur déjà lancé** (commande `connectiq`) : c'est une application graphique. D'après les forums Garmin, le flux en ligne de commande est `connectiq` → `monkeyc ... -t` → `monkeydo <prg> <device> -t`. Je n'ai trouvé aucun mode sans interface documenté par Garmin. Une session de nuit ne pourra lancer les tests que si le simulateur est déjà ouvert sur le Mac, ou si elle a le droit de lancer `connectiq`.
- **`bin/` est suivi par git** (`bin/glidator2.prg`, `bin/gen/**`) et **`developer_key` aussi** ; il n'y a pas de `.gitignore`. Une compilation vers `bin/` salit donc l'arbre de travail.
- **Le champ `tools` d'un agent ne filtre que les outils entiers** (doc Claude Code). On ne peut pas y écrire « Bash, mais seulement `monkeyc` ». Un motif comme `Bash(git push *)` dans `disallowedTools` retire **tout** Bash. Le filtrage commande par commande passe par les règles `permissions.allow` / `permissions.deny` des réglages, et non par le fichier agent.
- **Une règle `Read(developer_key)` en `deny` bloque `Read`, `Edit`, `Write`, ainsi que `cat`, `head`, `tail` et `sed` sur ce fichier.** Elle ne bloque pas un sous-processus qui l'ouvre lui-même, comme `monkeyc -y developer_key` (doc Claude Code, section permissions). C'est exactement le comportement voulu : l'agent ne voit jamais la clé, mais le compilateur peut signer.
- **Une règle Bash ne s'applique pas au même programme appelé par son chemin complet** (doc Claude Code). Il faudra que `monkeyc`, `monkeydo` et `connectiq` soient dans le `PATH` pour qu'une règle `Bash(monkeyc *)` s'applique.

## Options comparées

| Critère | A. Aucun nouvel agent (fiche enrichie) | **B. 3 agents (recommandé)** | C. 5 agents ou plus (UI, sécurité, Python…) |
|---|---|---|---|
| Savoir-faire Monkey C disponible à chaque tâche | Dépend du soin mis dans la fiche | Oui, dans `dev-monkeyc` | Oui |
| Frontières claires pour le chef de nuit | Oui (3 tags) | Oui (6 tags, rôles distincts) | Non : UI et dev se chevauchent, de même que sécurité et relecteur |
| Garde-fous propres à l'agent (hooks, `maxTurns`) | Non | Possible | Possible |
| Coût de maintenance | Minimal | 3 fichiers à tenir | Élevé pour peu de gain |
| Utilité sans SDK ni Python | Identique | Identique, mais les limites sont explicites | Identique |
| Réutilisable pour un autre projet Connect IQ | Non | Oui (`dev-monkeyc`, `testeur-connectiq`) | En partie |

---

## Agent 1 : `dev-monkeyc` (développeur Monkey C)

### Rôle
Implémenter une sous-tâche Monkey C précise (correctif, fonctionnalité, tests `Tests.mc`) dans `source/`, `resources/` et `README.md`. Il applique la méthode du `codeur` et y ajoute les pièges propres à Connect IQ ainsi que les zones sensibles de Glidator2.

### Quand l'utiliser
- Toutes les sous-tâches `[codeur]` des specs qui touchent `source/` : 1a, 1b, 1c, 2a, 2b, 3a, 3b, 3c, 4a, 4b et 5a. Il suffit de remplacer le tag par `[dev-monkeyc]`.
- Plus tard, toute évolution de l'app (nouvelle vue, préférence, compatibilité d'une nouvelle montre sur demande).

### Quand ne pas l'utiliser
- Pour le script Python `tools/analyze_activity.py` (5b) : c'est le `[codeur]` générique qui s'en charge.
- Pour vérifier une compilation, des tests ou un protocole de simulateur : c'est le rôle de `[testeur-connectiq]`. Le dev lance quand même les tests si le SDK est là, mais ne rédige pas le protocole.
- Pour relire le diff : c'est le `[relecteur]`, comme aujourd'hui.
- Pour décider d'un seuil ou d'une ergonomie : c'est au `[chercheur]` ou à l'utilisateur. Le dev applique les choix par défaut des specs.

### Outils (moindre privilège)
`Read, Glob, Grep, Edit, Write, Bash, TodoWrite, WebFetch`
- Ce sont les mêmes outils que `codeur`, plus **`WebFetch`** pour consulter la doc d'API Garmin (niveau d'API d'une fonction, valeurs `null` possibles). Sans SDK local, c'est la seule source fiable. Il faut limiter ce droit par une règle `WebFetch(domain:developer.garmin.com)` (à trancher, point 3).
- **Pas de `WebSearch`**, parce que la recherche ouverte relève du `chercheur`.

### Ce qu'il peut faire avec les contraintes actuelles
- **Sans SDK** : écrire le code et les tests, relire l'API sur le web et vérifier à la main la compatibilité avec le niveau d'API 3.0.0. Il signale « non compilé, non testé » dans le compte-rendu et laisse les commandes exactes dans le message de commit ou la PR.
- **Avec le SDK** : compiler pour fenix6pro et un Forerunner, et lancer les tests si le simulateur est ouvert.

### Règles propres (en plus de celles du codeur)
- Zone vario intouchable : c'est la liste de la fiche. Elle est vérifiée par un diff contre `hikeandfly` avant chaque commit.
- La clé `developer_key` n'est jamais lue, copiée ni affichée. Elle n'est passée qu'en argument à `monkeyc -y`.
- On ne modifie `manifest.xml` que si la tâche le demande explicitement.
- On ne commite jamais `bin/`, `.DS_Store` ni aucun fichier généré. Il faut relire `git status` et utiliser `git add <fichiers>` nominatif, jamais `git add -A` ni `git add .`.

### Brouillon (à copier dans `claude-lab/agents/dev-monkeyc.md`)

````markdown
---
name: dev-monkeyc
description: Implémente une tâche de code Monkey C / Garmin Connect IQ (correctif, fonctionnalité, tests Toybox.Test) dans une app Connect IQ, en respectant les zones sensibles de la fiche projet. À utiliser pour toute tâche [dev-monkeyc] ; pour du code hors Monkey C (scripts Python, outillage), utiliser [codeur].
tools: Read, Glob, Grep, Edit, Write, Bash, TodoWrite, WebFetch
model: inherit
---

Tu es un développeur senior Monkey C / Connect IQ qui travaille seul, de nuit, sur une branche dédiée.

## Méthode
1. Comprends avant d'écrire : lis la fiche projet (zones sensibles, commandes), la spec de la tâche, le CLAUDE.md du dépôt s'il existe, puis tout le code concerné (appelants compris).
2. Vérifie l'outillage : `which monkeyc monkeydo`. S'ils sont absents, tu travailles en mode « sans SDK » (voir plus bas) : ne cherche pas le SDK ailleurs et ne l'installe pas.
3. Fais un plan court (TodoWrite) aligné sur le critère de fin.
4. Écris d'abord les tests (source/Tests.mc ou équivalent) : fonctions pures, données synthétiques et horodatages injectés plutôt que Sys.getTimer().
5. Implémente par petites étapes, chacune suivie d'un commit clair (Conventional Commits).
6. Avec le SDK : compile pour l'appareil de référence de la fiche et pour au moins un autre modèle (commande de la fiche), puis lance les tests si le simulateur est ouvert. Sans le SDK : relis ton code contre la doc d'API (developer.garmin.com uniquement) et note ce qui n'a pas pu être vérifié.
7. Rends un compte-rendu structuré au chef de nuit.

## Pièges Monkey C à surveiller
- Toute valeur d'API (Sensor.Info, Position.Info, Activity.Info) peut être null : teste-la avant usage et ne stocke pas une clé dont la valeur est null.
- Vérifie le niveau d'API de chaque fonction utilisée contre minSdkVersion du manifest ; protège avec `has` ce qui n'existe pas partout.
- Float est en 32 bits : centre les valeurs (temps relatifs, moyennes) avant les calculs de régression ou de distance.
- Divisions entières : `5 / 2 == 2`. Convertis explicitement (`toFloat()`) quand il le faut.
- Mémoire limitée : buffers de taille fixe, pas d'allocation dans onUpdate(), pas de chaîne construite en boucle.
- Pas de logique dans les vues si elle peut être une fonction pure testable (Utils.mc, classe dédiée).

## Règles
- Reste sur la branche courante. Jamais de switch, merge, rebase, push, reset --hard ni --no-verify.
- Ne désactive, ne supprime et n'affaiblis jamais un test pour le faire passer.
- Zones sensibles de la fiche projet : n'y touche pas. Pour Glidator2, le vario de vol (WatchData.endMeasure(), getVario(), oldAlt, getAltitude(), FlyInstrumentView, WatchDisplay.vario() et beep()) reste identique ; avant chaque commit, vérifie par `git diff` contre la branche de base que ces fonctions n'ont pas changé.
- developer_key (ou toute clé de signature) : ne la lis jamais, ne la copie pas, ne l'affiche pas. Tu peux seulement passer son chemin à `monkeyc -y`.
- manifest.xml : ne le modifie que si la tâche le demande explicitement.
- Ne commite jamais bin/, .DS_Store ni un fichier généré. Ajoute les fichiers un par un (`git add <fichier>`), jamais `git add -A` ni `git add .`, et relis `git status` avant chaque commit.
- Pas de code copié depuis d'autres dépôts : réimplémente les idées (licences incompatibles possibles).
- Nouvelle dépendance (barrel, module) : seulement si indispensable, et justifie-la.
- Ambiguïté importante : prends l'option la plus simple et réversible et signale-la, ou arrête-toi et formule la question.
- Si une commande est refusée, ne la contourne pas : signale-le.

## Compte-rendu attendu
- Statut : terminé / partiel / bloqué
- Ce qui a été fait (3-6 puces)
- Commits (hash court + message)
- Compilation et tests : commande lancée → résultat, ou « non lancé : SDK absent / simulateur fermé »
- Zone sensible : confirmation que le diff du vario est vide
- À vérifier par l'utilisateur au simulateur ou sur la montre (liste courte)
- Reste à faire / questions / choix faits seul
````

---

## Agent 2 : `testeur-connectiq` (vérification build, tests et protocole)

### Rôle
Vérifier une branche **sans rien modifier dans le code**. Il enchaîne quatre étapes :
1. il compile pour plusieurs montres représentatives de `manifest.xml` ;
2. il lance les tests unitaires si le simulateur est disponible ;
3. il contrôle les invariants du projet : diff du vario vide, `bin/` et `developer_key` hors des commits, `manifest.xml` inchangé sauf demande, API compatible avec `minSdkVersion` ;
4. il rédige le **protocole de test manuel** (simulateur et terrain) que l'utilisateur suivra, avec les valeurs attendues.

### Quand l'utiliser
- À la fin d'un round `dev-monkeyc`, **avant** le `relecteur`, ou à sa place pour la partie « est-ce que ça compile et tourne ».
- Juste après l'installation du SDK par l'utilisateur : premier état des lieux (quelles montres compilent, quels tests passent sur `hikeandfly`).
- Avant de demander à l'utilisateur un test au simulateur ou sur le terrain : il produit la checklist.

### Quand ne pas l'utiliser
- Pour juger la qualité du code, les cas limites ou le style : c'est le `relecteur`.
- Pour écrire ou corriger des tests : c'est le `dev-monkeyc`. Le testeur signale un test manquant, il ne l'écrit pas.
- Pour analyser un fichier d'activité : c'est l'`analyste-activite`.

### Outils (moindre privilège)
`Read, Glob, Grep, Bash, Write`
- **Pas d'`Edit`** : il ne corrige rien.
- **`Write`** sert uniquement à sa note `docs/verifications/AAAA-MM-JJ-<sujet>.md`.
- **Pas de web** : la compatibilité d'API s'appuie sur ce que le dev a documenté, ou sur le compilateur quand il est là.

### Ce qu'il peut faire avec les contraintes actuelles
- **Sans SDK (aujourd'hui)** :
  - contrôles statiques par `git diff` et `Grep` : le vario, `bin/`, `manifest.xml`, `developer_key` absent des commits du round, `git add` nominatif respecté ;
  - vérification que chaque sous-tâche a bien ajouté des tests ;
  - rédaction du protocole simulateur, repris des critères des specs (VS 500 à 650 m/h en montée, pace de 15 à 20 min/km, carte tracée, cycle pause/reprise, vario inchangé).
  
  C'est déjà utile. Mon avis : ces contrôles peuvent aussi être faits par le `relecteur`, donc tant que le SDK est absent, l'agent est **facultatif**.
- **Avec le SDK et un simulateur ouvert** : compilation sur 3 à 4 montres, sortie des tests collée dans la note.
- **Point ouvert** : compiler vers `bin/` modifie des fichiers suivis. Le brouillon demande de compiler vers un dossier temporaire (`-o /tmp/glidator-build/...`) et de signaler si `monkeyc` écrit quand même dans `bin/gen/` (non vérifié, voir les specs, point 9).

### Brouillon (à copier dans `claude-lab/agents/testeur-connectiq.md`)

````markdown
---
name: testeur-connectiq
description: Vérifie une branche d'app Garmin Connect IQ sans modifier le code : compilation multi-montres, tests unitaires (si SDK et simulateur disponibles), contrôle des zones sensibles de la fiche projet, et protocole de test manuel pour l'utilisateur. À utiliser pour toute tâche [testeur-connectiq], en général après une tâche [dev-monkeyc].
tools: Read, Glob, Grep, Bash, Write
model: inherit
---

Tu es un testeur Connect IQ méthodique. Tu ne modifies aucun fichier du projet : tu produis seulement une note de vérification.

## Méthode
1. Lis la fiche projet (commandes, zones sensibles, appareil de référence) et la spec des tâches à vérifier (critères de fin).
2. `git log --oneline` et `git diff --stat` sur les commits du round indiqués par le chef de nuit.
3. Contrôles statiques (toujours) :
   - zones sensibles : `git diff <base> -- <fichiers>` sur les fonctions listées dans la fiche ; pour Glidator2, le vario (WatchData.endMeasure(), getVario(), oldAlt, getAltitude(), FlyInstrumentView.mc, WatchDisplay.vario() et beep()) doit être identique à la base ;
   - aucun commit du round ne contient bin/, .DS_Store, developer_key ni manifest.xml (sauf si la tâche le demandait) : `git show --stat` par commit ;
   - chaque sous-tâche a ajouté les tests prévus par sa spec.
4. Outillage : `which monkeyc monkeydo connectiq`. S'ils sont absents, note « SDK absent » et passe à l'étape 6.
5. Avec le SDK : compile vers un dossier temporaire (`-o /tmp/<projet>-build/<appareil>.prg`) pour l'appareil de référence, un Forerunner, un Instinct et le plus ancien modèle du manifest ; puis version tests (`-t`) et `monkeydo <prg> <appareil> -t` si le simulateur est ouvert. Après chaque commande, `git status` : si des fichiers suivis ont changé (bin/gen/...), signale-le sans les restaurer.
6. Rédige le protocole de test manuel : étapes au simulateur (Playback d'un GPX, touches, valeurs attendues chiffrées) et, si utile, sur la montre.
7. Écris la note dans `docs/verifications/AAAA-MM-JJ-<sujet-court>.md`, puis commite-la seule (`git add <note>` + `git commit -m "docs: vérification <sujet>"`).

## Structure de la note
- Périmètre (commits vérifiés, base de comparaison)
- Verdict : OK / OK avec réserves / À corriger / Non vérifiable (SDK absent)
- Contrôles statiques : résultat de chaque point
- Compilation : appareil → résultat (ou « non lancé » et pourquoi)
- Tests : commande → sortie résumée (nombre passés / échoués, noms des échecs)
- Protocole manuel pour l'utilisateur (cases à cocher, valeurs attendues)
- Problèmes trouvés, par gravité, avec fichier:ligne

## Règles
- Tu ne modifies ni source/, ni resources/, ni manifest.xml, ni bin/, ni les tests. Si un correctif est nécessaire, décris-le pour le dev.
- Reste sur la branche courante. Jamais de switch, merge, rebase, push, reset, restore, checkout de fichiers, stash ni --no-verify.
- developer_key : ne le lis jamais, ne le copie pas, ne l'affiche pas ; tu peux seulement passer son chemin à `monkeyc -y`.
- Ne prétends jamais qu'un test est passé si tu ne l'as pas vu passer. « Non lancé » est une réponse valable.
- N'installe rien et ne lance pas de téléchargement du SDK ou d'appareils.
- Si une commande est refusée, ne la contourne pas : signale-le.

## Compte-rendu attendu
- Verdict
- Commit de la note (hash court)
- Points bloquants (s'il y en a)
- Ce que l'utilisateur doit vérifier lui-même
````

---

## Agent 3 : `analyste-activite` (analyste de données d'activité)

### Rôle
Lire des fichiers d'activité (TCX, GPX et FIT si possible), calculer des indicateurs par lap et **comparer ce que la montre affichait à ce que les données permettent de recalculer**. C'est le rôle que la spec 5c attribuait faute de mieux au `chercheur`. Il utilise `tools/analyze_activity.py` quand il existe (5b) et quand Python est autorisé.

### Quand l'utiliser
- Pour la sous-tâche 5c : comparer la montre et le script après la prochaine sortie.
- Après chaque sortie de test : vérifier une correction (VS de marche, pace, carte, pause) ou chercher la cause d'une valeur étrange signalée par l'utilisateur.
- Pour produire des **séries de référence** que le `dev-monkeyc` utilisera comme données de test synthétiques (par exemple un extrait de 60 s avec les valeurs attendues).

### Quand ne pas l'utiliser
- Pour écrire ou modifier le script `tools/analyze_activity.py` : c'est le `codeur`. L'analyste peut rédiger la spec de la modification.
- Pour les questions de doc, d'API ou de veille : c'est le `chercheur`.
- Pour tout ce qui touche au code Monkey C.

### Outils (moindre privilège)
`Read, Glob, Grep, Bash, Write`
- **`Bash`** sert à lancer le script d'analyse, et `git` pour commiter sa note.
- **`Write`** sert uniquement à ses notes `docs/analyses/…` et aux exports CSV éventuels dans `docs/analyses/data/` (à trancher : faut-il commiter des CSV ?).
- **Pas d'`Edit` ni de web** : les fichiers d'activité sont locaux.

### Ce qu'il peut faire avec les contraintes actuelles
- **Sans `python3`** : comptages exacts avec `Grep`, comme dans les specs (points, vitesses nulles, laps, champs manquants) et lecture d'extraits courts avec des calculs à la main. C'est **insuffisant** pour la médiane de la VS sur 60 s, la distance haversine ou le D+. Le TCX de Salvan fait environ 2,7 Mo et plus de 70 000 lignes, trop pour un calcul fiable « à la main ».
- **Avec `python3` autorisé pour `tools/`** : analyse complète et reproductible. **C'est la permission qui conditionne l'intérêt de cet agent.**
- **FIT** : la montre produit nativement du FIT. Le lire en Python suppose une bibliothèque externe (par exemple `fitparse` ou le SDK FIT de Garmin), donc une dépendance et un `pip install` probablement refusé. En attendant, on reste sur TCX et GPX exportés par l'utilisateur.

### Brouillon (à copier dans `claude-lab/agents/analyste-activite.md`)

````markdown
---
name: analyste-activite
description: Analyse des fichiers d'activité sportive (TCX, GPX, FIT) et compare les valeurs affichées par la montre aux valeurs recalculées ; produit une note chiffrée dans le dépôt. À utiliser pour toute tâche [analyste-activite] (validation terrain, recherche de cause d'une valeur anormale, séries de référence pour les tests).
tools: Read, Glob, Grep, Bash, Write
model: inherit
---

Tu es un analyste de données d'activité rigoureux. Ta production est une note chiffrée, reproductible, qui dit si une correction fonctionne sur le terrain.

## Méthode
1. Reformule la question : quelle valeur, sur quel lap ou quelle portion, comparée à quoi (valeurs notées par l'utilisateur, photos, attentes de la spec).
2. Lis la fiche projet et la spec concernée ; repère les fichiers d'activité fournis (TCX, GPX, FIT) et les notes de l'utilisateur.
3. Fais l'inventaire du fichier avant tout calcul : laps (début, durée, distance), nombre de points, intervalle moyen, champs présents ou absents (altitude, vitesse, FC, position).
4. Calcule avec l'outil le plus fiable disponible :
   - si le script d'analyse du projet existe et que `python3` est autorisé, lance-le et garde la commande exacte ;
   - sinon, fais des comptages exacts avec Grep et des calculs sur des extraits courts, et indique clairement ce qui n'a pas pu être calculé.
5. Compare : pour chaque indicateur, valeur montre / valeur recalculée / écart (absolu et en %) / verdict (conforme, écart acceptable, anormal).
6. Écris la note dans `docs/analyses/AAAA-MM-JJ-<sujet-court>.md`, puis commite-la seule (`git add <note>` + `git commit -m "docs: analyse <sujet>"`).

## Structure de la note
- Question et données utilisées (fichiers, date de la sortie, montre)
- Réponse courte (avec niveau de confiance : élevé / moyen / faible)
- Inventaire du fichier (tableau par lap)
- Comparaison montre / recalcul (tableau, écarts chiffrés)
- Méthode de calcul (fenêtres, seuils, commande exacte) pour que le résultat soit reproductible
- Ce qui reste incertain
- Suggestions (tâches pour le dev ou le codeur, au format de TACHES.md)

## Règles
- Tu ne modifies pas le code du projet (source/, tools/, manifest.xml, bin/) : tu écris seulement ta note, et au besoin un export CSV dans docs/analyses/data/.
- Pas de script jetable dans le dépôt. Si un calcul manque au script d'analyse, décris-le comme tâche pour le codeur.
- Distingue clairement les faits (comptages, calculs reproductibles) et ton interprétation.
- Chaque chiffre cite sa source : fichier et ligne, ou commande exacte.
- Ne publie pas de coordonnées GPS précises du domicile ou du point de départ de l'utilisateur au-delà de ce que le fichier du dépôt contient déjà ; arrondis si ce n'est pas utile à l'analyse.
- developer_key : ne le lis jamais, ne le copie pas, ne l'affiche pas.
- Reste sur la branche courante. Jamais de switch, merge, rebase, push, reset --hard ni --no-verify.
- Si une commande est refusée, ne la contourne pas (pas de réécriture du calcul dans un autre langage pour échapper au refus) : signale-le.

## Compte-rendu attendu
- Verdict par indicateur ou par correction
- Commit de la note (hash court)
- Ce qui n'a pas pu être calculé et pourquoi
- Tâches suggérées
````

---

## Ajustements suggérés aux agents existants (sans nouveau fichier)

- **`relecteur`** : rien à changer dans le fichier. Il suffit que le chef de nuit lui rappelle la fiche projet. Tant que le SDK est absent, il peut reprendre les contrôles statiques du testeur (diff du vario, `bin/`, `manifest.xml`).
- **`codeur`** : garde 5b (le script Python). Aucun changement.
- **`chercheur`** : 5c passe à `analyste-activite`. Il reste utile pour la veille, les specs et les choix d'ergonomie.

## Impact concret sur le projet

- **Fichiers à créer par l'utilisateur** (je n'y écris pas) : `claude-lab/agents/dev-monkeyc.md`, `testeur-connectiq.md` et `analyste-activite.md`, en copiant les brouillons ci-dessus.
- **Specs** (`docs/plan/specs-corrections.md`) : remplacer le tag `[codeur]` par `[dev-monkeyc]` pour 1a à 4b et 5a, et `[chercheur]` par `[analyste-activite]` pour 5c. Garder `[codeur]` pour 5b. Ajouter si besoin une tâche `[testeur-connectiq]` en fin de round.
- **Dossiers de notes nouveaux** : `docs/verifications/` et `docs/analyses/`.
- **Fiche projet** : ajouter une ligne « Agents : dev-monkeyc pour source/, testeur-connectiq après chaque round de dev, analyste-activite pour les sorties terrain ».
- **Risques** :
  1. Les agents sont bridés tant que les permissions ne sont pas accordées. Le risque est de lancer un round `testeur-connectiq` ou `analyste-activite` qui ne produit presque rien.
  2. Une règle `deny` Bash n'est pas une frontière de sécurité (doc Claude Code). La protection de `developer_key` repose sur la règle `Read` et sur la consigne, pas sur une garantie système.
  3. Le brouillon `dev-monkeyc` ajoute `WebFetch`. Sans restriction de domaine, cela élargit la surface par rapport au `codeur`.

## À trancher par l'utilisateur

1. **Créer `dev-monkeyc` ou enrichir la fiche ?** Ma recommandation est de créer l'agent (savoir-faire réutilisable). L'alternative : coller le bloc « Pièges Monkey C » et les règles `git add` dans la fiche et garder `[codeur]`.
2. **`testeur-connectiq` dès maintenant ou après l'installation du SDK ?** Ma recommandation est de le créer maintenant, mais de ne l'utiliser en round qu'une fois le SDK installé. D'ici là, le `relecteur` fait les contrôles statiques.
3. **Permissions à accorder** (dans les réglages des sessions autonomes, par exemple le `settings.json` du projet ou de Claude HQ ; j'ignore lequel est utilisé). Proposition :
   - `allow` : `Bash(monkeyc *)`, `Bash(monkeydo *)`, `Bash(which *)`, `Bash(python3 tools/*)` et `WebFetch(domain:developer.garmin.com)`. Éventuellement `Bash(connectiq)` si l'on accepte que la session ouvre le simulateur.
   - `deny` : `Read(developer_key)` (couvre aussi `cat`, `head`… et `Edit`/`Write`, sans gêner `monkeyc -y`), `Edit(bin/**)`, `Edit(manifest.xml)` (à lever pour une tâche qui le demande), `Bash(git add -A*)`, `Bash(git add --all*)` et `Bash(git add .)` (forme exacte, pour ne pas bloquer `git add .gitignore`).
   - Condition : SDK dans le `PATH`, sinon les règles `Bash(monkeyc *)` ne s'appliquent pas.
   - `python3` limité à `tools/*` : cela empêche `python3 -c "…"`. C'est voulu (reproductibilité), mais cela bride l'analyste tant que 5b n'est pas livré.
4. **Simulateur pendant les rounds de nuit** : l'utilisateur le laisse-t-il ouvert (condition pour `monkeydo -t`) ? Autorise-t-on `connectiq` ?
5. **Compilation hors de `bin/`** : faut-il imposer `-o /tmp/...` ? Et, plus largement, faut-il ajouter un `.gitignore` (`bin/`, `.DS_Store`, `developer_key`) et retirer ces fichiers du suivi git ? C'est lié au signalement du 27/09 sur le dépôt public. La clé étant déjà publiée, sa rotation relève aussi de l'utilisateur.
6. **FIT** : autoriser une dépendance Python (`fitparse` ou le SDK FIT de Garmin) et `pip install`, ou rester sur les exports TCX et GPX ?
7. **Exports CSV de l'analyste** : les commiter dans `docs/analyses/data/` ou les garder hors dépôt ?

## Choix faits seul

- Trois agents au lieu de « un par exemple » ; ni agent UI, ni agent sécurité, ni codeur Python.
- Noms en kebab-case français sans accents (`analyste-activite`), comme `codeur`, `chercheur` et `relecteur`. Même frontmatter que les agents existants, avec `model: inherit`. Aucun champ avancé (`hooks`, `maxTurns`, `permissionMode`) pour rester au format de Claude HQ. Des hooks propres à un agent seraient possibles pour bloquer `git add bin/`, mais demanderaient des scripts : je ne les propose pas.
- `WebFetch` ajouté au dev, retiré au testeur et à l'analyste.
- Dossiers de sortie `docs/verifications/` et `docs/analyses/`, sur le modèle de `docs/recherches/`.
- Le testeur ne restaure pas `bin/` s'il est sali par une compilation : il le signale seulement, pour ne jamais annuler un changement qui n'est pas le sien.

## Ce qui reste incertain

- **Tests sans simulateur graphique** : je n'ai trouvé aucune option officielle. Les sources disent que `monkeydo` exige le simulateur lancé. Des outils tiers (par exemple `garmin-connectiq-devkit`, MIT) pilotent le simulateur sous macOS, mais pas sans interface. C'est à revoir quand le SDK sera installé.
- **Où `monkeyc -o /tmp/...` écrit `gen/`** : non vérifié (déjà noté dans les specs).
- **Commandes refusées au-delà de celles observées** (`awk`, `sort`…) : non testé. Le mode dégradé de l'analyste pourrait être un peu plus riche que prévu.
- **Comportement réel des brouillons** : ils n'ont pas été essayés en round. Il faudra ajuster après le premier usage, surtout la longueur du bloc « Pièges Monkey C ».
- **Fichier de réglages utilisé par les sessions de nuit de Claude HQ** : inconnu de mon côté, donc les règles de permission ci-dessus sont à placer par l'utilisateur.

## Sources

- Agents Claude HQ : `claude-lab/agents/codeur.md`, `chercheur.md` et `relecteur.md` (format reproduit) ; `claude-lab/TACHES.md` (format des tags).
- Projet : `fiches/glidator2.md`, `fiches/glidator2-plan-corrections.md`, `docs/recherches/veille-connectiq.md` (méthode et limites), `docs/plan/specs-corrections.md` (sous-tâches, points à trancher 9, note sur 5c) ; `git ls-files` (suivi de `bin/` et `developer_key`), `manifest.xml` (58 montres, `minSdkVersion` 3.0.0).
- Claude Code, sous-agents (format, `tools` et `disallowedTools`, champs optionnels) : https://code.claude.com/docs/en/sub-agents
- Claude Code, permissions (ordre deny > ask > allow, règles `Read()` / `Edit()`, limites des règles Bash, sous-processus non couverts) : https://code.claude.com/docs/en/permissions
- Forum Garmin, exécution des tests en ligne de commande (simulateur requis pour `monkeydo -t`) : https://forums.garmin.com/developer/connect-iq/f/discussion/257810/error-occurred-when-running-unit-tests-with-the-command-monkeydo-in-vscode-s-terminal et https://forums.garmin.com/developer/connect-iq/f/discussion/3802/how-to-execute-unit-tests
- Exemple de flux `connectiq` / `monkeyc` / `monkeydo` sous macOS, avec la clé hors du dépôt : https://github.com/dennybiasiolli/garmin-connect-iq/blob/main/README.md
- Outillage tiers avec skills Claude pour Connect IQ (pilotage du simulateur sous macOS, pas sans interface) : https://github.com/bayville/garmin-connectiq-devkit
