library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Comparaison de la regle de comptage de l'enonce et du decodage complet.
-- Les deux encodeurs ont le meme anti-rebond et recoivent les memes signaux :
--   1) rotations normales : les deux doivent donner +2 / -2 par cycle
--   2) encodeur immobile, une voie oscille lentement (plus long que le filtre,
--      ce n'est donc pas un rebond) : la valeur ne doit pas bouger
--   3) saturation en mode complet : la valeur reste entre 0 et g_max
--   4) sensibilite reduite (g_div_log2 = 2, 1 pas par cycle) : pendant les
--      oscillations, la valeur ne doit pas varier du tout, meme un instant
entity encoder_vibration_tb is
end entity encoder_vibration_tb;

architecture tb of encoder_vibration_tb is
    constant c_width : natural := 10;
    constant c_clk_period : time := 20 ns;  -- 50 MHz
    constant c_debounce : natural := 50;    -- 50 cycles = 1 us
    constant c_step : time := 5 us;         -- duree d'un etat (>> filtre)
    constant c_max : natural := 5;          -- borne pour le test de saturation

    signal i_clk : std_logic := '0';
    signal i_rst_n : std_logic := '0';
    signal i_ch_a : std_logic := '0';
    signal i_ch_b : std_logic := '0';
    signal o_value_enonce : std_logic_vector(c_width-1 downto 0);
    signal o_value_complet : std_logic_vector(c_width-1 downto 0);
    signal o_value_sat : std_logic_vector(c_width-1 downto 0);
    signal o_value_lent : std_logic_vector(c_width-1 downto 0);

    signal s_end : boolean := false;
begin
    dut_enonce : entity work.encoder
        generic map (g_width => c_width, g_debounce => c_debounce, g_full_decode => false)
        port map (i_clk, i_rst_n, i_ch_a, i_ch_b, o_value_enonce);

    dut_complet : entity work.encoder
        generic map (g_width => c_width, g_debounce => c_debounce, g_full_decode => true)
        port map (i_clk, i_rst_n, i_ch_a, i_ch_b, o_value_complet);

    dut_sat : entity work.encoder
        generic map (g_width => c_width, g_debounce => c_debounce, g_full_decode => true,
                     g_saturate => true, g_max => c_max)
        port map (i_clk, i_rst_n, i_ch_a, i_ch_b, o_value_sat);

    dut_lent : entity work.encoder
        generic map (g_width => c_width, g_debounce => c_debounce, g_full_decode => true,
                     g_div_log2 => 2)
        port map (i_clk, i_rst_n, i_ch_a, i_ch_b, o_value_lent);

    i_clk <= not i_clk after c_clk_period/2 when not s_end;

    process
        procedure turn_right is
        begin
            i_ch_a <= '1'; wait for c_step;
            i_ch_b <= '1'; wait for c_step;
            i_ch_a <= '0'; wait for c_step;
            i_ch_b <= '0'; wait for c_step;
        end procedure;

        procedure turn_left is
        begin
            i_ch_b <= '1'; wait for c_step;
            i_ch_a <= '1'; wait for c_step;
            i_ch_b <= '0'; wait for c_step;
            i_ch_a <= '0'; wait for c_step;
        end procedure;

        impure function val(v : std_logic_vector) return integer is
        begin
            return to_integer(unsigned(v));
        end function;

        procedure show(msg : string) is
        begin
            report msg & " : enonce = " & integer'image(val(o_value_enonce))
                 & ", complet = " & integer'image(val(o_value_complet));
        end procedure;
    begin
        wait for 5 * c_clk_period;
        i_rst_n <= '1';
        wait for c_step;

        -- 1) Rotations normales
        for i in 1 to 4 loop
            turn_right;
        end loop;
        show("4 cycles a droite (attendu 8)");
        assert val(o_value_complet) = 8 report "Complet : rotation a droite incorrecte" severity error;
        report "Sensibilite reduite : 4 cycles a droite -> " & integer'image(val(o_value_lent)) & " (attendu 4)";
        assert val(o_value_lent) = 4 report "Lent : rotation a droite incorrecte" severity error;

        -- 2) Encodeur immobile, A oscille 10 fois (B = 0)
        for i in 1 to 10 loop
            i_ch_a <= '1'; wait for c_step;
            assert val(o_value_lent) = 4 report "Lent : variation pendant l'oscillation de A" severity error;
            i_ch_a <= '0'; wait for c_step;
        end loop;
        show("10 oscillations de A, encodeur immobile (attendu 8)");
        assert val(o_value_complet) = 8 report "Complet : la valeur a derive" severity error;

        -- Pareil sur B (5 oscillations)
        for i in 1 to 5 loop
            i_ch_b <= '1'; wait for c_step;
            assert val(o_value_lent) = 4 report "Lent : variation pendant l'oscillation de B" severity error;
            i_ch_b <= '0'; wait for c_step;
        end loop;
        report "Sensibilite reduite : apres les oscillations -> " & integer'image(val(o_value_lent))
             & " (attendu 4, sans aucune variation pendant les oscillations)";
        show("5 oscillations de B, encodeur immobile (attendu 8)");
        assert val(o_value_complet) = 8 report "Complet : la valeur a derive" severity error;

        -- Retour a gauche
        for i in 1 to 4 loop
            turn_left;
        end loop;
        show("4 cycles a gauche (attendu 0)");
        assert val(o_value_complet) = 0 report "Complet : rotation a gauche incorrecte" severity error;
        assert val(o_value_lent) = 0 report "Lent : rotation a gauche incorrecte" severity error;

        -- 3) Saturation : on part de 0, 2 cycles a gauche puis 6 a droite
        for i in 1 to 2 loop
            turn_left;
        end loop;
        assert val(o_value_sat) = 0 report "Saturation basse incorrecte" severity error;
        for i in 1 to 6 loop
            turn_right;
        end loop;
        assert val(o_value_sat) = c_max report "Saturation haute incorrecte" severity error;
        turn_left;
        assert val(o_value_sat) = c_max - 2 report "Retour apres saturation incorrect" severity error;
        report "Saturation : bloque a 0 puis a " & integer'image(c_max)
             & ", puis " & integer'image(val(o_value_sat)) & " apres un cycle a gauche (attendu "
             & integer'image(c_max - 2) & ")";

        report "Fin de la simulation";
        s_end <= true;
        wait;
    end process;
end architecture tb;
