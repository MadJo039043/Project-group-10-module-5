.data
    # Constants
    INPUT_SIZE: .word 784    # Number of input pixels
    OUTPUT_SIZE: .word 10    # Number of output classes
    newline: .asciiz "\n"    # For debug printing
    
    # Arrays
    X_q: .space 3136        # 784 * 4 bytes for input array
    W_q: .space 31360       # (784 * 10) * 4 bytes for weights
    b_q: .space 40          # 10 * 4 bytes for biases
    y_int: .space 40        # 10 * 4 bytes for output

.text
.globl main
main:
    # Load constants using labels
    lw $s6, INPUT_SIZE     # $s6 = 784 (INPUT_SIZE)
    lw $s7, OUTPUT_SIZE    # $s7 = 10 (OUTPUT_SIZE)
    
    # Get base address of weights using load address pseudo-instruction
    .set noreorder         # Prevent reordering of instructions
    la $s0, W_q           # Load address of weights array
    .set reorder          # Re-enable instruction reordering

    # Initialize counters to zero
    li $s1, 0             # i = 0 (outer loop counter)

outer_loop:
    # Check outer loop condition
    beq $s1, $s7, end_program    # if i == 10, end program

    # Calculate bias address and load bias
    la $t0, b_q            # Get base address of biases
    sll $t1, $s1, 2        # i * 4 (multiply by 4 for word alignment)
    add $t0, $t0, $t1      # b_q + i*4
    lw $s3, ($t0)          # acc = b_q[i]

    # Initialize inner loop counter
    move $s2, $zero        # j = 0 (inner loop counter)

inner_loop:
    # Check inner loop condition
    beq $s2, $s6, end_inner_loop  # if j == 784, end inner loop

    # Calculate addresses and load values
    # Load X_q[j]
    la $t0, X_q            # Get base address of inputs
    sll $t1, $s2, 2        # j * 4
    add $t0, $t0, $t1      # X_q + j*4
    lw $t2, ($t0)          # Load X_q[j]

    # Load W_q[i,j]
    la $t0, W_q            # Get base address of weights
    mul $t1, $s1, $s6      # i * 784
    add $t1, $t1, $s2      # (i * 784) + j
    sll $t1, $t1, 2        # multiply by 4 for word alignment
    add $t0, $t0, $t1      # W_q + (i*784 + j)*4
    lw $t3, ($t0)          # Load W_q[i,j]

    # Multiply and accumulate
    mul $t4, $t2, $t3      # W_q[i,j] * X_q[j]
    add $s3, $s3, $t4      # acc += product

    # Increment inner loop counter
    addi $s2, $s2, 1       # j++
    j inner_loop           # continue inner loop

end_inner_loop:
    # Store result in y_int[i]
    la $t0, y_int          # Get base address of output array
    sll $t1, $s1, 2        # i * 4
    add $t0, $t0, $t1      # y_int + i*4
    sw $s3, ($t0)          # y_int[i] = acc

    # Increment outer loop counter
    addi $s1, $s1, 1       # i++
    j outer_loop           # continue outer loop

end_program:
    # Exit program
    li $v0, 10             # syscall code for exit
    syscall                # make syscall