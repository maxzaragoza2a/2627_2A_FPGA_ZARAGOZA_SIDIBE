library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Top-level de test : affiche la valeur de l'encodeur gauche en barre de LED
-- (valeur 0 : aucune LED, 1 : LED0, 2 : LED0 et LED1, ..., 10 ou plus : toutes les LED)
entity encoder_leds is
    port (
        i_clk_50 : in std_logic;
        i_rst_n : in std_logic;
        i_left_ch_a : in std_logic;
        i_left_ch_b : in std_logic;
        o_leds : out std_logic_vector(9 downto 0)
    );
end entity encoder_leds;

architecture rtl of encoder_leds is
    signal s_value : std_logic_vector(9 downto 0);
begin
    encoder0 : entity work.encoder
        generic map (
            g_width => 10
        )
        port map (
            i_clk => i_clk_50,
            i_rst_n => i_rst_n,
            i_ch_a => i_left_ch_a,
            i_ch_b => i_left_ch_b,
            o_value => s_value
        );

    -- la LED i est allumée si la valeur est strictement supérieure à i
    gen_leds : for i in 0 to 9 generate
        o_leds(i) <= '1' when unsigned(s_value) > i else '0';
    end generate;
end architecture rtl;
