module cycle_counter #(
    parameter int CLK_FREQ = 100_000_000
)(
    input logic aclk,
    input logic aresetn,

    // sideband inputs
    input logic pixel_start,
    input logic frame_done,

    // AXI-Lite slave Address Read (AR) channel
    input logic [3:0] s_axil_araddr,    // why not make this set = 4 to get the counter in order to make it more intentional?
    input logic s_axil_arvalid,
    output logic s_axil_arready,

    // AXI-Lite slave R channel (Read data)
    output logic [31:0] s_axil_rdata,
    output logic [1:0] s_axil_rresp,
    output logic s_axil_rvalid,
    input logic s_axil_rready

);
    // Handle the counting
    // Note that at 100MHz, 1 cycle takes 10ns. 
    // 2^32 approx 4 billion hence the counter is large enough

    logic [31:0] count, latchedCount;

    typedef enum logic [1:0] {
        IDLE,
        COUNTING,
        STOP
    } state_t;
    
    // questions to ask, why aclk and aresetn?
    state_t currState, nextState;
    
    always_comb begin
        case(currState)

        IDLE: begin
            if(pixel_start) begin
                nextState = COUNTING;
            end else begin
                nextState = IDLE;
            end
        end

        COUNTING: begin
            if (frame_done) begin
                nextState = STOP;
            end else begin
                nextState = COUNTING;
            end
        end

        STOP: begin
            nextState = IDLE;
            // add in the axi signals
            // we are ready to read address and read data
        end

        default: begin
            nextState = IDLE;
        end

        endcase
    end
    
    // deal with the state transitions
    always_ff @(posedge aclk) begin
        if(!aresetn) begin
            currState <= IDLE;
        end else begin
            currState <= nextState;
        end
    end

    always_ff @(posedge aclk) begin
        if(!aresetn) begin
            count <= 0;
        end else if (currState == IDLE && pixel_start) begin
            count <= 0;
        end else if(currState == COUNTING) begin
            count <= count + 1;
        end
        // note that for any other state, the count does not increment or reset
    end

    always_ff @(posedge aclk) begin
        if(!aresetn) begin
            latchedCount <= 0;
        end else if (currState == STOP) begin
            latchedCount <= count + 1;
        end
    end

    // now we can deal with the axi transfer
    // could be done with an FSM, or just simple seq logic
    always_ff @(posedge aclk) begin
        if(!aresetn) begin
            s_axil_arready <= 0;
        end else if (s_axil_arvalid) begin
            s_axil_arready <= 1;
        end else begin
            s_axil_arready <= 0;
        end
    end

    // axi read
    always_ff @(posedge aclk) begin
        if(!aresetn) begin
            s_axil_rvalid <= 0;
        end else if (s_axil_arready && s_axil_arvalid && !s_axil_rvalid) begin
            s_axil_rvalid <= 1;
        end else if (s_axil_rvalid && s_axil_rready) begin
            s_axil_rvalid <= 0;
        end
    end

    assign s_axil_rresp = 2'b00;

    // final register mux
    // using s_axil_araddr[3:2] instead of the full address as it ignores the byte lane bits [1:0] which AXI masters sometimes drive non zero even for word aligned accesses
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            s_axil_rdata <= 0;
        end else if (s_axil_arvalid && !s_axil_arready) begin
            case (s_axil_araddr[3:2])
                2'b00: s_axil_rdata <= latchedCount;
                2'b01: s_axil_rdata <= 32'(CLK_FREQ); // explicit cast
                default: s_axil_rdata <= 32'hDEADBEEF;
            endcase
        end
    end
endmodule