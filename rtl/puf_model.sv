module puf_macro_model (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        puf_start,
    input  logic [6:0]  puf_index,
    output logic        puf_valid,
    output logic        puf_bit
);

    logic [31:0] lfsr_state;

    always_ff @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_state <= 32'hA5A5A5A5;
            puf_valid  <= 1'b0;
            puf_bit    <= 1'b0;
        end else begin
            puf_valid <= 1'b0;

            if (puf_start) begin
                puf_valid <= 1'b1;
                puf_bit   <= lfsr_state[0] ^ lfsr_state[3] ^ lfsr_state[5] ^ lfsr_state[7];
                lfsr_state <= {lfsr_state[30:0], lfsr_state[31] ^ lfsr_state[21] ^ lfsr_state[1] ^ lfsr_state[0]};
            end
        end
    end
endmodule
