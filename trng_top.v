//=============================================================================
// trng_top.v — Top-level TRNG system for Nexys A7
//
// Signal flow:
//   ring oscillators → XOR → synchroniser → decimation → raw bits
//   raw bits → Von Neumann corrector → corrected bits
//   corrected bits → 16-bit shift register → 7-segment display (hex)
//   corrected bits → 8-bit shift register → UART TX → laptop
//
// Controls:
//   SW[0]  = freeze display (1 = hold, 0 = run)
//   CPU_RESETN = active-low system reset
//
// Outputs:
//   7-segment (rightmost 4 digits): current 16-bit random word in hex
//   LED[0]        : raw entropy bit (toggles fast — appears dim)
//   LED[1]        : corrected-bit valid pulse (brief flickers)
//   LED[9:2]      : last 8 corrected bits
//   LED[15]       : heartbeat (slow blink proving the design is alive)
//   UART_RXD_OUT  : 115200-baud stream of corrected bytes to laptop
//=============================================================================
module trng_top (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,        // active-low reset button
    input  wire [15:0] SW,
    output wire [15:0] LED,
    output wire [7:0]  AN,
    output wire [6:0]  SEG,
    output wire        UART_RXD_OUT       // FPGA TX → USB-UART bridge RX
);

    wire clk = CLK100MHZ;
    wire rst = ~CPU_RESETN;

    //==================================================================
    // 1.  ENTROPY SOURCE
    //==================================================================
    wire       raw_bit;
    wire       raw_valid;
    wire [4:0] ro_debug;

    entropy_source #(
        .DECIM_BITS(8)                     // sample every 256 clocks
    ) u_entropy (
        .clk       (clk),
        .rst       (rst),
        .raw_bit   (raw_bit),
        .raw_valid (raw_valid),
        .ro_debug  (ro_debug)
    );

    //==================================================================
    // 2.  VON NEUMANN CORRECTOR
    //==================================================================
    wire corr_bit;
    wire corr_valid;

    von_neumann u_corrector (
        .clk        (clk),
        .rst        (rst),
        .raw_bit    (raw_bit),
        .raw_valid  (raw_valid),
        .corr_bit   (corr_bit),
        .corr_valid (corr_valid)
    );

    //==================================================================
    // 3.  COLLECT CORRECTED BITS → 16-BIT WORD FOR DISPLAY
    //==================================================================
    reg [15:0] random_word;

    always @(posedge clk or posedge rst) begin
        if (rst)
            random_word <= 16'h0000;
        else if (corr_valid)
            random_word <= {random_word[14:0], corr_bit};
    end

    //==================================================================
    // 4.  7-SEGMENT DISPLAY
    //==================================================================
    seven_seg_ctrl u_display (
        .clk         (clk),
        .rst         (rst),
        .display_val (random_word),
        .freeze      (SW[0]),
        .an          (AN),
        .seg         (SEG)
    );

    //==================================================================
    // 5.  COLLECT CORRECTED BITS → 8-BIT BYTE FOR UART
    //==================================================================
    reg [7:0] uart_byte_shift;
    reg [7:0] uart_byte_out;
    reg [2:0] uart_bit_cnt;
    reg       uart_byte_valid;
    wire      uart_ready;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            uart_byte_shift <= 8'd0;
            uart_byte_out   <= 8'd0;
            uart_bit_cnt    <= 3'd0;
            uart_byte_valid <= 1'b0;
        end else begin
            uart_byte_valid <= 1'b0;               // default: no byte ready
            if (corr_valid) begin
                uart_byte_shift <= {uart_byte_shift[6:0], corr_bit};
                if (uart_bit_cnt == 3'd7) begin
                    // full byte assembled — latch it and signal UART
                    uart_byte_out   <= {uart_byte_shift[6:0], corr_bit};
                    uart_byte_valid <= 1'b1;
                    uart_bit_cnt    <= 3'd0;
                end else begin
                    uart_bit_cnt <= uart_bit_cnt + 1'b1;
                end
            end
        end
    end

    //==================================================================
    // 6.  UART TRANSMITTER
    //==================================================================
    uart_tx #(
        .CLK_FREQ (100_000_000),
        .BAUD     (115_200)
    ) u_uart (
        .clk   (clk),
        .rst   (rst),
        .data  (uart_byte_out),
        .valid (uart_byte_valid & uart_ready),     // drop if busy
        .tx    (UART_RXD_OUT),
        .ready (uart_ready)
    );

    //==================================================================
    // 7.  LED INDICATORS
    //==================================================================
    // Heartbeat — blink LED[15] slowly so you know the design is running
    reg [25:0] heartbeat_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) heartbeat_cnt <= 0;
        else     heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end

    // Last 8 corrected bits (visual entropy indicator)
    reg [7:0] last_8_bits;
    always @(posedge clk or posedge rst) begin
        if (rst)
            last_8_bits <= 8'd0;
        else if (corr_valid)
            last_8_bits <= {last_8_bits[6:0], corr_bit};
    end

    assign LED[0]    = raw_bit;                     // raw entropy
    assign LED[1]    = corr_valid;                   // corrector output pulse
    assign LED[9:2]  = last_8_bits;                  // recent corrected bits
    assign LED[14:10]= 5'b0;
    assign LED[15]   = heartbeat_cnt[25];            // ~1.5 Hz blink

endmodule
