library ieee;
use ieee.std_logic_1164.all;

entity led_blink_chenillard is
    port (
        i_clk : in std_logic;
        i_rst_n : in std_logic;
        o_led : out std_logic_vector(9 downto 0)
    );
end entity led_blink_chenillard;

architecture rtl of led_blink_chenillard is
    signal r_led : std_logic_vector(9 downto 0) := "0000000011";
    signal r_led_enable : std_logic := '0';
begin
    --- compteur : génère une impulsion r_led_enable d'un cycle toutes les 5 000 001 périodes d'horloge (~10 Hz à 50 MHz)
    process(i_clk, i_rst_n)
        variable counter : natural range 0 to 5000000 := 0;
    begin
        if (i_rst_n = '0') then
            counter := 0;
            r_led_enable <= '0';
        elsif (rising_edge(i_clk)) then
            if (counter = 5000000) then
                counter := 0;
                r_led_enable <= '1';
            else
                counter := counter + 1;
                r_led_enable <= '0';
            end if;
        end if;
    end process;

    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_led <= "0000000011";
        elsif (rising_edge(i_clk)) then
            if (r_led_enable = '1') then
                r_led <= r_led(7 downto 0) & r_led(9 downto 8);
            end if;
        end if;
    end process; 

    o_led <= r_led;
end architecture rtl;
