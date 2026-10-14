if { $RUN_NAME == "v3" } {
    # Clock/reset pins
    set clk_pin CLK
    set rstn_pin RST_N
    # Synthesize at strict frequency
    set clk_period 1.8

    # Derived timing values
    set eighths  [expr {$clk_period / 8.0}]     ;# 0.25 ns
    set quarter  [expr {$clk_period / 4.0}]     ;# 0.50 ns
    set half_period [expr {$clk_period / 2.0}]  ;# 1.00 ns

    # Inputs except clk and reset
    set inputs_no_clk_rstn \
        [remove_from_collection [all_inputs] [get_ports "$clk_pin $rstn_pin"]]

    set_max_fanout 4 $inputs_no_clk_rstn

    # 1. Create real core clock
    create_clock [get_ports $clk_pin] \
        -name core_clk \
        -period $clk_period \
        -waveform "0 $half_period"

    # 2. Input driving cell (1/8 cycle rise/fall)
    set_driving_cell \
        -lib_cell DFFX1 \
        -input_transition_rise $eighths \
        -input_transition_fall $eighths \
        $inputs_no_clk_rstn

    # 3. Output load = 4x NAND2X4/A
    set_load \
        [expr {[load_of [get_lib_pins */NAND2X4/A]] * 4}] \
        [all_outputs]

    # 4. I/O timing (1/4 cycle)
    create_clock -name io_virtual_clk -period $clk_period

    set_input_delay \
        -max $quarter \
        -clock io_virtual_clk \
        -add_delay \
        $inputs_no_clk_rstn

    set_output_delay \
        -max $quarter \
        -clock io_virtual_clk \
        -add_delay \
        [all_outputs]

    # 5. Clock uncertainty + latency (1/8 cycle)
    set_clock_uncertainty $eighths  [get_clocks core_clk]
    set_clock_latency     $eighths  [get_clocks core_clk]
}
