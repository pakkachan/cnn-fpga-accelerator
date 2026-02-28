`timescale 1ns / 1ns
// iverilog -o top_layer_debug_tb.vvp top_layer_debug_tb.v top_layer_debug.v conv.v mac_unit.v var_shift_reg.v relu_quantize.v max_pooler.v fifo.v

module top_layer_debug_tb();

    parameter BIT_WIDTH = 16;
    parameter IMG_WIDTH = 28;
    parameter OUT_CHANNELS = 16;
    
    reg clk;
    reg reset;

    // AXI Slave (Input)
    reg [BIT_WIDTH - 1:0] s_axis_tdata;
    reg s_axis_tvalid;
    wire s_axis_tready;

    // AXI Master (Output)
    wire [(BIT_WIDTH*OUT_CHANNELS) - 1:0] m_axis_tdata;
    wire m_axis_tvalid;
    reg m_axis_tready;
    wire m_axis_tlast;

    // Simulation Tracking
    integer i, out_count;
    integer start_time_cycles, first_valid_cycle;
    integer current_cycle;

    // Instantiate the DUT
    top_layer_debug #(
        .BIT_WIDTH(BIT_WIDTH),
        .IMG_WIDTH(IMG_WIDTH),
        .KERNEL_WIDTH(3),
        .OUT_CHANNELS(OUT_CHANNELS)
    ) dut (
        .clk(clk), .reset(reset),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

    // Clock Logic
    initial begin clk = 0; forever #5 clk = ~clk; end
    always @(posedge clk) current_cycle <= (reset) ? 0 : current_cycle + 1;

    // --- Step 1: Input Feeding (Ramp Pattern) ---
    initial begin
        reset = 1; s_axis_tvalid = 0; s_axis_tdata = 0; m_axis_tready = 1;
        #100; reset = 0; #20;

        $display("\n========================================================");
        $display("   CNN TOP LAYER DEBUGGER: STARTING SIMULATION");
        $display("========================================================\n");
        
        start_time_cycles = current_cycle;

        for (i = 0; i < 784; i = i + 1) begin
            wait(s_axis_tready);
            @(posedge clk);
            s_axis_tdata <= i; // Ramp: Pixel value = Pixel index
            s_axis_tvalid <= 1;
        end

        @(posedge clk);
        s_axis_tvalid <= 0;
        $display("[%0t ns] STIMULUS: All 784 pixels injected.", $time);
    end

    // --- Step 2: Output Monitor Terminal ---
    initial begin
        out_count = 0;
        first_valid_cycle = 0;

        forever begin
            @(posedge clk);
            if (m_axis_tvalid && m_axis_tready) begin
                if (out_count == 0) begin
                    first_valid_cycle = current_cycle;
                    $display("--------------------------------------------------------");
                    $display("LATENCY DETECTED: %0d cycles", (first_valid_cycle - start_time_cycles));
                    $display(" (Expected for 3x3 Conv + Pooling: ~60-100 cycles)");
                    $display("--------------------------------------------------------");
                    $display(" INDEX | CHAN 0 (Center) | CHAN 1 (TL) | CHAN 2 (BR) | TLAST");
                    $display("-------|-----------------|-------------|-------------|-------");
                end
                
                // Print Channel 0, 1, and 2 outputs
                $display(" %5d | %15d | %11d | %11d |   %b", 
                         out_count, 
                         m_axis_tdata[15:0],          // Chan 0
                         m_axis_tdata[31:16],         // Chan 1
                         m_axis_tdata[47:32],         // Chan 2
                         m_axis_tlast);

                out_count = out_count + 1;
                
                if (out_count == 169) begin
                    $display("--------------------------------------------------------");
                    $display("TOTAL PIXELS RECEIVED: %0d/169", out_count);
                    if (m_axis_tlast) $display("STATUS: TLAST successfully received at end of frame.");
                    else $display("ERROR: TLAST was NOT seen at index 168!");
                    $display("========================================================\n");
                    #100; $finish;
                end
            end
        end
    end

    initial begin
        $dumpfile("top_layer_debug.vcd");
        $dumpvars(0, top_layer_debug_tb);
    end

endmodule