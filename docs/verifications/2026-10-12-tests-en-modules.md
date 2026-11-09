# Vieux tests rangés dans un module (décision D2 du 12/10)

- **Date** : 12/10/2026, branche `claude/corrections-marche`, SDK Connect IQ 9.2.0.
- **But** : libérer des membres du module `globals`, limité à 253 par le compilateur (`Found 254 members in module 'globals', exceeding the limit of 253`, voir la vérification du 09/10), sans supprimer ni modifier aucun test.

## Ce qui a changé

- `source/Tests.mc` : les 42 premiers tests du fichier, de `testFormatDuration` à `testHikeHistorySalvanRealClimb`, sont dans le module `(:test) module CoreTests { ... }`. Ce sont les plus anciens de la suite : les 5 tests d'origine (23/08), tous ceux du 04/10 (enregistrement, `HikeHistory`), et ceux des 05 et 06/10 qui se trouvent entre eux dans le fichier.
- Corps des tests inchangés et **non réindentés** : `git diff` n'ajoute que les lignes du module et un commentaire (11 lignes, aucune suppression).
- Le lanceur trouve ces tests sous le nom `CoreTests.<nom>` (comme `LayoutBenchTests.*`, `HikeGridLayoutTests.*` et `HikeMapLayoutTests.*`, déjà en modules).

## Vérification préalable : un test dans un module est-il découvert ?

Oui. Un seul test (`testFormatDuration`) a d'abord été placé dans `CoreTests` : sur fenix6pro, la sortie montre `Executing test CoreTests.testFormatDuration...` puis `PASS`, et 195 tests au total, comme avant.

## Comptage des membres globaux

Méthode : un jungle temporaire (`/tmp/glidator-build/probe/probe.jungle`) compile le dépôt **plus** un fichier hors dépôt de 50 fonctions globales vides `(:test) function zzProbeNN() {}`. Le compilateur refuse alors le build `-t` et donne le total : `Found N members in module 'globals'`. Le projet seul compte N − 50 membres. Rien n'est ajouté au dépôt.

| Montre | Avant | Après | Libres après |
|---|---|---|---|
| fenix6pro | 303 − 50 = **253** (0 libre) | 262 − 50 = **212** | **41** |
| fenix5 | 303 − 50 = **253** | 262 − 50 = **212** | **41** |
| instinct2 | — | 262 − 50 = **212** | **41** |
| fr265s | le build sonde passe même avec 50 de plus | — | non mesurable ainsi |

41 = 42 fonctions sorties du module `globals` − 1 membre pour le module `CoreTests`. Sur fr265s, le build avec 50 fonctions de plus passe : la limite y est plus haute (ou différente), la contrainte réelle vient des montres plus anciennes comme fenix5 et fenix6pro.

## Tests

- Avant : 195 tests, 195 PASS sur fenix6pro, fenix5 et fr265s.
- Après : 195 tests, 195 PASS sur les 17 montres représentatives (fenix6pro, fenix7, fenix5, fr55, fr255s, fenix7x, fr265s, epix2pro42mm, epix2, fenix843mm, fr965, fenix9pro51mm, instinct2, instincte40mm, instinct2s, instinct3amoled45mm, instinct3amoled50mm), par `zsh tools/run-watches.zsh`.
- Mêmes noms au préfixe près : sur chaque journal, les 195 lignes `Executing test` correspondent à la liste d'avant (préfixe `CoreTests.` facultatif), et exactement 42 portent le préfixe `CoreTests.`. Listes gardées dans `/tmp/glidator-build/tests-before-fenix6pro.txt` et `tests-after-fenix6pro.txt`.
- Compilation release : OK sur les 17 montres.

## Pour revenir en arrière

`git revert` du commit `refactor(tests): move the 42 oldest Tests.mc tests into module CoreTests` : les tests redeviennent globaux (et le module `globals` revient à 253 membres).

## Pour la suite

- Un nouveau test peut être global (41 places), mais il vaut mieux le mettre directement dans un module (`CoreTests` ou un module par fichier) : un module ne coûte qu'un membre.
- Le commentaire dans `testSensorsFollowPauseAndResume` (« the 'globals' module is at the compiler's 253-member limit ») n'est plus vrai ; il est laissé tel quel pour ne pas toucher au contenu des tests (décision D2).
