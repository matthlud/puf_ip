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
