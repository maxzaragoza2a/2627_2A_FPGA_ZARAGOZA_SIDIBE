library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity encoder is
    generic (
        g_width : natural := 10
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
    
    signal r_a_d1 : std_logic := '0';
    signal r_a_d2 : std_logic := '0';
    signal r_b_d1 : std_logic := '0';
    signal r_b_d2 : std_logic := '0';

    signal s_a_rise : std_logic;
    signal s_a_fall : std_logic;
    signal s_b_rise : std_logic;
    signal s_b_fall : std_logic;

    signal r_value : unsigned(g_width-1 downto 0) := (others => '0');
begin
    
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_a_d1 <= '0';
            r_a_d2 <= '0';
            r_b_d1 <= '0';
            r_b_d2 <= '0';
        elsif (rising_edge(i_clk)) then
            r_a_d1 <= i_ch_a;
            r_a_d2 <= r_a_d1;
            r_b_d1 <= i_ch_b;
            r_b_d2 <= r_b_d1;
        end if;
    end process;

    s_a_rise <= r_a_d1 and not r_a_d2;
    s_a_fall <= not r_a_d1 and r_a_d2;
    s_b_rise <= r_b_d1 and not r_b_d2;
    s_b_fall <= not r_b_d1 and r_b_d2;

    
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_value <= (others => '0');
        elsif (rising_edge(i_clk)) then
            if ((s_a_rise = '1' and r_b_d1 = '0') or (s_a_fall = '1' and r_b_d1 = '1')) then
                r_value <= r_value + 1;
            elsif ((s_b_rise = '1' and r_a_d1 = '0') or (s_b_fall = '1' and r_a_d1 = '1')) then
                r_value <= r_value - 1;
            end if;
        end if;
    end process;

    o_value <= std_logic_vector(r_value);
end architecture rtl;
