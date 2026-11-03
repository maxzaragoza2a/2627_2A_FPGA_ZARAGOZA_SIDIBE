# Simulation de l'effacement (composant effacement + dpram de 32 cases)
# Dans ModelSim : cd vers le dossier Effacement, puis "do effacement.do"

quit -sim

vlib work
vcom -2008 ../../telecran/telecran/dpram.vhd
vcom -2008 effacement.vhd
vcom -2008 effacement_tb.vhd

vsim work.effacement_tb

add wave -divider "Entrees"
add wave clk
add wave rst_n
add wave pb_n
add wave -radix unsigned draw_addr

add wave -divider "Bouton (anti-rebond + front)"
add wave dut/r_pb_sync
add wave -radix unsigned dut/r_pb_cnt
add wave dut/r_pb_d1
add wave dut/s_pb_press

add wave -divider "Machine d'etat"
add wave dut/r_state
add wave -radix unsigned dut/r_clr_addr
add wave busy

add wave -divider "Port A de la RAM"
add wave -radix unsigned addr_a
add wave data_a

add wave -divider "Lecture de controle (port B)"
add wave -radix unsigned addr_b
add wave q_b

run -all
wave zoom full
