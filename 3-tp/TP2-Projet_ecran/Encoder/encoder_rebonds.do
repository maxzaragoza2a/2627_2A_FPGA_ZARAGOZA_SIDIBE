# Simulation de l'anti-rebond : encodeur sans filtre vs avec filtre
# Dans ModelSim : cd vers le dossier Encoder, puis "do encoder_rebonds.do"

quit -sim

vlib work
vcom -2008 encoder.vhd
vcom -2008 encoder_rebonds_tb.vhd

vsim work.encoder_rebonds_tb

add wave -divider "Entrees (avec rebonds)"
add wave i_clk
add wave i_rst_n
add wave i_ch_a
add wave i_ch_b

add wave -divider "Sans anti-rebond"
add wave dut_brut/s_a_rise
add wave dut_brut/s_a_fall
add wave -radix unsigned o_value_brut

add wave -divider "Avec anti-rebond"
add wave dut_filtre/r_a_sync
add wave -radix unsigned dut_filtre/r_a_cnt
add wave dut_filtre/r_a_d1
add wave dut_filtre/s_a_rise
add wave dut_filtre/s_a_fall
add wave -radix unsigned o_value_filtre

run -all
wave zoom full
