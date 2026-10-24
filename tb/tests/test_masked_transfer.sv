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
