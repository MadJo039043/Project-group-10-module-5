;=======================================================================
; 2-LAYER MNIST INFERENCE (784 → 256 → 10) - OPTIMIZED WITH MAC
; Integer-only version — uses MAC instruction for faster computation
;=======================================================================
; Layer 1: H = ReLU(W1 * X + b1)
; Layer 2: Y = W2 * H + b2
;=======================================================================

;-----------------------------------------------------------------------
; REGISTER USAGE
;-----------------------------------------------------------------------
; R0  = constant 0
; R1  = i (outer loop)
; R2  = j (inner loop)
; R3  = acc (accumulator) - USED BY MAC AS ACCUMULATOR
; R4  = X_base / H_base
; R5  = W_base
; R6  = B_base
; R7  = Y_base / H_out_base
; R8  = tmp (address calc)
; R9  = one (constant 1)
; R10 = out_dim
; R11 = in_dim
; R12 = W_q[i,j]
; R13 = X_q[j] / H[j]
; R15 = word_size (4 for int32 addressing)
;-----------------------------------------------------------------------

;=======================================================================
; MEMORY MAP (all int32, no overlap)
;=======================================================================
; 0x00000 : X   (784 × int32)
; 0x01000 : W1  (256×784 × int32)
; 0x32000 : b1  (256 × int32)
; 0x32400 : H   (256 × int32)
; 0x32800 : W2  (10×256 × int32)
; 0x32E00 : b2  (10 × int32)
; 0x33000 : Y   (10 × int32)
;=======================================================================

;=======================================================================
; CONSTANT INITIALIZATION
;=======================================================================
ORI  R9,  R0, 1           ; one = 1
ORI  R15, R0, 4           ; word size = 4

; in_dim (layer1) = 784 (0x0310)
LUI  R11, 0x03
ORI  R11, R11, 0x10

; out_dim (layer1) = 256 (0x0100)
LUI  R10, 0x01
ORI  R10, R10, 0x00

;=======================================================================
; === LAYER 1 ===  (Input X → Hidden H)
;=======================================================================

; Base address setup
LUI  R4, 0x00             ; X_base = 0x00000
ORI  R4, R4, 0x00
LUI  R5, 0x01             ; W1_base = 0x01000
ORI  R5, R5, 0x00
LUI  R6, 0x32             ; B1_base = 0x32000
ORI  R6, R6, 0x00
LUI  R7, 0x32             ; H_base = 0x32400
ORI  R7, R7, 0x40

; i = 0
ADD  R1, R0, R0
OUTER1:

    ; acc = b1[i]  (initialize accumulator)
    MUL  R8,  R1, R15
    ADD  R8,  R6, R8
    LOAD R3,  R8, 0

    ; row_base = W1_base + i * in_dim * 4
    MUL  R8,  R1, R11
    MUL  R8,  R8, R15
    ADD  R8,  R5, R8

    ; j = 0
    ADD  R2,  R0, R0
INNER1:
        ; W1[i,j]
        MUL  R12, R2, R15
        ADD  R12, R8, R12
        LOAD R12, R12, 0

        ; X[j]
        MUL  R13, R2, R15
        ADD  R13, R4, R13
        LOAD R13, R13, 0

        ; *** MAC: acc += W1[i,j] * X[j] ***
        ; BEFORE: MUL R14, R12, R13 + ADD R3, R3, R14 (2 instructions)
        ; NOW:    MAC R3, R12, R13               (1 instruction!)
        MAC  R3,  R12, R13

        ; j++
        ADD  R2,  R2,  R9
        BEQ  R2,  R11, END_INNER1
        JMP  INNER1
END_INNER1:

    ;-------------------------------------------------------------
    ; ReLU: if acc < 0, set to 0
    ; *** USING BLT INSTEAD OF BNEG ***
    ;-------------------------------------------------------------
    BLT  R3, R0, RELU_ZERO1    ; if (R3 < 0) goto RELU_ZERO1
    JMP  REQUANT1
RELU_ZERO1:
    ORI  R3, R0, 0
REQUANT1:
    ;-------------------------------------------------------------
    ; Requantization: H[i] = acc >> 13 (divide by 8192)
    ; This prevents overflow in Layer 2
    ;-------------------------------------------------------------
    SHR  R3, R3, 13            ; R3 = R3 >>> 13 (arithmetic shift right)
STORE_H1:
    MUL  R8,  R1, R15
    ADD  R8,  R7, R8
    STORE R3, R8, 0

    ; i++
    ADD  R1,  R1, R9
    BEQ  R1,  R10, END_OUTER1
    JMP  OUTER1
END_OUTER1:

;=======================================================================
; === LAYER 2 ===  (Hidden H → Output Y)
;=======================================================================

; Reset loop dimensions
LUI  R11, 0x01            ; in_dim = 256 (0x0100)
ORI  R11, R11, 0x00
ORI  R10, R0, 10           ; out_dim = 10

; Base address setup
LUI  R4, 0x32             ; X_base = H_base = 0x32400
ORI  R4, R4, 0x40
LUI  R5, 0x32             ; W2_base = 0x32800
ORI  R5, R5, 0x80
LUI  R6, 0x32             ; B2_base = 0x32E00
ORI  R6, R6, 0xE0
LUI  R7, 0x33             ; Y_base = 0x33000
ORI  R7, R7, 0x00

; i = 0
ADD  R1,  R0, R0
OUTER2:

    ; acc = b2[i]
    MUL  R8,  R1, R15
    ADD  R8,  R6, R8
    LOAD R3,  R8, 0

    ; row_base = W2_base + i * in_dim * 4
    MUL  R8,  R1, R11
    MUL  R8,  R8, R15
    ADD  R8,  R5, R8

    ; j = 0
    ADD  R2,  R0, R0
INNER2:
        ; W2[i,j]
        MUL  R12, R2, R15
        ADD  R12, R8, R12
        LOAD R12, R12, 0

        ; H[j]
        MUL  R13, R2, R15
        ADD  R13, R4, R13
        LOAD R13, R13, 0

        ; *** MAC: acc += W2[i,j] * H[j] ***
        MAC  R3,  R12, R13

        ; j++
        ADD  R2,  R2,  R9
        BEQ  R2,  R11, END_INNER2
        JMP  INNER2
END_INNER2:

    ; Y[i] = acc
    MUL  R8,  R1, R15
    ADD  R8,  R7, R8
    STORE R3, R8, 0

    ; i++
    ADD  R1,  R1, R9
    BEQ  R1,  R10, END_OUTER2
    JMP  OUTER2
END_OUTER2:

;=======================================================================
; END PROGRAM
;=======================================================================
HALT
