`timescale 1ns / 1ps

module fifo_tb();

    // Parameters
    parameter WIDTH = 8; // Use 8 bits for easier debugging in waveforms
    parameter DEPTH = 16;
    
    // Testbench Signals
    reg clk;
    reg reset;
    reg write_en;
    reg [WIDTH-1:0] data_in;
    wire full;
    wire almost_full;
    reg read_en;
    wire [WIDTH-1:0] data_out;
    wire empty;
    wire almost_empty;

    // Instantiate UUT (Unit Under Test)
    fifo #(
        .FIFO_WIDTH(WIDTH),
        .FIFO_DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        .write_en(write_en),
        .data_in(data_in),
        .full(full),
        .almost_full(almost_full),
        .read_en(read_en),
        .data_out(data_out),
        .empty(empty),
        .almost_empty(almost_empty)
    );

    // Clock Generation (100MHz)
    always #5 clk = ~clk;

    initial begin
        // Initialize Signals
        clk = 0;
        reset = 1;
        write_en = 0;
        read_en = 0;
        data_in = 0;

        // Reset Pulse
        #20 reset = 0;
        #10;

        // --- TEST 1: Single Write/Read (FWFT Check) ---
        $display("Test 1: Single Write/Read");
        data_in = 8'hAA;
        write_en = 1;
        #10 write_en = 0;
        // In FWFT, data_out should be AA immediately after the clock edge
        #5; 
        if (data_out == 8'hAA && !empty) 
            $display("  Pass: FWFT working. Data visible immediately.");
        
        read_en = 1;
        #10 read_en = 0;

        // --- TEST 2: Fill to Almost Full ---
        $display("Test 2: Filling to Almost Full threshold");
        write_en = 1;
        repeat (14) begin
            data_in = data_in + 1;
            #10;
        end
        write_en = 0;
        if (almost_full) $display("  Pass: Almost Full detected at 14 items.");

        // --- TEST 3: Simultaneous Read and Write ---
        // This is the most important test for your case statement logic
        $display("Test 3: Simultaneous Read and Write");
        write_en = 1;
        read_en = 1;
        data_in = 8'hFF;
        #10;
        write_en = 0;
        read_en = 0;
        $display("  Check: Counter should remain stable.");

        // --- TEST 4: Full Capacity & Overflow Protection ---
        $display("Test 4: Filling to Full");
        write_en = 1;
        repeat (5) #10; // Try to overfill
        write_en = 0;
        if (full) $display("  Pass: Full flag set.");

        // --- TEST 5: Drain to Empty ---
        $display("Test 5: Draining FIFO");
        read_en = 1;
        repeat (20) #10; // Try to over-read
        read_en = 0;
        if (empty) $display("  Pass: Empty flag set.");

        #50;
        $display("All tests completed.");
        $finish;
    end

    initial begin
        $dumpfile("fifo_tb.vcd");
        $dumpvars(0, fifo_tb);
    end

endmodule