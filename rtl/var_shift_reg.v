// very cool way to write this shift reg which may map into bram if dimensions are large enough

module var_shift_reg #(parameter WIDTH = 32, parameter DEPTH = 2)(
    input clk, input reset, input ce, input signed [WIDTH - 1 :0] data_in, output signed [WIDTH - 1 :0] data_out
);
    // internal memory 
    reg signed [WIDTH - 1 :0] memory [0: DEPTH - 1];

    // pointer to memory
    reg [($clog2(DEPTH) > 0 ? $clog2(DEPTH) - 1 : 0) : 0] pointer; // handle the edge case of DEPTH = 1, clog2(1) = 0
    
    always @(posedge clk) begin
        if (reset) begin
            pointer <= 0;
        end else if (ce) begin
            memory[pointer] <= data_in;

            if (pointer == (DEPTH - 1)) begin
                pointer <= 0; // pointer wrap arounc control, note not necessary if depth is a power of 2. But necessary for non 2^n depths
            end else begin
                pointer <= pointer + 1;
            end
        end
    end

    assign data_out = memory[pointer];

endmodule
