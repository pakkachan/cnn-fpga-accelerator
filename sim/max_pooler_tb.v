`timescale 1ns/1ns
// iverilog -o max_pooler_tb.vvp max_pooler_tb.v max_pooler.v
module max_pooler_tb();
    // create signals
    parameter INPUT_WIDTH = 26;    // Image dimension (e.g., 26)
    parameter BIT_WIDTH = 16;
    //inputs
    reg clk;
    reg reset;
    reg ce;
    reg valid_in;
    reg signed [BIT_WIDTH - 1 : 0] data_in;
    integer i;

    // outputs
    wire signed [BIT_WIDTH - 1 : 0] data_out;
    wire valid_out;

    // init the uut
    max_pooler #(.INPUT_WIDTH(INPUT_WIDTH), .BIT_WIDTH(BIT_WIDTH)) uut(
        .clk(clk),
        .reset(reset),
        .ce(ce),
        .valid_in(valid_in),
        .data_in(data_in),
        .data_out(data_out),
        .valid_out(valid_out)
    );
    // set clk
    always #5 clk = ~clk;

    // init inputs
    initial begin
        clk = 0; reset = 1; ce = 0; valid_in = 0; data_in = 0;
        #20;
        reset = 0;
        ce = 1;
        for (i = 0; i < (INPUT_WIDTH*INPUT_WIDTH); i = i + 1) begin
            @(posedge clk) begin
                data_in <= i;
                valid_in <= 1;
            end
        end
        #20;
        $finish;
    end

    initial begin
        $dumpfile("max_pooler_tb.vcd");
        $dumpvars(0, max_pooler_tb);
    end



endmodule