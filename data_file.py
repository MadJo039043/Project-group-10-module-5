"""
make_data_mem.py
----------------
Generates a 24-bit memory initialization file (data_mem.mem)
from quantized .npy arrays for the custom DNN ISA.

Memory layout matches the assembly code:

  X_base = 0x0000   (784 values, uint8)
  W_base = 0x1000   (10 x 784 = 7840 values, int8)
  B_base = 0x2EA0   (10 values, int16)
  Y_base = 0x3000   (10 outputs, left zeroed)

Output:
  data_mem.mem  -- one 24-bit hex word per line (000000–FFFFFF)
  ready for Verilog:  $readmemh("data_mem.mem", mem);
"""

import numpy as np

# ===========================================================
# CONFIGURATION
# ===========================================================
ADDR_X_BASE = 0x0000
ADDR_W_BASE = 0x1000
ADDR_B_BASE = 0x2EA0
ADDR_Y_BASE = 0x3000
MEM_SIZE     = 0x4000   # 16K words of 24-bit memory

OUTPUT_FILE  = "data_mem.mem"

# ===========================================================
# LOAD QUANTIZED ARRAYS
# ===========================================================
print("[INFO] Loading .npy files...")

X_q = np.load("X_q.npy")     # shape: (784,) uint8
W_q = np.load("W_q.npy")     # shape: (10,784) int8
B_q = np.load("b_q.npy")     # shape: (10,) int16

# flatten weights row-major (i,j)
W_q_flat = W_q.flatten()

print(f"  X_q: {X_q.shape}  -> {len(X_q)} words @ 0x{ADDR_X_BASE:04X}")
print(f"  W_q: {W_q.shape}  -> {len(W_q_flat)} words @ 0x{ADDR_W_BASE:04X}")
print(f"  b_q: {B_q.shape}  -> {len(B_q)} words @ 0x{ADDR_B_BASE:04X}")

# ===========================================================
# INITIALIZE MEMORY
# ===========================================================
mem = np.zeros(MEM_SIZE, dtype=np.int32)  # store as int32, use only 24 bits

# ===========================================================
# MAP EACH REGION INTO MEMORY
# ===========================================================
# Inputs (uint8)
mem[ADDR_X_BASE : ADDR_X_BASE + len(X_q)] = X_q.astype(np.int32)

# Weights (int8)
mem[ADDR_W_BASE : ADDR_W_BASE + len(W_q_flat)] = W_q_flat.astype(np.int32)

# Biases (int16)
mem[ADDR_B_BASE : ADDR_B_BASE + len(B_q)] = B_q.astype(np.int32)

# Output (Y_base): left as zeros for simulation
print(f"[INFO] Y_base region 0x{ADDR_Y_BASE:04X}-0x{ADDR_Y_BASE+9:04X} reserved for outputs.")

# ===========================================================
# SAVE AS 24-BIT HEX FILE
# ===========================================================
print(f"[INFO] Writing 24-bit memory file → {OUTPUT_FILE}")
with open(OUTPUT_FILE, "w") as f:
    for value in mem:
        # Mask to 24 bits and write as 6-digit hex
        word = np.uint32(value & 0xFFFFFF)
        f.write(f"{word:06X}\n")

print("[OK] Done.")
print(f"Total memory words: {MEM_SIZE} (24 bits each)")
print(f"File saved as: {OUTPUT_FILE}")
