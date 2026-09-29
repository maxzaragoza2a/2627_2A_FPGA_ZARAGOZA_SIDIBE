# Document réponse

### faire clignoter une led

D'après la documentation l'horloge FPGA_CLK1_50 est connecté sur le PIN_V11. 

_n signifie que i_rst_n est actif à l'état bas : le reset agit quand i_rst_n = '0'. Ce choix a deux raisons :
- Le matériel : KEY0 est câblé avec une résistance de pull-up. Il vaut '1' au repos et '0' quand on appuie, donc l'appui déclenche directement le reset.
- La fiabilité : si le fil est débranché, la pull-up maintient le signal à '1' et le circuit n'est pas bloqué en reset. C'est aussi la convention habituelle, qui permet de relier plusieurs sources de reset sur le même fil.


