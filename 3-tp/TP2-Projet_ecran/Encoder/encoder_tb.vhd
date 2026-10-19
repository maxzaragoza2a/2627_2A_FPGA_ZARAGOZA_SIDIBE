library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity encoder_tb is
end entity encoder_tb;

architecture tb of encoder_tb is
    constant c_width : natural := 10;
    constant c_clk_period : time := 20 ns;   -- 50 MHz
    constant c_step : time := 200 ns;        -- durée entre deux changements de A ou B

    signal i_clk : std_logic := '0';
    signal i_rst_n : std_logic := '0';
    signal i_ch_a : std_logic := '0';
    signal i_ch_b : std_logic := '0';
    signal o_value : std_logic_vector(c_width-1 downto 0);

    signal s_end : boolean := false;
begin
    dut : entity work.encoder
        generic map (
            g_width => c_width
        )
        port map (
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_ch_a => i_ch_a,
            i_ch_b => i_ch_b,
            o_value => o_value
        );

    i_clk <= not i_clk after c_clk_period/2 when not s_end;

    process
        -- un cycle complet de quadrature, A en avance sur B : 00 -> 10 -> 11 -> 01 -> 00
        procedure turn_right is
        begin
            i_ch_a <= '1'; wait for c_step;
            i_ch_b <= '1'; wait for c_step;
            i_ch_a <= '0'; wait for c_step;
            i_ch_b <= '0'; wait for c_step;
        end procedure;

        -- un cycle complet de quadrature, B en avance sur A : 00 -> 01 -> 11 -> 10 -> 00
        procedure turn_left is
        begin
            i_ch_b <= '1'; wait for c_step;
            i_ch_a <= '1'; wait for c_step;
            i_ch_b <= '0'; wait for c_step;
            i_ch_a <= '0'; wait for c_step;
        end procedure;

        procedure check(expected : natural) is
        begin
            assert to_integer(unsigned(o_value)) = expected
                report "o_value = " & integer'image(to_integer(unsigned(o_value)))
                     & ", attendu " & integer'image(expected)
                severity error;
        end procedure;
    begin
        -- reset
        wait for 5 * c_clk_period;
        i_rst_n <= '1';
        wait for c_step;
        check(0);

        -- 4 cycles à droite : +2 par cycle
        for i in 1 to 4 loop
            turn_right;
        end loop;
        check(8);

        -- pas de mouvement : la valeur ne change pas
        wait for 5 * c_step;
        check(8);

        -- 5 cycles à gauche : -2 par cycle, passage sous 0 -> 1022
        for i in 1 to 5 loop
            turn_left;
        end loop;
        check(2**c_width - 2);

        -- reset en cours de fonctionnement
        i_rst_n <= '0';
        wait for 2 * c_clk_period;
        check(0);
        i_rst_n <= '1';
        wait for c_step;

        report "Fin de la simulation";
        s_end <= true;
        wait;
    end process;
end architecture tb;
