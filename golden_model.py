import numpy as np

# === Load quantized parameters ===
W_q = np.load("W_q.npy")       # quantized weights (int8)
b_q = np.load("b_q.npy")       # quantized biases (int16)
X_q = np.load("X_q.npy")       # quantized input (uint8 or int8)

# === Optional: convert to int32 to prevent overflow ===
W_q = W_q.astype(np.int32)
b_q = b_q.astype(np.int32)
X_q = X_q.astype(np.int32)

# ==========================================================
# === Compute quantized (integer) golden model output ===
# ==========================================================
y_int = np.zeros(10, dtype=np.int32)

for i in range(10):               # for each output neuron
    acc = b_q[i]                  # start with quantized bias
    for j in range(784):          # go through all input pixels
        acc += W_q[i, j] * X_q[j] # multiply and accumulate
    y_int[i] = acc                # store integer output

# Save for hardware comparison
np.save("Y_golden_int.npy", y_int)
print("Quantized (integer) output Y_int:\n", y_int)
