module puf_controller_formal;
    (* gclk *) logic clk;
    (* anyseq *) logic rst_n;

    (* anyseq *) logic        reg_wr;
    (* anyseq *) logic        reg_rd;
    (* anyseq *) logic [7:0]  reg_addr;
    (* anyseq *) logic [31:0] reg_wdata;
    logic [31:0] reg_rdata;
    logic        puf_start;
    logic [6:0]  puf_index;
    (* anyseq *) logic        puf_valid;
    (* anyseq *) logic        puf_bit;
    logic        irq;

    logic response_pending;

    initial begin
        clk = 1'b0;
        response_pending = 1'b0;
    end

    always @($global_clock)
        clk <= !clk;

    // Start with reset sampled once, then prove behavior from the reset state.
    always @(posedge clk) begin
        if ($initstate)
            assume (!rst_n);
        else
            assume (rst_n);

        if (!rst_n) begin
            response_pending <= 1'b0;
        end else begin
            assume (!(reg_wr && reg_rd));
            assume (!puf_valid || response_pending || puf_start);

            if (puf_start)
                response_pending <= 1'b1;
            if (puf_valid)
                response_pending <= 1'b0;
        end
    end

    puf_controller dut (
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

    always @(posedge clk) begin
        if (reg_rd && reg_addr == 8'h04)
            assert (irq == (reg_rdata[2] | reg_rdata[1]));

        if (reg_rd &&
            reg_addr != 8'h04 &&
            reg_addr != 8'h08 &&
            reg_addr != 8'h0C &&
            reg_addr != 8'h10 &&
            reg_addr != 8'h14 &&
            reg_addr != 8'h18 &&
            reg_addr != 8'h1C &&
            reg_addr != 8'h20 &&
            reg_addr != 8'h24 &&
            reg_addr != 8'h28)
            assert (reg_rdata == 32'b0);
    end
endmodule
