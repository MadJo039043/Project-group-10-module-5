import numpy as np

def generate_test_data():
    # Create small test vectors
    X_test = np.array([1, 2, 3, 4] * 196, dtype=np.int8)  # 784 inputs
    W_test = np.zeros((10, 784), dtype=np.int8)
    b_test = np.array([10, 20, 30, 40, 50, 60, 70, 80, 90, 100], dtype=np.int16)
    
    # Simple pattern in weights for easy verification
    for i in range(10):
        W_test[i] = np.array([i+1] * 784, dtype=np.int8)
    
    # Save test vectors
    np.save("X_q.npy", X_test)
    np.save("W_q.npy", W_test)
    np.save("b_q.npy", b_test)
    
    print("Test vectors generated:")
    print(f"X_q shape: {X_test.shape}, values: {X_test[:4]}...")
    print(f"W_q shape: {W_test.shape}, first row: {W_test[0,:4]}...")
    print(f"b_q shape: {b_test.shape}, values: {b_test}")
    
    return X_test, W_test, b_test

if __name__ == "__main__":
    # Generate and save test data
    X_test, W_test, b_test = generate_test_data()
    
    # Run golden model with test data
    print("\nRunning golden model...")
    
    # Convert to int32 as in original model
    W_q = W_test.astype(np.int32)
    b_q = b_test.astype(np.int32)
    X_q = X_test.astype(np.int32)
    
    # Compute reference output
    y_int = np.zeros(10, dtype=np.int32)
    for i in range(10):
        acc = b_q[i]
        for j in range(784):
            acc += W_q[i,j] * X_q[j]
        y_int[i] = acc
    
    np.save("Y_golden_int.npy", y_int)
    print("\nExpected outputs (golden model):")
    print(y_int)
    print("\nSaved test data and expected outputs to .npy files")
    print("You can now run the assembly implementation and compare results")