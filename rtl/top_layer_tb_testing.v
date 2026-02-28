`timescale 1ns/1ps

// iverilog -o top_layer_tb_testing.vvp top_layer_tb_testing.v top_layer.v conv.v mac_unit.v var_shift_reg.v relu_quantize.v max_pooler.v fifo.v

module top_layer_tb_testing();
    parameter BIT_WIDTH = 16;
    parameter OUT_CHANNELS = 16;
    
    reg clk, reset;
    reg [BIT_WIDTH-1:0] s_axis_tdata;
    reg s_axis_tvalid;
    wire s_axis_tready;
    
    wire [(BIT_WIDTH*OUT_CHANNELS)-1:0] m_axis_tdata;
    wire m_axis_tvalid, m_axis_tlast;
    reg m_axis_tready;

    integer i, out_count;

    top_layer dut (
        .clk(clk), .reset(reset),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin
        reset = 1; s_axis_tvalid = 0; m_axis_tready = 1;
        #100; reset = 0; #20;

        $display("--- STARTING RAMP STIMULUS ---");
        for (i = 0; i < 784; i = i + 1) begin
            wait(s_axis_tready);
            @(posedge clk);
            s_axis_tdata <= i;
            s_axis_tvalid <= 1;
        end
        @(posedge clk); s_axis_tvalid = 0;
    end

    initial begin
        out_count = 0;
        wait(!reset);
        forever begin
            @(posedge clk);
            if (m_axis_tvalid && m_axis_tready) begin
                if (out_count == 0) begin
                    $display("\n INDEX | CHAN 0      | CHAN 1      | CHAN 2      | CHAN 3");
                    $display("-------|-------------|-------------|-------------|------------");
                end
                $display(" %5d | %11d | %11d | %11d | %11d", 
                    out_count, 
                    $signed(m_axis_tdata[15:0]), 
                    $signed(m_axis_tdata[31:16]), 
                    $signed(m_axis_tdata[47:32]), 
                    $signed(m_axis_tdata[63:48])
                );
                out_count = out_count + 1;
                if (m_axis_tlast) begin
                    $display("--- TLAST RECEIVED AT INDEX %0d ---", out_count-1);
                    #100; $finish;
                end
            end
        end
    end
endmodule