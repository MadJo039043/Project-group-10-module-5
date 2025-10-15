# =================================================================
# MNIST Neural Network Inference - Integer Quantized Version
# Converted from Python golden model (pyt_golden_model)
# =================================================================

# Memory Map (matches numpy arrays from Python):
# [0-783]:    X_q input array (784 pixels, int8/uint8 converted to int32)
# [784-7839]: W_q weights (10x784 matrix, int8 converted to int32)
# [7840-7849]: b_q bias values (10 neurons, int16 converted to int32)
# [7850-7859]: y_int output array (10 logits, int32 results)

# Register Allocation:
# R1: i - Outer loop counter (0 to 9) for output neurons
# R2: j - Inner loop counter (0 to 783) for input pixels
# R3: acc - Accumulator for dot product (matches Python 'acc')
# R4: Address calculation temporary
# R5: Value temporary (loaded weights/inputs)
# R6: Constant 784 (INPUT_SIZE, number of pixels)
# R7: Constant 10 (OUTPUT_SIZE, number of classes)
# R8: Weight matrix base address (for faster indexing)
# R9: Product temporary (W_q[i,j] * X_q[j])

# Python equivalent operations:
# y_int = np.zeros(10)                -> Zero initialization done in memory
# acc = b_q[i]                        -> LOAD from bias array
# acc += W_q[i,j] * X_q[j]           -> MUL + ADD sequence
# y_int[i] = acc                      -> STORE to output array

# ===== Initialize Constants and Pointers =====
# Python: X_q.shape[0] = 784, y_int.shape[0] = 10
LOAD R6, [8000]    # R6 = 784 (INPUT_SIZE constant)
LOAD R7, [8001]    # R7 = 10 (OUTPUT_SIZE constant)
LOAD R8, 784       # R8 = W_q base address (skip X_q array)

# ===== Outer Loop: iterate over output neurons =====
# Python: for i in range(10):
LOAD R1, 0         # i = 0 (initialize outer loop counter)
outer_loop:
    # ===== Initialize Accumulator with Bias =====
    # Python: acc = b_q[i]
    LOAD R4, 7840  # R4 = b_q base address (7840)
    ADD R4, R4, R1 # R4 = &b_q[i] = base + i
    LOAD R3, [R4]  # acc = b_q[i] (initialize with bias)
    
    # ===== Inner Loop: compute dot product with one row of weights =====
    # Python: for j in range(784):
    LOAD R2, 0     # j = 0 (initialize inner loop counter)
inner_loop:
    # ===== Calculate address for W_q[i,j] =====
    # Python array indexing: W_q[i,j]
    MUL R4, R1, R6 # R4 = i * 784 (row offset)
    ADD R4, R4, R8 # R4 = W_q base + (i * 784)
    ADD R4, R4, R2 # R4 = &W_q[i,j] = base + (i * 784) + j
    LOAD R5, [R4]  # R5 = W_q[i,j] (load weight)
    
    # ===== Load input pixel X_q[j] =====
    # Python: X_q[j]
    LOAD R4, [R2]  # R4 = X_q[j] (input pixel)
    
    # ===== Multiply and Accumulate =====
    # Python: acc += W_q[i,j] * X_q[j]
    MUL R9, R5, R4 # R9 = W_q[i,j] * X_q[j]
    ADD R3, R3, R9 # acc += result (accumulate)
    
    # ===== Inner Loop Control =====
    # Python: for j in range(784):
    ADD R2, R2, 1  # j += 1
    SUB R4, R6, R2 # R4 = 784 - j (check if j < 784)
    BEQ R4, 0, inner_done # Exit when j reaches 784
    JMP inner_loop        # Otherwise, continue inner loop
    
inner_done:
    # ===== Store Output Neuron Result =====
    # Python: y_int[i] = acc
    LOAD R4, 7850  # R4 = y_int base address (7850)
    ADD R4, R4, R1 # R4 = &y_int[i] = base + i
    STORE R3, [R4] # y_int[i] = acc (store neuron output)
    
    # Debug: Store intermediate result to debug output area
    LOAD R4, 8100  # Debug output base = 8100
    ADD R4, R4, R1 # Debug slot for neuron i
    STORE R3, [R4] # Store for verification
    
    # ===== Outer Loop Control =====
    # Python: for i in range(10):
    ADD R1, R1, 1  # i += 1
    SUB R4, R7, R1 # R4 = 10 - i (check if i < 10)
    BEQ R4, 0, done # Exit when i reaches 10
    JMP outer_loop  # Otherwise, continue outer loop

# ===== Program Completion =====
# Python: np.save("Y_golden_int.npy", y_int)
# Note: File I/O handled outside assembly
done:
    HALT

# ===== Constants Section =====
# These match the Python array dimensions
.data 8000
784     # INPUT_SIZE (28x28 pixels)
10      # OUTPUT_SIZE (digit classes 0-9)