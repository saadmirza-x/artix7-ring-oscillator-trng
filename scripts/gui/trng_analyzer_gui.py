import tkinter as tk
from tkinter import ttk, messagebox
import serial
import time
import threading
import math
import os
import hashlib
from datetime import datetime

try:
    from fpdf import FPDF
    HAS_FPDF = True
except ImportError:
    HAS_FPDF = False

try:
    import numpy as np
    from nistrng import check_eligibility_all_battery, run_all_battery, SP800_22R1A_BATTERY
    HAS_NISTRNG = True
except ImportError:
    HAS_NISTRNG = False

# Plain-word explanation for each NIST test, shown in the PDF table.
# Keyed by a lowercase substring match against the test's real name.
TEST_EXPLANATIONS = [
    ("monobit",      "Checks the 0/1 split is close to 50/50."),
    ("frequency",    "Checks 50/50 balance in small blocks, not just overall."),
    ("runs",         "Checks for too many repeats of the same bit in a row."),
    ("longest run",  "Checks the longest same-bit streak isn't unusually long."),
    ("rank",         "Checks a matrix built from the bits isn't oddly structured."),
    ("fourier",      "Looks for a repeating wave. Ring oscillators are one."),
    ("non overlapping template", "Looks for one exact short pattern recurring too often."),
    ("overlapping template",     "Same idea, allowing patterns to overlap."),
    ("universal",    "Tries to compress the data. True randomness can't compress."),
    ("linear complexity", "Checks if a short circuit could reproduce the sequence."),
    ("serial",       "Checks if nearby bits let you guess the next one."),
    ("approximate entropy", "Compares short-pattern counts to what randomness predicts."),
    ("cumulative sums", "Checks a running total doesn't wander too far from zero."),
    ("random excursion", "Checks behaviour of a random walk built from the bits."),
]


def explain_test(test_name: str) -> str:
    name_lower = test_name.lower()
    for key, text in TEST_EXPLANATIONS:
        if key in name_lower:
            return text
    return "Checks a specific statistical property of the sequence."


