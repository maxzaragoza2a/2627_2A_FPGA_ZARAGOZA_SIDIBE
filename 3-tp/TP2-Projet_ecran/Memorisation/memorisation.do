# Simulation de l'alignement framebuffer / controleur HDMI
# Dans ModelSim : cd vers le dossier Memorisation, puis "do memorisation.do"

quit -sim

vlib work
vcom -2008 ../../telecran/telecran/hdmi_controler.vhd
vcom -2008 ../../telecran/telecran/dpram.vhd
vcom -2008 memorisation_tb.vhd

vsim work.memorisation_tb

add wave -divider "Ecriture (port A)"
add wave clk
add wave we
add wave -radix unsigned wr_addr
add wave wr_data

add wave -divider "Controleur HDMI"
add wave rst_n
add wave hs
add wave vs
add wave de
add wave -radix unsigned hdmi/o_x_counter
add wave -radix unsigned hdmi/o_y_counter

add wave -divider "Lecture (port B)"
add wave -radix unsigned rd_addr
add wave rd_data

run -all
wave zoom full
