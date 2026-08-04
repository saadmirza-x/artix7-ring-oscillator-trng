#!/usr/bin/env python3
"""
verify.py — Capture TRNG output over UART and run a basic monobit test.

Usage:
    python verify.py                     # auto-detect port
    python verify.py COM3                # Windows
    python verify.py /dev/ttyUSB1        # Linux
    python verify.py /dev/tty.usbserial  # macOS

Collects 1024 bytes (8192 bits) and checks whether the ones/zeros
ratio is statistically consistent with a fair coin (NIST monobit test).
"""
import sys
import math
import time

# ---------- configuration ----------
BAUD      = 115200
NUM_BYTES = 1024          # 1 KB = 8192 bits — enough for a basic monobit test
TIMEOUT   = 10            # seconds

def find_port():
    """Try to auto-detect the serial port."""
    import serial.tools.list_ports
    ports = list(serial.tools.list_ports.comports())
    for p in ports:
        desc = (p.description or "").lower()
        if any(kw in desc for kw in ["uart", "usb", "serial", "ft232", "cp210"]):
            return p.device
    if ports:
        return ports[0].device
    return None

def main():
    try:
        import serial
    except ImportError:
        print("pyserial is required.  Install it with:")
        print("    pip install pyserial")
        sys.exit(1)

    # pick port
    if len(sys.argv) > 1:
        port = sys.argv[1]
    else:
        port = find_port()
        if port is None:
            print("No serial port detected.  Pass the port name as an argument.")
            sys.exit(1)
        print(f"Auto-detected port: {port}")

    # open serial
    print(f"Opening {port} at {BAUD} baud …")
    ser = serial.Serial(port, BAUD, timeout=TIMEOUT)
    time.sleep(0.5)           # let the port settle
    ser.reset_input_buffer()  # discard any stale bytes

    print(f"Collecting {NUM_BYTES} bytes ({NUM_BYTES * 8} bits) …")
    data = ser.read(NUM_BYTES)
    ser.close()

    received = len(data)
    if received == 0:
        print("ERROR: received 0 bytes.  Check that the FPGA is programmed")
        print("and the board's USB-UART bridge is connected.")
        sys.exit(1)

    if received < NUM_BYTES:
        print(f"Warning: only received {received} of {NUM_BYTES} bytes.")

    # ---------- statistics ----------
    total_bits = received * 8
    ones       = sum(bin(b).count('1') for b in data)
    zeros      = total_bits - ones
    ratio      = ones / total_bits

    print()
    print(f"Total bits : {total_bits}")
    print(f"Ones       : {ones}  ({100 * ones / total_bits:.2f}%)")
    print(f"Zeros      : {zeros} ({100 * zeros / total_bits:.2f}%)")
    print(f"Ratio      : {ratio:.4f}  (ideal = 0.5000)")

    # ---------- NIST monobit test ----------
    # Test statistic: S = |ones - zeros| / sqrt(n)
    # Under H0 (fair coin), S ~ N(0,1).
    # p-value = erfc(S / sqrt(2)).  Pass if p >= 0.01.
    s_obs   = abs(ones - zeros) / math.sqrt(total_bits)
    p_value = math.erfc(s_obs / math.sqrt(2))

    print()
    print("NIST SP 800-22 Monobit Test")
    print(f"  S       = {s_obs:.4f}")
    print(f"  p-value = {p_value:.6f}")
    if p_value >= 0.01:
        print(f"  Result  : PASS  (p >= 0.01)")
    else:
        print(f"  Result  : FAIL  (p < 0.01)")
        print()
        print("  A failure means the output has a statistically significant")
        print("  bias toward ones or zeros.  Possible causes:")
        print("    - ring oscillators not oscillating (stuck at 0 or 1)")
        print("    - decimation counter too small (correlated samples)")
        print("    - Von Neumann corrector bypassed or wired wrong")

if __name__ == "__main__":
    main()
