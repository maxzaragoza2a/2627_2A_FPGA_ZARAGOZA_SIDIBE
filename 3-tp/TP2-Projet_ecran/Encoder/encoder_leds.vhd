library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Top-level de test : affiche la valeur de l'encodeur gauche en barre de LED
-- (0 cran : aucune LED, 1 cran : LED0, 2 crans : LED0 et LED1, ..., 10 crans ou plus : toutes les LED)
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
    signal s_steps : unsigned(9 downto 0);
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

    -- l'encodeur compte +1 par cran : 1 LED par cran
    s_steps <= unsigned(s_value);

    -- la LED i est allumé si le nombre de crans est strictement supérieure à i
    gen_leds : for i in 0 to 9 generate
        o_leds(i) <= '1' when s_steps > i else '0';
    end generate;
end architecture rtl;
