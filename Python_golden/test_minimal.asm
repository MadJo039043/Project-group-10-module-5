# Minimal MIPS test program
.data
    message: .asciiz "Hello World\n"

.text
.globl main
main:
    # Print message
    li $v0, 4           # syscall 4 is for printing string
    la $a0, message     # load address of string to print
    syscall

    # Exit program
    li $v0, 10          # syscall 10 is for exit
    syscall