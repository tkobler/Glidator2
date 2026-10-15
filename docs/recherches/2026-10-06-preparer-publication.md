# Préparer la publication (et la vente) de Glidator2 sur le Connect IQ Store

*Note du chercheur. Sources consultées le 2026-10-05. Aucun fichier du projet modifié ; seule cette note est commitée.*

## 1. Question

Que faut-il faire avant de publier une version « produit fini » de Glidator2 sur le Connect IQ Store, et éventuellement de la vendre ?

Pour trancher, il faut savoir :
- ce que Garmin exige pour publier, et pour vendre (compte, frais, commission, pays, montres compatibles) ;
- quels tests manquent encore pour une app qu'on fait payer (batterie, mémoire, plantages, terrain, langues, réglages) ;
- si la licence permet de vendre (MIT, mais aussi l'origine du code) ;
- ce que change la clé `developer_key` publiée dans le dépôt public.

## 2. Réponse courte

**Recommandation : ne pas mettre une version payante en ligne tant que deux points bloquants ne sont pas réglés. Une mise à jour gratuite est possible plus tôt, une fois la licence réglée.** Confiance : **élevée** pour les deux points bloquants, **moyenne** pour les détails de la vente via Garmin.

1. **Licence et droits sur le code d'origine (bloquant, fait vérifié).** Le dépôt d'origine `gaetanmarti/glidator`, dont Glidator2 dérive (README, `garmin_description.md`), **n'a aucune licence** (GitHub : `license: null`). Sans licence, l'auteur garde tous ses droits : personne ne peut redistribuer ni créer d'œuvre dérivée (doc GitHub). Le fichier `LICENSE` MIT ajouté sur la branche couvre donc seulement le code écrit par Tim Kobler, pas la part qui vient de Gaetan Marti. Avant de vendre, et même pour garder la licence MIT, il faut **un accord écrit de Gaetan Marti** (par exemple qu'il publie son dépôt sous MIT, ou qu'il donne une autorisation explicite), ou bien **réécrire** le code repris. Le Developer Agreement de Garmin demande aussi au développeur de garantir qu'il a le droit de distribuer tout le code tiers de l'app. À noter : sur GitHub, la branche par défaut `main` de `tkobler/Glidator2` n'affiche toujours aucune licence (`license: null`), car le fichier n'existe que sur les branches de travail.
2. **La clé de signature est compromise (bloquant pour une version payante).** `developer_key` est suivie par git dans un dépôt public qui a déjà au moins un fork. Il faut la considérer comme publique pour toujours : réécrire l'historique ne la rendra pas secrète. Le Store refuse toute mise à jour signée par une autre clé que la première. Changer de clé oblige donc à créer **une nouvelle fiche Store avec un nouvel UUID**. Mon avis : le meilleur moment pour changer de clé est la création de la fiche payante, car cette fiche devra probablement être séparée de toute façon (voir § 3.4).
3. **Vendre via Garmin est possible** (fait sourcé, détails en § 3.2). Il faut un compte marchand, des frais annuels de 100 USD et une commission de 15 % sur le prix hors taxes. Mais **une bonne partie des montres du manifest ne permettrait pas l'achat** : d'après les forums (pas de liste officielle lisible), les Instinct 2/3 MIP et le FR945 ne sont pas compatibles. Garmin ne propose pas de période d'essai, seulement un remboursement sous 48 h. L'autre voie est KiezelPay : l'app reste gratuite sur le Store, avec un essai puis un déverrouillage payant. Cela demande du code en plus et la permission `Communications`.
4. **Côté produit, il reste à faire** : traduire l'app (une seule langue, l'anglais, et des textes écrits en dur dans le code), un vrai réglage dans Garmin Connect (aucun `properties.xml` ni `settings.xml`, et `AppBase.getProperty`, une méthode dépréciée), des tests de batterie et de mémoire sur la plus petite montre, un suivi des plantages (ERA) et un test terrain complet de vol.

## 3. Détails

### 3.1 Ce que le dépôt montre (lecture du code, sans compilation)

