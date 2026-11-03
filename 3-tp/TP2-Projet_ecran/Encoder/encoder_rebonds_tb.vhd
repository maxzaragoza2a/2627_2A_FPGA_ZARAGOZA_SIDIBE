library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Comparaison de deux encodeurs recevant les mêmes signaux A/B avec rebonds :
--   dut_brut   : sans anti-rebond (g_debounce = 0)
--   dut_filtre : avec anti-rebond (g_debounce = c_debounce)
entity encoder_rebonds_tb is
end entity encoder_rebonds_tb;

architecture tb of encoder_rebonds_tb is
    constant c_width : natural := 10;
    constant c_clk_period : time := 20 ns;      -- 50 MHz
    constant c_debounce : natural := 50;        -- 50 cycles = 1 us
    constant c_bounce : time := 120 ns;         -- durée d'un rebond (< 1 us)
    constant c_stable : time := 5 us;           -- palier stable entre deux fronts

    signal i_clk : std_logic := '0';
    signal i_rst_n : std_logic := '0';
    signal i_ch_a : std_logic := '0';
    signal i_ch_b : std_logic := '0';
    signal o_value_brut : std_logic_vector(c_width-1 downto 0);
    signal o_value_filtre : std_logic_vector(c_width-1 downto 0);

    signal s_end : boolean := false;
begin
    dut_brut : entity work.encoder
        generic map (
            g_width => c_width,
            g_debounce => 0
        )
        port map (
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_ch_a => i_ch_a,
            i_ch_b => i_ch_b,
            o_value => o_value_brut
        );

    dut_filtre : entity work.encoder
        generic map (
            g_width => c_width,
            g_debounce => c_debounce
        )
        port map (
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_ch_a => i_ch_a,
            i_ch_b => i_ch_b,
            o_value => o_value_filtre
        );

    i_clk <= not i_clk after c_clk_period/2 when not s_end;

    process
        -- Fait passer un signal à la valeur v avec n rebonds, puis attend le palier stable
        procedure bouncy(signal s : out std_logic; v : std_logic; n : natural) is
        begin
            for i in 1 to n loop
                s <= v;     wait for c_bounce;
                s <= not v; wait for c_bounce;
            end loop;
            s <= v;
            wait for c_stable;
        end procedure;

        -- Cycle de quadrature, A en avance sur B : 00 -> 10 -> 11 -> 01 -> 00
        -- Comme sur un vrai encodeur, les deux voies ne rebondissent pas autant :
        -- 3 rebonds sur A, 1 seul sur B
        procedure turn_right is
        begin
            bouncy(i_ch_a, '1', 3);
            bouncy(i_ch_b, '1', 1);
            bouncy(i_ch_a, '0', 3);
            bouncy(i_ch_b, '0', 1);
        end procedure;

        -- Cycle de quadrature, B en avance sur A : 00 -> 01 -> 11 -> 10 -> 00
        procedure turn_left is
        begin
            bouncy(i_ch_b, '1', 3);
            bouncy(i_ch_a, '1', 1);
            bouncy(i_ch_b, '0', 3);
            bouncy(i_ch_a, '0', 1);
        end procedure;

        procedure show(msg : string) is
        begin
            report msg & " : sans filtre = " & integer'image(to_integer(unsigned(o_value_brut)))
                 & ", avec filtre = " & integer'image(to_integer(unsigned(o_value_filtre)));
        end procedure;
    begin
        wait for 5 * c_clk_period;
        i_rst_n <= '1';
        wait for c_stable;

        -- 4 cycles à droite : on attend +2 par cycle, soit 8
        for i in 1 to 4 loop
            turn_right;
            show("Cycle a droite " & integer'image(i) & " (attendu " & integer'image(2*i) & ")");
        end loop;
        assert to_integer(unsigned(o_value_filtre)) = 8
            report "Filtre : valeur incorrecte apres rotation a droite" severity error;

        -- 4 cycles à gauche : retour à 0
        for i in 1 to 4 loop
            turn_left;
            show("Cycle a gauche " & integer'image(i) & " (attendu " & integer'image(8 - 2*i) & ")");
        end loop;
        assert to_integer(unsigned(o_value_filtre)) = 0
            report "Filtre : valeur incorrecte apres rotation a gauche" severity error;

        report "Fin de la simulation";
        s_end <= true;
        wait;
    end process;
end architecture tb;
