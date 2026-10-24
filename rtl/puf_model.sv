// Deterministic PUF macro model used for simulation.
// The model intentionally uses a small PRBS/LFSR instead of real silicon noise so
// that the controller can be tested in a reproducible and deterministic way.
module puf_macro_model (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        puf_start,
    input  logic [6:0]  puf_index,
    output logic        puf_valid,
    output logic        puf_bit
);

    // LFSR state used to generate a pseudo-random bit stream.
    // The state is seeded with a fixed value so the entire simulation is repeatable.
    logic [31:0] lfsr_state;

    // A request from the controller produces a single valid bit and then advances the
    // PRBS state for the next index.  The model is intentionally synchronous to the
    // negative clock edge so it behaves like a simple macro response generator.
    always_ff @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_state <= 32'hA5A5A5A5;
            puf_valid  <= 1'b0;
            puf_bit    <= 1'b0;
        end else begin
            // Default: no response is valid unless the controller requests one.
            puf_valid <= 1'b0;

            if (puf_start) begin
                // One-cycle valid pulse that carries the generated bit.
                puf_valid <= 1'b1;
                puf_bit   <= lfsr_state[0] ^ lfsr_state[3] ^ lfsr_state[5] ^ lfsr_state[7];

                // Advance the LFSR state so the next PUF response remains deterministic.
                lfsr_state <= {lfsr_state[30:0], lfsr_state[31] ^ lfsr_state[21] ^ lfsr_state[1] ^ lfsr_state[0]};
            end
        end
    end
endmodule
