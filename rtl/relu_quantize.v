module relu_quantize #(parameter INPUT_WIDTH = 32, parameter OUTPUT_WIDTH = 16, parameter F_BITS = 12)(
    input clk,
    input reset,
    input ce,
    input valid_in,
    input signed [INPUT_WIDTH - 1 : 0] data_in,

    output reg signed [OUTPUT_WIDTH - 1 : 0] data_out,
    output reg valid_out
);
    // first shift the points to the same
    wire signed [INPUT_WIDTH - 1 : 0] data_in_shifted = data_in >>> F_BITS; 
    // note arithmetic shift >>> ensures sign bit is preserved

    // now we check for the overflow
    always @(posedge clk) begin
        if (reset) begin
            data_out <= 0;
            valid_out <= 0;
        // if ce
        end else if (ce) begin
            valid_out <= valid_in;
            // if the data_in msb is 1 (data_in is negative)
            if (data_in[INPUT_WIDTH - 1] == 1) begin
                data_out <= 0;
            end else if (data_in_shifted > 32'sh00007FFF) begin
                // if overflow, then clamp data_out to max value
                data_out <= 16'sh7FFF;
            end else begin
                data_out <= data_in_shifted[OUTPUT_WIDTH - 1:0]; // slice the shifted data
            end
        // if no ce
        end else begin
            valid_out <= 0;
        end
    end
endmodule