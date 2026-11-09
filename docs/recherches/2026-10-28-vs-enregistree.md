# D'où vient la « VS enregistrée » du test du 22/10 ?

Date : 2026-10-28 (tâche D2 A du 27/10). Branche : `claude/corrections-marche`.

## Conclusion

Il n'y a pas de VS enregistrée par l'app, ni par le firmware dans le TCX. Les « 20 VS enregistrées au-delà de ±3000 m/h » de l'analyse du 22/10 sont une **reconstitution par rejeu** de `HikeHistory.mc` faite par `tools/analyze_activity.py` sur les points du fichier. Aucun correctif de code n'est donc possible ni nécessaire : on ne peut pas borner une valeur qui n'est pas enregistrée. Le diff de cette tâche est une note seulement.

## Preuves

1. **L'app ne code aucun champ FIT.** Recherche dans `source/`, `resources/`, `monkey.jungle` de `createField`, `FitContributor`, `FitField` : aucun résultat. L'enregistrement se limite à `ActivityRecording.createSession({:name, :sport})` puis `start/stop/addLap/save/discard` (`source/FlyInstrumentApp.mc`, `startRecording()` et suivantes). Le fichier FIT est donc entièrement écrit par le firmware, avec ses champs standard.
2. **Référence SDK** (developer.garmin.com/connect-iq/api-docs/Toybox/FitContributor.html, consultée le 2026-10-28) : le module FitContributor sert aux apps à écrire leurs propres données dans le FIT (`Session.createField()`), pour des valeurs que l'appareil ne calcule pas. Sans cet appel, rien de l'app n'entre dans le fichier. La permission `Fit` du manifest (ligne 70) est déclarée mais jamais utilisée.
3. **Le TCX ne contient aucune VS.** Éléments par point du fichier du 22/10 (comptage des noms de balises, sans lire de valeur) : `Time`, `Position` (latitude, longitude), `AltitudeMeters`, `DistanceMeters`, `HeartRateBpm`, et en extension `ns3:Speed` (3796 occurrences) ; par tour : `AvgSpeed`, `LX`, `MaximumSpeed`, calories, etc. Aucun élément de vitesse verticale.
4. **L'origine du chiffre.** `tools/analyze_activity.py` (docstring lignes 20-23 et fonction `watch_vertical_speed_series`, lignes 347 et suivantes) : la colonne « VS montre (HikeHistory) » est un rejeu de l'algorithme de la montre (échantillon au plus toutes les 5 s, remise à zéro après un trou > 15 s, régression sur 60 s) appliqué aux altitudes du TCX. Cette fonction ne borne pas la valeur à ±3000 m/h. Les 20 valeurs hors borne (minimum -4737,6 m/h) sont donc ce que la formule donne pendant la phase aérienne, pas ce que la montre a affiché ni enregistré. Sur la montre, l'affichage passe par `formatVerticalSpeed()` (`source/Utils.mc`, `VERTICAL_SPEED_MAX_MH` = 3000) et lit « -- » au-delà de la borne.
5. **Même raison pour le tour 2 (vol).** Le tableau « Mode Vol : montre (enregistré) » de `docs/verifications/2026-10-22-villeneuve.md` est lui aussi un rejeu, pas un champ du fichier.

## Corrections à faire dans l'analyse du 22/10

L'analyse parle de « VS enregistrée » / « champ enregistré par l'app » : à lire « VS rejouée à partir des points ». La phrase « l'enregistrement n'est pas borné » est sans objet : il n'y a pas de VS enregistrée. Je n'ai pas modifié ce fichier (hors périmètre de la tâche) ; à reprendre par `analyste-activite`.

## Ce qui n'est pas prouvé

- Le FIT d'origine n'a pas été lu (seul le TCX issu de Garmin Connect l'a été). Le firmware pourrait écrire un champ de vitesse verticale dans le FIT que l'export TCX n'a pas retransmis ; il serait de toute façon hors de portée de l'app (aucun contrôle sur les champs natifs). Si l'utilisateur veut lever ce doute, il faut le FIT et un décodeur.
- Le texte de la doc SDK a été lu via un résumé automatique de la page, pas une lecture intégrale.

## Pistes (non faites)

- Si l'on veut une VS bornée dans le fichier, il faudrait créer un champ de développeur avec `Session.createField()` (type record, unité m/h) alimenté par une valeur bornée. Ce serait une nouvelle fonctionnalité, avec ses coûts mémoire sur les vieilles montres et un risque sur la zone sensible ; non recommandé sans besoin explicite.
- Pour l'outil : donner au rejeu `watch` la même borne que l'affichage, ou l'étiqueter « rejeu » dans le rapport, afin que le chiffre ne soit plus lu comme une valeur enregistrée.
