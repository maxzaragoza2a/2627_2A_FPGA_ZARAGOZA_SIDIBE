library ieee;
use ieee.std_logic_1164.all;

entity tuto_fpga is
    port (
        pushl : in std_logic;
        led0 : out std_logic
    );
end entity tuto_fpga;

architecture rtl of tuto_fpga is
begin
    --- pushl etant a l'etat haut de base, on assigne a la led son "inverse" pour qu'elle soit eteinte par defaut
    led0 <= not pushl;  
end architecture rtl;