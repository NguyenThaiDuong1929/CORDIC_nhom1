# gui_app.py
# Tkinter Popup UI for Adaptive CORDIC Simulation

import tkinter as tk
from tkinter import ttk, messagebox
import numpy as np
import matplotlib
matplotlib.use("TkAgg")
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
import os

from cordic_model import run_cordic, get_iters, deg_to_phase, phase_to_deg, to_s16, K_FACT, LUT
from test_vector_gen import gen_vectors

# History function to plot convergence
def run_history(phase, iters):
    x = to_s16(K_FACT)
    y = 0
    z = to_s16(phase)
    xs, ys, zs = [x], [y], [z]
    for g in range(16):
        if g < iters:
            x_sh = to_s16(x >> g)
            y_sh = to_s16(y >> g)
            if z >= 0:
                x = to_s16(x - y_sh)
                y = to_s16(y + x_sh)
                z = to_s16(z - LUT[g])
            else:
                x = to_s16(x + y_sh)
                y = to_s16(y - x_sh)
                z = to_s16(z + LUT[g])
        xs.append(x)
        ys.append(y)
        zs.append(z)
    return xs, ys, zs

class App:
    def __init__(self, root):
        self.root = root
        self.root.title("Adaptive CORDIC Simulator & Vector Generator")
        self.root.geometry("900x600")
        
        # Style configuration
        style = ttk.Style()
        style.theme_use("clam")
        
        # Left Panel (Inputs)
        left = ttk.Frame(root, padding=10)
        left.pack(side=tk.LEFT, fill=tk.Y, padx=10, pady=10)
        
        # Title Label
        ttk.Label(left, text="CORDIC Parameters", font=("Arial", 14, "bold")).grid(row=0, column=0, columnspan=2, pady=10)
        
        # Angle Input
        ttk.Label(left, text="Angle (deg):").grid(row=1, column=0, sticky=tk.W, pady=5)
        self.e_ang = ttk.Entry(left, width=15)
        self.e_ang.insert(0, "45.0")
        self.e_ang.grid(row=1, column=1, pady=5)
        
        # Modulation dropdown
        ttk.Label(left, text="Modulation:").grid(row=2, column=0, sticky=tk.W, pady=5)
        self.c_mod = ttk.Combobox(left, values=["BPSK", "QPSK", "16QAM", "64QAM", "256QAM"], width=13, state="readonly")
        self.c_mod.current(3) # Default 64QAM
        self.c_mod.grid(row=2, column=1, pady=5)
        
        # SNR slider
        ttk.Label(left, text="SNR (dB):").grid(row=3, column=0, sticky=tk.W, pady=5)
        self.s_snr = ttk.Scale(left, from_=0, to=120, orient=tk.HORIZONTAL)
        self.s_snr.set(100)
        self.s_snr.grid(row=3, column=1, pady=5, sticky=tk.EW)
        
        # Slider value label
        self.l_snr_val = ttk.Label(left, text="100 dB")
        self.l_snr_val.grid(row=4, column=1, sticky=tk.E)
        self.s_snr.config(command=self.update_snr_label)
        
        # Run Button
        self.b_run = ttk.Button(left, text="Run Simulation", command=self.simulate)
        self.b_run.grid(row=5, column=0, columnspan=2, pady=15, sticky=tk.EW)
        
        # Separator
        ttk.Separator(left, orient='horizontal').grid(row=6, column=0, columnspan=2, pady=10, sticky=tk.EW)
        
        # Output info labels
        ttk.Label(left, text="Simulation Results", font=("Arial", 12, "bold")).grid(row=7, column=0, columnspan=2, pady=5)
        
        self.l_iters = ttk.Label(left, text="Iterations: -")
        self.l_iters.grid(row=8, column=0, columnspan=2, sticky=tk.W, pady=2)
        
        self.l_fixed = ttk.Label(left, text="Fixed Cos: -\nFixed Sin: -")
        self.l_fixed.grid(row=9, column=0, columnspan=2, sticky=tk.W, pady=2)
        
        self.l_float = ttk.Label(left, text="Float Cos: -\nFloat Sin: -")
        self.l_float.grid(row=10, column=0, columnspan=2, sticky=tk.W, pady=2)
        
        self.l_err = ttk.Label(left, text="Max Error: -")
        self.l_err.grid(row=11, column=0, columnspan=2, sticky=tk.W, pady=2)
        
        # Separator
        ttk.Separator(left, orient='horizontal').grid(row=12, column=0, columnspan=2, pady=10, sticky=tk.EW)
        
        # Vector Gen Button
        self.b_gen = ttk.Button(left, text="Generate 10k Vectors", command=self.generate_vectors)
        self.b_gen.grid(row=13, column=0, columnspan=2, pady=10, sticky=tk.EW)
        
        # Right Panel (Plot)
        right = ttk.Frame(root, padding=10)
        right.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        self.fig = Figure(figsize=(5, 4), dpi=100)
        self.ax = self.fig.add_subplot(111)
        self.canvas = FigureCanvasTkAgg(self.fig, master=right)
        self.canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)
        
        self.init_plot()
        
    def update_snr_label(self, val):
        self.l_snr_val.config(text=f"{int(float(val))} dB")
        
    def init_plot(self):
        self.ax.clear()
        self.ax.set_title("CORDIC Pipeline Convergence Path")
        self.ax.set_xlabel("Pipeline Stage")
        self.ax.set_ylabel("Value (Scaled)")
        self.ax.grid(True)
        self.canvas.draw()
        
    def simulate(self):
        try:
            ang = float(self.e_ang.get())
        except ValueError:
            messagebox.showerror("Error", "Invalid Angle value.")
            return
            
        mod = self.c_mod.current()
        snr = int(self.s_snr.get())
        
        # Calculate CORDIC inputs
        phase = deg_to_phase(ang)
        iters = get_iters(mod, snr)
        
        # Run model
        x, y, z = run_cordic(phase, iters)
        xs, ys, zs = run_history(phase, iters)
        
        # Theoretical values
        rad = np.radians(ang)
        fl_cos = np.cos(rad)
        fl_sin = np.sin(rad)
        
        # Scaled values
        fx_cos = x / 16384.0
        fx_sin = y / 16384.0
        
        err = max(abs(fx_cos - fl_cos), abs(fx_sin - fl_sin))
        
        # Update labels
        self.l_iters.config(text=f"Iterations: {iters} / 16")
        self.l_fixed.config(text=f"Fixed Cos: {fx_cos:.5f} ({x})\nFixed Sin: {fx_sin:.5f} ({y})")
        self.l_float.config(text=f"Float Cos: {fl_cos:.5f}\nFloat Sin: {fl_sin:.5f}")
        self.l_err.config(text=f"Max Error: {err:.6f}")
        
        # Plotting
        self.ax.clear()
        stages = np.arange(17)
        # Scale history to compare with float reference
        hist_cos = np.array(xs) / 16384.0
        hist_sin = np.array(ys) / 16384.0
        
        self.ax.plot(stages, hist_cos, 'o-', label="Fixed-point Cos", color="blue")
        self.ax.plot(stages, hist_sin, 'o-', label="Fixed-point Sin", color="green")
        self.ax.axhline(y=fl_cos, color="blue", linestyle="--", alpha=0.5, label="Float Cos Ref")
        self.ax.axhline(y=fl_sin, color="green", linestyle="--", alpha=0.5, label="Float Sin Ref")
        
        # Draw a vertical line showing where iteration calculation stopped
        self.ax.axvline(x=iters, color="red", linestyle=":", label=f"Bypass after stage {iters}")
        
        self.ax.set_title(f"CORDIC Convergence (Iterations = {iters})")
        self.ax.set_xlabel("Pipeline Stage")
        self.ax.set_ylabel("Scaled Value")
        self.ax.legend(loc="best")
        self.ax.grid(True)
        self.canvas.draw()
        
    def generate_vectors(self):
        output_file = "test_vectors.txt"
        try:
            gen_vectors(output_file, 10000)
            messagebox.showinfo("Success", f"Successfully generated 10,000 vectors\nSaved to: {os.path.abspath(output_file)}")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to generate vectors:\n{str(e)}")

if __name__ == "__main__":
    root = tk.Tk()
    app = App(root)
    root.mainloop()
