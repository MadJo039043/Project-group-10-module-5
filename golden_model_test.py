import numpy as np

# ==========================================================
# === Define small quantized parameters (like W_q, b_q, X_q) ===
# ==========================================================
W_q = np.array([
    [1, 2, 3],
    [4, 5, 6]
], dtype=np.int32)

b_q = np.array([10, 20], dtype=np.int32)
X_q = np.array([1, 1, 1], dtype=np.int32)

# === Optional: convert to int32 to prevent overflow ===
W_q = W_q.astype(np.int32)
b_q = b_q.astype(np.int32)
X_q = X_q.astype(np.int32)

# ==========================================================
# === Compute quantized (integer) golden model output ===
# ==========================================================
NUM_OUT = 2     # number of output neurons
NUM_IN  = 3     # number of input values

y_int = np.zeros(NUM_OUT, dtype=np.int32)

for i in range(NUM_OUT):          # for each output neuron
    acc = b_q[i]                  # start with quantized bias
    for j in range(NUM_IN):       # go through all input values
        acc += W_q[i, j] * X_q[j] # multiply and accumulate
    y_int[i] = acc                # store integer output

# ==========================================================
# === Save and print ===
# ==========================================================
np.save("Y_golden_small.npy", y_int)
print("Quantized (integer) output Y_int:\n", y_int)