| Point | Constat | Source |
|---|---|---|
| Type, SDK, version | `watch-app`, `minSdkVersion="3.0.0"`, `version="0.0.1"` | `manifest.xml` |
| Montres | 58 produits : fenix 5 à 9, Forerunner 55 à 970, Instinct 2/2S/2X/3/E | `manifest.xml` |
| Permissions | `Fit`, `Positioning`, `Sensor`, `SensorHistory`. Pas `Communications` (donc pas de paiement tiers possible en l'état) | `manifest.xml` |
| Langues | `eng` seulement. `strings.xml` ne contient que `AppName` (« Glidator », alors que la fiche Store dit « Glidator2 ») et des restes du modèle (`menu_label_1/2` = « Item 1/2 »). Environ 28 textes en dur dans `source/` | `resources/strings/strings.xml`, grep |
| Réglages | Un seul réglage, le bip, lu via `app.getProperty("beep")`. Pas de réglages dans l'app Garmin Connect | `source/Preferences.mc` |
| GPS | `LOCATION_CONTINUOUS`, configuration GNSS par défaut ; capteurs FC et température | `source/FlyInstrumentApp.mc:235-237` |
| Mémoire des tampons | `BreadcrumbTrail` : 250 points × 2 ; `HikeHistory` : 60 × 3. Peu de mémoire en jeu, à mesurer quand même | `source/BreadcrumbTrail.mc`, `source/HikeHistory.mc` |
| Mention aviation | L'avertissement exigé par Garmin pour les apps d'aviation figure déjà en tête de `garmin_description.md` | `garmin_description.md` |
| Déjà publiée ? | Le README dit que l'app est sur le Store sous le nom « Glidator2 ». Le dépôt contient `glidator2_export/glidator2.iq` et `glidator2_export/V2.1/Glidator2.1.iq`. Je n'ai pas pu vérifier la fiche Store (pages rendues en JavaScript) | `README.md`, arborescence |
| Fichiers publiés à tort | `developer_key`, `bin/` (environ 100 fichiers, dont des `.prg`), `.DS_Store` et les `.iq` exportés sont suivis par git. Le `.gitignore` ne les retire pas du suivi | fiche projet, `docs/verifications/2026-10-05-corrections-marche.md` |
| fenix 5 | La vérification du 05/10 avait trouvé un plantage au démarrage de l'enregistrement (`SPORT_FLYING`). Depuis, le code définit `RECORDING_SPORT_FLYING = 20` et le README annonce un repli en `SPORT_GENERIC`. **À revérifier sur fenix5** | `source/FlyInstrumentApp.mc:57`, README |

### 3.2 Exigences de Garmin : publier et vendre

**Publier (gratuit)** : compte développeur Garmin, export `.iq` signé qui contient toutes les montres du manifest, envoi sur le portail, validation automatique du binaire, puis description et captures d'écran, puis relecture par Garmin. Pendant la relecture, l'app n'est pas visible. Il existe des apps bêta, qui doivent avoir un UUID différent de l'app publique. *(docs « Submit an app » et « Beta apps » ; fil « UUID not accepted », 2026)*

**Contenu et relecture** :
- Garmin accepte la plupart des apps. Il existe des exceptions, dont les **« extreme flight sports »** (skydiving, base jump…). Les apps d'aviation doivent afficher l'avertissement « in-flight aid only… » (déjà présent). *(wiki « App approval exceptions »)* Le parapente n'est pas cité nommément. Glidator et Glidator2 semblent avoir été acceptés, mais une nouvelle fiche, payante, sera relue à nouveau (incertain).
- Une app qui exige un paiement pour ses fonctions principales doit le dire dans sa description (badge « Payment Required »). Si elle propose un essai, elle doit afficher le temps restant. *(billet Garmin « Best Practices for Creating Monetized Content », 17/12/2021)*
- Hero image (bannière de la fiche) : 1440 × 720 px, avec le nom et un slogan, une image par langue si l'app est traduite. *(billet Garmin « We want you to feel seen » ; page officielle des consignes non lisible directement)*
- Exhibit A du Developer Agreement : politique de confidentialité obligatoire **si l'app collecte des données**, et la collecte de position doit être activée par l'utilisateur (opt-in). Glidator2 n'envoie rien hors de la montre (pas de `Communications`) : à mon avis ces clauses ne s'appliquent pas aujourd'hui, mais il faudra y revenir avec KiezelPay. *(Developer Agreement, version du 6 août 2024)*

**Vendre via Garmin (« Connect IQ monetization », lancé le 6 août 2024)** :

| Élément | État connu | Fiabilité |
|---|---|---|
| Paiement | Achat dans le Connect IQ Store, présenté comme « Garmin Pay », en pratique avec une carte bancaire classique ; traitement par Adyen | Communiqué Garmin (08/2024) ; the5krunner ; forum |
| Commission | 15 % du prix hors taxes. Garmin ajoute la TVA ou la taxe de vente et gère les frais de carte. Les taxes sur les services numériques et les frais de change sont retenus sur les versements | Développeurs sur le forum et the5krunner ; le contrat renvoie à la « Documentation » sans donner le taux |
| Frais fixes | 100 USD par an, non remboursables | Extraits indexés de la page officielle « Merchant onboarding » + forum |
| Compte marchand | Onglet « Merchant Account » du tableau de bord. Il n'apparaît qu'après l'envoi d'au moins une app : une app « DO NOT APPROVE » suffit. L'approbation prend plusieurs jours | Réponse de Garmin sur le forum (fil 403060) |
| Pays du développeur | Entité légale aux États-Unis, au Canada, en Australie, à Singapour ou dans « la plupart de l'UE ». **La Suisse serait incluse** d'après l'extrait indexé de la page officielle, mais je n'ai pas pu lire la page | Moyenne à faible pour la Suisse |
| Pays des acheteurs | US, DE, UK, MX, CA, UE, AU, NZ en 2024 | the5krunner 08/2024, peut avoir changé |
| Montres compatibles | **Pas toutes.** D'après des développeurs, les Instinct 2/3 MIP et le FR945 ne permettent pas l'achat : le bouton d'achat est grisé. the5krunner parle d'apps « CIQ System 7 ». Aucune liste officielle n'a pu être lue | Moyenne (forum + presse) |
| Essai | **Aucun** dans le système de Garmin. Remboursement sous 48 h seulement. Les API `isTrial()` et `getTrialDaysRemaining()` viennent d'un ancien système et ne sont pas reliées à celui-ci | Forum (fil 436796, 2026) |
| Arrêt du compte marchand | Les apps restent en ligne, mais deviennent gratuites | Forum (fil 404968) |
| Prix | Paliers fixés par Garmin (page « Price Points », non lisible). Le communiqué parle de « premium à partir de 4,99 $ » (prix conseillé) | Faible pour la grille exacte |

**Autre voie : déverrouillage par un tiers (KiezelPay)**. L'app reste gratuite sur le Store, et KiezelPay vend le déverrouillage hors du Store. KiezelPay est le vendeur officiel (« merchant of record ») : il gère la TVA et le change. On peut régler la durée d'essai et offrir des codes gratuits. En contrepartie : du code en plus dans l'app, la permission `Communications`, une connexion de temps en temps via le téléphone, et la mention « Payment Required » dans la description. Je n'ai pas pu lire les tarifs de KiezelPay (site rendu en JavaScript). Un développeur cite environ 24 USD par an et 7,69 % par vente pour son propre système, sans dire lequel. *(forums 426202 et 439822)* Le contrat Garmin dit que le service marchand de Garmin est **facultatif**.

### 3.3 Licence : MIT et vente

**Fait** : la licence MIT autorise explicitement à vendre (« sell copies »). La seule condition est de garder l'avis de copyright et de licence. Vendre l'app sur le Store est donc compatible avec MIT, **pour le code dont l'auteur a les droits**.

**Fait** : le code d'origine (`gaetanmarti/glidator`, créé le 18/08/2024, dernier push le 13/09/2024) n'a pas de licence. Les CGU de GitHub permettent de voir et de forker un dépôt public, rien de plus. C'est le point bloquant n° 1 (§ 2).

**Conséquence pratique de MIT, même une fois le point 1 réglé (avis)** : n'importe qui peut compiler le dépôt public et installer l'app à la main sur sa montre, ou publier un clone (avec son propre UUID et sa propre clé). De plus, les `.iq` et `.prg` déjà présents dans le dépôt s'installent sans rien payer. Le prix paierait donc surtout la commodité et le soutien au développeur, pas une exclusivité.

**Options** (je ne tranche pas, c'est à l'utilisateur de décider) :

| Option | Pour | Contre |
|---|---|---|
| A. Tout garder en MIT et public, vendre la commodité (ou passer par des dons) | Simple, cohérent avec l'esprit de Glidator ; les contributions restent possibles | Des clones sont possibles, et le public sait que le code est gratuit |
| B. MIT pour ce qui est déjà publié, dépôt privé (ou nouveau dépôt fermé) pour les versions futures | Le code déjà publié reste MIT (on ne peut pas reprendre une licence déjà accordée), le nouveau code est protégé | Le code d'avant reste réutilisable ; la crédibilité « open source » en souffre ; il faut l'accord de Gaetan pour ses parties dans tous les cas |
| C. Double licence (par exemple GPLv3 public + licence commerciale) ou « open core » (le cœur en MIT, les fonctions premium fermées) | Les concurrents ne peuvent pas fermer un dérivé (GPL) ; on garde un modèle commercial | Plus complexe ; il faut détenir les droits sur 100 % du code (accord de Gaetan, et des contributeurs le cas échéant) ; on ne peut pas retirer MIT du code déjà publié |
| D. Licence « source disponible » (PolyForm Noncommercial, BSL…) pour les versions futures | Le code reste visible, mais l'usage commercial est interdit | Ce n'est plus de l'open source au sens OSI ; mêmes limites que B pour le code d'avant |

Note : la fiche projet interdit de copier du code venant des apps GPLv3 étudiées, ce qui laisse toutes ces options ouvertes.

### 3.4 La clé `developer_key` publiée

**Faits** :
- Une clé perdue ne se récupère pas. Toutes les versions d'une app doivent être signées par la même paire de clés, sinon le Store répond « Signature check has failed ». Changer de clé oblige à changer l'UUID et donc à créer une nouvelle fiche. *(forums Garmin : « developer key lost », « Is there a way to recover my signing key? », « signature check failed »)*
- Le dépôt est public et a au moins un fork (API GitHub : `forks_count: 1`), donc la clé est déjà copiée ailleurs.

**Analyse (avis)** :
- Avec la clé seule, un tiers **ne peut pas** mettre à jour la fiche Store : il lui faut aussi le compte Garmin. Depuis la fuite, le mot de passe du compte est donc la seule protection. Il faut sécuriser le compte : mot de passe unique et 2FA si Garmin la propose.
- Pour une app **gratuite déjà publiée**, garder la clé est défendable : la changer ferait perdre la fiche, ses installations et ses avis.
- Pour une **version payante**, je recommande une nouvelle clé (générée hors du dépôt, sauvegardée en au moins 2 copies chiffrées) avec un nouvel UUID et une nouvelle fiche. Trois raisons : (1) on repart avec un secret propre ; (2) une fiche payante séparée est sans doute nécessaire de toute façon, puisque les montres qui ne permettent pas l'achat ne peuvent pas acheter, et que des développeurs gardent une fiche gratuite « legacy » à côté d'une fiche payante (fil 404968) ; (3) les utilisateurs actuels gardent la version gratuite.
- **À vérifier par l'utilisateur** : la version 2.1 publiée a-t-elle été signée avec **cette** clé ? Si l'app publiée vient d'une autre clé (par exemple générée par VS Code ailleurs), la clé du dépôt ne sert à rien pour la fiche existante.
- Nettoyer le dépôt (`git rm --cached developer_key bin/ .DS_Store glidator2_export/`) évite d'aggraver la fuite et empêche que les `.iq` restent installables gratuitement. Réécrire l'historique (git filter-repo) n'efface pas la clé des forks ni des clones : c'est utile seulement pour les `.iq` et le bruit, pas pour la clé.

### 3.5 Tests encore manquants pour un produit fini

| Domaine | État | À faire (avis) |
|---|---|---|
| Plantages | 37 tests unitaires ; vérifications au simulateur à faire (protocole du 05/10) | Faire le protocole A à F ; lancer l'app (pas seulement les tests) sur une montre de chaque famille et taille d'écran, en particulier **fenix5** (correctif `SPORT_FLYING` à confirmer), instinct2 (écran monochrome), instincte40mm, fr55 et une AMOLED ; après publication, surveiller **ERA** (Exception Reporting App : plantages des utilisateurs sur 30 jours, avec des trous connus, cf. forum) |
| Mémoire | Non mesurée | Dans le simulateur, ouvrir *File > View Memory* (et le profileur) après 3 h de lecture GPX accélérée, sur la montre qui a le moins de mémoire pour une watch-app (voir `compiler.json` de chaque montre dans le dossier `Devices` du SDK) ; vérifier que le pic reste bien sous la limite |
| Batterie | Non mesurée | Sortie réelle de 3 h ou plus : noter le % de batterie par heure et comparer à une activité Garmin native du même type ; tester l'écran en continu (vue vol) ; vérifier que les capteurs sont bien arrêtés en quittant l'app (`onStop`) |
| Terrain | Une seule sortie (Salvan, 13/09/2026), surtout de la marche | Au moins un vrai vol complet (décollage, thermiques, atterrissage) et un changement de mode pendant l'enregistrement ; vérifier le FIT dans Garmin Connect (sport, laps, D+) ; durée longue (plus de 5 h) ; froid ; perte du GPS |
| Langues | `eng` seulement, textes en dur | Sortir les textes dans `strings.xml`, ajouter au moins `fre` et `deu` (et `ita` pour la Suisse et les Alpes) ; vérifier la longueur des libellés sur petit écran ; traduire aussi la fiche Store |
| Réglages | Un bip, API dépréciée, pas de réglages dans Garmin Connect | Passer à `Application.Storage` / `Properties` avec un repli via `has` ; réfléchir à des réglages utiles (unités m/ft, seuils du vario, mode de départ) ; tester un premier lancement sans valeur enregistrée et une mise à jour qui conserve les réglages |
| Version | `version="0.0.1"` dans le manifest, alors que la version publiée est 2.1 | Aligner le numéro de version (je n'ai pas trouvé de source qui dise si le Store refuse une version inférieure : à vérifier) |
| Fiche Store | `garmin_description.md` existe | Captures par famille de montres, hero image 1440 × 720, nom cohérent (`AppName` = « Glidator » contre « Glidator2 »), mention « Payment Required » si l'app est payante, crédit et lien vers le code d'origine |

## 4. Impact concret sur le projet

- **Fichiers concernés plus tard** (rien n'est modifié par cette note) : `LICENSE` (copyright partagé avec Gaetan Marti ou autre texte selon sa réponse), `README.md` (§ Credits et § Publishing ; la commande d'export sans `-y` et l'URL `yourusername` sont fausses), `manifest.xml` (version, langues, éventuellement nouvel UUID et liste de montres pour une fiche payante, permission `Communications` si KiezelPay), `resources/strings/` (traductions), `source/Preferences.mc` (Storage), éventuellement `resources/settings/`.
- **Ordre conseillé** : (1) contacter Gaetan Marti ; (2) sécuriser le compte Garmin et décider de la clé ; (3) retirer du suivi `developer_key`, `bin/`, les `.iq` et `.DS_Store` ; (4) traductions et réglages ; (5) tests batterie, mémoire, terrain ; (6) choisir le modèle de vente ; (7) créer le compte marchand si on passe par Garmin ; (8) soumettre.
- **Risques** : retrait de l'app pour atteinte au droit d'auteur (DMCA) si Gaetan Marti s'y oppose ; refus d'une fiche payante au titre des « extreme flight sports » ; peu d'acheteurs possibles à cause des montres non compatibles ; mauvais avis si l'app plante sur des modèles anciens ; responsabilité envers les clients pour une aide au vol vendue (avis : l'avertissement MIT « AS IS » ne suffit pas forcément face au droit de la consommation en Suisse ou dans l'UE).

## 5. Checklist priorisée avant publication

### Bloquant
- [ ] Obtenir un **accord écrit de Gaetan Marti** (licence MIT sur `glidator`, ou autorisation de redistribuer et de vendre le dérivé), ou bien réécrire le code repris. Mettre à jour `LICENSE` et les crédits en conséquence.
- [ ] Faire arriver `LICENSE` sur `main` (aujourd'hui, GitHub n'affiche aucune licence pour le dépôt).
- [ ] Vérifier dans le tableau de bord du Store quelle clé et quel UUID utilise la fiche Glidator2 existante.
- [ ] Sécuriser le compte développeur Garmin (mot de passe unique, 2FA si disponible), puisque la clé est publique.
- [ ] Si l'app devient payante : **nouvelle clé hors du dépôt** (2 sauvegardes chiffrées), **nouvel UUID**, nouvelle fiche.
- [ ] Retirer du suivi `developer_key`, `bin/`, `glidator2_export/*.iq` et `.DS_Store` (`git rm --cached`, décision de l'utilisateur).
- [ ] Faire le protocole du simulateur du 05/10 (A à F) et confirmer que l'enregistrement ne plante plus sur **fenix5** (sinon, retirer les fenix 5 du manifest).
- [ ] Pour une version payante : choisir **Garmin ou KiezelPay**, avec la liste des montres compatibles en tête. Avec Garmin, vérifier que l'entité suisse est acceptée pendant l'inscription marchand.

### Important
- [ ] Test de batterie sur une vraie sortie (3 h ou plus) et comparaison avec une activité native.
- [ ] Mesure de la mémoire (pic) après une longue simulation sur la montre la plus limitée.
- [ ] Au moins un vrai vol complet enregistré et le FIT vérifié dans Garmin Connect.
- [ ] Traductions FR/DE (IT) : textes sortis du code, manifest `<iq:languages>`, fiche Store traduite.
- [ ] Remplacer `AppBase.getProperty` par Storage/Properties ; supprimer les textes « Item 1/2 » restés du modèle.
- [ ] Aligner `AppName` et la version du manifest avec la fiche Store.
- [ ] Fiche Store : captures par famille de montres, hero image 1440 × 720, avertissement aviation (déjà présent), crédits, mention « Payment Required » si l'app est payante.
- [ ] Décider de la licence pour la suite (options A à D, § 3.3).
- [ ] Demander à un fiduciaire comment déclarer ces revenus et qui gère la TVA (Garmin ou KiezelPay).

### Confort
- [ ] Réglages dans Garmin Connect (unités, seuils du vario, mode de départ).
- [ ] Bêta privée (app bêta avec un autre UUID) auprès de quelques pilotes avant la sortie publique.
- [ ] Surveiller ERA chaque semaine après la sortie.
- [ ] Corriger le README : commande d'export avec `-y`, URL du dépôt, section Publishing.
- [ ] Page de support ou FAQ (recommandée par Garmin pour les apps payantes).

## 6. Ce qui reste incertain

- **Liste officielle des montres qui permettent l'achat** via Garmin : les pages `developer.garmin.com/connect-iq/monetization/*` sont rendues en JavaScript et je n'ai pas pu les lire. Ce que j'en dis vient du forum et de la presse.
- **La Suisse dans la liste des pays du compte marchand** : seulement un extrait indexé de la page officielle.
- **Grille de prix** (paliers min et max) et **calendrier des versements** : non lus.
- **Contrôle des achats sur la montre** : je ne sais pas si une app payante via Garmin vérifie l'achat sur la montre, ou si un `.prg` installé à la main fonctionne sans payer.
- **Parapente et « extreme flight sports »** : interprétation par Garmin inconnue ; l'acceptation de la fiche actuelle laisse penser que c'est toléré.
- **Clé utilisée pour la fiche publiée** et existence réelle de la fiche « Glidator2 » (non vérifiable sans le compte).
- **Numéro de version** : je ne sais pas si le Store refuse un numéro inférieur à celui de la version publiée.
- **Tarifs actuels de KiezelPay** (site non lisible).
- **Responsabilité juridique** d'une aide au vol vendue (droit suisse ou européen) : hors de mon champ, à confier à un juriste si les ventes deviennent significatives.

## 7. Sources (consultées le 2026-10-05)

- Garmin, communiqué « Garmin enables premium app purchases in the Connect IQ Store… » (6 août 2024) : https://www.garmin.com/en-US/newsroom/press-release/wearables-health/garmin-enables-premium-app-purchases-in-the-connect-iq-store-and-unveils-fun-new-watch-faces-and-apps/
- Garmin, Connect IQ Developer Agreement (version du 6 août 2024) : https://developer.garmin.com/downloads/connect-iq/sdks/agreement.html
- Garmin, Merchant Onboarding (page rendue en JS, extraits indexés seulement) : https://developer.garmin.com/connect-iq/monetization/merchant-onboarding
- Garmin, App Sales / Price Points (non lisibles) : https://developer.garmin.com/connect-iq/monetization/app-sales/ , https://developer.garmin.com/connect-iq/monetization/price-points/
- Garmin, Submit an app : https://developer.garmin.com/connect-iq/submit-an-app/
- Garmin, App Review Guidelines (non lisible) : https://developer.garmin.com/connect-iq/app-review-guidelines/
- Garmin, wiki « App approval exceptions » : https://forums.garmin.com/developer/connect-iq/w/wiki/10/app-approval-exceptions/revision/7
- Garmin, wiki « New Developer FAQ » : https://forums.garmin.com/developer/connect-iq/w/wiki/4/new-developer-faq
- Garmin, billet « Best Practices for Creating Monetized Content » (17/12/2021) : https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/tips-for-monetizing-your-apps
- Garmin, billet « We want you to feel seen » (hero image) : https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/we-want-you-to-feel-seen
- Forum, « Where is Merchant Onboarding? » (réponse de Garmin) : https://forums.garmin.com/developer/connect-iq/f/connect-iq-web-store/403060/where-is-merchant-onboarding
- Forum, « New Merchant, first update with pricing and buy buttons greyed out » : https://forums.garmin.com/developer/connect-iq/f/connect-iq-web-store/404968/new-merchant-first-update-with-pricing-and-buy-buttons-greyed-out/1905051
- Forum, « Connect IQ Monetization System vs own payment system » : https://forums.garmin.com/developer/connect-iq/f/discussion/426202/connect-iq-monetization-system-vs-own-payment-system---increase-in-sales/1990898
- Forum, « Adding a 7-day trial to a Garmin Pay paid app » : https://forums.garmin.com/developer/connect-iq/f/connect-iq-web-store/436796/adding-a-7-day-trial-to-a-garmin-pay-paid-app-what-s-the-official-path
- Forum, « Paid CIQ Apps » (KiezelPay) : https://forums.garmin.com/developer/connect-iq/f/discussion/439822/paid-ciq-apps
- Forum, « developer key lost » : https://forums.garmin.com/developer/connect-iq/f/connect-iq-web-store/402228/developer-key-lost
- Forum, « Is there a way to recover my signing key? » : https://forums.garmin.com/developer/connect-iq/f/discussion/238347/is-there-a-way-to-recover-my-signing-key
- Forum, « signature check failed » : https://forums.garmin.com/developer/connect-iq/f/connect-iq-web-store/431892/signature-check-failed
- Forum, « UUID not accepted » (2026) : https://forums.garmin.com/developer/connect-iq/f/connect-iq-web-store/437376/uuid-not-accepted/2036285
- Forum, ERA : https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/exceptional-crash-logging et https://forums.garmin.com/developer/connect-iq/i/bug-reports/era-tool-does-not-provide-crash-reports-consistently
- Garmin API, AppBase (getProperty déprécié) : https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html ; Storage : https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html
- the5krunner, « Garmin Connect IQ Store allows paid-for apps using Garmin PAY » (7 août 2024) : https://the5krunner.com/2024/08/07/garmin-connect-iq-store-allows-paid-for-apps-using-garmin-pay/
- GitHub, dépôt d'origine sans licence : https://github.com/gaetanmarti/glidator et https://api.github.com/repos/gaetanmarti/glidator
- GitHub, dépôt Glidator2 (licence null sur main, 1 fork) : https://api.github.com/repos/tkobler/Glidator2
- GitHub Docs, « Licensing a repository » (absence de licence) : https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository
