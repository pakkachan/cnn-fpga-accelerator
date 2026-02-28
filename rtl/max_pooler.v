module max_pooler #(
    parameter INPUT_WIDTH = 26,    // Image dimension
    parameter BIT_WIDTH = 16,      // Fixed-point precision
    parameter OUTPUT_WIDTH = INPUT_WIDTH / 2
)(
    input clk,
    input reset,
    input ce,
    input valid_in,
    input signed [BIT_WIDTH - 1 : 0] data_in,

    output reg signed [BIT_WIDTH - 1 : 0] data_out,
    output reg valid_out
);
    localparam POINTER_WIDTH = $clog2(OUTPUT_WIDTH);

    reg signed [BIT_WIDTH - 1: 0] line_buffer_odd [0 : OUTPUT_WIDTH - 1];
    reg signed [BIT_WIDTH - 1: 0] line_buffer_even [0 : OUTPUT_WIDTH - 1];
    
    // --- MOVED DECLARATION HERE ---
    reg signed [BIT_WIDTH-1:0] current_h_max; 
    
    reg even_col; // Toggles every row
    reg even_row; // Toggles every pixel
    reg [POINTER_WIDTH - 1 : 0] line_buffer_pointer;

    always @(posedge clk) begin
        if (reset) begin
            even_col <= 0;
            even_row <= 0;
            line_buffer_pointer <= 0;
            data_out <= 0;
            valid_out <= 0;
            current_h_max <= 0;
        end else if (ce && valid_in) begin
            // ---------------------------------------------------------
            // ODD Y (First Row of the 2x2 block)
            // ---------------------------------------------------------
            if (even_col == 0) begin
                valid_out <= 0;
                if (even_row == 0) begin
                    line_buffer_odd[line_buffer_pointer] <= data_in;
                end else begin
                    if (data_in > line_buffer_odd[line_buffer_pointer]) begin
                        line_buffer_odd[line_buffer_pointer] <= data_in;
                    end
                    
                    if (line_buffer_pointer == (OUTPUT_WIDTH - 1)) begin
                        line_buffer_pointer <= 0;
                        even_col <= 1;
                    end else begin
                        line_buffer_pointer <= line_buffer_pointer + 1;
                    end
                end

            // ---------------------------------------------------------
            // EVEN Y (Second Row of the 2x2 block - PUSH OUTPUT)
            // ---------------------------------------------------------
            end else begin
                if (even_row == 0) begin
                    line_buffer_even[line_buffer_pointer] <= data_in;
                    valid_out <= 0;
                end else begin
                    // 1. Find the horizontal winner for the current row
                    // We calculate this temporarily using blocking assignment (=) 
                    // so we can use it immediately in the next if statement.
                    current_h_max = (data_in > line_buffer_even[line_buffer_pointer]) ? data_in : line_buffer_even[line_buffer_pointer];

                    // 2. Find the Vertical winner (current vs odd buffer)
                    // TYPO FIXED: changed 'current_h_win' to 'current_h_max'
                    if (current_h_max > line_buffer_odd[line_buffer_pointer]) begin
                        data_out <= current_h_max; 
                    end else begin
                        data_out <= line_buffer_odd[line_buffer_pointer];
                    end
                    
                    valid_out <= 1; 

                    // 3. Increment/Reset Pointer
                    if (line_buffer_pointer == (OUTPUT_WIDTH - 1)) begin
                        line_buffer_pointer <= 0;
                        even_col <= 0; 
                    end else begin
                        line_buffer_pointer <= line_buffer_pointer + 1;
                    end
                end
            end
            
            even_row <= ~even_row;
            
        end else begin
            valid_out <= 0;
        end
    end
endmodule