library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Controle du port A du framebuffer : dessin ou effacement.
--
-- Machine d'etat a 2 etats :
--   ST_CLEAR : ecrit '0' a toutes les adresses, une par cycle (0 -> g_mem_size-1),
--              puis passe en ST_DRAW
--   ST_DRAW  : ecrit '1' a l'adresse du stylet (i_draw_addr)
--
-- L'effacement demarre :
--   - au reset (i_rst_n = '0') : l'etat initial est ST_CLEAR
--   - a l'appui sur le bouton i_pb_n (actif bas, '1' au repos)
--
-- Le bouton est synchronise (2 bascules), filtre contre les rebonds
-- (stable pendant g_debounce cycles), puis on detecte son front
-- descendant : un appui = un seul effacement, meme si on reste appuye.
entity effacement is
    generic (
        g_mem_size : natural := 720 * 480;
        g_debounce : natural := 27_000      -- 1 ms a 27 MHz
    );
    port (
        i_clk : in std_logic;
        i_rst_n : in std_logic;
        i_pb_n : in std_logic;

        -- Adresse du stylet (mode dessin)
        i_draw_addr : in natural range 0 to g_mem_size - 1;

        -- Vers le port A du framebuffer
        o_addr : out natural range 0 to g_mem_size - 1;
        o_data : out std_logic_vector(0 downto 0);
        o_busy : out std_logic                  -- '1' pendant l'effacement
    );
end entity effacement;

architecture rtl of effacement is
    type t_state is (ST_CLEAR, ST_DRAW);
    signal r_state : t_state := ST_CLEAR;

    signal r_clr_addr : natural range 0 to g_mem_size - 1 := 0;

    -- Bouton : synchronisation, anti-rebond, detection de front
    signal r_pb_meta : std_logic := '1';
    signal r_pb_sync : std_logic := '1';
    signal r_pb_cnt : natural range 0 to g_debounce := 0;
    signal r_pb_d1 : std_logic := '1';     -- valeur filtree
    signal r_pb_d2 : std_logic := '1';     -- valeur filtree au cycle precedent
    signal s_pb_press : std_logic;
begin
    -- Bouton
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_pb_meta <= '1';
            r_pb_sync <= '1';
            r_pb_cnt <= 0;
            r_pb_d1 <= '1';
            r_pb_d2 <= '1';
        elsif rising_edge(i_clk) then
            r_pb_meta <= i_pb_n;
            r_pb_sync <= r_pb_meta;

            if (r_pb_sync = r_pb_d1) then
                r_pb_cnt <= 0;
            elsif (r_pb_cnt = g_debounce) then
                r_pb_d1 <= r_pb_sync;
                r_pb_cnt <= 0;
            else
                r_pb_cnt <= r_pb_cnt + 1;
            end if;

            r_pb_d2 <= r_pb_d1;
        end if;
    end process;

    -- Appui = front descendant (actif bas)
    s_pb_press <= r_pb_d2 and not r_pb_d1;

    -- Machine d'etat
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_state <= ST_CLEAR;
            r_clr_addr <= 0;
        elsif rising_edge(i_clk) then
            case r_state is
                when ST_CLEAR =>
                    if (r_clr_addr = g_mem_size - 1) then
                        r_clr_addr <= 0;
                        r_state <= ST_DRAW;
                    else
                        r_clr_addr <= r_clr_addr + 1;
                    end if;

                when ST_DRAW =>
                    if (s_pb_press = '1') then
                        r_clr_addr <= 0;
                        r_state <= ST_CLEAR;
                    end if;
            end case;
        end if;
    end process;

    -- Multiplexeur du port A
    o_addr <= r_clr_addr when r_state = ST_CLEAR else i_draw_addr;
    o_data <= "0" when r_state = ST_CLEAR else "1";
    o_busy <= '1' when r_state = ST_CLEAR else '0';
end architecture rtl;
