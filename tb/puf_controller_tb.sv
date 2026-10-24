`timescale 1ns/1ps

module puf_controller_tb;
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

    always #5 clk = ~clk;

    function automatic logic [31:0] next_lfsr_state(input logic [31:0] state);
        begin
            next_lfsr_state = {state[30:0], state[31] ^ state[21] ^ state[1] ^ state[0]};
        end
    endfunction

    function automatic logic prbs_bit_for_index(input integer index);
        logic [31:0] state;
        integer j;
        begin
            state = 32'hA5A5A5A5;
            for (j = 0; j < index; j = j + 1) begin
                state = next_lfsr_state(state);
            end
            prbs_bit_for_index = state[0] ^ state[3] ^ state[5] ^ state[7];
        end
    endfunction

    function automatic logic [31:0] crc32_response(input logic [127:0] data);
        logic [31:0] crc_value;
        logic feedback;
        integer bit_index;
        begin
            crc_value = 32'hFFFFFFFF;
            for (bit_index = 0; bit_index < 128; bit_index = bit_index + 1) begin
                feedback = crc_value[0] ^ data[bit_index];
                crc_value = crc_value >> 1;
                if (feedback) begin
                    crc_value = crc_value ^ 32'hEDB88320;
                end
            end
            crc32_response = ~crc_value;
        end
    endfunction

    function automatic logic [31:0] crc32_masked_response(
        input logic [127:0] data,
        input logic [127:0] mask
    );
        logic [31:0] crc_value;
        logic feedback;
        integer bit_index;
        begin
            crc_value = 32'hFFFFFFFF;
            for (bit_index = 0; bit_index < 128; bit_index = bit_index + 1) begin
                if (mask[bit_index]) begin
                    feedback = crc_value[0] ^ data[bit_index];
                    crc_value = crc_value >> 1;
                    if (feedback) begin
                        crc_value = crc_value ^ 32'hEDB88320;
                    end
                end
            end
            crc32_masked_response = ~crc_value;
        end
    endfunction

    task automatic write_reg(input logic [7:0] address, input logic [31:0] data);
        @(negedge clk);
        reg_addr = address;
        reg_wdata = data;
        reg_wr = 1'b1;
        @(negedge clk);
        reg_wr = 1'b0;
    endtask

    task automatic expect_read(input logic [7:0] address, input logic [31:0] expected);
        @(negedge clk);
        reg_addr = address;
        reg_rd = 1'b1;
        #1;
        if (reg_rdata !== expected) begin
            $fatal(1, "read %02h: got %08h, expected %08h", address, reg_rdata, expected);
        end
        reg_rd = 1'b0;
    endtask

    task automatic wait_for_done();
        while (!dut.done) begin
            @(negedge clk);
        end
    endtask

    task automatic wait_until_busy();
        while (!dut.busy) begin
            @(negedge clk);
        end
    endtask

    task automatic reset_dut();
        rst_n = 1'b0;
        reg_wr = 1'b0;
        reg_rd = 1'b0;
        reg_addr = 8'b0;
        reg_wdata = 32'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
    endtask

    task automatic test_reset_and_default_acquisition();
        logic [127:0] expected_response;
        logic [31:0] expected_crc;
        integer i;

        $display("[test] reset and default acquisition");
        reset_dut();

        expect_read(ADDR_STATUS, 32'h00000000);
        expect_read(ADDR_DATA0, 32'h00000000);
        expect_read(ADDR_DATA1, 32'h00000000);
        expect_read(ADDR_DATA2, 32'h00000000);
        expect_read(ADDR_DATA3, 32'h00000000);
        expect_read(ADDR_CRC, 32'h00000000);
        expect_read(ADDR_MASK0, 32'hFFFFFFFF);
        expect_read(ADDR_MASK1, 32'hFFFFFFFF);
        expect_read(ADDR_MASK2, 32'hFFFFFFFF);
        expect_read(ADDR_MASK3, 32'hFFFFFFFF);

        write_reg(ADDR_CONTROL, 32'h00000001);
        wait_until_busy();

        for (i = 0; i < 128; i = i + 1) begin
            expected_response[i] = prbs_bit_for_index(i);
        end
        expected_crc = crc32_response(expected_response);

        wait_for_done();
        expect_read(ADDR_STATUS, 32'h00000002);
        expect_read(ADDR_DATA0, expected_response[31:0]);
        expect_read(ADDR_DATA1, expected_response[63:32]);
        expect_read(ADDR_DATA2, expected_response[95:64]);
        expect_read(ADDR_DATA3, expected_response[127:96]);
        expect_read(ADDR_CRC, expected_crc);
    endtask

    task automatic test_masked_transfer();
        logic [127:0] expected_response;
        logic [127:0] expected_input_bits;
        logic [127:0] expected_mask;
        logic [31:0] expected_crc;
        integer i;

        $display("[test] masked transfer");
        reset_dut();

        for (i = 0; i < 128; i = i + 1) begin
            expected_mask[i] = (i % 2 == 0) ? 1'b1 : 1'b0;
            expected_input_bits[i] = prbs_bit_for_index(i);
            expected_response[i] = expected_mask[i] ? expected_input_bits[i] : 1'b0;
        end
        expected_crc = crc32_masked_response(expected_input_bits, expected_mask);

        write_reg(ADDR_MASK0, 32'h55555555);
        write_reg(ADDR_MASK1, 32'h55555555);
        write_reg(ADDR_MASK2, 32'h55555555);
        write_reg(ADDR_MASK3, 32'h55555555);
        expect_read(ADDR_MASK0, 32'h55555555);
        expect_read(ADDR_MASK1, 32'h55555555);
        expect_read(ADDR_MASK2, 32'h55555555);
        expect_read(ADDR_MASK3, 32'h55555555);

        write_reg(ADDR_CONTROL, 32'h00000001);
        wait_for_done();

        expect_read(ADDR_STATUS, 32'h00000002);
        expect_read(ADDR_DATA0, expected_response[31:0]);
        expect_read(ADDR_DATA1, expected_response[63:32]);
        expect_read(ADDR_DATA2, expected_response[95:64]);
        expect_read(ADDR_DATA3, expected_response[127:96]);
        expect_read(ADDR_CRC, expected_crc);
    endtask

    task automatic test_reset_command();
        $display("[test] reset command");
        reset_dut();
        write_reg(ADDR_CONTROL, 32'h00000001);
        wait_for_done();
        write_reg(ADDR_CONTROL, 32'h00000002);
        expect_read(ADDR_STATUS, 32'h00000000);
        expect_read(ADDR_DATA0, 32'h00000000);
        expect_read(ADDR_DATA1, 32'h00000000);
        expect_read(ADDR_DATA2, 32'h00000000);
        expect_read(ADDR_DATA3, 32'h00000000);
        expect_read(ADDR_CRC, 32'h00000000);
    endtask

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
