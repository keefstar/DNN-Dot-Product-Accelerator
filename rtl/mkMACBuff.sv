module mkMACBuff (
    input  logic CLK, RST_N, EN_mac, EN_blockRead,
    input  logic [15:0] mac_vectA_0, mac_vectB_0,
    input  logic [15:0] mac_vectA_1, mac_vectB_1,
    input  logic [15:0] mac_vectA_2, mac_vectB_2,
    input  logic [15:0] mac_vectA_3, mac_vectB_3,
    /* Memory interface */
    output logic  EN_writeMem, RDY_blockRead,
    output logic  EN_readMem,
    output logic [5:0]  writeMem_addr, readMem_addr,
    output logic [33:0] writeMem_val,
    input  logic [33:0] readMem_val,
    /* Outputs to testbench */
    output logic  RDY_mac, VALID_memVal,
    output logic [33:0] memVal_data
);
    /************ State / counters ************/
    logic [6:0] values_written, input_count, reads_issued, read_count;
    logic [2:0] state, next_state;	
    logic valid_all;
    localparam [2:0] FILL = 3'b000, FULL = 3'b010, STREAM = 3'b100;
    /************ RDY_mac ************/
    assign RDY_mac = ((input_count < 64) && (state == FILL) || (VALID_memVal && read_count == (7'd64)));
    assign RDY_blockRead = ~RDY_mac;
    /************ Next-state logic ************/
    always_comb begin
        next_state = state;
        unique case (state)
            FILL: if ((values_written == 7'd63) && valid_all) next_state = FULL;
            FULL:   if (EN_blockRead)            next_state = STREAM;
            STREAM: if (read_count == 7'd64)     next_state = FILL;
            default:                             next_state = FILL;
        endcase
    end
    /************ Parallel multipliers ************/
    logic [31:0] prod_0, prod_1, prod_2, prod_3;
    logic        valid_mul0, valid_mul1, valid_mul2, valid_mul3;
    // All four multipliers see the same EN_mac, so their VALID_output. Pulses are aligned for each vector.
    multiplier_800M_16b mul0 (
        .CLK(CLK), .RST_N(RST_N), .EN(EN_mac), .input0(mac_vectA_0), .input1(mac_vectB_0), 
        .stage1_occupied(),.stage2_occupied(), .stage3_occupied(), .VALID_output(valid_mul0),.output_val(prod_0));
    multiplier_800M_16b mul1 (
        .CLK(CLK), .RST_N(RST_N), .EN(EN_mac), .input0(mac_vectA_1), .input1(mac_vectB_1), 
        .stage1_occupied(),.stage2_occupied(), .stage3_occupied(), .VALID_output(valid_mul1),.output_val(prod_1));
     multiplier_800M_16b mul2 (
        .CLK(CLK), .RST_N(RST_N), .EN(EN_mac), .input0(mac_vectA_2), .input1(mac_vectB_2), 
        .stage1_occupied(),.stage2_occupied(), .stage3_occupied(), .VALID_output(valid_mul2),.output_val(prod_2));
    multiplier_800M_16b mul3 (
        .CLK(CLK), .RST_N(RST_N), .EN(EN_mac), .input0(mac_vectA_3), .input1(mac_vectB_3), 
        .stage1_occupied(),.stage2_occupied(), .stage3_occupied(), .VALID_output(valid_mul3),.output_val(prod_3));
    /************ Combinational dot product ************/
    logic [33:0] dot_result;
    always_comb begin
        valid_all  = valid_mul0 & valid_mul1 & valid_mul2 & valid_mul3;
        // Zero-extend to 34 bits before summing 4×32-bit products
        dot_result = {2'b0, prod_0} + {2'b0, prod_1}  + {2'b0, prod_2} + {2'b0, prod_3};
    end
    /************  Sequential control + memory logic ************/
    always_ff @(posedge CLK) begin
        if (!RST_N) begin
            state <= FILL;
            /* Write side */
            input_count <= 7'd0;
            writeMem_addr <= 6'd0;
            EN_writeMem <= 1'b0;
            values_written <= 7'd0;
            writeMem_val <= 34'd0;
            /* Read side */
            readMem_addr   <= 6'd0;
            EN_readMem     <= 1'b0;
            reads_issued   <= 7'd0;
            VALID_memVal   <= 1'b0;
            memVal_data    <= 34'd0;
            read_count     <= 7'd0;
        end
        else begin
            state <= next_state;
            VALID_memVal <= '0;
            readMem_addr <= readMem_addr;
            unique case (state)
                FILL: begin // FILL: accept MAC inputs, write 64 results
                    // Memory write when all four products are valid
                    if (valid_all) begin
                        writeMem_val   <= dot_result;
                        EN_writeMem    <= 1'b1;
                        writeMem_addr  <= values_written[5:0];
                        values_written <= values_written + 7'd1;
                    end
                    else begin
                        EN_writeMem <= 1'b0;
                        if (values_written == 7'd64) writeMem_addr <= '0;
                    end
                    if (EN_mac && RDY_mac) input_count <= input_count + 7'd1; // Count inputs accepted
                end
                FULL: begin // FULL: memory full, wait for EN_blockRead
                    EN_writeMem <= 1'd0;
                    writeMem_addr <= 6'd0;
                    values_written <= 7'd0;
                    input_count <= 7'd0;
                    if (EN_blockRead) begin
                        EN_readMem   <= 1'b1;
                        readMem_addr <= '0;
                        reads_issued <= 7'd1;
                        read_count   <= '0;
                    end
                    else begin
                        EN_readMem   <= 1'b0;
                        reads_issued <= '0;
                    end
                end
                STREAM: begin // STREAM: stream out 64 values
                    memVal_data  <= readMem_val;
                    VALID_memVal <= EN_readMem;
                    read_count   <= read_count + 7'd1;
                    if (reads_issued < 7'd64) begin
                        EN_readMem   <= 1'b1;
                        readMem_addr <= reads_issued[5:0];   // use counter, not readMem_addr feedback
                        reads_issued <= reads_issued + 7'd1;
                    end
                    else begin
                        EN_readMem <= 1'b0;
                    end
                end
                default: ;
            endcase
        end
    end
endmodule

