`timescale 1ns/1ps

module puf_controller_tb;
    logic clk = 1'b0;
    logic rst_n = 1'b1;
    logic reg_wr = 1'b0;
    logic reg_rd = 1'b0;
    logic [7:0] reg_addr = 8'b0;
    logic [31:0] reg_wdata = 32'b0;
    logic [31:0] reg_rdata;
    logic puf_start;
    logic [6:0] puf_index;
    logic puf_valid = 1'b0;
    logic puf_bit = 1'b0;
    logic irq;

    logic [127:0] expected_response;
    logic [31:0] expected_crc;
    logic previous_puf_start = 1'b0;
    integer request_count = 0;
    integer i;

    puf_controller dut (
        .clk,
        .rst_n,
        .reg_wr,
        .reg_rd,
        .reg_addr,
        .reg_wdata,
        .reg_rdata,
        .puf_start,
        .puf_index,
        .puf_valid,
        .puf_bit,
        .irq
    );

    always #5 clk = ~clk;

    always @(negedge clk) begin
        puf_valid = 1'b0;
        if (puf_start && previous_puf_start) begin
            $fatal(1, "puf_start was asserted in consecutive cycles");
        end
        previous_puf_start = puf_start;

        if (puf_start) begin
            request_count = request_count + 1;
            puf_bit = puf_index[0] ^ puf_index[3] ^ puf_index[5];
            puf_valid = 1'b1;
        end
    end

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
            $fatal(1, "read %02h: got %08h, expected %08h",
                   address, reg_rdata, expected);
        end
        reg_rd = 1'b0;
    endtask

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

    initial begin
        expected_response = 128'b0;
        #1;
        rst_n = 1'b0;
        #2;
        rst_n = 1'b1;

        expect_read(8'h04, 32'b0);
        expect_read(8'h08, 32'b0);
        expect_read(8'h18, 32'b0);

        write_reg(8'h00, 32'h00000001);
        expect_read(8'h04, 32'h00000001);

        write_reg(8'h00, 32'h00000001);
        expect_read(8'h04, 32'h00000005);

        for (i = 0; i < 128; i = i + 1) begin
            expected_response[i] = (i[0] ^ i[3] ^ i[5]);
        end
        expected_crc = crc32_response(expected_response);

        wait (dut.done);
        expect_read(8'h04, 32'h00000006);
        expect_read(8'h08, expected_response[31:0]);
        expect_read(8'h0C, expected_response[63:32]);
        expect_read(8'h10, expected_response[95:64]);
        expect_read(8'h14, expected_response[127:96]);
        expect_read(8'h18, expected_crc);
        if (request_count != 128) begin
            $fatal(1, "observed %0d PUF requests, expected 128", request_count);
        end

        write_reg(8'h00, 32'h00000002);
        expect_read(8'h04, 32'b0);
        expect_read(8'h08, 32'b0);
        expect_read(8'h18, 32'b0);

        write_reg(8'h00, 32'h00000003);
        expect_read(8'h04, 32'b0);

        $display("puf_controller_tb: PASS");
        $finish;
    end
endmodule
