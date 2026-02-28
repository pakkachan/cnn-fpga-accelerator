`timescale 1ns/1ns

// iverilog -o relu_quantize_tb.vvp relu_quantize_tb.v relu_quantize.v


module relu_quantize_tb();
    // tb of input of A7.24 and output of A3.12

    parameter INPUT_WIDTH = 32; parameter OUTPUT_WIDTH = 16; parameter F_BITS = 12;

    // inputs
    reg clk;
    reg reset;
    reg ce;
    reg valid_in;
    reg signed [INPUT_WIDTH - 1 : 0] data_in;

    // outputs
    wire signed [OUTPUT_WIDTH - 1 : 0] data_out;
    wire valid_out;

    // inst the uut
    relu_quantize #(.INPUT_WIDTH(INPUT_WIDTH), .OUTPUT_WIDTH(OUTPUT_WIDTH), .F_BITS(F_BITS)) uut(
        .clk(clk), .reset(reset), .ce(ce), .valid_in(valid_in), .data_in(data_in), .data_out(data_out),
        .valid_out(valid_out)
    );

    // set the clock
    always #5 clk = ~clk;

    // tb set

    initial begin
        // init
        clk = 0; reset = 1; ce = 0; valid_in = 0; data_in = 0;
        #20 reset = 0; ce = 1;

        // --- TEST 1: Positive Value (In Range) ---
        // Let's send 2.0. In A(7,24), 2.0 is 2 * 2^24 = 33,554,432
        data_in = 32'sd33554432; 
        valid_in = 1;
        #10;
        $display("Input: 2.0 | Output: %h (Expected: 2000 for 2.0 in A3.12)", data_out);

        // --- TEST 2: Negative Value (ReLU check) ---
        // Let's send -5.0. 
        data_in = -32'sd83886080; 
        #10;
        $display("Input: -5.0 | Output: %h (Expected: 0000)", data_out);

        // --- TEST 3: Large Positive Value (Saturation check) ---
        // Let's send 20.0 (Which is > 7.99 max range)
        data_in = 32'sd335544320; 
        #10;
        $display("Input: 20.0 | Output: %h (Expected: 7fff)", data_out);

        // --- TEST 4: Clock Enable Check ---
        ce = 0;
        data_in = 32'sd16777216; // 1.0
        #10;
        $display("CE Low | Valid_out: %b (Expected: 0)", valid_out);

        #20;
        $finish;
    end

    initial begin
        $dumpfile("relu_quantize_tb.vcd");
        $dumpvars(0, relu_quantize_tb);
    end
endmodule