`timescale 1ns/1ps

module puf_controller_tb;
    // Register addresses used by the controller register map.
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

    logic clk = 1'b0;
    logic rst_n = 1'b1;
    logic reg_wr = 1'b0;
    logic reg_rd = 1'b0;
    logic [7:0] reg_addr = 8'b0;
    logic [31:0] reg_wdata = 32'b0;
    logic [31:0] reg_rdata;
    logic puf_start;
    logic [6:0] puf_index;
    logic puf_valid;
    logic puf_bit;
    logic irq;

    puf_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .reg_wr(reg_wr),
        .reg_rd(reg_rd),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_rdata(reg_rdata),
        .puf_start(puf_start),
        .puf_index(puf_index),
        .puf_valid(puf_valid),
        .puf_bit(puf_bit),
        .irq(irq)
    );

    puf_macro_model puf_model (
        .clk(clk),
        .rst_n(rst_n),
        .puf_start(puf_start),
        .puf_index(puf_index),
        .puf_valid(puf_valid),
        .puf_bit(puf_bit)
    );

    // Shared utility tasks and model helpers.
    `include "tb/tests/test_common.sv"

    // Register each test case in the top-level testbench.
    `include "tb/tests/test_reset_and_default_acquisition.sv"
    `include "tb/tests/test_masked_transfer.sv"
    `include "tb/tests/test_reset_command.sv"

    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/sim/puf_controller_tb.vcd");
        $dumpvars(0, puf_controller_tb);

        reset_dut();
        test_reset_and_default_acquisition();
        test_masked_transfer();
        test_reset_command();

        $display("puf_controller_tb: PASS");
        $finish;
    end
endmodule
