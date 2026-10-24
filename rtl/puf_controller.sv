// PUF controller for a 128-bit acquisition from a PUF macro.
// The block exposes a simple memory-mapped register interface and converts the
// macro handshake into captured response bits plus a CRC over the selected bits.
// The controller accepts a request pulse, captures the macro response bit-by-bit,
// and keeps the final data and CRC available to software even when the acquisition
// completes asynchronously with respect to the host interface.
module puf_controller (
    input  logic        clk,
    input  logic        rst_n,

    // Register interface
    input  logic        reg_wr,
    input  logic        reg_rd,
    input  logic [7:0]  reg_addr,
    input  logic [31:0] reg_wdata,
    output logic [31:0] reg_rdata,

    // PUF macro interface
    output logic        puf_start,
    output logic [6:0]  puf_index,
    input  logic        puf_valid,
    input  logic        puf_bit,

    // Status
    output logic        irq
);

    // Software-visible register map.
    localparam logic [7:0] ADDR_CONTROL = 8'h00;
    localparam logic [7:0] ADDR_STATUS  = 8'h04;
    localparam logic [7:0] ADDR_DATA0   = 8'h08;
    localparam logic [7:0] ADDR_DATA1   = 8'h0C;
    localparam logic [7:0] ADDR_DATA2   = 8'h10;
    localparam logic [7:0] ADDR_DATA3   = 8'h14;
    localparam logic [7:0] ADDR_CRC     = 8'h18;
    localparam logic [7:0] ADDR_MASK0   = 8'h1C;
    localparam logic [7:0] ADDR_MASK1   = 8'h20;
    localparam logic [7:0] ADDR_MASK2   = 8'h24;
    localparam logic [7:0] ADDR_MASK3   = 8'h28;

    // Reflected CRC-32 polynomial used by the bit-serial update function.
    localparam logic [31:0] CRC32_REFLECTED_POLY = 32'hEDB88320;

    // Bit-serial CRC update for the standard reflected polynomial.
    function automatic logic [31:0] crc32_update(
        input logic [31:0] state,
        input logic        data_bit
    );
        logic feedback;
        begin
            feedback = state[0] ^ data_bit;
            crc32_update = state >> 1;
            if (feedback) begin
                crc32_update = crc32_update ^ CRC32_REFLECTED_POLY;
            end
        end
    endfunction

    // Acquisition state.
    logic        busy;
    logic        done;
    logic        error;
    logic        request_pending;
    logic [127:0] response;
    logic [127:0] transfer_mask;
    logic [31:0] crc;
    logic [31:0] crc_state;
    logic [31:0] crc_bit_next;

    // Compute the next CRC state for the current PUF bit.
    always @* begin
        crc_bit_next = crc32_update(crc_state, puf_bit);
    end

    // Register read mux; the interface is combinational and returns data for the
    // selected address while reg_rd is active.
    always @* begin
        reg_rdata = 32'b0;

        if (reg_rd) begin
            case (reg_addr)
                ADDR_STATUS: reg_rdata = {29'b0, error, done, busy};
                ADDR_DATA0:  reg_rdata = response[31:0];
                ADDR_DATA1:  reg_rdata = response[63:32];
                ADDR_DATA2:  reg_rdata = response[95:64];
                ADDR_DATA3:  reg_rdata = response[127:96];
                ADDR_CRC:    reg_rdata = crc;
                ADDR_MASK0:  reg_rdata = transfer_mask[31:0];
                ADDR_MASK1:  reg_rdata = transfer_mask[63:32];
                ADDR_MASK2:  reg_rdata = transfer_mask[95:64];
                ADDR_MASK3:  reg_rdata = transfer_mask[127:96];
                default:     reg_rdata = 32'b0;
            endcase
        end
    end

    // Interrupt is active while a completion or error condition remains latched.
    assign irq = done | error;

    // Main acquisition FSM and register write logic.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy          <= 1'b0;
            done          <= 1'b0;
            error         <= 1'b0;
            request_pending <= 1'b0;
            response      <= 128'b0;
            transfer_mask <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
            crc           <= 32'b0;
            crc_state     <= 32'hFFFFFFFF;
            puf_start     <= 1'b0;
            puf_index     <= 7'b0;
        end else begin
            // Deassert the request pulse after one cycle.
            puf_start <= 1'b0;

            // If the previous request is still pending, issue a single-cycle pulse.
            if (request_pending) begin
                puf_start       <= 1'b1;
                request_pending <= 1'b0;
            end

            // Capture a valid PUF bit and update the response/CRC if the bit is enabled.
            if (busy && puf_valid) begin
                if (transfer_mask[puf_index]) begin
                    response[puf_index] <= puf_bit;
                    crc_state <= crc_bit_next;
                end else begin
                    response[puf_index] <= 1'b0;
                end

                if (puf_index == 7'd127) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    crc <= ~((transfer_mask[puf_index]) ? crc_bit_next : crc_state);
                end else begin
                    puf_index <= puf_index + 7'd1;
                    request_pending <= 1'b1;
                end
            end

            // Register write handling.
            if (reg_wr) begin
                // Mask registers can be updated only while idle.
                case (reg_addr)
                    ADDR_MASK0: if (!busy) transfer_mask[31:0] <= reg_wdata;
                    ADDR_MASK1: if (!busy) transfer_mask[63:32] <= reg_wdata;
                    ADDR_MASK2: if (!busy) transfer_mask[95:64] <= reg_wdata;
                    ADDR_MASK3: if (!busy) transfer_mask[127:96] <= reg_wdata;
                    default: begin end
                endcase

                if (reg_addr == ADDR_CONTROL) begin
                    if (reg_wdata[1]) begin
                        // RESET: clear snapshot and status bits when idle.
                        if (!busy) begin
                            busy      <= 1'b0;
                            done      <= 1'b0;
                            error     <= 1'b0;
                            response  <= 128'b0;
                            crc       <= 32'b0;
                            crc_state <= 32'hFFFFFFFF;
                            puf_start <= 1'b0;
                            puf_index <= 7'b0;
                            request_pending <= 1'b0;
                        end
                    end else if (reg_wdata[0]) begin
                        // START: begin acquisition unless already busy.
                        if (busy) begin
                            error <= 1'b1;
                        end else begin
                            busy      <= 1'b1;
                            done      <= 1'b0;
                            response  <= 128'b0;
                            crc       <= 32'b0;
                            crc_state <= 32'hFFFFFFFF;
                            puf_index <= 7'b0;
                            puf_start <= 1'b1;
                            request_pending <= 1'b0;
                        end
                    end
                end
            end
        end
    end
endmodule