# verify_example.py
# Verify specific test vectors using local cordic_model.py

from cordic_model import run_cordic, get_iters, to_s16

# Two test cases from the user's screenshot
test_cases = [
    {"phase_hex": "3d53", "mod": 1, "snr_hex": "2e", "exp_sin_hex": "3fe0", "exp_cos_hex": "03f3"},
    {"phase_hex": "a9d0", "mod": 0, "snr_hex": "fe", "exp_sin_hex": "c8fc", "exp_cos_hex": "df53"}
]

print("=" * 70)
print("           CORDIC Python Verification for Specific Vectors")
print("=" * 70)

for i, case in enumerate(test_cases):
    phase = to_s16(int(case["phase_hex"], 16))
    mod = case["mod"]
    snr = int(case["snr_hex"], 16)
    exp_sin = to_s16(int(case["exp_sin_hex"], 16))
    exp_cos = to_s16(int(case["exp_cos_hex"], 16))
    
    # Calculate using local cordic_model.py
    iters = get_iters(mod, snr)
    cos_val, sin_val, _ = run_cordic(phase, iters)
    
    h_cos = f"{cos_val & 0xFFFF:04x}"
    h_sin = f"{sin_val & 0xFFFF:04x}"
    
    # Convert phase to angle in degrees
    deg = phase * 360.0 / 65536.0
    
    mod_name = "BPSK" if mod == 0 else ("QPSK" if mod == 1 else "QAM")
    
    print(f"Test Case {i+1}: Input Phase = {case['phase_hex']} ({deg:.2f}°), Mod = {mod_name} ({mod}), SNR = {case['snr_hex']} ({snr} dB)")
    print(f"  Iterations determined: {iters}")
    print(f"  Expected (from file) : Sin = {case['exp_sin_hex']} ({exp_sin}), Cos = {case['exp_cos_hex']} ({exp_cos})")
    print(f"  Calculated (Python)  : Sin = {h_sin} ({sin_val}), Cos = {h_cos} ({cos_val})")
    
    matched = (h_sin.lower() == case["exp_sin_hex"].lower()) and (h_cos.lower() == case["exp_cos_hex"].lower())
    print(f"  Matching Status      : {'SUCCESS (100% Match)' if matched else 'FAILED'}")
    print("-" * 70)
