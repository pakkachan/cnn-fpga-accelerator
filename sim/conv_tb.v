// iverilog -o conv_tb.vvp conv_tb.v conv.v mac_unit.v var_shift_reg.v


`timescale 1ns/1ns

module conv_tb();
    parameter IMG_WIDTH = 4; // test a 4 bit image
    parameter KERNEL_WIDTH = 3;
    parameter BIT_WIDTH = 16;
    parameter K2 = KERNEL_WIDTH * KERNEL_WIDTH;

    // input signals
    reg clk;
    reg reset;
    reg [BIT_WIDTH - 1 : 0] pixel_in;
    reg [(KERNEL_WIDTH * KERNEL_WIDTH * BIT_WIDTH) - 1 : 0] weights_in; // to be unpacked into weights[0] ... weights[KERNEL_WIDTH^2]
    reg ce;

    // output signals 
    wire [(2*BIT_WIDTH) - 1 : 0] pixel_out;
    wire valid_out;

    // inst the uut
    conv #(.IMG_WIDTH(IMG_WIDTH), .KERNEL_WIDTH(KERNEL_WIDTH), .BIT_WIDTH(BIT_WIDTH)) uut(
        .clk(clk),
        .reset(reset),
        .pixel_in(pixel_in),
        .weights_in(weights_in),
        .ce(ce),
        .pixel_out(pixel_out),
        .valid_out(valid_out)
    );

    // inst the clk 
    always #5 clk = ~clk;

    task send_image;
        integer i; 
        begin
            for (i = 1; i <= 16; i = i + 1) begin
                @(posedge clk);
                pixel_in <= i;
                ce <= 1;
            end
            @(posedge clk) begin
                pixel_in <= 0;
                ce <= 0;
            end
        end
    endtask

    initial begin
        clk = 0; reset = 1; ce = 0; pixel_in = 0;

        weights_in = { 16'd9, 16'd8, 16'd7,     
                       16'd6, 16'd5, 16'd4, 
                       16'd3, 16'd2, 16'd1 };
        #20;
        reset = 0;

        send_image();
        #20;
        $finish;
    end

    initial begin
        $dumpfile("conv_tb.vcd");
        $dumpvars(0, conv_tb);
    end
endmodule

