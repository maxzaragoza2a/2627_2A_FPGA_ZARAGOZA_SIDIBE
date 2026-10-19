# Simulation de l'encodeur
# Dans ModelSim : cd vers le dossier Encoder, puis "do encoder.do"

vlib work
vcom -2008 encoder.vhd
vcom -2008 encoder_tb.vhd

vsim work.encoder_tb

add wave -divider "Entrées"
add wave i_clk
add wave i_rst_n
add wave i_ch_a
add wave i_ch_b

add wave -divider "Détecteur de fronts"
add wave dut/r_a_d1
add wave dut/r_a_d2
add wave dut/s_a_rise
add wave dut/s_a_fall
add wave dut/r_b_d1
add wave dut/r_b_d2
add wave dut/s_b_rise
add wave dut/s_b_fall

add wave -divider "Sortie"
add wave -radix unsigned o_value

run -all
wave zoom full
