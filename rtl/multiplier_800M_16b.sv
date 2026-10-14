
module multiplier_800M_16b(
    CLK, RST_N,
    EN, input0, input1,
    stage1_occupied,
    stage2_occupied,
    stage3_occupied,
    VALID_output,
    output_val
);

    input  CLK, RST_N;
    input  EN;
    input  [15:0] input0, input1;

    output stage1_occupied, stage2_occupied, stage3_occupied;
    output VALID_output;
    output [31:0] output_val;

    reg         stage1_occupied_reg;
    wire [7:0]  partials_4bmult [15:0];
    reg  [7:0]  stage1_regs     [15:0];

    assign partials_4bmult[0]  = input0[3:0]   * input1[3:0];
    assign partials_4bmult[1]  = input0[3:0]   * input1[7:4];
    assign partials_4bmult[2]  = input0[3:0]   * input1[11:8];
    assign partials_4bmult[3]  = input0[3:0]   * input1[15:12];

    assign partials_4bmult[4]  = input0[7:4]   * input1[3:0];
    assign partials_4bmult[5]  = input0[7:4]   * input1[7:4];
    assign partials_4bmult[6]  = input0[7:4]   * input1[11:8];
    assign partials_4bmult[7]  = input0[7:4]   * input1[15:12];

    assign partials_4bmult[8]  = input0[11:8]  * input1[3:0];
    assign partials_4bmult[9]  = input0[11:8]  * input1[7:4];
    assign partials_4bmult[10] = input0[11:8]  * input1[11:8];
    assign partials_4bmult[11] = input0[11:8]  * input1[15:12];

    assign partials_4bmult[12] = input0[15:12] * input1[3:0];
    assign partials_4bmult[13] = input0[15:12] * input1[7:4];
    assign partials_4bmult[14] = input0[15:12] * input1[11:8];
    assign partials_4bmult[15] = input0[15:12] * input1[15:12];

    integer i;
    always @(posedge CLK) begin
        if (~RST_N) stage1_occupied_reg <= 1'b0;
        else        stage1_occupied_reg <= EN;
    end

    always @(posedge CLK) begin
        for (i = 0; i < 16; i = i + 1) begin
            stage1_regs[i] <= partials_4bmult[i];
        end
    end

    reg stage2_occupied_reg;
    reg [31:0] output_val_reg;

    wire [31:0] row0, row1, row2, row3;

    assign row0 = {24'd0, stage1_regs[0]}  +
                  {20'd0, stage1_regs[1],  4'd0} +
                  {16'd0, stage1_regs[2],  8'd0} +
                  {12'd0, stage1_regs[3], 12'd0};

    assign row1 = {20'd0, stage1_regs[4],  4'd0} +
                  {16'd0, stage1_regs[5],  8'd0} +
                  {12'd0, stage1_regs[6], 12'd0} +
                  { 8'd0, stage1_regs[7], 16'd0};

    assign row2 = {16'd0, stage1_regs[8],  8'd0} +
                  {12'd0, stage1_regs[9], 12'd0} +
                  { 8'd0, stage1_regs[10],16'd0} +
                  { 4'd0, stage1_regs[11],20'd0};

    assign row3 = {12'd0, stage1_regs[12],12'd0} +
                  { 8'd0, stage1_regs[13],16'd0} +
                  { 4'd0, stage1_regs[14],20'd0} +
                  {      stage1_regs[15],24'd0};

    wire [31:0] sum0 = row0 + row1;
    wire [31:0] sum1 = row2 + row3;
    wire [31:0] final_sum = sum0 + sum1;

    always @(posedge CLK) begin
        if (~RST_N) stage2_occupied_reg <= 1'b0;
        else stage2_occupied_reg <= stage1_occupied_reg;
    end

    always @(posedge CLK) begin
        output_val_reg <= final_sum;
    end

    assign stage1_occupied = stage1_occupied_reg;
    assign stage2_occupied = stage2_occupied_reg;
    assign stage3_occupied = 1'b0;

    assign VALID_output = stage2_occupied_reg;
    assign output_val   = output_val_reg;

endmodule
