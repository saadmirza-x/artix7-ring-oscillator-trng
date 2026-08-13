//=============================================================================
// Name : Muhammad Saad Bin Waqas
// Module Name : von_neumann.v — Von Neumann de-biasing corrector
//================================================================================
//
// Reads raw entropy bits in pairs:
//   (0, 1) gives output 0        (1, 0) will give output 1
//   (0, 0) will get discard         (1, 1) will get discard
//
// This removes any first-order bias (e.g. 60 % ones) at the cost of
// throughput — roughly 75 % of pairs are discarded when the source is
// near 50/50, more when it is heavily biased.
//
// The mapping direction (01→0 vs 01→1) is arbitrary and self-consistent;
// either convention removes bias equally.
//=============================================================================
module von_neumann (
    input  wire clk,
    input  wire rst,
    input  wire raw_bit,          // one raw entropy bit
    input  wire raw_valid,        //pulse high for one clk when raw_bit is new
    output reg  corr_bit,         // corrected output bit
    output reg  corr_valid        // pulse high for one clk when corr_bit is new
);

    reg first_bit;                //stored first bit of current pair
    reg have_first;               //1 = waiting for second bit

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            have_first <= 1'b0;
            first_bit  <= 1'b0;
            corr_bit   <= 1'b0;
            corr_valid <= 1'b0;
        end else begin
            corr_valid <= 1'b0;                // default: no output this cycle

            if (raw_valid) begin
                if (!have_first) begin
                    //first bit of pair: just store it ---
                    first_bit  <= raw_bit;
                    have_first <= 1'b1;
                end else begin
                    //-second bit of pair: compare ---
                    have_first <= 1'b0;        // reset for next pair
                    if (first_bit != raw_bit) begin
                        corr_bit   <= first_bit;
                        corr_valid <= 1'b1;
                    end
                    // if first_bit == raw_bit → discard silently
                end
            end
        end
    end

endmodule
