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

    localparam logic [7:0] ADDR_CONTROL = 8'h00;
    localparam logic [7:0] ADDR_STATUS  = 8'h04;
    localparam logic [7:0] ADDR_DATA0   = 8'h08;
    localparam logic [7:0] ADDR_DATA1   = 8'h0C;
    localparam logic [7:0] ADDR_DATA2   = 8'h10;
    localparam logic [7:0] ADDR_DATA3   = 8'h14;
    localparam logic [7:0] ADDR_CRC     = 8'h18;

    localparam logic [31:0] CRC32_REFLECTED_POLY = 32'hEDB88320;

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

    logic        busy;
    logic        done;
    logic        error;
    logic        request_pending;
    logic [127:0] response;
    logic [31:0] crc;
    logic [31:0] crc_state;
    logic [31:0] crc_bit_next;

    always @* begin
        crc_bit_next = crc32_update(crc_state, puf_bit);
    end

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
                default:     reg_rdata = 32'b0;
            endcase
        end
    end

    assign irq = done | error;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy      <= 1'b0;
            done      <= 1'b0;
            error     <= 1'b0;
            request_pending <= 1'b0;
            response  <= 128'b0;
            crc       <= 32'b0;
            crc_state <= 32'hFFFFFFFF;
            puf_start <= 1'b0;
            puf_index <= 7'b0;
        end else begin
            puf_start <= 1'b0;

            if (request_pending) begin
                puf_start       <= 1'b1;
                request_pending <= 1'b0;
            end

            if (busy && puf_valid) begin
                response[puf_index] <= puf_bit;
                crc_state <= crc_bit_next;

                if (puf_index == 7'd127) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    crc <= ~crc_bit_next;
                end else begin
                    puf_index <= puf_index + 7'd1;
                    request_pending <= 1'b1;
                end
            end

            if (reg_wr && reg_addr == ADDR_CONTROL) begin
                if (reg_wdata[1]) begin
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
endmodule