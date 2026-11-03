# Comparaison regle de l'enonce / decodage complet (encodeur immobile qui oscille)
# Dans ModelSim : cd vers le dossier Encoder, puis "do encoder_vibration.do"

quit -sim

vlib work
vcom -2008 encoder.vhd
vcom -2008 encoder_vibration_tb.vhd

vsim work.encoder_vibration_tb

add wave -divider "Entrees"
add wave i_clk
add wave i_rst_n
add wave i_ch_a
add wave i_ch_b

add wave -divider "Regle de l'enonce"
add wave -radix unsigned o_value_enonce

add wave -divider "Decodage complet"
add wave -radix unsigned dut_complet/r_pos
add wave -radix unsigned o_value_complet

add wave -divider "Decodage complet avec saturation (max = 5)"
add wave -radix unsigned o_value_sat

add wave -divider "Decodage complet, 1 pas par cycle (g_div_log2 = 2)"
add wave -radix unsigned dut_lent/r_pos
add wave -radix unsigned o_value_lent

run -all
wave zoom full
