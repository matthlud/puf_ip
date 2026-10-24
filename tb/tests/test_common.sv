// Shared helper tasks/functions used by all test cases.

// Register write helper used by all tests.
task automatic write_reg(input logic [7:0] address, input logic [31:0] data);
    @(negedge clk);
    reg_addr = address;
    reg_wdata = data;
    reg_wr = 1'b1;
    @(negedge clk);
    reg_wr = 1'b0;
endtask

// Read helper with fail-fast checking against the expected value.
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

// Wait until the controller reports completion.
task automatic wait_for_done();
    while (!dut.done) begin
        @(negedge clk);
    end
endtask

// Wait until the controller reports busy.
task automatic wait_until_busy();
    while (!dut.busy) begin
        @(negedge clk);
    end
endtask

// Reset the DUT and all local stimulus signals to a known idle state.
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

// Model-based helper functions for expected response and CRC generation.
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

function automatic logic [31:0] crc32_masked_response(input logic [127:0] data, input logic [127:0] mask);
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
