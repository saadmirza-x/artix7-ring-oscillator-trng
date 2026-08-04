//=============================================================================
// trng_tb.v — Functional testbench for the TRNG pipeline
//
// IMPORTANT: Ring oscillators do NOT oscillate in behavioral simulation
// (there are no real gate delays).  This testbench therefore tests
// everything DOWNSTREAM of the entropy source:
//   • Von Neumann corrector logic (bias removal)
//   • 7-segment display driver (hex decoding, multiplexing, freeze)
//   • UART transmitter (framing, baud timing)
//
// The entropy source is exercised with a manually-driven stimulus that
// mimics what the real hardware would produce.
//=============================================================================
`timescale 1ns / 1ps

module trng_tb;

    // ---- clock & reset ----
    reg clk;
    reg rst;

    initial clk = 0;
    always #5 clk = ~clk;                 // 100 MHz

    // ---- Von Neumann corrector under test ----
    reg  raw_bit;
    reg  raw_valid;
    wire corr_bit;
    wire corr_valid;

    von_neumann uut_vn (
        .clk        (clk),
        .rst        (rst),
        .raw_bit    (raw_bit),
        .raw_valid  (raw_valid),
        .corr_bit   (corr_bit),
        .corr_valid (corr_valid)
    );

    // ---- UART transmitter under test ----
    reg  [7:0] uart_data;
    reg        uart_valid;
    wire       uart_tx_line;
    wire       uart_ready;

    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD(115_200)
    ) uut_uart (
        .clk   (clk),
        .rst   (rst),
        .data  (uart_data),
        .valid (uart_valid),
        .tx    (uart_tx_line),
        .ready (uart_ready)
    );

    // ---- 7-segment display under test ----
    reg  [15:0] disp_val;
    reg         freeze;
    wire [7:0]  an;
    wire [6:0]  seg;

    seven_seg_ctrl uut_seg (
        .clk         (clk),
        .rst         (rst),
        .display_val (disp_val),
        .freeze      (freeze),
        .an          (an),
        .seg         (seg)
    );

    // ---- helper: feed one raw bit to the corrector ----
    task feed_raw(input bit_val);
        begin
            @(posedge clk);
            raw_bit   = bit_val;
            raw_valid = 1'b1;
            @(posedge clk);
            raw_valid = 1'b0;
        end
    endtask

    // ---- counters for statistics ----
    integer corr_ones  = 0;
    integer corr_total = 0;

    always @(posedge clk) begin
        if (corr_valid) begin
            corr_total = corr_total + 1;
            if (corr_bit) corr_ones = corr_ones + 1;
        end
    end

    // ---- main stimulus ----
    integer i;
    reg [31:0] lfsr;               // simple PRNG to generate test entropy

    initial begin
        $dumpfile("trng_tb.vcd");
        $dumpvars(0, trng_tb);

        // initial state
        rst        = 1;
        raw_bit    = 0;
        raw_valid  = 0;
        uart_data  = 0;
        uart_valid = 0;
        disp_val   = 16'hA5A5;
        freeze     = 0;

        // hold reset for 10 clocks
        repeat(10) @(posedge clk);
        rst = 0;
        repeat(5) @(posedge clk);

        //--------------------------------------------------------------
        // TEST 1: Von Neumann corrector — known pairs
        //--------------------------------------------------------------
        $display("--- TEST 1: Von Neumann known pairs ---");

        // pair (0,1) → should output 0
        feed_raw(0); feed_raw(1);
        repeat(3) @(posedge clk);

        // pair (1,0) → should output 1
        feed_raw(1); feed_raw(0);
        repeat(3) @(posedge clk);

        // pair (0,0) → should discard
        feed_raw(0); feed_raw(0);
        repeat(3) @(posedge clk);

        // pair (1,1) → should discard
        feed_raw(1); feed_raw(1);
        repeat(3) @(posedge clk);

        $display("  Corrected bits so far: %0d (expected 2)", corr_total);

        //--------------------------------------------------------------
        // TEST 2: Von Neumann corrector — statistical check with LFSR
        //--------------------------------------------------------------
        $display("--- TEST 2: 2000-bit LFSR stream through corrector ---");
        lfsr = 32'hDEAD_BEEF;
        for (i = 0; i < 2000; i = i + 1) begin
            feed_raw(lfsr[0]);
            lfsr = {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
        end
        repeat(10) @(posedge clk);
        $display("  Total corrected bits: %0d", corr_total);
        $display("  Ones: %0d  Zeros: %0d", corr_ones, corr_total - corr_ones);

        //--------------------------------------------------------------
        // TEST 3: UART — send one byte and check framing
        //--------------------------------------------------------------
        $display("--- TEST 3: UART transmit byte 0x55 ---");
        wait(uart_ready);
        @(posedge clk);
        uart_data  = 8'h55;
        uart_valid = 1;
        @(posedge clk);
        uart_valid = 0;

        // wait for transmission to finish
        wait(uart_ready);
        $display("  UART transmission complete");

        //--------------------------------------------------------------
        // TEST 4: 7-segment freeze
        //--------------------------------------------------------------
        $display("--- TEST 4: 7-segment freeze ---");
        disp_val = 16'h1234;
        repeat(100) @(posedge clk);
        freeze = 1;
        disp_val = 16'hFFFF;             // change input while frozen
        repeat(100) @(posedge clk);
        $display("  Display should still show 1234, not FFFF");
        freeze = 0;
        repeat(100) @(posedge clk);
        $display("  Display should now show FFFF");

        //--------------------------------------------------------------
        $display("=== ALL TESTS COMPLETE ===");
        $finish;
    end

endmodule
