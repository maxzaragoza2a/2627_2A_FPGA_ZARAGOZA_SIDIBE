library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity encoder is
    generic (
        g_width : natural := 10;
        -- g_saturate = false : la valeur reboucle (0 -> 2**g_width-1 et inversement)
        -- g_saturate = true  : la valeur reste bloquee entre 0 et g_max
        g_saturate : boolean := false;
        g_max : natural := 1023;
        -- Anti-rebond : un changement de A ou B n'est pris en compte que s'il
        -- reste stable pendant g_debounce cycles d'horloge (0 = pas de filtre)
        g_debounce : natural := 0;
        -- g_full_decode = false : regle de l'enonce (seuls les fronts de A
        --   incrementent et seuls les fronts de B decrementent)
        -- g_full_decode = true  : decodage complet des 8 transitions (+1 ou -1
        --   chacune). Une oscillation sur une seule voie s'annule au lieu de
        --   s'accumuler.
        g_full_decode : boolean := false;
        -- Sensibilite en mode complet : la sortie avance de 1 toutes les
        -- 2**g_div_log2 transitions (un cycle de quadrature = 4 transitions).
        --   g_div_log2 = 1 : 2 pas par cycle (meme vitesse que l'enonce)
        --   g_div_log2 = 2 : 1 pas par cycle
        --   g_div_log2 = 3 : 1 pas tous les 2 cycles
        g_div_log2 : natural := 1
    );
    port (
        i_clk : in std_logic;
        i_rst_n : in std_logic;
        i_ch_a : in std_logic;
        i_ch_b : in std_logic;
        o_value : out std_logic_vector(g_width-1 downto 0)
    );
end entity encoder;

architecture rtl of encoder is

    -- Synchroniseur 2 bascules (les voies A et B sont asynchrones)
    signal r_a_meta : std_logic := '0';
    signal r_a_sync : std_logic := '0';
    signal r_b_meta : std_logic := '0';
    signal r_b_sync : std_logic := '0';

    -- Compteurs de stabilite de l'anti-rebond
    signal r_a_cnt : natural range 0 to g_debounce := 0;
    signal r_b_cnt : natural range 0 to g_debounce := 0;

    -- Detecteur de fronts : d1 = valeur filtree, d2 = valeur filtree au cycle precedent
    signal r_a_d1 : std_logic := '0';
    signal r_a_d2 : std_logic := '0';
    signal r_b_d1 : std_logic := '0';
    signal r_b_d2 : std_logic := '0';

    signal s_a_rise : std_logic;
    signal s_a_fall : std_logic;
    signal s_b_rise : std_logic;
    signal s_b_fall : std_logic;

    signal r_value : unsigned(g_width-1 downto 0) := (others => '0');

    -- Decodage complet : position au quart de cycle (g_div_log2 bits de plus
    -- que la sortie). Elle demarre et reste au MILIEU d'un pas de sortie :
    -- une petite oscillation autour d'une position de repos ne fait donc pas
    -- changer la sortie.
    constant c_div : natural := 2**g_div_log2;
    constant c_pos_min : natural := c_div / 2;                -- sortie = 0
    constant c_pos_max : natural := g_max * c_div + c_div / 2; -- sortie = g_max

    signal s_a_edge : std_logic;
    signal s_b_edge : std_logic;
    signal s_up : std_logic;
    signal r_pos : unsigned(g_width + g_div_log2 - 1 downto 0) := to_unsigned(c_pos_min, g_width + g_div_log2);
begin

    -- Synchronisation, anti-rebond, puis memorisation pour la detection de fronts
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_a_meta <= '0';
            r_a_sync <= '0';
            r_b_meta <= '0';
            r_b_sync <= '0';
            r_a_cnt <= 0;
            r_b_cnt <= 0;
            r_a_d1 <= '0';
            r_a_d2 <= '0';
            r_b_d1 <= '0';
            r_b_d2 <= '0';
        elsif (rising_edge(i_clk)) then
            r_a_meta <= i_ch_a;
            r_a_sync <= r_a_meta;
            r_b_meta <= i_ch_b;
            r_b_sync <= r_b_meta;

            -- Voie A : la valeur filtree ne change que si l'entree est restee
            -- differente pendant g_debounce cycles. Un rebond remet le compteur a 0.
            if (r_a_sync = r_a_d1) then
                r_a_cnt <= 0;
            elsif (r_a_cnt = g_debounce) then
                r_a_d1 <= r_a_sync;
                r_a_cnt <= 0;
            else
                r_a_cnt <= r_a_cnt + 1;
            end if;

            -- Voie B : meme principe
            if (r_b_sync = r_b_d1) then
                r_b_cnt <= 0;
            elsif (r_b_cnt = g_debounce) then
                r_b_d1 <= r_b_sync;
                r_b_cnt <= 0;
            else
                r_b_cnt <= r_b_cnt + 1;
            end if;

            r_a_d2 <= r_a_d1;
            r_b_d2 <= r_b_d1;
        end if;
    end process;

    s_a_rise <= r_a_d1 and not r_a_d2;
    s_a_fall <= not r_a_d1 and r_a_d2;
    s_b_rise <= r_b_d1 and not r_b_d2;
    s_b_fall <= not r_b_d1 and r_b_d2;

    -- Regle de l'enonce
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_value <= (others => '0');
        elsif (rising_edge(i_clk)) then
            if ((s_a_rise = '1' and r_b_d1 = '0') or (s_a_fall = '1' and r_b_d1 = '1')) then
                if (not g_saturate) or (r_value < g_max) then
                    r_value <= r_value + 1;
                end if;
            elsif ((s_b_rise = '1' and r_a_d1 = '0') or (s_b_fall = '1' and r_a_d1 = '1')) then
                if (not g_saturate) or (r_value > 0) then
                    r_value <= r_value - 1;
                end if;
            end if;
        end if;
    end process;

    -- Decodage complet. Sens d'une transition (A en avance = +1) :
    --   seule A change : +1 si A /= B apres le changement, -1 sinon
    --   seule B change : +1 si A =  B apres le changement, -1 sinon
    -- Si A et B changent en meme temps (transition impossible), on ignore.
    s_a_edge <= s_a_rise or s_a_fall;
    s_b_edge <= s_b_rise or s_b_fall;
    s_up <= (r_a_d1 xor r_b_d1) when s_a_edge = '1' else not (r_a_d1 xor r_b_d1);

    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_pos <= to_unsigned(c_pos_min, r_pos'length);
        elsif (rising_edge(i_clk)) then
            if (s_a_edge xor s_b_edge) = '1' then
                if s_up = '1' then
                    if (not g_saturate) or (r_pos < c_pos_max) then
                        r_pos <= r_pos + 1;
                    end if;
                else
                    if (not g_saturate) or (r_pos > c_pos_min) then
                        r_pos <= r_pos - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Sortie : position divisee par 2**g_div_log2 en mode complet
    o_value <= std_logic_vector(r_pos(r_pos'high downto g_div_log2)) when g_full_decode
               else std_logic_vector(r_value);
end architecture rtl;
