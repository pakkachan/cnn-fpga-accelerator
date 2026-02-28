
// stride = 1 conv engine
module conv #(
    parameter IMG_WIDTH = 28, 
    parameter KERNEL_WIDTH = 3,
    parameter BIT_WIDTH = 16
)(
    input clk,
    input reset,
    input signed [BIT_WIDTH - 1: 0] pixel_in,
    input signed [(KERNEL_WIDTH * KERNEL_WIDTH * BIT_WIDTH) - 1 : 0] weights_in, // to be unpacked into weights[0] ... weights[KERNEL_WIDTH^2]
    input ce,
    input valid_in,

    output signed [(2*BIT_WIDTH) - 1:0] pixel_out,
    output valid_out // valid signal for wrap
);
    // 1.) unpack weights to feed into MAC units later
    wire signed [BIT_WIDTH - 1:0] weight [0 : (KERNEL_WIDTH*KERNEL_WIDTH) - 1]; //wires to attatch onto weights_in
    genvar i;
    generate 
        for (i=0; i<(KERNEL_WIDTH*KERNEL_WIDTH); i = i+1) begin
            //reverse order!!
            assign weight[KERNEL_WIDTH*KERNEL_WIDTH - 1 - i] = weights_in[(BIT_WIDTH * (i + 1)) - 1 : (BIT_WIDTH * (i))];
        end
    endgenerate

    // 2.) Inst the chain wires that chain up the MAC units together, KERNEL_WIDTH^2 MAC units therefore 
    // we need K^2 wires. chain[0] is the input to the first MAC, chain[K^2] is the final output
    wire signed [(2*BIT_WIDTH) - 1 : 0] chain[0: KERNEL_WIDTH*KERNEL_WIDTH];
    assign chain[0] = 0;


    
    // 3.) instantiate the mac units
    generate
        for (i=0; i<(KERNEL_WIDTH*KERNEL_WIDTH); i = i+1 ) begin: MAC
            if (((i + 1) % KERNEL_WIDTH == 0) && (i != (KERNEL_WIDTH*KERNEL_WIDTH) - 1)) begin
                // create mac to sr wire
                wire [(2*BIT_WIDTH) - 1 : 0] mac_to_sr;

                (* use_dsp = "yes" *)
                // create mac unit
                mac_unit #(.INPUT_WIDTH(BIT_WIDTH)) mac1(
                    .clk(clk),
                    .reset(reset),
                    .ce(ce && valid_in),
                    .weight(weight[i]),
                    .pixel(pixel_in),
                    .prev_sum(chain[i]),
                    .result(mac_to_sr)
                ); 
                // and then connect to shift reg of depth (N - K), note CE is enabled for now. need to implement logic later.
                var_shift_reg #(.WIDTH((BIT_WIDTH*2)), .DEPTH(IMG_WIDTH - KERNEL_WIDTH)) shift_reg(
                    .clk(clk),
                    .reset(reset),
                    .ce(ce && valid_in),
                    .data_in(mac_to_sr),
                    .data_out(chain[i+1])
                );

            end else begin
                (* use_dsp = "yes" *)
                // regular mac instantiation, connected in by chain[i] and out chain[i+1]
                mac_unit #(.INPUT_WIDTH(BIT_WIDTH)) mac2(
                    .clk(clk),
                    .reset(reset),
                    .ce(ce && valid_in),
                    .weight(weight[i]),
                    .pixel(pixel_in),
                    .prev_sum(chain[i]),
                    .result(chain[i+1])
                ); 
                
            end
        end
    endgenerate

    assign pixel_out = chain[KERNEL_WIDTH*KERNEL_WIDTH]; //pixel out is the last of the chain
    /*
    for i in range (KERNEL_WIDTH^2)

        //decide what comes next
        if (at end of row) && (not last mac unit):
            instantiate shift reg of (N - K) depth
        else:
            inst mac and prep connection to next mac

    pixel_out = connection[K^2]
    */

    // create counters
    localparam COUNT_WIDTH = $clog2(IMG_WIDTH);

    reg [COUNT_WIDTH - 1 : 0] h_count, v_count;

    always @(posedge clk) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
            // when valid data is entering
        end else if (ce && valid_in) begin
            if (h_count == (IMG_WIDTH - 1)) begin
                h_count <= 0;
                v_count <= (v_count == IMG_WIDTH - 1) ? 0 : v_count + 1; // vcount = 0 when in the bottom right corner
            end else begin
                h_count <= h_count + 1;
            end
        end
    end
    // 5.) Valid output logic

    /*
    my logic to implement, nvm got simplified down to the bottom line:
    */
    //this line is when in valid range, only 1 line required :)
    wire is_valid_range = (v_count >= KERNEL_WIDTH - 1) && (h_count >= KERNEL_WIDTH - 1);

    reg valid_out_reg;

    always @(posedge clk) begin
        if (reset) begin
            valid_out_reg <= 0;
        end else if (ce && valid_in) begin
            valid_out_reg <= is_valid_range;
        end
    end
    assign valid_out = valid_out_reg;

endmodule

