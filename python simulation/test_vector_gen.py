# test_vector_gen.py
# Generate test vectors for CORDIC Verilog simulation

import random
from cordic_model import run_cordic, get_iters

def gen_vectors(file_path, num_vecs=10000):
    """Generate random test vectors and save to a file."""
    with open(file_path, 'w') as f:
        for _ in range(num_vecs):
            # Random inputs
            phase = random.randint(-32768, 32767)
            mod = random.randint(0, 4)
            snr = random.randint(0, 255)
            
            # Compute expected outputs
            iters = get_iters(mod, snr)
            cos_val, sin_val, _ = run_cordic(phase, iters)
            
            # Convert to hex strings
            h_phase = f"{phase & 0xFFFF:04x}"
            h_mod = f"{mod & 0x7:01x}"
            h_snr = f"{snr & 0xFF:02x}"
            h_sin = f"{sin_val & 0xFFFF:04x}"
            h_cos = f"{cos_val & 0xFFFF:04x}"
            
            # Write to file
            f.write(f"{h_phase} {h_mod} {h_snr} {h_sin} {h_cos}\n")

if __name__ == "__main__":
    import sys
    path = "test_vectors.txt"
    if len(sys.argv) > 1:
        path = sys.argv[1]
    gen_vectors(path)
    print(f"Generated 10,000 vectors in {path}")
