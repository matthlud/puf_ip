// ASIC top that combines the register controller with the deterministic PUF model.
module puf_r2g_top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        reg_wr,
    input  logic        reg_rd,
    input  logic [7:0]  reg_addr,
    input  logic [31:0] reg_wdata,
    output logic [31:0] reg_rdata,
    output logic        irq
);
    logic       puf_start;
    logic [6:0] puf_index;
    logic       puf_valid;
    logic       puf_bit;

    puf_controller u_controller (
        .clk       (clk),
        .rst_n     (rst_n),
        .reg_wr    (reg_wr),
        .reg_rd    (reg_rd),
        .reg_addr  (reg_addr),
        .reg_wdata (reg_wdata),
        .reg_rdata (reg_rdata),
        .puf_start (puf_start),
        .puf_index (puf_index),
        .puf_valid (puf_valid),
        .puf_bit   (puf_bit),
        .irq       (irq)
    );

    puf_macro_model u_puf_model (
        .clk       (clk),
        .rst_n     (rst_n),
        .puf_start (puf_start),
        .puf_index (puf_index),
        .puf_valid (puf_valid),
        .puf_bit   (puf_bit)
    );
endmodule
