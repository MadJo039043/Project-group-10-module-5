;==========================================================
; Custom ISA Definition with Updated Instructions
;==========================================================

; Original Instructions:
; | Mnemonic | Operands      | Description                       | Example         | Encoding (hex) |
; |----------|---------------|-----------------------------------|-----------------|----------------|
; | LOAD     | Rdest, [addr] | Load data from memory to register | LOAD R1, [10]   | 0x0_op_1_10    |
; | STORE    | Rsrc, [addr]  | Store register data to memory     | STORE R1, [20]  | 0x0_op_1_20    |
; | ADD      | Rdest, R1, R2 | Add R1 and R2 → Rdest            | ADD R3, R1, R2  | 0x0_op_3_1_2   |
; | SUB      | Rdest, R1, R2 | Subtract R2 from R1 → Rdest      | SUB R3, R1, R2  | 0x0_op_3_1_2   |
; | MUL      | Rdest, R1, R2 | Multiply R1 and R2 → Rdest       | MUL R3, R1, R2  | 0x0_op_3_1_2   |
; | JMP      | addr          | Jump to instruction address       | JMP 12          | 0x0_op_12      |
; | BEQ      | R1, R2, addr  | If R1=R2, jump to addr           | BEQ R1, R2, 8   | 0x0_op_1_2_8   |
; | HALT     | -             | Stop program execution            | HALT            | 0x0_op_0_0_0   |

; New Instructions:
; | Mnemonic | Operands       | Description                      | Example         | Encoding (hex) |
; |----------|----------------|----------------------------------|-----------------|----------------|
; | LUI      | Rdest, imm8    | Load upper 8 bits into register  | LUI R6, 0x2E    | 0x11_06_2E     |
; | ORI      | Rdest, R1, imm8| OR immediate with register      | ORI R6, R6, 0xA0| 0x12_06_A0     |

; Encoding Details:
; LUI format: [0001][000001][6-bit Rdest][8-bit immediate]
; ORI format: [0001][000010][6-bit Rdest][6-bit R1][8-bit immediate]

; Example - Loading 0x2EA0 into R6:
;   LUI R6, 0x2E      -> 0x11_06_2E  (Type=1, Op=1, Rdest=6, Imm=0x2E)
;   ORI R6, R6, 0xA0   -> 0x12_06_A0  (Type=1, Op=2, Rdest=6, R1=6, Imm=0xA0)
;
; Example of loading large address 0x2EA0:
;   LUI R1, 0x2E       ; R1 = 0x2E00
;   ORI R1, R1, 0xA0    ; R1 = 0x2EA0

;----------------------------------------------------------
; Register Mapping (for reference)
;----------------------------------------------------------
; R0  = 0 (constant zero)
; R1  = i (outer loop index)
; R2  = j (inner loop index)
; R3  = acc (accumulator)
; R4  = X_base
; R5  = W_base
; R6  = B_base
; R7  = Y_base
; R8  = tmp (temporary)
; R9  = one (constant 1)
; R10 = end10 (loop bound = 10)
; R11 = 784 (input size)
; R12 = W_q[i,j]
; R13 = X_q[j]
; R14 = product

;----------------------------------------------------------
; Initialize constants and base addresses
;----------------------------------------------------------
; Load X_base (0x0000)
LUI R4, 0x00
ORI R4, R4, 0x00

; Load W_base (0x1000)
LUI R5, 0x10
ORI R5, R5, 0x00

; Load B_base (0x2EA0)
LUI R6, 0x2E
ORI R6, R6, 0xA0

; Load Y_base (0x3000)
LUI R7, 0x30
ORI R7, R7, 0x00

; Load constants directly (no memory read needed)
ORI R9, R0, 1         ; one = 1
ORI R10, R0, 10       ; end10 = 10

; Load 784 (0x0310) using LUI/ORI
LUI R11, 0x03
ORI R11, R11, 0x10

;==========================================================
; Outer loop: for i in range(10)
;==========================================================
ADD R1, R0, R0        ; i = 0
OUTER_LOOP:

    ; acc = b_q[i]
    ADD R8, R6, R1          ; tmp = B_base + i
    LOAD R3, [R8]           ; acc = b_q[i]

    ; Precompute row offset = W_base + i * 784
    MUL R8, R1, R11         ; tmp = i * 784
    ADD R8, R8, R5          ; tmp += W_base

    ;------------------------------------------------------
    ; Inner loop: for j in range(784)
    ;------------------------------------------------------
    ADD R2, R0, R0          ; j = 0
INNER_LOOP:

        ; Load W_q[i, j]
        ADD R12, R8, R2
        LOAD R12, [R12]

        ; Load X_q[j]
        ADD R13, R4, R2
        LOAD R13, [R13]

        ; Multiply and accumulate
        MUL R14, R12, R13
        ADD R3, R3, R14

        ; j++
        ADD R2, R2, R9
        BEQ R2, R11, END_INNER
        JMP INNER_LOOP
END_INNER:

    ;------------------------------------------------------
    ; y_int[i] = acc
    ;------------------------------------------------------
    ADD R8, R7, R1
    STORE R3, [R8]

    ; i++
    ADD R1, R1, R9
    BEQ R1, R10, END_OUTER
    JMP OUTER_LOOP
END_OUTER:

HALT
