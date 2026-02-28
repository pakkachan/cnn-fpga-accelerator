module top_layer_debug#(
    parameter BIT_WIDTH = 16,
    parameter IMG_WIDTH = 28,
    parameter KERNEL_WIDTH = 3,
    parameter OUT_CHANNELS = 16
)(
    input clk,
    input reset,

    // axi slave interface
    input signed [BIT_WIDTH - 1: 0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,

    // axi master interface
    output signed [(BIT_WIDTH*OUT_CHANNELS) - 1: 0] m_axis_tdata,
    output m_axis_tvalid,
    input m_axis_tready, // tell master when ready to rx
    output m_axis_tlast // todo later
);

    // FIFO signals
    wire fifo_full;
    wire fifo_almost_full;
    wire fifo_empty;
    wire fifo_almost_empty;
    wire fifo_read_en;
    // without data out fifo

    // ==============================================================
    // 1.) FLOW CONTROL/ backpressure
    // ==============================================================

    // frame active logic, to keep the pipeline running until the last piece of data is output

    reg frame_active;
    wire ce;
    wire m_axis_tlast_int;


    always @(posedge clk) begin
        if (reset) begin
            frame_active <= 0;
        end else begin
            if (s_axis_tready && s_axis_tvalid) begin
                frame_active <= 1;
            end else if (m_axis_tlast_int) begin
                frame_active <= 0;
            end
        end
    end


    // only process input when the input is valid (s_axis_tvalid) and 
    assign ce = (s_axis_tvalid || frame_active) && s_axis_tready;
    
    // prolly assign this statement later down when we have inst the fifo
    assign s_axis_tready = ~fifo_almost_full; 
    
    // ==============================================================
    // 2.) Instantiate fixed weights
    // ==============================================================
    // localparam OUT_CHANNELS = 16;
    // 16 weight lanes, each having 9 weights at 16 bits each
    // 16*9 = 144
    // parameterise this later
    wire signed [143 : 0] weight_lane [0:15];

    // CHANNEL 0: The "Identity" (Center Weight = 1.0)
    // In A3.12, 1.0 is 16'h1000. 
    // This should pass the center pixel through unchanged.
    assign weight_lane[0]  = 144'h0000_0000_0000_0000_1000_0000_0000_0000_0000;

    // CHANNEL 1: The "Top-Left" (First Weight = 1.0)
    // Helps diagnose if your kernel is mirrored or rotated.
    assign weight_lane[1]  = 144'h1000_0000_0000_0000_0000_0000_0000_0000_0000;

    // CHANNEL 2: The "Bottom-Right" (Last Weight = 1.0)
    assign weight_lane[2]  = 144'h0000_0000_0000_0000_0000_0000_0000_0000_1000;

    // CHANNEL 3: The "Sum" (All weights = 1/16th)
    // 16'h0100 is 0.0625. If input is a ramp, output should be (sum of 9 pixels) / 16.
    assign weight_lane[3]  = 144'h0100_0100_0100_0100_0100_0100_0100_0100_0100;

    // CHANNELS 4-15: Set to 0 to keep the waveform clean
    genvar i;
    generate
        for (i = 4; i < 16; i = i + 1) begin
            assign weight_lane[i] = 144'h0;
        end
    endgenerate

    // also add the intermediate wires for connecting up the modules together
    // conv:
    wire signed [(BIT_WIDTH*2) - 1 : 0] conv_out [0:(OUT_CHANNELS-1)];
    wire conv_valid [0:(OUT_CHANNELS - 1)];
    // relu:
    wire signed [(BIT_WIDTH) - 1 : 0] relu_out [0:(OUT_CHANNELS-1)];
    wire relu_valid [0:(OUT_CHANNELS - 1)];
    // max_pool:
    wire signed [(BIT_WIDTH) - 1 : 0] max_out [0:(OUT_CHANNELS - 1)];
    wire max_valid [0:(OUT_CHANNELS - 1)];
    // fifo:
    // we combine 16 channels of 16 
    localparam ALL_CHANNELS = BIT_WIDTH * OUT_CHANNELS;
    wire [(ALL_CHANNELS - 1) : 0] fifo_data_in;
    wire [(ALL_CHANNELS - 1) : 0] fifo_data_out;

    
    // ==============================================================
    // 3.) Generate the parallel CNN lanes (conv -> relu -> max_pool)
    // ==============================================================
    genvar k;
    generate
        for (k = 0; k < OUT_CHANNELS; k = k + 1) begin: CHANNEL
            conv #(
                .IMG_WIDTH(IMG_WIDTH),
                .KERNEL_WIDTH(KERNEL_WIDTH),
                .BIT_WIDTH(BIT_WIDTH)
            ) conv_unit(
                .clk(clk),
                .reset(reset),
                .pixel_in(s_axis_tdata),
                .weights_in(weight_lane[k]),
                .ce(ce),
                .valid_in(s_axis_tvalid),
                .pixel_out(conv_out[k]),
                .valid_out(conv_valid[k])
            );

            relu_quantize #(
                .INPUT_WIDTH((2*BIT_WIDTH)),
                .OUTPUT_WIDTH(BIT_WIDTH),
                .F_BITS(12)
            ) relu_unit(
                .clk(clk),
                .reset(reset),
                .ce(ce),
                .valid_in(conv_valid[k]),
                .data_in(conv_out[k]),
                .data_out(relu_out[k]),
                .valid_out(relu_valid[k])
            );

            max_pooler #(
                .INPUT_WIDTH(IMG_WIDTH - KERNEL_WIDTH + 1),
                .BIT_WIDTH(BIT_WIDTH) 
            ) max_pool_unit(
                .clk(clk),
                .reset(reset),
                .ce(ce),
                .valid_in(relu_valid[k]),
                .data_in(relu_out[k]),
                .data_out(max_out[k]),
                .valid_out(max_valid[k])
            );
            
            // pack this (kth) data lanes output onto the combined bus
            assign fifo_data_in[((k+1)*BIT_WIDTH) - 1: (k*BIT_WIDTH)] = max_out[k];
        end
    endgenerate
    
    // ==============================================================
    // 4.) Create the counter that counts the valid clock cycles to assert t_last
    // ==============================================================

    // out of the max_pooler, has dimensions of (N-K+1)/2

    localparam COUNTER_DIMENSION = (IMG_WIDTH - KERNEL_WIDTH + 1)/2;
    localparam COUNTER_BITS = $clog2(COUNTER_DIMENSION*COUNTER_DIMENSION);

    reg [COUNTER_BITS - 1 : 0] finish_counter;
    
    wire all_max_pool_valid;
    wire [OUT_CHANNELS - 1 : 0] max_valid_flat;

    genvar v;
    generate
        for (v = 0; v < OUT_CHANNELS; v=v+1) begin
            assign max_valid_flat[v] = max_valid[v];
        end
    endgenerate 


    assign all_max_pool_valid = &max_valid_flat; // AND all 16 valids together

    // synchronous reset counter that counts when ce and all_pool_valid are active
    always @(posedge clk) begin
        if (reset) begin
            finish_counter <= 0;
        end 
        else if (ce && all_max_pool_valid) begin
            if (finish_counter == (COUNTER_DIMENSION*COUNTER_DIMENSION) - 1) begin
                finish_counter <= 0; // rollover on 168 (169 ticks since start from 0)
            end else begin
                finish_counter <= finish_counter + 1;
            end
        end
    end

    // TLAST for every last pixel that is sent out validly
    assign m_axis_tlast_int = (finish_counter == 168) && all_max_pool_valid;

    // ==============================================================
    // 5.) Inst the fifo and connect to AXIS_M and AXIS_S interfaces
    // ==============================================================
    
    // Note that for a pixel/ data from start to finish to get through
    // conv, relu and max_pool, it takes approx:
    // 10 cycles

    // + 1 channel for the TLAST channel signal
    fifo #(
        .FIFO_WIDTH((BIT_WIDTH*OUT_CHANNELS) + 1),
        .FIFO_DEPTH(32),
        .SKID_THRESH(3)
    ) out_fifo(
        .clk(clk),
        .reset(reset),
        .write_en(all_max_pool_valid), // only write when all out_channels have valid data
        .data_in({m_axis_tlast_int, fifo_data_in}),
        .almost_full(fifo_almost_full),
        .read_en(fifo_read_en),
        .data_out({m_axis_tlast, fifo_data_out}),
        .empty(fifo_empty),
        .almost_empty(fifo_almost_empty)
        );

    assign fifo_read_en = m_axis_tready && m_axis_tvalid;
    assign s_axis_tready = !fifo_almost_full;
    assign m_axis_tvalid = !fifo_empty;
    assign m_axis_tdata = fifo_data_out;

endmodule