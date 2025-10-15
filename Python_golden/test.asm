.data
filenameW: .asciiz "W_q.txt"
filenameB: .asciiz "b_q.txt"
filenameX: .asciiz "X_q.txt"

# allocate enough space (4 bytes per element)
W_q:   .space 31360      # 10x784x4
b_q:   .space 40         # 10x4
X_q:   .space 3136       # 784x4
Y_int: .space 40         # 10x4

.text
.globl main
main:
    # === Load data from files ===
    la $a0, filenameW
    la $a1, W_q
    li $a2, 31360
    jal load_file

    la $a0, filenameB
    la $a1, b_q
    li $a2, 40
    jal load_file

    la $a0, filenameX
    la $a1, X_q
    li $a2, 3136
    jal load_file

    # === Compute inference ===
    jal compute_layer

    # === Print output ===
    jal print_outputs

    li $v0, 10
    syscall


# =====================================================
# load_file(filename_addr, buffer_addr, size_bytes)
# =====================================================
load_file:
    li   $v0, 13
    move $a0, $a0
    li   $a1, 0
    li   $a2, 0
    syscall
    move $s0, $v0

    li   $v0, 14
    move $a0, $s0
    move $a1, $a1
    move $a2, $a2
    syscall

    li   $v0, 16
    move $a0, $s0
    syscall
    jr $ra


# =====================================================
# compute_layer
# =====================================================
compute_layer:
    li $t0, 0          # i = 0
    li $t1, 10         # num outputs

outer_loop:
    beq $t0, $t1, end_outer

    # acc = b_q[i]
    mul $t2, $t0, 4
    la  $t3, b_q
    add $t3, $t3, $t2
    lw  $t4, 0($t3)

    li $t5, 0          # j = 0
    li $t6, 784        # num inputs

inner_loop:
    beq $t5, $t6, end_inner

    # W_q[i,j]
    li  $t7, 784
    mul $t8, $t0, $t7
    add $t8, $t8, $t5
    mul $t8, $t8, 4
    la  $t9, W_q
    add $t9, $t9, $t8
    lw  $t9, 0($t9)

    # X_q[j]
    mul $t10, $t5, 4
    la  $t11, X_q
    add $t11, $t11, $t10
    lw  $t11, 0($t11)

    mul $t12, $t9, $t11
    add $t4, $t4, $t12

    addi $t5, $t5, 1
    j inner_loop

end_inner:
    # y_int[i] = acc
    mul $t13, $t0, 4
    la  $t14, Y_int
    add $t14, $t14, $t13
    sw  $t4, 0($t14)

    addi $t0, $t0, 1
    j outer_loop

end_outer:
    jr $ra


# =====================================================
# print_outputs
# =====================================================
print_outputs:
    li $t0, 0
    li $t1, 10
print_loop:
    beq $t0, $t1, end_print
    mul $t2, $t0, 4
    la  $t3, Y_int
    add $t3, $t3, $t2
    lw  $a0, 0($t3)
    li  $v0, 1
    syscall

    # space
    li  $v0, 11
    li  $a0, 32
    syscall

    addi $t0, $t0, 1
    j print_loop
end_print:
    li $v0, 11
    li $a0, 10
    syscall
    jr $ra