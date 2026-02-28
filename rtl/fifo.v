// fifo with skid buffer, 

// never write to a full fifo

// never read from an empty fifo

// Adjust SKID_THRESH depending on backpressure ctrl latency

// Created by pakkachan (c)

module fifo#(parameter FIFO_WIDTH = 256, parameter FIFO_DEPTH = 16, parameter SKID_THRESH = 2, parameter AF_THRESH = FIFO_DEPTH - SKID_THRESH,
parameter AE_THRESH = SKID_THRESH) (
    
    input wire clk,
    input wire reset,

    // write interface
    input wire write_en,
    input wire [FIFO_WIDTH - 1:0] data_in,
    output wire full,
    output wire almost_full,

    // read interface
    input wire read_en,
    output wire [FIFO_WIDTH - 1 :0] data_out,
    output wire empty,
    output wire almost_empty

    );

    localparam PTR_WIDTH = $clog2(FIFO_DEPTH);

    // storing write_pointer and read_pointer
    reg [PTR_WIDTH - 1:0] write_pointer;
    reg [PTR_WIDTH - 1:0] read_pointer;

    // store the fifo information, create the literal fifos
    reg [FIFO_WIDTH - 1 : 0] fifo[FIFO_DEPTH - 1 :0];

    // counter for AF/AE logic
    reg [PTR_WIDTH:0] counter;
    

    // write logic
    always @(posedge clk) begin
        if (reset) begin
            write_pointer <= 0;
        end else if (write_en && !full) begin
            fifo[write_pointer] <= data_in;
            write_pointer <= write_pointer + 1;
        end
    end

    // read logic
    always @(posedge clk) begin
        if (reset) begin
            read_pointer <= 0;
        end else if (read_en && !empty) begin
            read_pointer <= read_pointer + 1;
        end
    end

    // AF/ AE logic, when written, count +=1, when read, count -= 1
    always @(posedge clk) begin
        if (reset) begin
            counter <= 0;
        end else begin 
            case({write_en && !full, read_en && !empty})
                2'b10 : counter <= counter + 1;
                2'b01 : counter <= counter - 1;
                default : counter <= counter; endcase 
        end
    end
    
    assign full = (counter == FIFO_DEPTH);
    assign empty = (counter == 0);
    assign almost_empty = (counter <= AE_THRESH); // almost empty when 2 are remaining
    assign almost_full = (counter >= AF_THRESH);
    assign data_out = fifo[read_pointer]; // FWFT fifo

endmodule