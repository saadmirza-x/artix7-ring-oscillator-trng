## =============================================================================
## Name : Muhammad Saad Bin Waqas
## Module Name : Constraint (.xdc file)
## ================================================================================
## Nexys A7 (Artix-7) — Pin constraints for TRNG project
##
## Active pins only.  Active-low reset button, 16 switches, 16 LEDs,
## 8-digit 7-segment display, UART TX, 100 MHz oscillator.
## ==========================================================================

## ----- 100 MHz system clock -----
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports CLK100MHZ]
create_clock -name sys_clk -period 10.000 [get_ports CLK100MHZ]

## ----- Reset (active-low CPU reset button) -----
set_property -dict { PACKAGE_PIN C12  IOSTANDARD LVCMOS33 } [get_ports CPU_RESETN]

## ----- Switches -----
set_property -dict { PACKAGE_PIN J15  IOSTANDARD LVCMOS33 } [get_ports {SW[0]}]
set_property -dict { PACKAGE_PIN L16  IOSTANDARD LVCMOS33 } [get_ports {SW[1]}]
set_property -dict { PACKAGE_PIN M13  IOSTANDARD LVCMOS33 } [get_ports {SW[2]}]
set_property -dict { PACKAGE_PIN R15  IOSTANDARD LVCMOS33 } [get_ports {SW[3]}]
set_property -dict { PACKAGE_PIN R17  IOSTANDARD LVCMOS33 } [get_ports {SW[4]}]
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports {SW[5]}]
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports {SW[6]}]
set_property -dict { PACKAGE_PIN R13  IOSTANDARD LVCMOS33 } [get_ports {SW[7]}]
set_property -dict { PACKAGE_PIN T8   IOSTANDARD LVCMOS18 } [get_ports {SW[8]}]
set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS18 } [get_ports {SW[9]}]
set_property -dict { PACKAGE_PIN R16  IOSTANDARD LVCMOS33 } [get_ports {SW[10]}]
set_property -dict { PACKAGE_PIN T13  IOSTANDARD LVCMOS33 } [get_ports {SW[11]}]
set_property -dict { PACKAGE_PIN H6   IOSTANDARD LVCMOS33 } [get_ports {SW[12]}]
set_property -dict { PACKAGE_PIN U12  IOSTANDARD LVCMOS33 } [get_ports {SW[13]}]
set_property -dict { PACKAGE_PIN U11  IOSTANDARD LVCMOS33 } [get_ports {SW[14]}]
set_property -dict { PACKAGE_PIN V10  IOSTANDARD LVCMOS33 } [get_ports {SW[15]}]

## ----- LEDs -----
set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS33 } [get_ports {LED[0]}]
set_property -dict { PACKAGE_PIN K15  IOSTANDARD LVCMOS33 } [get_ports {LED[1]}]
set_property -dict { PACKAGE_PIN J13  IOSTANDARD LVCMOS33 } [get_ports {LED[2]}]
set_property -dict { PACKAGE_PIN N14  IOSTANDARD LVCMOS33 } [get_ports {LED[3]}]
set_property -dict { PACKAGE_PIN R18  IOSTANDARD LVCMOS33 } [get_ports {LED[4]}]
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {LED[5]}]
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports {LED[6]}]
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {LED[7]}]
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {LED[8]}]
set_property -dict { PACKAGE_PIN T15  IOSTANDARD LVCMOS33 } [get_ports {LED[9]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {LED[10]}]
set_property -dict { PACKAGE_PIN T16  IOSTANDARD LVCMOS33 } [get_ports {LED[11]}]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {LED[12]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {LED[13]}]
set_property -dict { PACKAGE_PIN V12  IOSTANDARD LVCMOS33 } [get_ports {LED[14]}]
set_property -dict { PACKAGE_PIN V11  IOSTANDARD LVCMOS33 } [get_ports {LED[15]}]

## ----- 7-Segment Display (active-low cathodes) -----
set_property -dict { PACKAGE_PIN T10  IOSTANDARD LVCMOS33 } [get_ports {SEG[0]}]
set_property -dict { PACKAGE_PIN R10  IOSTANDARD LVCMOS33 } [get_ports {SEG[1]}]
set_property -dict { PACKAGE_PIN K16  IOSTANDARD LVCMOS33 } [get_ports {SEG[2]}]
set_property -dict { PACKAGE_PIN K13  IOSTANDARD LVCMOS33 } [get_ports {SEG[3]}]
set_property -dict { PACKAGE_PIN P15  IOSTANDARD LVCMOS33 } [get_ports {SEG[4]}]
set_property -dict { PACKAGE_PIN T11  IOSTANDARD LVCMOS33 } [get_ports {SEG[5]}]
set_property -dict { PACKAGE_PIN L18  IOSTANDARD LVCMOS33 } [get_ports {SEG[6]}]

## ----- 7-Segment Anodes (active-low) -----
set_property -dict { PACKAGE_PIN J17  IOSTANDARD LVCMOS33 } [get_ports {AN[0]}]
set_property -dict { PACKAGE_PIN J18  IOSTANDARD LVCMOS33 } [get_ports {AN[1]}]
set_property -dict { PACKAGE_PIN T9   IOSTANDARD LVCMOS33 } [get_ports {AN[2]}]
set_property -dict { PACKAGE_PIN J14  IOSTANDARD LVCMOS33 } [get_ports {AN[3]}]
set_property -dict { PACKAGE_PIN P14  IOSTANDARD LVCMOS33 } [get_ports {AN[4]}]
set_property -dict { PACKAGE_PIN T14  IOSTANDARD LVCMOS33 } [get_ports {AN[5]}]
set_property -dict { PACKAGE_PIN K2   IOSTANDARD LVCMOS33 } [get_ports {AN[6]}]
set_property -dict { PACKAGE_PIN U13  IOSTANDARD LVCMOS33 } [get_ports {AN[7]}]

## ----- UART TX (FPGA to USB-UART bridge) -----
set_property -dict { PACKAGE_PIN D4   IOSTANDARD LVCMOS33 } [get_ports UART_RXD_OUT]

## ==========================================================================
## Ring oscillator loop handling
##
## 1. LUTLP-1 DRC: Vivado flags combinational loops as an ERROR by default,
##    which blocks implementation entirely.  We downgrade it to a warning
##    because these loops are intentional (they ARE the entropy source).
##
## 2. ALLOW_COMBINATORIAL_LOOPS: tells opt_design not to break the loops.
##
## 3. set_false_path: tells timing analysis to skip these paths (they have
##    no meaningful timing to analyse).
## ==========================================================================

## Downgrade the combinational-loop DRC from ERROR to WARNING
set_property SEVERITY {Warning} [get_drc_checks LUTLP-1]

## Allow the loops through opt_design without removal
## (net names confirmed from DRC message: u_entropy/u_ro4/w[0], etc.)
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *u_ro*/w*}]

## Tell timing analysis to ignore the oscillator paths
## (brackets in the old pattern were being parsed as Tcl character classes
##  and never matched the literal names like stage[0].feedback.lut_inv)
set_false_path -through [get_pins -hierarchical -filter {NAME =~ *u_ro*lut_inv/O}]

## Async domain crossing is handled by our 2-stage synchroniser
set_false_path -to [get_pins -hierarchical -filter {NAME =~ *u_entropy/sync_meta/D}]
