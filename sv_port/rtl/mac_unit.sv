// (* use_dsp = "yes" *)

module mac_unit #(
    parameter INPUT_WIDTH = 16, 
    parameter OUTPUT_WIDTH = 2*INPUT_WIDTH)(
    input clk,
    input reset,
    input ce,
    input signed [INPUT_WIDTH - 1:0] weight, pixel,
    input signed [OUTPUT_WIDTH - 1:0] prev_sum,
    output logic signed [OUTPUT_WIDTH - 1: 0] result
    );

    always_ff@(posedge clk) begin
        if(reset)begin
            result <= 0;
        end else if (ce) begin
            result <= (weight * pixel) + prev_sum;
        end
    end
    
endmodule   

