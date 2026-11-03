# TP FPGA — Compte rendu global

**Binôme :** Maxime Zaragoza — Sidibé
**Formation :** ENSEA, 2A — 2026/2027
**Carte :** Terasic DE10-Nano (Cyclone V `5CSEBA6U23I7`) + carte mezzanine TELECRAN
**Outils :** Quartus Prime Lite 24.1, ModelSim / Questa

L'énoncé est dans [`3-tp/fpga_tp.md`](3-tp/fpga_tp.md).

## Sommaire

- [Organisation du dépôt](#organisation-du-dépôt)
- [Séance 1 (29/09/2026) — TP1 : Tutoriel Quartus](#séance-1-29092026--tp1--tutoriel-quartus)
- [Séance 2 (19/10/2026) — Projet Écran magique : encodeurs](#séance-2-19102026--projet-écran-magique--encodeurs)
- [Séance 3 (03/11/2026) — Projet Écran magique : contrôleur HDMI](#séance-3-03112026--projet-écran-magique--contrôleur-hdmi)
- [Reste à faire](#reste-à-faire)
- [Annexe : simuler et tester](#annexe--simuler-et-tester)

## Organisation du dépôt

```
3-tp/
├── fpga_tp.md                     énoncé
├── TP1-Tuto_Quartus/              séance 1
│   ├── tuto_fpga.vhd              bouton -> LED
│   ├── led_blink.vhd              LED clignotante (avec diviseur)
│   ├── led_blink_chenillard.vhd   chenillard 10 LED
│   ├── img/                       captures et photos de la séance
│   └── Projet quartus/            projets Quartus
├── TP2-Projet_ecran/              projet Écran magique (simulations)
│   ├── Encoder/                   encodeur : VHDL, testbench, .do, captures
│   └── HDMI/                      contrôleur HDMI : testbench, .do
└── telecran/telecran/             projet Quartus du télécran (top : telecran.vhd)
```

---

## Séance 1 (29/09/2026) — TP1 : Tutoriel Quartus

### Premier projet : un bouton allume une LED

Code : [`tuto_fpga.vhd`](3-tp/TP1-Tuto_Quartus/tuto_fpga.vhd)

Le projet `tuto_fpga` a été créé pour le FPGA `5CSEBA6U23I7`. Les broches assignées sont `PIN_AH27` pour `pushl` (bouton de l'encodeur gauche) et `PIN_AG28` pour `led0`. La synthèse passe sans erreur, avec un seul warning (sur le nombre de processeurs, sans importance) :

![Analysis & Synthesis réussie](<3-tp/TP1-Tuto_Quartus/img/analyse_synthèse.png>)

La carte a été programmée par le port USB BLASTER II avec l'outil Programmer (chaîne JTAG : `SOCVHPS` puis `5CSEBA6U23`) :

![Programmation réussie](3-tp/TP1-Tuto_Quartus/img/televersement_du_premier_programme.png)

**Observation :** avec `led0 <= pushl;`, le comportement est inversé. La LED est allumée au repos et s'éteint quand on appuie. Le bouton est câblé avec une résistance de pull-up : il vaut `'1'` au repos et `'0'` quand il est enfoncé.

**Correction :** `led0 <= not pushl;`. La LED est maintenant éteinte au repos et s'allume à l'appui :

| Bouton relâché | Bouton enfoncé |
|:---:|:---:|
| <img src="3-tp/TP1-Tuto_Quartus/img/resultat_inversement_fonctionnement_bouton_nonpressé.png" width="300"> | <img src="3-tp/TP1-Tuto_Quartus/img/resultat_inversement_fonctionnement_bouton_pressé.png" width="300"> |

### Faire clignoter une LED

**Q1 — Broche de l'horloge `FPGA_CLK1_50` :** elle est sur `PIN_V11` (DE10-Nano User Manual, table 3-5).

![Table des horloges du User Manual](3-tp/TP1-Tuto_Quartus/img/pin_horloge.png)

**Q3/Q4 — Schéma du code de base :** une seule bascule D `r_led` dont la sortie est rebouclée sur l'entrée à travers un inverseur. `i_rst_n` est relié à la remise à zéro asynchrone (CLRN). Le RTL Viewer de Quartus donne exactement ce schéma :

![RTL Viewer du clignotement simple](3-tp/TP1-Tuto_Quartus/img/schema-led_blink.png)

La LED change d'état à chaque front d'horloge, donc elle clignote à 25 MHz : c'est invisible à l'œil.

**Q6/Q7/Q8 — Réduire la fréquence :** code dans [`led_blink.vhd`](3-tp/TP1-Tuto_Quartus/led_blink.vhd). On ajoute :
- un compteur `counter` sur 23 bits (additionneur +1, puis multiplexeur qui le remet à 0) ;
- un comparateur avec 5 000 000 (`23'h4C4B40`) ;
- un registre `r_led_enable`, qui vaut 1 pendant un seul cycle tous les 5 000 001 cycles, soit environ 10 Hz ;
- `r_led` qui n'inverse son état que quand `r_led_enable = '1'` (entrée ENA de la bascule).

La LED change donc d'état 10 fois par seconde : elle clignote à environ 5 Hz. Le RTL Viewer confirme le schéma :

![RTL Viewer du clignotement avec diviseur](<3-tp/TP1-Tuto_Quartus/img/schema-led_blink_corrigée.png>)

**Q9/Q10 — Reset :** chaque registre a un reset asynchrone sur `i_rst_n`, câblé sur le bouton `KEY0` (`PIN_AH17`).

**Q11 — Que signifie `_n` dans `i_rst_n` ?** Que le signal est actif à l'état bas : le reset agit quand `i_rst_n = '0'`. Ce choix a deux raisons :
- Le matériel : `KEY0` est câblé avec une résistance de pull-up. Il vaut `'1'` au repos et `'0'` quand on appuie, donc l'appui déclenche directement le reset.
- La fiabilité : si le fil est débranché, la pull-up maintient le signal à `'1'` et le circuit n'est pas bloqué en reset. C'est aussi la convention habituelle, qui permet de relier plusieurs sources de reset sur le même fil.

### Chenillard

Code : [`led_blink_chenillard.vhd`](3-tp/TP1-Tuto_Quartus/led_blink_chenillard.vhd)

On réutilise le diviseur de fréquence ci-dessus (impulsion `r_led_enable` à environ 10 Hz). Un registre de 10 bits, initialisé à `"0000000011"`, tourne de 2 positions à chaque impulsion (`r_led(7 downto 0) & r_led(9 downto 8)`). Deux LED allumées défilent donc en boucle sur les 10 LED de la carte mezzanine. Un appui sur `KEY0` ramène le motif au départ.

---

## Séance 2 (19/10/2026) — Projet Écran magique : encodeurs

### Q2 — Détection d'un front montant ou descendant

![Détecteur de front](3-tp/figures/edge_detector.png)

Les deux bascules D en série mémorisent A à deux instants successifs. `A_d1` est la valeur actuelle de A (synchronisée sur `clk`) et `A_d2` sa valeur au coup d'horloge précédent. Si les deux diffèrent, A vient de changer : il y a un front.

| `A_d2` | `A_d1` | Détection |
|:---:|:---:|---|
| 0 | 1 | front montant → `E = A_d1 and not A_d2` |
| 1 | 0 | front descendant → `E = not A_d1 and A_d2` |

Le bloc `???` est donc une simple porte logique. `E` vaut 1 pendant une seule période d'horloge et sert d'*enable* pour incrémenter ou décrémenter le registre. En plaçant la même structure sur la voie B, on distingue les deux sens de rotation en combinant le front d'une voie avec le niveau de l'autre.

La première bascule sert aussi à resynchroniser le signal de l'encodeur, qui arrive de façon asynchrone par rapport à l'horloge du FPGA.

### Q3 — Implémentation

Code : [`encoder.vhd`](3-tp/TP2-Projet_ecran/Encoder/encoder.vhd)

- Un détecteur de fronts, comme ci-dessus, sur chacune des voies A et B (`s_a_rise`, `s_a_fall`, `s_b_rise`, `s_b_fall`).
- La taille du registre est réglable par le generic `g_width` (10 par défaut).
- Incrémentation : front montant sur A avec B à 0, **ou** front descendant sur A avec B à 1.
- Décrémentation : front montant sur B avec A à 0, **ou** front descendant sur B avec A à 1.

Pour le test sur carte, le top [`encoder_leds.vhd`](3-tp/TP2-Projet_ecran/Encoder/encoder_leds.vhd) affiche la valeur sous forme de barre : la LED *i* s'allume si la valeur est strictement supérieure à *i*. Schéma RTL :

![RTL de encoder_leds](3-tp/TP2-Projet_ecran/Encoder/img/schema.png)

### Q4 — Simulation

Testbench : [`encoder_tb.vhd`](3-tp/TP2-Projet_ecran/Encoder/encoder_tb.vhd). Script : [`encoder.do`](3-tp/TP2-Projet_ecran/Encoder/encoder.do).

Le testbench génère des cycles de quadrature complets dans les deux sens et vérifie la valeur avec des `assert`.

**Rotation à droite (A en avance sur B) :**

![Simulation : incrémentation](<3-tp/TP2-Projet_ecran/Encoder/img/incrémentation.png>)

**Observations :**
- Chaque front de A produit une impulsion d'un seul cycle (`s_a_rise`, `s_a_fall`), au front d'horloge qui suit le changement de `i_ch_a`, c'est-à-dire dès que `r_a_d1` et `r_a_d2` diffèrent.
- Dans ce sens, seuls les fronts de A remplissent une condition d'incrémentation. La valeur augmente donc de **+2 par cycle de quadrature** : de 0 à 8 en 4 cycles.

**Rotation à gauche (B en avance sur A), puis reset :**

![Simulation : décrémentation](<3-tp/TP2-Projet_ecran/Encoder/img/décrémentation.png>)

**Observations :**
- La valeur descend de 8 jusqu'à 0, puis passe à **1023 et 1022**. Le registre de 10 bits non signé reboucle bien à `2^10 - 1`.
- Le reset en cours de fonctionnement remet la valeur à 0.
- Aucune assertion n'échoue.

### Q5 — Test sur carte

> 📝 À compléter : résultat du test avec `encoder_leds` (sens de rotation, nombre de LED par cran, rebonds éventuels) et photo de la carte.

### Contrôleur HDMI : préparation

Le contrôleur HDMI du TD 3 ([`hdmi_controler.vhd`](3-tp/telecran/telecran/hdmi_controler.vhd)) a été ajouté au projet `telecran`. Son testbench ([`hdmi_controler_tb.vhd`](3-tp/TP2-Projet_ecran/HDMI/hdmi_controler_tb.vhd)) et son script de simulation ([`hdmi_controler.do`](3-tp/TP2-Projet_ecran/HDMI/hdmi_controler.do)) ont aussi été écrits.

---

## Séance 3 (03/11/2026) — Projet Écran magique : contrôleur HDMI

### Q1 — Simulation du contrôleur

Simulation dans ModelSim avec `do hdmi_controler.do` (dossier `3-tp/TP2-Projet_ecran/HDMI`). Timings mesurés :

| Grandeur | Mesure | Standard 480p (CEA-861) |
|---|:---:|:---:|
| Période d'une ligne | 858 cycles | 858 |
| Largeur de HS (actif bas) | 62 cycles | 62 |
| Largeur de VS (actif bas) | 6 lignes | 6 |
| Pixels actifs par ligne (DE = 1) | 720 | 720 |
| Lignes actives par image | 480 | 480 |
| Nombre de lignes par image | 525 | 525 |
| Plage de `x` / `y` | 0–719 / 0–479 | — |

À 27 MHz, on obtient 27·10⁶ / (858 × 525) ≈ **60 images/s**.

**Observation :** `o_x_counter` est en avance d'un cycle sur `o_hdmi_de`, qui est registré. Une couleur calculée directement depuis `x` est donc décalée d'un pixel, ce qui ne se voit pas. Ce décalage sera compensé dans la partie Mémorisation par le cycle de latence de la lecture en RAM.

> 📝 À compléter : capture des chronogrammes HS / VS / DE à comparer avec celles du TD.

### Q2/Q3/Q4 — Intégration dans le top

Dans [`telecran.vhd`](3-tp/telecran/telecran/telecran.vhd) :
- le composant `hdmi_controler` est instancié avec l'horloge à 27 MHz et le reset fournis par la PLL (`s_clk_27`, `s_rst_n` = `locked`) ;
- `o_pixel_en` et `o_pixel_address` ne sont pas utilisés (`open`) ;
- la couleur des pixels dépend des compteurs :

```vhdl
o_hdmi_tx_d(23 downto 16) <= std_logic_vector(to_unsigned(s_x_counter mod 256, 8)); -- rouge = x
o_hdmi_tx_d(15 downto 8)  <= std_logic_vector(to_unsigned(s_y_counter mod 256, 8)); -- vert  = y
o_hdmi_tx_d(7 downto 0)   <= (others => '0');                                       -- bleu  = 0
```

### Q5 — À quels bits correspond chaque couleur ?

| Bits de `o_hdmi_tx_d` | Composante |
|:---:|:---:|
| 23 – 16 | Rouge |
| 15 – 8 | Vert |
| 7 – 0 | Bleu |

L'image attendue est la suivante :
- en haut à gauche, du noir ;
- le rouge augmente vers la droite et repart de 0 à x = 256 et x = 512 (environ 3 bandes) ;
- le vert augmente vers le bas et repart de 0 à y = 256 (environ 2 bandes) ;
- les zones où rouge et vert se mélangent virent au jaune.

### Correction de la contrainte d'horloge

Le fichier [`telecran.sdc`](3-tp/telecran/telecran/telecran.sdc) déclarait l'horloge sur `FPGA_CLK1_50`, un port qui n'existe pas dans notre top. Quartus n'avait donc aucune contrainte d'horloge. L'horloge est maintenant déclarée sur `i_clk_50`, et `derive_pll_clocks` contraint aussi l'horloge de 27 MHz.

**Résultat de la compilation :** 0 erreur, 0 warning critique, 99 ALM utilisés (moins de 1 %). Les marges de setup sont positives : 15,0 ns sur `i_clk_50` et 33,3 ns sur l'horloge de la PLL.

### Q6 — Test sur carte

> 📝 À compléter : capture VLC de l'image obtenue et observations (dégradé, effet de KEY0).

---

## Reste à faire

- [ ] Déplacement d'un pixel (encodeur gauche pour x, encodeur droit pour y)
- [ ] Mémorisation : Q1 (mémoire dual-port), Q2 (schéma), instanciation de `dpram`
- [ ] Effacement : Q1 (méthode), implémentation

---

## Annexe : simuler et tester

**Simulation (ModelSim) :** se placer dans le dossier du composant et lancer le script `.do` :
```
cd 3-tp/TP2-Projet_ecran/Encoder   ->  do encoder.do
cd 3-tp/TP2-Projet_ecran/HDMI      ->  do hdmi_controler.do
```

**Test sur carte (Quartus) :**
1. Ouvrir `3-tp/telecran/telecran/telecran.qpf`, puis lancer *Compile Design*.
2. Brancher l'alimentation, le port USB BLASTER II, et le câble HDMI vers l'adaptateur HDMI-USB.
3. *Tools > Programmer* > *Auto Detect* > choisir `5CSEBA6` > *Change File* : `output_files/telecran.sof` > cocher *Program/Configure* > *Start*.
4. Dans VLC : *Media > Open Capture Device* > DirectShow > choisir l'adaptateur.
5. Si VLC affiche « pas de signal », appuyer sur `KEY0`. Le reset relance la configuration I2C de l'ADV7513.
