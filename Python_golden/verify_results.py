import numpy as np

def compare_results(asm_output_file, golden_output_file="Y_golden_int.npy"):
    # Load results
    y_golden = np.load(golden_output_file)
    y_asm = np.load(asm_output_file)
    
    # Compare
    matches = np.array_equal(y_golden, y_asm)
    print("\nVerification Results:")
    print("===================")
    print(f"Golden Model Output: {y_golden}")
    print(f"Assembly Output:     {y_asm}")
    print(f"\nOutputs Match: {'✓' if matches else '✗'}")
    
    if not matches:
        diff = y_golden - y_asm
        mismatch_idx = np.where(diff != 0)[0]
        print("\nMismatches found at indices:", mismatch_idx)
        for idx in mismatch_idx:
            print(f"Index {idx}: Golden={y_golden[idx]}, ASM={y_asm[idx]}, Diff={diff[idx]}")

if __name__ == "__main__":
    # First generate test data if not exists
    try:
        import test_generator
        test_generator.generate_test_data()
    except Exception as e:
        print(f"Warning: Could not generate new test data: {e}")
    
    # Compare results
    try:
        compare_results("Y_asm_output.npy", "Y_golden_int.npy")
    except FileNotFoundError as e:
        print("\nError: Output files not found.")
        print("Make sure to:")
        print("1. Run test_generator.py to create test inputs")
        print("2. Run your assembly implementation")
        print("3. Run this verification script")