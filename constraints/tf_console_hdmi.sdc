create_clock -name sys_clk -period 20 [get_ports {sys_clk}]
derive_clocks
set_false_path -from [get_ports {sys_rst_n}]
