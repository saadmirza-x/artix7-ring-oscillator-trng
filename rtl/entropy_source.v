//=============================================================================
// entropy_source.v — Multi-oscillator jitter sampler
//
// Five ring oscillators of different odd lengths run free.  Their outputs
// are XORed, then captured into the system clock domain through a 2-stage
// synchroniser.  A decimation counter emits one sample every DECIM_BITS
// system-clock cycles so that successive samples are less correlated.
//
// The first synchroniser flip-flop may go metastable — that is expected
// and is actually part of the entropy mechanism.  The second stage
// resolves metastability before the rest of the design sees the signal.
//=============================================================================
module entropy_source #(
    parameter DECIM_BITS = 8       // sample once every 2^DECIM_BITS clocks
                                   // 8 → every 256 clocks → ~390 k samples/s
)(
    input  wire clk,
    input  wire rst,
    output reg  raw_bit,
    output reg  raw_valid,
    output wire [4:0] ro_debug     // individual RO states for LEDs
);

    //------------------------------------------------------------------
    // Ring oscillators — different lengths give different free-running
    // frequencies, so their combined jitter has more entropy.
    //------------------------------------------------------------------
    wire ro0, ro1, ro2, ro3, ro4;

    ring_osc #(.STAGES(3))  u_ro0 (.osc_out(ro0));
    ring_osc #(.STAGES(5))  u_ro1 (.osc_out(ro1));
    ring_osc #(.STAGES(7))  u_ro2 (.osc_out(ro2));
    ring_osc #(.STAGES(9))  u_ro3 (.osc_out(ro3));
    ring_osc #(.STAGES(11)) u_ro4 (.osc_out(ro4));

    assign ro_debug = {ro4, ro3, ro2, ro1, ro0};

    //------------------------------------------------------------------
    // XOR combiner
    //------------------------------------------------------------------
    wire combined = ro0 ^ ro1 ^ ro2 ^ ro3 ^ ro4;

    //------------------------------------------------------------------
    // 2-stage synchroniser (async → clk domain)
    //------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg sync_meta;
    (* ASYNC_REG = "TRUE" *) reg sync_safe;

    always @(posedge clk) begin
        sync_meta <= combined;
        sync_safe <= sync_meta;
    end

    //------------------------------------------------------------------
    // Decimation counter — only emit a sample when it rolls over
    //------------------------------------------------------------------
    reg [DECIM_BITS-1:0] decim_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            decim_cnt <= 0;
            raw_bit   <= 1'b0;
            raw_valid <= 1'b0;
        end else begin
            decim_cnt <= decim_cnt + 1'b1;
            if (decim_cnt == {DECIM_BITS{1'b1}}) begin   // all ones → rollover
                raw_bit   <= sync_safe;
                raw_valid <= 1'b1;
            end else begin
                raw_valid <= 1'b0;
            end
        end
    end

endmodule
