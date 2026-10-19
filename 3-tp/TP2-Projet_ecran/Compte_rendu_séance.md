# Compte rendu — Projet Écran magique

## Gestion des encodeurs

### Question 2 : détection d'un front montant ou descendant

![Détecteur de front](../figures/edge_detector.png)

Les deux bascules D en série mémorisent A à deux instants successifs : `A_d1` est la valeur actuelle de A (synchronisée sur `clk`) et `A_d2` sa valeur au coup d'horloge précédent. Si les deux diffèrent, A vient de changer : il y a un front.

| `A_d2` | `A_d1` | Détection |
|:---:|:---:|---|
| 0 | 1 | front montant → `E = A_d1 and not A_d2` |
| 1 | 0 | front descendant → `E = not A_d1 and A_d2` |

Le bloc `???` est donc une simple porte logique. `E` vaut 1 pendant une seule période d'horloge et sert d'*enable* pour incrémenter ou décrémenter le registre. En plaçant la même structure sur la voie B, on distingue les deux sens de rotation en combinant le front d'une voie avec le niveau de l'autre.
