library ieee;
use ieee.std_logic_1164.all;


entity hdmi_controler is
    generic (
        h_res : natural := 720;
        v_res : natural := 480;

        h_fp : natural := 16;
        h_sync : natural := 62;
        h_bp : natural := 60;

        v_fp : natural := 9;
        v_sync : natural := 6;
        v_bp : natural := 30
    );
    port (
        i_clk : in std_logic;
        i_rst_n : in std_logic;

        o_hdmi_hs : out std_logic;
        o_hdmi_vs : out std_logic;
        o_hdmi_de : out std_logic;

        o_pixel_en : out std_logic;
        o_pixel_address : out natural range 0 to h_res * v_res - 1;
        o_x_counter : out natural range 0 to h_res - 1;
        o_y_counter : out natural range 0 to v_res - 1
    );
end entity hdmi_controler;

architecture rtl of hdmi_controler is
    constant h_total : natural := h_res + h_fp + h_sync + h_bp;   -- 858
    constant v_total : natural := v_res + v_fp + v_sync + v_bp;   -- 525

    signal r_h_count : natural range 0 to h_total - 1 := 0;
    signal r_v_count : natural range 0 to v_total - 1 := 0;

    signal s_h_active : std_logic;
    signal s_v_active : std_logic;
    signal s_active : std_logic;
begin
    --- compteurs horizontal et vertical
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_h_count <= 0;
            r_v_count <= 0;
        elsif (rising_edge(i_clk)) then
            if (r_h_count = h_total - 1) then
                r_h_count <= 0;
                if (r_v_count = v_total - 1) then
                    r_v_count <= 0;
                else
                    r_v_count <= r_v_count + 1;
                end if;
            else
                r_h_count <= r_h_count + 1;
            end if;
        end if;
    end process;

    --- zones actives
    s_h_active <= '1' when r_h_count < h_res else '0';
    s_v_active <= '1' when r_v_count < v_res else '0';
    s_active <= s_h_active and s_v_active;

    --- synchronisations, actives à l'état bas
    o_hdmi_hs <= '0' when (r_h_count >= h_res + h_fp) and (r_h_count < h_res + h_fp + h_sync) else '1';
    o_hdmi_vs <= '0' when (r_v_count >= v_res + v_fp) and (r_v_count < v_res + v_fp + v_sync) else '1';
    o_hdmi_de <= s_active;

    --- coordonnées du pixel courant (maintenues à 0 hors de la zone active)
    o_pixel_en <= s_active;
    o_x_counter <= r_h_count when r_h_count < h_res else 0;
    o_y_counter <= r_v_count when r_v_count < v_res else 0;
    o_pixel_address <= r_v_count * h_res + r_h_count when (r_h_count < h_res) and (r_v_count < v_res) else 0;
end architecture rtl;
