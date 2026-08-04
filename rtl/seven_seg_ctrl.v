//=============================================================================
// seven_seg_ctrl.v — 4-digit hex display for Nexys A7
//
// Displays a 16-bit value as four hex digits on the rightmost four
// 7-segment digits.  The remaining four anodes are kept off.
//
// FREEZE input: when high, the displayed value stops updating (the
// internal register holds its last value).  When low, it tracks
// display_val continuously.
//
// Digit multiplexing runs off a counter derived from the system clock
// (~100 MHz → ~1.5 kHz per-digit refresh, well above flicker threshold).
//=============================================================================
module seven_seg_ctrl (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] display_val,
    input  wire        freeze,         // SW[0]
    output reg  [7:0]  an,             // anodes  (active low)
    output reg  [6:0]  seg             // cathodes (active low)  segments a–g
);

    //------------------------------------------------------------------
    // Freeze register
    //------------------------------------------------------------------
    reg [15:0] held_val;

    always @(posedge clk or posedge rst) begin
        if (rst)
            held_val <= 16'h0000;
        else if (!freeze)
            held_val <= display_val;
    end

    //------------------------------------------------------------------
    // Refresh counter — upper 2 bits select which digit is active
    //------------------------------------------------------------------
    reg [19:0] refresh_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst)
            refresh_cnt <= 20'd0;
        else
            refresh_cnt <= refresh_cnt + 1'b1;
    end

    wire [1:0] digit_sel = refresh_cnt[19:18];

    //------------------------------------------------------------------
    // Digit mux — pick the 4-bit nibble for the active digit
    //------------------------------------------------------------------
    reg [3:0] hex_digit;

    always @(*) begin
        an = 8'hFF;                         // all digits off by default
        case (digit_sel)
            2'd0: begin an[0] = 1'b0; hex_digit = held_val[ 3: 0]; end
            2'd1: begin an[1] = 1'b0; hex_digit = held_val[ 7: 4]; end
            2'd2: begin an[2] = 1'b0; hex_digit = held_val[11: 8]; end
            2'd3: begin an[3] = 1'b0; hex_digit = held_val[15:12]; end
            default: begin an = 8'hFF; hex_digit = 4'h0; end
        endcase
    end

    //------------------------------------------------------------------
    // Hex → 7-segment decoder   (active low: 0 lights a segment)
    //
    //       a
    //      ---
    //  f |     | b
    //      -g-
    //  e |     | c
    //      ---
    //       d
    //
    // Bit order: seg = {g, f, e, d, c, b, a}
    //------------------------------------------------------------------
    always @(*) begin
        case (hex_digit)
            //                gfedcba
            4'h0: seg = 7'b100_0000;
            4'h1: seg = 7'b111_1001;
            4'h2: seg = 7'b010_0100;
            4'h3: seg = 7'b011_0000;
            4'h4: seg = 7'b001_1001;
            4'h5: seg = 7'b001_0010;
            4'h6: seg = 7'b000_0010;
            4'h7: seg = 7'b111_1000;
            4'h8: seg = 7'b000_0000;
            4'h9: seg = 7'b001_0000;
            4'hA: seg = 7'b000_1000;
            4'hB: seg = 7'b000_0011;
            4'hC: seg = 7'b100_0110;
            4'hD: seg = 7'b010_0001;
            4'hE: seg = 7'b000_0110;
            4'hF: seg = 7'b000_1110;
            default: seg = 7'b111_1111;     // blank
        endcase
    end

endmodule