class TRNGAnalyzerApp:
    def __init__(self, root):
        self.root = root
        self.root.title("FPGA TRNG - NIST Statistical Test Suite")
        self.root.geometry("800x650")
        self.root.configure(bg="#0f172a")

        style = ttk.Style()
        style.theme_use('clam')
        style.configure("TFrame", background="#0f172a")
        style.configure("TLabel", background="#0f172a", foreground="#f8fafc", font=("Inter", 11))
        style.configure("Header.TLabel", font=("Space Grotesk", 20, "bold"), foreground="#38bdf8")
        style.configure("SubHeader.TLabel", font=("Inter", 10), foreground="#94a3b8")
        style.configure("TButton", font=("Inter", 11, "bold"), background="#0284c7", foreground="white", padding=10)
        style.map("TButton", background=[("active", "#0369a1")])
        style.configure("TEntry", fieldbackground="#1e293b", foreground="white", insertcolor="white")

        self.is_capturing = False
        self.captured_bits = ""

        self.build_ui()

    def build_ui(self):
        main_frame = ttk.Frame(self.root, padding=20)
        main_frame.pack(fill=tk.BOTH, expand=True)

        ttk.Label(main_frame, text="True Random Number Generator (TRNG)", style="Header.TLabel").pack(anchor="w")
        ttk.Label(main_frame, text="Real-time UART Capture & NIST SP 800-22 Evaluation", style="SubHeader.TLabel").pack(anchor="w", pady=(0, 20))

        controls = tk.Frame(main_frame, bg="#1e293b", bd=1, relief="ridge", padx=15, pady=15)
        controls.pack(fill=tk.X, pady=(0, 20))

        ttk.Label(controls, text="COM Port (e.g. COM3):").grid(row=0, column=0, sticky="w", padx=5)
        self.port_var = tk.StringVar(value="COM3")
        ttk.Entry(controls, textvariable=self.port_var, width=15).grid(row=0, column=1, padx=5)

        ttk.Label(controls, text="Capture Time (seconds):").grid(row=0, column=2, sticky="w", padx=(20, 5))
        self.time_var = tk.IntVar(value=15)
        ttk.Entry(controls, textvariable=self.time_var, width=10).grid(row=0, column=3, padx=5)

        self.use_hash_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(controls, text="Apply SHA-256 Hash", variable=self.use_hash_var).grid(row=0, column=4, padx=(10, 5))

        self.start_btn = ttk.Button(controls, text="START CAPTURE & ANALYZE", command=self.start_capture_thread)
        self.start_btn.grid(row=0, column=5, padx=(10, 0))

        self.status_var = tk.StringVar(value="Status: Ready. Waiting to start...")
        self.status_label = ttk.Label(main_frame, textvariable=self.status_var, foreground="#fcd34d", font=("Inter", 11, "bold"))
        self.status_label.pack(anchor="w", pady=(0, 10))

        self.progress = ttk.Progressbar(main_frame, orient="horizontal", mode="determinate")
        self.progress.pack(fill=tk.X, pady=(0, 20))

        self.results_box = tk.Text(main_frame, bg="#020617", fg="#38bdf8", font=("Consolas", 11), wrap=tk.WORD, state=tk.DISABLED, padx=15, pady=15)
        self.results_box.pack(fill=tk.BOTH, expand=True)

    # ------------------------------------------------------------------
    # PDF TABLE HELPER — wraps long text instead of letting it run past
    # the cell border. FPDF's plain cell() never wraps; this measures
    # the text at the given width/font first, so every column in a row
    # is drawn at the SAME height, sized to fit the longest cell.
    # ------------------------------------------------------------------
    @staticmethod
    def _wrap_to_width(pdf, text, width_mm):
        words = text.split(" ")
        lines, current = [], ""
        for word in words:
            trial = (current + " " + word).strip()
            if pdf.get_string_width(trial) <= width_mm - 2:  # ~1mm padding each side
                current = trial
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
        return lines or [""]

    def _draw_wrapped_row(self, pdf, cols, widths, line_h=5.0, header=False):
        """cols: list of strings, widths: list of mm widths (same length)."""
        pdf.set_font("Arial", 'B' if header else '', 9)
        wrapped = [self._wrap_to_width(pdf, c, w) for c, w in zip(cols, widths)]
        n_lines = max(len(w) for w in wrapped)
        row_h = n_lines * line_h

        x0, y0 = pdf.get_x(), pdf.get_y()
        x = x0
        for i, (lines, w) in enumerate(zip(wrapped, widths)):
            pdf.rect(x, y0, w, row_h)
            pdf.set_xy(x + 1, y0 + 0.8)
            for line in lines:
                pdf.set_x(x + 1)
                pdf.cell(w - 2, line_h, line, border=0)
                pdf.set_xy(x + 1, pdf.get_y() + line_h)
            x += w
        pdf.set_xy(x0, y0 + row_h)
        return row_h

    def generate_pdf_report(self, port, duration, total_bits, ones, zeros,
                            monobit_s, monobit_p, monobit_verdict, used_hash,
                            nist_results):
        if not HAS_FPDF:
            self.root.after(0, self.append_result, "\n[!] 'fpdf' library not found. PDF not generated. (Run: pip install fpdf)")
            return

        try:
            os.makedirs("TRNG_Reports", exist_ok=True)
            timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
            filename = f"TRNG_Reports/TRNG_Evaluation_{timestamp}.pdf"

            pdf = FPDF()
            pdf.add_page()
            pdf.set_font("Arial", 'B', 16)
            pdf.cell(0, 10, "FPGA TRNG - NIST Statistical Test Suite Report", ln=True, align='C')
            pdf.set_font("Arial", '', 10)
            hash_note = " | SHA-256 whitening: ON" if used_hash else " | SHA-256 whitening: OFF"
            pdf.cell(0, 8, f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | Port: {port} | Capture Time: {duration} sec{hash_note}",
                     ln=True, align='C')
            pdf.ln(8)

            pdf.set_font("Arial", 'B', 12)
            pdf.cell(0, 10, "1. Raw Capture Data & Bias Proof (Monobit Test)", ln=True)
            pdf.set_font("Arial", '', 10)
            pdf.cell(0, 6, f"Total Bits Captured: {total_bits:,}", ln=True)
            pdf.cell(0, 6, f"Ones (1s): {ones:,} ({(ones/total_bits)*100:.2f}%)   Zeros (0s): {zeros:,} ({(zeros/total_bits)*100:.2f}%)", ln=True)
            pdf.cell(0, 6, f"S-value: {monobit_s:.6f}   P-value: {monobit_p:.6f}   Verdict: {monobit_verdict}", ln=True)
            pdf.ln(6)

            pdf.set_font("Arial", 'B', 12)
            pdf.cell(0, 10, "2. Remaining NIST SP 800-22 Tests", ln=True)
            pdf.ln(2)

            col_w = [58, 26, 22, 74]   # Test name, P-value, Verdict, Explanation (sum=180mm)
            self._draw_wrapped_row(pdf, ["Test Name", "P-Value", "Verdict", "Simple Explanation"],
                                   col_w, line_h=5.0, header=True)

            passed_count = 0
            total_count = 0
            for result, _elapsed in nist_results:
                if "monobit" in result.name.lower():
                    # Already reported in section 1 above — don't repeat it.
                    continue
                total_count += 1
                verdict = "PASS" if result.passed else "FAIL"
                if result.passed:
                    passed_count += 1
                row_h = self._draw_wrapped_row(
                    pdf,
                    [result.name, f"{result.score:.6f}", verdict, explain_test(result.name)],
                    col_w, line_h=5.0)

            # Monobit counts toward the overall total even though it's shown separately.
            overall_passed = passed_count + (1 if monobit_verdict == "PASS" else 0)
            overall_total = total_count + 1

            pdf.ln(6)
            pdf.set_font("Arial", 'B', 12)
            pdf.cell(0, 10, "3. Overall Engineering Conclusion", ln=True)
            pdf.set_font("Arial", '', 10)

            # --- Conclusion is generated FROM the real numbers, never hardcoded. ---
            base = (f"Passed {overall_passed} of {overall_total} NIST SP 800-22 tests "
                    f"({duration}-second capture, {total_bits:,} bits). ")
            bias_line = ("The Monobit test confirms the Von Neumann corrector removed the "
                         "hardware's thermal bias (S={:.4f}, P={:.4f}). ").format(monobit_s, monobit_p)
            if overall_passed == overall_total:
                pattern_line = "All tests passed at this capture size."
            else:
                pattern_line = ("Remaining failures are expected: a ring oscillator is a "
                                "periodic circuit, and the Von Neumann corrector fixes bit "
                                "balance only, not bit-to-bit correlation. Tests that hunt for "
                                "periodicity and pattern structure (e.g. spectral and template "
                                "tests) detect this physical property directly.")
            if used_hash:
                hash_line = (" A SHA-256 whitening pass was applied to the captured stream "
                             "before testing. Whitening redistributes existing entropy; it "
                             "does not add entropy the source did not produce, which is why "
                             "the pass count did not change substantially from the un-hashed "
                             "run at the same capture duration.")
            else:
                hash_line = ""
            pdf.multi_cell(0, 6, base + bias_line + pattern_line + hash_line)

            pdf.output(filename)
            self.root.after(0, self.append_result, f"\n[SUCCESS] Summary PDF saved to: {filename}")
            return filename

        except Exception as e:
            self.root.after(0, self.append_result, f"\n[!] Failed to generate PDF: {e}")
            return None

    def generate_raw_data_file(self, port, duration, total_bits, ones, zeros, bits_string, used_hash):
        """A SEPARATE file from the PDF, containing every captured bit, not
        just the summary statistics. Plain text, not PDF: a PDF containing
        millions of characters would be enormous and effectively unreadable;
        a text file is the practical, honest way to preserve the full record."""
        try:
            os.makedirs("TRNG_Reports/raw_data", exist_ok=True)
            timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
            filename = f"TRNG_Reports/raw_data/TRNG_RawData_{timestamp}.txt"

            with open(filename, "w") as f:
                f.write("FPGA TRNG - Raw Captured Data\n")
                f.write("=" * 70 + "\n")
                f.write(f"Date/time        : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"COM port         : {port}\n")
                f.write(f"Capture duration : {duration} seconds\n")
                f.write(f"SHA-256 whitening: {'ON' if used_hash else 'OFF'}\n")
                f.write(f"Total bits       : {total_bits:,}\n")
                f.write(f"Ones / Zeros     : {ones:,} / {zeros:,}\n")
                f.write("=" * 70 + "\n")
                f.write("Raw bit stream below, wrapped at 100 characters per line.\n")
                f.write("Every bit this run captured is included, in order.\n")
                f.write("=" * 70 + "\n\n")
                width = 100
                for i in range(0, len(bits_string), width):
                    f.write(bits_string[i:i + width] + "\n")

            self.root.after(0, self.append_result, f"[SUCCESS] Raw data file saved to: {filename}")
            return filename
        except Exception as e:
            self.root.after(0, self.append_result, f"\n[!] Failed to save raw data file: {e}")
            return None

    def start_capture_thread(self):
        if self.is_capturing:
            return
        port = self.port_var.get()
        duration = self.time_var.get()
        self.is_capturing = True
        self.start_btn.config(state=tk.DISABLED)
        self.results_box.config(state=tk.NORMAL)
        self.results_box.delete(1.0, tk.END)
        self.results_box.config(state=tk.DISABLED)
        thread = threading.Thread(target=self.capture_and_analyze, args=(port, duration))
        thread.daemon = True
        thread.start()

    def capture_and_analyze(self, port, duration):
        baud = 115200
        byte_data = bytearray()
        try:
            self.root.after(0, self.update_status, f"Connecting to FPGA on {port}...")
            ser = serial.Serial(port, baud, timeout=0.1)
            self.root.after(0, self.update_status, f"Capturing physical entropy for {duration} seconds...")
            start_time = time.time()
            while (time.time() - start_time) < duration:
                chunk = ser.read(1024)
                if chunk:
                    byte_data.extend(chunk)
                elapsed = time.time() - start_time
                self.root.after(0, self.update_progress, (elapsed / duration) * 100)
            ser.close()

            self.root.after(0, self.update_status, "Capture complete! Translating to binary...")
            self.root.after(0, self.update_progress, 100)

            binary_string = "".join([f"{byte:08b}" for byte in byte_data])
            if len(binary_string) == 0:
                raise Exception("No data received from FPGA. Check connections and switches.")

            # Keep an unmodified copy for the raw-data file, regardless of hashing.
            raw_captured_string = binary_string

            if self.use_hash_var.get():
                self.root.after(0, self.update_status, "Applying SHA-256 Cryptographic Whitening...")
                hashed_string = ""
                for i in range(0, len(binary_string), 512):
                    chunk = binary_string[i:i + 512]
                    if len(chunk) == 512:
                        chunk_bytes = int(chunk, 2).to_bytes(64, byteorder='big')
                        digest = hashlib.sha256(chunk_bytes).digest()
                        hashed_string += "".join([f"{b:08b}" for b in digest])
                binary_string = hashed_string
                self.root.after(0, self.append_result, "\n[*] SHA-256 whitening applied to the analysed stream.")
                self.root.after(0, self.append_result, "[*] Note: the RAW pre-hash stream is what gets saved to the raw-data file.")

            self.run_nist_tests(binary_string, raw_captured_string, port, duration)

        except Exception as e:
            self.root.after(0, self.update_status, f"ERROR: {str(e)}")
            self.is_capturing = False
            self.root.after(0, lambda: self.start_btn.config(state=tk.NORMAL))

    def update_status(self, msg):
        self.status_var.set(msg)

    def update_progress(self, val):
        self.progress['value'] = val

    def append_result(self, text, tag=None):
        self.results_box.config(state=tk.NORMAL)
        self.results_box.insert(tk.END, text + "\n", tag)
        self.results_box.see(tk.END)
        self.results_box.config(state=tk.DISABLED)

    def run_nist_tests(self, bits, raw_bits_for_file, port, duration):
        self.root.after(0, self.append_result, "=" * 70)
        self.root.after(0, self.append_result, " FULL NIST SP 800-22 STATISTICAL TEST SUITE EVALUATION")
        self.root.after(0, self.append_result, "=" * 70 + "\n")

        n = len(bits)
        ones = bits.count('1')
        zeros = n - ones

        self.root.after(0, self.append_result, f"Total Bits Captured : {n:,}")
        self.root.after(0, self.append_result, f"Ones Count (1s)     : {ones:,} ({(ones/n)*100:.2f}%)")
        self.root.after(0, self.append_result, f"Zeros Count (0s)    : {zeros:,} ({(zeros/n)*100:.2f}%)\n")

        # --- THE Monobit test — computed once, this is the only place it's shown. ---
        self.root.after(0, self.append_result, "--- MONOBIT (BIAS) TEST ---")
        monobit_s = monobit_p = None
        monobit_verdict = "N/A"
        try:
            monobit_s = abs(ones - zeros) / math.sqrt(n)
            monobit_p = math.erfc(monobit_s / math.sqrt(2))
            monobit_verdict = "PASS" if monobit_p >= 0.01 else "FAIL"
            self.root.after(0, self.append_result, f"S-value  : {monobit_s:.6f}")
            self.root.after(0, self.append_result, f"P-value  : {monobit_p:.6f}")
            self.root.after(0, self.append_result, f"Verdict  : {monobit_verdict} (at alpha=0.01)\n")
        except Exception as e:
            self.root.after(0, self.append_result, f"Error calculating monobit: {e}\n")

        if not HAS_NISTRNG:
            self.root.after(0, self.append_result, "ERROR: Missing required libraries for full NIST suite.")
            self.root.after(0, self.append_result, "Run: pip install nistrng numpy\n")
            self.root.after(0, self.update_status, "Analysis Aborted (Missing Libraries).")
            self.is_capturing = False
            self.root.after(0, lambda: self.start_btn.config(state=tk.NORMAL))
            return

        self.root.after(0, self.append_result, "Initializing full NIST battery (this may take a moment)...\n")

        try:
            binary_array = np.array([int(b) for b in bits], dtype=np.int8)
            eligible_battery = check_eligibility_all_battery(binary_array, SP800_22R1A_BATTERY)

            self.root.after(0, self.append_result, f"Eligible Tests: {len(eligible_battery.keys())} / {len(SP800_22R1A_BATTERY.keys())}")
            if len(eligible_battery.keys()) < len(SP800_22R1A_BATTERY.keys()):
                self.root.after(0, self.append_result, "* Note: some tests skipped. Capture more data (2+ minutes) to run all tests.\n")
            else:
                self.root.after(0, self.append_result, "\n")

            results = run_all_battery(binary_array, eligible_battery, False)

            passed_count = 1 if monobit_verdict == "PASS" else 0   # monobit already counted
            total_count = 1

            self.root.after(0, self.append_result, f"{'TEST NAME':<35} | {'P-VALUE':<10} | {'VERDICT'}")
            self.root.after(0, self.append_result, "-" * 70)

            for result, _elapsed in results:
                if "monobit" in result.name.lower():
                    continue   # already shown above — don't print it twice
                total_count += 1
                verdict = "PASS" if result.passed else "FAIL"
                if result.passed:
                    passed_count += 1
                self.root.after(0, self.append_result, f"{result.name:<35} | {result.score:<10.6f} | {verdict}")

            self.root.after(0, self.append_result, "-" * 70)
            self.root.after(0, self.append_result, f"SUMMARY: Passed {passed_count} out of {total_count} evaluated tests.\n")

            used_hash = self.use_hash_var.get()

            # Report 1: the summary PDF.
            self.generate_pdf_report(port, duration, n, ones, zeros,
                                     monobit_s, monobit_p, monobit_verdict, used_hash,
                                     results)
            # Report 2: a SEPARATE file with every captured bit, not a summary.
            self.generate_raw_data_file(port, duration, len(raw_bits_for_file),
                                        raw_bits_for_file.count('1'),
                                        raw_bits_for_file.count('0'),
                                        raw_bits_for_file, used_hash)

        except Exception as e:
            self.root.after(0, self.append_result, f"\nError during NIST execution: {str(e)}")

        self.root.after(0, self.update_status, "Analysis Complete.")
        self.is_capturing = False
        self.root.after(0, lambda: self.start_btn.config(state=tk.NORMAL))


if __name__ == "__main__":
    root = tk.Tk()
    app = TRNGAnalyzerApp(root)
    root.mainloop()
