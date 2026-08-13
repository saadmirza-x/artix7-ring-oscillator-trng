//=============================================================================
// Name : Muhammad Saad Bin Waqas
// Module Name : ring_osc.v—Parameterizable ring oscillator for Xilinx 7-series FPGAs
//=============================================================================
//
//Uses LUT1 primitives (NOT gates) chained in a combinational feedback loop.
// STAGES must be odd so the loop is logically unstable and oscillates.
//
// (* dont_touch *) prevents Vivado from optimizing away the loop.
// You WILL get a combinational-loop DRC warning — that is expected;
// add a timing exception in constraints (see nexys_a7.xdc in Constraint Foldder).
//=============================================================================
module ring_osc #(
    parameter STAGES = 3          //Must be odd (3, 5, 7, 9, 11 and so on)
)(
    output wire osc_out
);

    (* dont_touch = "true" *) wire [STAGES-1:0] w;

    genvar i;
    generate
        for (i = 0; i < STAGES; i = i + 1) begin : stage
            if (i == 0) begin : feedback
                //first inverter: input = last wire (closes the loop)
                (* dont_touch = "true" *)
                LUT1 #(.INIT(2'b01)) lut_inv (
                    .O  (w[0]),
                    .I0 (w[STAGES-1])
                );
            end else begin : forward
                //remaining inverters: chain through
                (* dont_touch = "true" *)
                LUT1 #(.INIT(2'b01)) lut_inv (
                    .O  (w[i]),
                    .I0 (w[i-1])
                );
            end
        end
    endgenerate

    assign osc_out = w[STAGES-1];

endmodule
