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
