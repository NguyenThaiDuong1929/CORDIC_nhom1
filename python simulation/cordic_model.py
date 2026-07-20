# cordic_model.py
# Bit-true 16-bit Fixed-point CORDIC Model

import math

# Constants
K_FACT = 9949  # 0.60725 * 2^14
LUT = [
    8192, 4836, 2555, 1297, 651, 326, 163, 81,
    41, 20, 10, 5, 3, 1, 1, 0
]

def to_s16(v):
    """Convert value to 16-bit signed integer."""
    v = int(round(v)) & 0xFFFF
    return v - 0x10000 if v >= 0x8000 else v

def deg_to_phase(deg):
    """Convert degrees (-180 to 180) to 16-bit signed phase value."""
    # Wrap angle to [-180, 180]
    deg = (deg + 180) % 360 - 180
    return to_s16(deg * 65536 / 360)

def phase_to_deg(phase):
    """Convert 16-bit signed phase to degrees."""
    return to_s16(phase) * 360.0 / 65536.0

def get_iters(mod, snr):
    """Determine iterations based on modulation and SNR (matching controller.v)."""
    # Modulation: 0=BPSK, 1=QPSK, 2=16QAM, 3=64QAM, 4=256QAM
    if mod == 0:  # BPSK
        return 4 if snr < 30 else (5 if snr < 80 else 6)
    elif mod == 1:  # QPSK
        return 6 if snr < 30 else (7 if snr < 80 else 8)
    elif mod == 2:  # 16QAM
        return 8 if snr < 30 else (9 if snr < 80 else 10)
    elif mod == 3:  # 64QAM
        return 10 if snr < 30 else (12 if snr < 80 else 14)
    elif mod == 4:  # 256QAM
        return 12 if snr < 30 else (14 if snr < 80 else 16)
    else:
        return 16

def run_cordic(phase, iters):
    """Run 16-bit CORDIC algorithm with dynamic iterations (bit-true)."""
    phase_val = to_s16(phase)
    in_q23 = (phase_val > 16384) or (phase_val < -16384)

    x = to_s16(K_FACT)
    y = 0
    if phase_val > 16384:
        z = to_s16(phase_val - 32768)
    elif phase_val < -16384:
        z = to_s16(phase_val + 32768)
    else:
        z = phase_val

    # 16 pipeline stages
    for g in range(16):
        if g < iters:
            x_sh = to_s16(x >> g)
            y_sh = to_s16(y >> g)
            
            if z >= 0:
                x_next = to_s16(x - y_sh)
                y_next = to_s16(y + x_sh)
                z_next = to_s16(z - LUT[g])
            else:
                x_next = to_s16(x + y_sh)
                y_next = to_s16(y - x_sh)
                z_next = to_s16(z + LUT[g])
            x, y, z = x_next, y_next, z_next
        else:
            # Bypass stage (keep values)
            pass
            
    if in_q23:
        return to_s16(-x), to_s16(-y), z
    else:
        return x, y, z

if __name__ == "__main__":
    import os
    # Prioritize looking in python simulation/ folder first
    file_path = os.path.join("python simulation", "test_vectors.txt")
    if not os.path.exists(file_path):
        file_path = "test_vectors.txt"
    if not os.path.exists(file_path):
        file_path = os.path.join("..", "python simulation", "test_vectors.txt")
        
    if not os.path.exists(file_path):
        print(f"ERROR: Could not find test_vectors.txt file to verify!")
    else:
        test_cases = []
        with open(file_path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                parts = line.split()
                if len(parts) == 5:
                    test_cases.append({
                        "phase_hex": parts[0],
                        "mod": int(parts[1]),
                        "snr_hex": parts[2],
                        "exp_sin_hex": parts[3],
                        "exp_cos_hex": parts[4]
                    })
                    if len(test_cases) == 2: # Grab first 2 vectors dynamically
                        break
                        
        print("=" * 70)
        print("           CORDIC Python Model Self-Verification (Bit-True)")
        print("           (Dynamically loaded from test_vectors.txt)")
        print("=" * 70)

        for i, case in enumerate(test_cases):
            phase = to_s16(int(case["phase_hex"], 16))
            mod = case["mod"]
            snr = int(case["snr_hex"], 16)
            exp_sin = to_s16(int(case["exp_sin_hex"], 16))
            exp_cos = to_s16(int(case["exp_cos_hex"], 16))
            
            iters = get_iters(mod, snr)
            cos_val, sin_val, _ = run_cordic(phase, iters)
            
            h_cos = f"{cos_val & 0xFFFF:04x}"
            h_sin = f"{sin_val & 0xFFFF:04x}"
            deg = phase * 360.0 / 65536.0
            mod_name = "BPSK" if mod == 0 else ("QPSK" if mod == 1 else "QAM")
            
            print(f"Test Case {i+1}: Input Phase = {case['phase_hex']} ({deg:.2f}°), Mod = {mod_name} ({mod}), SNR = {case['snr_hex']} ({snr} dB)")
            print(f"  Iterations determined: {iters}")
            print(f"  Expected (from file) : Sin = {case['exp_sin_hex']} ({exp_sin}), Cos = {case['exp_cos_hex']} ({exp_cos})")
            print(f"  Calculated (Python)  : Sin = {h_sin} ({sin_val}), Cos = {h_cos} ({cos_val})")
            
            matched = (h_sin.lower() == case["exp_sin_hex"].lower()) and (h_cos.lower() == case["exp_cos_hex"].lower())
            print(f"  Matching Status      : {'SUCCESS (100% Match)' if matched else 'FAILED'}")
            print("-" * 70)
