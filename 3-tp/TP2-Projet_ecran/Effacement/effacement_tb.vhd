library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Test du composant effacement relie a la vraie dpram (32 cases).
-- On lit tout le contenu de la memoire par le port B pour verifier :
--   1) effacement au reset
--   2) dessin de quelques pixels
--   3) effacement a l'appui sur le bouton (avec rebonds), qui dure g_mem_size cycles
--   4) un appui long ne lance qu'un seul effacement, le relachement non plus
--   5) le stylet redessine apres l'effacement
--   6) effacement par un nouveau reset
entity effacement_tb is
end entity effacement_tb;

architecture tb of effacement_tb is
    constant c_size : natural := 32;
    constant c_debounce : natural := 10;
    constant c_clk_period : time := 37 ns;

    signal clk : std_logic := '0';
    signal rst_n : std_logic := '0';
    signal pb_n : std_logic := '1';
    signal draw_addr : natural range 0 to c_size - 1 := 0;

    signal addr_a : natural range 0 to c_size - 1;
    signal data_a : std_logic_vector(0 downto 0);
    signal busy : std_logic;

    signal addr_b : natural range 0 to c_size - 1 := 0;
    signal q_b : std_logic_vector(0 downto 0);

    signal s_end : boolean := false;
begin
    dut : entity work.effacement
        generic map (g_mem_size => c_size, g_debounce => c_debounce)
        port map (
            i_clk => clk, i_rst_n => rst_n, i_pb_n => pb_n,
            i_draw_addr => draw_addr,
            o_addr => addr_a, o_data => data_a, o_busy => busy
        );

    ram : entity work.dpram
        generic map (mem_size => c_size, data_width => 1)
        port map (
            i_clk_a => clk, i_addr_a => addr_a, i_data_a => data_a, i_we_a => '1', o_q_a => open,
            i_clk_b => clk, i_addr_b => addr_b, i_data_b => "0", i_we_b => '0', o_q_b => q_b
        );

    clk <= not clk after c_clk_period / 2 when not s_end;

    process
        variable n_busy : natural;
        variable n_clears : natural;

        -- Lit toute la memoire par le port B et verifie que les cases a '1'
        -- sont exactement celles de la liste "expected".
        procedure check_mem(msg : string; expected : integer_vector) is
            variable is_expected : boolean;
            variable n_ones : natural := 0;
        begin
            for a in 0 to c_size - 1 loop
                addr_b <= a;
                wait until rising_edge(clk);   -- adresse prise en compte
                wait until rising_edge(clk);   -- donnee disponible (latence 1)
                is_expected := false;
                for i in expected'range loop
                    if expected(i) = a then
                        is_expected := true;
                    end if;
                end loop;
                if q_b(0) = '1' then
                    n_ones := n_ones + 1;
                end if;
                assert (q_b(0) = '1') = is_expected
                    report msg & " : case " & integer'image(a) & " = " & std_logic'image(q_b(0))
                         & ", attendu " & boolean'image(is_expected)
                    severity error;
            end loop;
            report msg & " : " & integer'image(n_ones) & " case(s) a '1' (attendu "
                 & integer'image(expected'length) & ")";
        end procedure;

        procedure draw(a : natural) is
        begin
            draw_addr <= a;
            for i in 1 to 3 loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        procedure wait_cycles(n : natural) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        -- Attend la fin d'un eventuel effacement en comptant sa duree
        procedure wait_clear is
        begin
            n_busy := 0;
            wait until rising_edge(clk);
            while busy = '1' loop
                n_busy := n_busy + 1;
                wait until rising_edge(clk);
            end loop;
        end procedure;
    begin
        -- 1) Reset : la memoire de simulation part a 'U', l'effacement la met a 0
        wait_cycles(3);
        rst_n <= '1';
        wait_clear;
        report "Effacement au reset : " & integer'image(n_busy) & " cycles (attendu " & integer'image(c_size) & ")";
        draw(0);
        check_mem("Apres le reset (stylet en 0)", (0 => 0));

        -- 2) Dessin : stylet en 3, 10, 31
        draw(3); draw(10); draw(31);
        check_mem("Apres le dessin (stylet passe par 0, 3, 10, 31)", (0, 3, 10, 31));

        -- 3) Appui avec rebonds, puis maintenu
        for i in 1 to 3 loop
            pb_n <= '0'; wait_cycles(3);
            pb_n <= '1'; wait_cycles(3);
        end loop;
        pb_n <= '0';
        n_clears := 0;
        for i in 1 to 4 * c_size loop          -- appui long
            wait until rising_edge(clk);
            if busy = '1' then
                wait_clear;
                n_clears := n_clears + 1;
                report "Effacement au bouton : " & integer'image(n_busy + 1) & " cycles";
            end if;
        end loop;

        -- 4) Relachement avec rebonds : ne doit rien declencher
        for i in 1 to 3 loop
            pb_n <= '1'; wait_cycles(3);
            pb_n <= '0'; wait_cycles(3);
        end loop;
        pb_n <= '1';
        for i in 1 to 4 * c_size loop
            wait until rising_edge(clk);
            if busy = '1' then
                n_clears := n_clears + 1;
                wait_clear;
            end if;
        end loop;
        report "Nombre d'effacements pour un appui long avec rebonds : " & integer'image(n_clears) & " (attendu 1)";
        assert n_clears = 1 report "Le bouton a declenche " & integer'image(n_clears) & " effacements" severity error;
        check_mem("Apres l'appui (seule la case du stylet, 31)", (0 => 31));

        -- 5) Le stylet redessine
        draw(7);
        check_mem("Apres un nouveau trait en 7 (cases 31 et 7)", (31, 7));

        -- 6) Nouveau reset. Sur la carte, le meme reset remet les encodeurs
        --    a 0 : le stylet revient en 0 en meme temps.
        rst_n <= '0'; draw_addr <= 0; wait_cycles(2); rst_n <= '1';
        wait_clear;
        draw(0);
        check_mem("Apres un nouveau reset (stylet en 0)", (0 => 0));

        report "Fin de la simulation";
        s_end <= true;
        wait;
    end process;
end architecture tb;
