//=============================================================================
// Name : Muhammad Saad Bin Waqas
// Module Name : uart_tx.v — Simple 8-N-1 UART transmitter
//================================================================================
//
// Accepts a byte on (data, valid) and shifts it out serially at BAUD rate (11500).
// ready is high when the transmitter can accept a new byte.
// If valid is asserted while ready is low, the byte is ignored (dropped).
//=============================================================================
module uart_tx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD     = 115_200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data,
    input  wire       valid,
    output wire       tx,
    output wire       ready
);

    localparam DIVISOR = CLK_FREQ / BAUD;          //868 for 100 MHz / 115200

    // States: 0 = idle, 1 = start bit, 2–9 = data[0]–data[7], 10 = stop bit
    reg [3:0]  state;
    reg [15:0] baud_cnt;
    reg [7:0]  tx_data;
    reg        tx_reg;

    assign tx    = tx_reg;
    assign ready = (state == 4'd0);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= 4'd0;
            baud_cnt <= 16'd0;
            tx_reg   <= 1'b1;                     // idle line = high
            tx_data  <= 8'd0;
        end else begin
            case (state)
                // ----- Idle state -----
                4'd0: begin
                    tx_reg <= 1'b1;
                    if (valid) begin
                        tx_data  <= data;
                        state    <= 4'd1;
                        baud_cnt <= 16'd0;
                        tx_reg   <= 1'b0;          // drive start bit now
                    end
                end

                // ----- Start bit -----
                4'd1: begin
                    if (baud_cnt == DIVISOR - 1) begin
                        baud_cnt <= 16'd0;
                        state    <= 4'd2;
                        tx_reg   <= tx_data[0];    // first data bit
                    end else
                        baud_cnt <= baud_cnt + 1'b1;
                end

                // ----- DATA BITS 0–6 -----
                4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8: begin
                    if (baud_cnt == DIVISOR - 1) begin
                        baud_cnt <= 16'd0;
                        state    <= state + 1'b1;
                        tx_reg   <= tx_data[state - 1]; // next data bit (LSB first)
                    end else
                        baud_cnt <= baud_cnt + 1'b1;
                end

                // ----- DATA bit 7 (last) -----
                4'd9: begin
                    if (baud_cnt == DIVISOR - 1) begin
                        baud_cnt <= 16'd0;
                        state    <= 4'd10;
                        tx_reg   <= 1'b1;          //stop bit
                    end else
                        baud_cnt <= baud_cnt + 1'b1;
                end

                // STOP bit
                4'd10: begin
                    if (baud_cnt == DIVISOR - 1) begin
                        baud_cnt <= 16'd0;
                        state    <= 4'd0;
                        tx_reg   <= 1'b1;
                    end else
                        baud_cnt <= baud_cnt + 1'b1;
                end

                default: state <= 4'd0;
            endcase
        end
    end

endmodule
