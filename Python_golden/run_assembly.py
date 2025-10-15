import numpy as np
from simple_processor import SimpleProcessor

def load_and_run_assembly():
    # Create processor instance
    processor = SimpleProcessor()
    
    # Load test data into memory
    print("Loading test data...")
    X_q = np.load("X_q.npy").astype(np.int32)
    W_q = np.load("W_q.npy").astype(np.int32)
    b_q = np.load("b_q.npy").astype(np.int32)
    
    # Load data into processor memory
    processor.load_data(0, X_q.tolist())           # X_q at address 0
    processor.load_data(784, W_q.flatten().tolist()) # W_q at address 784
    processor.load_data(7840, b_q.tolist())         # b_q at address 7840
    processor.load_data(8000, 784)                  # Constants
    processor.load_data(8001, 10)
    
    # Load assembly program
    print("Loading assembly program...")
    with open('golden_model.asm', 'r') as f:
        # Skip comments and empty lines, get only instructions
        instructions = []
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and not line.startswith('.'):
                instructions.append(line)
    
    # Load program into processor memory
    processor.load_program(instructions)
    
    # Run the program
    print("Running assembly program...")
    processor.run(debug=True)  # Set debug=True to see execution steps
    
    # Get results from memory
    results = processor.memory[7850:7860]  # Get 10 output values
    
    # Save results
    print("Saving results...")
    np.save("Y_asm_output.npy", np.array(results, dtype=np.int32))
    
    return results

if __name__ == "__main__":
    # First generate test data if needed
    try:
        import test_generator
        test_generator.generate_test_data()
    except Exception as e:
        print(f"Warning: Could not generate new test data: {e}")
    
    # Run assembly program
    results = load_and_run_assembly()
    print("\nAssembly program output:", results)
    
    # Verify results
    import verify_results
    verify_results.compare_results("Y_asm_output.npy")