library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library pll;
use pll.all;

entity telecran is
    port (
        i_clk_50: in std_logic;
        io_hdmi_i2c_scl       : inout std_logic;
        io_hdmi_i2c_sda       : inout std_logic;
        o_hdmi_tx_clk         : out std_logic;
        o_hdmi_tx_d           : out std_logic_vector(23 downto 0);
        o_hdmi_tx_de          : out std_logic;
        o_hdmi_tx_hs          : out std_logic;
        i_hdmi_tx_int         : in std_logic;
        o_hdmi_tx_vs          : out std_logic;
        i_rst_n : in std_logic;
        o_leds : out std_logic_vector(9 downto 0);
        o_de10_leds : out std_logic_vector(7 downto 0);
        i_left_ch_a : in std_logic;
        i_left_ch_b : in std_logic;
        i_left_pb : in std_logic;
        i_right_ch_a : in std_logic;
        i_right_ch_b : in std_logic;
        i_right_pb : in std_logic
    );
end entity telecran;

architecture rtl of telecran is
    component I2C_HDMI_Config 
        port (
            iCLK : in std_logic;
            iRST_N : in std_logic;
            I2C_SCLK : out std_logic;
            I2C_SDAT : inout std_logic;
            HDMI_TX_INT  : in std_logic
        );
     end component;

    component hdmi_controler
        generic (
            h_res : positive := 720;
            v_res : positive := 480;
            h_sync : positive := 61;
            h_fp : positive := 58;
            h_bp : positive := 18;
            v_sync : positive := 5;
            v_fp : positive := 30;
            v_bp : positive := 9
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
    end component;

    component pll
        port (
            refclk : in std_logic;
            rst : in std_logic;
            outclk_0 : out std_logic;
            locked : out std_logic
        );
    end component;

    constant h_res : natural := 720;
    constant v_res : natural := 480;

    constant c_debounce : natural := 27_000;
    constant c_div_log2 : natural := 2;

    signal s_clk_27 : std_logic;
    signal s_rst_n : std_logic;

    signal s_enc_x : std_logic_vector(9 downto 0);
    signal s_enc_y : std_logic_vector(9 downto 0);

    signal s_wr_addr : natural range 0 to h_res * v_res - 1;
    signal s_rd_addr : natural range 0 to h_res * v_res - 1;
    signal s_rd_data : std_logic_vector(0 downto 0);

    signal s_a_addr : natural range 0 to h_res * v_res - 1;
    signal s_a_data : std_logic_vector(0 downto 0);
begin
    o_leds <= s_enc_x;
    o_de10_leds <= s_enc_y(7 downto 0);
    
    pll0 : component pll 
        port map (
            refclk => i_clk_50,
            rst => not(i_rst_n),
            outclk_0 => s_clk_27,
            locked => s_rst_n
        );

    I2C_HDMI_Config0 : component I2C_HDMI_Config 
        port map (
            iCLK => i_clk_50,
            iRST_N => i_rst_n,
            I2C_SCLK => io_hdmi_i2c_scl,
            I2C_SDAT => io_hdmi_i2c_sda,
            HDMI_TX_INT => i_hdmi_tx_int
     );

    hdmi_controler0 : component hdmi_controler
        generic map (
            h_res => h_res,
            v_res => v_res
        )
        port map (
            i_clk => s_clk_27,
            i_rst_n => s_rst_n,
            o_hdmi_hs => o_hdmi_tx_hs,
            o_hdmi_vs => o_hdmi_tx_vs,
            o_hdmi_de => o_hdmi_tx_de,
            o_pixel_en => open,
            o_pixel_address => s_rd_addr,
            o_x_counter => open,
            o_y_counter => open
        );

    o_hdmi_tx_clk <= s_clk_27;

    encoder_x : entity work.encoder
        generic map (
            g_width => 10,
            g_saturate => true,
            g_debounce => c_debounce,
            g_full_decode => true,
            g_div_log2 => c_div_log2,
            g_max => h_res - 1
        )
        port map (
            i_clk => s_clk_27,
            i_rst_n => s_rst_n,
            i_ch_a => i_left_ch_a,
            i_ch_b => i_left_ch_b,
            o_value => s_enc_x
        );

    encoder_y : entity work.encoder
        generic map (
            g_width => 10,
            g_saturate => true,
            g_debounce => c_debounce,
            g_full_decode => true,
            g_div_log2 => c_div_log2,
            g_max => v_res - 1
        )
        port map (
            i_clk => s_clk_27,
            i_rst_n => s_rst_n,
            i_ch_a => i_right_ch_a,
            i_ch_b => i_right_ch_b,
            o_value => s_enc_y
        );

    s_wr_addr <= to_integer(unsigned(s_enc_x)) + to_integer(unsigned(s_enc_y)) * h_res;

    effacement0 : entity work.effacement
        generic map (
            g_mem_size => h_res * v_res,
            g_debounce => c_debounce
        )
        port map (
            i_clk => s_clk_27,
            i_rst_n => s_rst_n,
            i_pb_n => i_left_pb,
            i_draw_addr => s_wr_addr,
            o_addr => s_a_addr,
            o_data => s_a_data,
            o_busy => open
        );

    -- DPRAM compatible avec la version générée par Quartus IP Catalog
    framebuffer : entity work.dpram
        port map (
            clock => s_clk_27,
            wraddress => std_logic_vector(to_unsigned(s_a_addr, 19)),
            data => s_a_data,
            wren => '1',
            rdaddress => std_logic_vector(to_unsigned(s_rd_addr, 19)),
            q => s_rd_data
        );

    o_hdmi_tx_d <= (others => s_rd_data(0));
end architecture rtl;