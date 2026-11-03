library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Verifie l'alignement entre la lecture du framebuffer (port B de la dpram)
-- et le signal o_hdmi_de du controleur HDMI.
-- Resolution reduite (16 x 8) pour une simulation rapide.
-- On ecrit 3 pixels par le port A, puis on reconstruit l'image vue par
-- l'ecran (les pixels ou DE = 1) et on verifie que seuls ces 3 pixels
-- sont blancs, exactement a leur position.
entity memorisation_tb is
end entity memorisation_tb;

architecture tb of memorisation_tb is
    constant c_h_res : positive := 16;
    constant c_v_res : positive := 8;
    constant c_clk_period : time := 37 ns;  -- ~27 MHz

    signal clk : std_logic := '0';
    signal rst_n : std_logic := '0';

    signal hs, vs, de : std_logic;
    signal rd_addr : natural range 0 to c_h_res * c_v_res - 1;
    signal rd_data : std_logic_vector(0 downto 0);

    signal wr_addr : natural range 0 to c_h_res * c_v_res - 1 := 0;
    signal wr_data : std_logic_vector(0 downto 0) := "0";
    signal we : std_logic := '0';

    signal s_end : boolean := false;

    -- Pixels dessines (x, y) : un au milieu et deux dans les coins,
    -- pour tester les bords x = 0 et x = h_res - 1
    type t_int_array is array (0 to 2) of natural;
    constant c_x : t_int_array := (5, 0, c_h_res - 1);
    constant c_y : t_int_array := (3, 0, c_v_res - 1);

    function is_drawn(x, y : natural) return boolean is
    begin
        for i in c_x'range loop
            if (x = c_x(i)) and (y = c_y(i)) then
                return true;
            end if;
        end loop;
        return false;
    end function;
begin
    hdmi : entity work.hdmi_controler
        generic map (
            h_res => c_h_res, v_res => c_v_res,
            h_sync => 4, h_fp => 4, h_bp => 2,
            v_sync => 2, v_fp => 2, v_bp => 1
        )
        port map (
            i_clk => clk,
            i_rst_n => rst_n,
            o_hdmi_hs => hs,
            o_hdmi_vs => vs,
            o_hdmi_de => de,
            o_pixel_en => open,
            o_pixel_address => rd_addr,
            o_x_counter => open,
            o_y_counter => open
        );

    ram : entity work.dpram
        generic map (
            mem_size => c_h_res * c_v_res,
            data_width => 1
        )
        port map (
            i_clk_a => clk,
            i_addr_a => wr_addr,
            i_data_a => wr_data,
            i_we_a => we,
            o_q_a => open,
            i_clk_b => clk,
            i_addr_b => rd_addr,
            i_data_b => "0",
            i_we_b => '0',
            o_q_b => rd_data
        );

    clk <= not clk after c_clk_period / 2 when not s_end;

    p_main : process
        variable col, row : integer := 0;
        variable in_line : boolean := false;
        variable expected : std_logic;
        variable n_pixels, n_white, n_errors : natural := 0;
        variable frames : natural := 0;
        variable prev_vs : std_logic := '1';
    begin
        -- 1) Remise a 0 de toute la memoire (en simulation elle demarre a 'U' ;
        --    sur FPGA, les blocs M10K demarrent a 0)
        wait until rising_edge(clk);
        we <= '1';
        wr_data <= "0";
        for a in 0 to c_h_res * c_v_res - 1 loop
            wr_addr <= a;
            wait until rising_edge(clk);
        end loop;

        -- 2) Dessin des 3 pixels, adresse = x + y * h_res (comme dans telecran.vhd)
        wr_data <= "1";
        for i in c_x'range loop
            wr_addr <= c_x(i) + c_y(i) * c_h_res;
            wait until rising_edge(clk);
        end loop;
        we <= '0';
        wait until rising_edge(clk);

        -- 3) Demarrage du controleur et controle d'une image complete (la 2e)
        rst_n <= '1';
        while frames < 3 loop
            wait until rising_edge(clk);

            -- Debut d'image : front descendant de VS
            if (prev_vs = '1') and (vs = '0') then
                frames := frames + 1;
                row := 0;
            end if;
            prev_vs := vs;

            -- On ne compte qu'a partir de la 2e image (la 1re demarre apres le reset)
            if frames >= 2 then
                if de = '1' then
                    if not in_line then
                        in_line := true;
                        col := 0;
                    end if;
                    if is_drawn(col, row) then expected := '1'; else expected := '0'; end if;
                    if rd_data(0) /= expected then
                        n_errors := n_errors + 1;
                        report "Erreur au pixel (" & integer'image(col) & ", " & integer'image(row)
                             & ") : lu " & std_logic'image(rd_data(0))
                             & ", attendu " & std_logic'image(expected) severity error;
                    end if;
                    if rd_data(0) = '1' then n_white := n_white + 1; end if;
                    n_pixels := n_pixels + 1;
                    col := col + 1;
                elsif in_line then
                    in_line := false;
                    row := row + 1;
                end if;
            end if;
        end loop;

        report "Pixels affiches : " & integer'image(n_pixels)
             & " (attendu " & integer'image(c_h_res * c_v_res) & ")"
             & ", pixels blancs : " & integer'image(n_white) & " (attendu 3)"
             & ", erreurs : " & integer'image(n_errors);
        assert n_pixels = c_h_res * c_v_res report "Nombre de pixels incorrect" severity error;
        assert n_white = 3 report "Nombre de pixels blancs incorrect" severity error;
        report "Fin de la simulation";
        s_end <= true;
        wait;
    end process;
end architecture tb;
