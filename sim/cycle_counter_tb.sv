`timescale 1ns/1ns
// iverilog -g2012 -o sim cycle_counter_tb.sv ../rtl/cycle_counter.sv && vvp sim
// =============================================================================
// cycle_counter_tb.sv — cycle-accurate testbench
//
// AXI-Lite read timeline (all signal drives at #1 after posedge):
//   Cycle A   : arvalid=1 driven. arready=arvalid=1 immediately (combinatorial).
//               DUT rvalid FF sees arvalid=1 at posedge A+1 edge → rvalid=1.
//   Cycle A+1 : rvalid=1 visible at #1 after posedge A+1. Sample rdata here.
//               Assert rready=1 at same #1.
//   Cycle A+2 : rvalid&&rready seen at posedge A+2 → rvalid drops next cycle.
//
// run_measurement(N) counts exactly N cycles:
//   posedge 0: pixel_start seen, IDLE->COUNTING, count resets to 0
//   posedge 1..N-1: count = 1..N-1
//   posedge N: frame_done seen, COUNTING->STOP, latchedCount = count+1 = N
// =============================================================================
module cycle_counter_tb;
    localparam int CLK_FREQ = 100_000_000;
    logic aclk=0, aresetn=0, pixel_start=0, frame_done=0;
    logic [3:0]  s_axil_araddr=0;
    logic        s_axil_arvalid=0, s_axil_arready, s_axil_rvalid, s_axil_rready=0;
    logic [31:0] s_axil_rdata;
    logic [1:0]  s_axil_rresp;

    cycle_counter #(.CLK_FREQ(CLK_FREQ)) dut(
        .aclk(aclk),.aresetn(aresetn),.pixel_start(pixel_start),.frame_done(frame_done),
        .s_axil_araddr(s_axil_araddr),.s_axil_arvalid(s_axil_arvalid),.s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),.s_axil_rresp(s_axil_rresp),.s_axil_rvalid(s_axil_rvalid),.s_axil_rready(s_axil_rready)
    );

    always #5 aclk = ~aclk;

    int pass_count=0, fail_count=0;
    task automatic check(input string name, input logic [31:0] got, expected);
        if (got===expected) begin $display("  [PASS] %s: 0x%08X",name,got); pass_count++; end
        else begin $display("  [FAIL] %s: got 0x%08X expected 0x%08X",name,got,expected); fail_count++; end
    endtask

    task automatic apply_reset(input int cycles=4);
        aresetn=0; pixel_start=0; frame_done=0;
        s_axil_araddr=0; s_axil_arvalid=0; s_axil_rready=0;
        repeat(cycles) @(posedge aclk); #1;
        aresetn=1; @(posedge aclk); #1;
    endtask

    // axil_read: perform one AXI-Lite read. See timeline in header comment.
    task automatic axil_read(input logic [3:0] addr, output logic [31:0] data);
        // Cycle A: drive arvalid. arready is combinatorial so check immediately.
        s_axil_araddr=addr; s_axil_arvalid=1;
        #1;
        if (s_axil_arready!==1'b1) begin
            $display("  [FAIL] arready not combinatorially asserted"); fail_count++;
        end

        // Wait for posedge A — DUT registers rvalid=1 on this edge.
        @(posedge aclk); #1;
        s_axil_arvalid=0; // deassert — arready drops combinatorially

        // Now at #1 after posedge A: rvalid must be 1.
        if (s_axil_rvalid!==1'b1) begin
            $display("  [FAIL] rvalid not asserted one cycle after arvalid"); fail_count++;
        end
        data=s_axil_rdata;

        // Complete handshake: assert rready, wait one edge (rvalid&&rready fires).
        s_axil_rready=1;
        @(posedge aclk); #1;
        s_axil_rready=0;
        // rvalid drops on next edge — wait for it so next transaction starts clean.
        @(posedge aclk); #1;
    endtask

    // run_measurement: start counting, run N cycles, stop, return latchedCount.
    task automatic run_measurement(input int n_cycles, output logic [31:0] result);
        // Posedge 0: pixel_start seen — IDLE->COUNTING, count resets.
        pixel_start=1; @(posedge aclk); #1; pixel_start=0;
        // Posedge 1..N-1: count = 1..N-1.
        repeat(n_cycles-1) @(posedge aclk); #1;
        // Posedge N: frame_done seen — COUNTING->STOP, latchedCount=count+1=N.
        frame_done=1; @(posedge aclk); #1; frame_done=0;
        // One more edge for STOP to register and latch to settle.
        @(posedge aclk); #1;
        axil_read(4'h0, result);
    endtask

    initial begin
        $display("=== cycle_counter_tb ===");
        $dumpfile("cycle_counter_tb.vcd"); $dumpvars(0,cycle_counter_tb);

        $display("\n[TEST 1] Count accuracy: 10 cycles");
        apply_reset();
        begin logic [31:0] r; run_measurement(10,r); check("latchedCount==10",r,32'd10); end

        $display("\n[TEST 2] Count accuracy: 50 cycles");
        apply_reset();
        begin logic [31:0] r; run_measurement(50,r); check("latchedCount==50",r,32'd50); end

        $display("\n[TEST 3] arready combinatorial with arvalid");
        apply_reset();
        begin
            s_axil_araddr=4'h0; s_axil_arvalid=1; #1;
            if (s_axil_arready===1'b1) begin $display("  [PASS] arready high same cycle as arvalid"); pass_count++; end
            else begin $display("  [FAIL] arready not combinatorial"); fail_count++; end
            @(posedge aclk); #1; s_axil_arvalid=0; @(posedge aclk); #1;
        end

        $display("\n[TEST 4] arready=0 when arvalid=0");
        apply_reset();
        begin
            s_axil_arvalid=0; #1;
            if (s_axil_arready===1'b0) begin $display("  [PASS] arready=0 when arvalid=0"); pass_count++; end
            else begin $display("  [FAIL] arready unexpectedly high"); fail_count++; end
        end

        $display("\n[TEST 5] result_valid gating: pixel_start ignored in STOP");
        apply_reset();
        begin
            logic [31:0] r;
            pixel_start=1; @(posedge aclk); #1; pixel_start=0;
            repeat(19) @(posedge aclk); #1;
            frame_done=1; @(posedge aclk); #1; frame_done=0;
            @(posedge aclk); #1; // STOP registered
            pixel_start=1; @(posedge aclk); #1; pixel_start=0; // fire in STOP — ignored
            axil_read(4'h0,r);
            check("STOP blocks pixel_start, result==20",r,32'd20);
        end

        $display("\n[TEST 6] Second measurement after result consumed");
        apply_reset();
        begin
            logic [31:0] r;
            run_measurement(5,r);  check("First==5",r,32'd5);
            run_measurement(8,r);  check("Second==8",r,32'd8);
        end

        $display("\n[TEST 7] CLK_FREQ register (addr=4'h4)");
        apply_reset();
        begin logic [31:0] r; axil_read(4'h4,r); check("CLK_FREQ==100_000_000",r,32'(CLK_FREQ)); end

        $display("\n[TEST 8] Unmapped address -> DEADBEEF (addr=4'hC)");
        apply_reset();
        begin logic [31:0] r; axil_read(4'hC,r); check("Unmapped==DEADBEEF",r,32'hDEAD_BEEF); end

        $display("\n[TEST 9] Reset mid-count");
        apply_reset();
        begin
            logic [31:0] r;
            pixel_start=1; @(posedge aclk); #1; pixel_start=0;
            repeat(5) @(posedge aclk); #1;
            aresetn=0; repeat(2) @(posedge aclk); #1;
            aresetn=1; @(posedge aclk); #1;
            run_measurement(3,r); check("Post-reset==3",r,32'd3);
        end

        $display("\n[TEST 10] rresp always OKAY");
        apply_reset();
        begin logic [31:0] dummy; axil_read(4'h0,dummy); check("rresp==OKAY",{30'b0,s_axil_rresp},32'h0); end

        $display("\n=== Results: %0d passed, %0d failed ===",pass_count,fail_count);
        if (fail_count==0) $display("ALL TESTS PASSED");
        else               $display("SOME TESTS FAILED");
        $finish;
    end
    initial begin #2_000_000; $display("[TIMEOUT]"); $finish; end
endmodule