# ===============================================================
# DNN Golden Model Assembly → program.mem Encoder
# Custom ISA: 24-bit instructions
#
# R-type : [ op(4) | rs(6) | rt(6) | rd(6) | 00(2) ]
# I-type : [ op(4) | rs(6) | rt(6) | imm(8) ]
# J-type : [ op(4) | target(20) ]
#
# Opcodes (MATCHES VERILOG DECODER):
#   0x0 HALT
#   0x1 ADD
#   0x3 MUL
#   0x4 LI
#   0x5 LOAD
#   0x6 STORE
#   0x7 BEQ
#   0x8 JMP
#   0x9 LUI
#   0xA ORI
# ===============================================================

def encode_R(op, rs, rt, rd):
    """Encode R-type: [op(4)|rs(6)|rt(6)|rd(6)|00(2)]"""
    return (op << 20) | (rs << 14) | (rt << 8) | (rd << 2)

def encode_I(op, rs, rt, imm):
    """Encode I-type: [op(4)|rs(6)|rt(6)|imm(8)]"""
    imm &= 0xFF
    return (op << 20) | (rs << 14) | (rt << 8) | imm

def encode_J(op, target):
    """Encode J-type: [op(4)|target(20)]"""
    target &= 0xFFFFF
    return (op << 20) | target

# ---------------------------------------------------------------
# Opcode dictionary (matches Verilog exactly)
# ---------------------------------------------------------------
OP = {
    "HALT":  0x0,
    "ADD":   0x1,
    "MUL":   0x3,
    "LI":    0x4,
    "LOAD":  0x5,
    "STORE": 0x6,
    "BEQ":   0x7,
    "JMP":   0x8,
    "LUI":   0x9,
    "ORI":   0xA,
}

# ---------------------------------------------------------------
# Program instructions (simplified DNN loop)
# ---------------------------------------------------------------
program = []

# Initialization
program += [
    (encode_I(OP["LUI"], 0, 4, 0x00),   "LUI R4, 0x00        ; X_base = 0x0000"),
    (encode_I(OP["ORI"], 4, 4, 0x00),   "ORI R4, R4, 0x00"),
    (encode_I(OP["LUI"], 0, 5, 0x10),   "LUI R5, 0x10        ; W_base = 0x1000"),
    (encode_I(OP["ORI"], 5, 5, 0x00),   "ORI R5, R5, 0x00"),
    (encode_I(OP["LUI"], 0, 6, 0x2E),   "LUI R6, 0x2E        ; B_base upper"),
    (encode_I(OP["ORI"], 6, 6, 0xA0),   "ORI R6, R6, 0xA0    ; B_base = 0x2EA0"),
    (encode_I(OP["LUI"], 0, 7, 0x30),   "LUI R7, 0x30        ; Y_base upper"),
    (encode_I(OP["ORI"], 7, 7, 0x00),   "ORI R7, R7, 0x00    ; Y_base = 0x3000"),
    (encode_I(OP["LI"], 0, 9, 1),       "LI R9, 1            ; one = 1"),
    (encode_I(OP["LI"], 0, 10, 10),     "LI R10, 10          ; end10 = 10"),
    (encode_I(OP["LUI"], 0, 11, 0x03),  "LUI R11, 0x03       ; upper bits of 784"),
    (encode_I(OP["ORI"], 11, 11, 0x10), "ORI R11, R11, 0x10  ; 784 = 0x0310"),
]

# Outer Loop: for i in range(10)
program += [
    (encode_R(OP["ADD"], 0, 0, 1),      "ADD R1, R0, R0      ; i = 0"),
    (encode_R(OP["ADD"], 6, 1, 8),      "ADD R8, R6, R1      ; tmp = B_base + i"),
    (encode_I(OP["LOAD"], 8, 3, 0),     "LOAD R3, [R8]       ; acc = b_q[i]"),
    (encode_R(OP["MUL"], 1, 11, 8),     "MUL R8, R1, R11     ; tmp = i * 784"),
    (encode_R(OP["ADD"], 8, 5, 8),      "ADD R8, R8, R5      ; tmp += W_base"),
    (encode_R(OP["ADD"], 0, 0, 2),      "ADD R2, R0, R0      ; j = 0"),
    (encode_R(OP["ADD"], 8, 2, 12),     "ADD R12, R8, R2     ; tmp = W_row + j"),
    (encode_I(OP["LOAD"], 12, 12, 0),   "LOAD R12, [R12]     ; W_q[i,j]"),
    (encode_R(OP["ADD"], 4, 2, 13),     "ADD R13, R4, R2     ; tmp = X_base + j"),
    (encode_I(OP["LOAD"], 13, 13, 0),   "LOAD R13, [R13]     ; X_q[j]"),
    (encode_R(OP["MUL"], 12, 13, 14),   "MUL R14, R12, R13   ; product"),
    (encode_R(OP["ADD"], 3, 14, 3),     "ADD R3, R3, R14     ; acc += product"),
    (encode_R(OP["ADD"], 2, 9, 2),      "ADD R2, R2, R9      ; j++"),
    (encode_I(OP["BEQ"], 2, 11, 0x10),  "BEQ R2, R11, END_INNER"),
    (encode_J(OP["JMP"], 0x12),         "JMP INNER_LOOP"),
    (encode_R(OP["ADD"], 7, 1, 8),      "ADD R8, R7, R1      ; tmp = Y_base + i"),
    (encode_I(OP["STORE"], 8, 3, 0),    "STORE R3, [R8]      ; y_int[i] = acc"),
    (encode_R(OP["ADD"], 1, 9, 1),      "ADD R1, R1, R9      ; i++"),
    (encode_I(OP["BEQ"], 1, 10, 0x20),  "BEQ R1, R10, END_OUTER"),
    (encode_J(OP["JMP"], 0x0A),         "JMP OUTER_LOOP"),
    (encode_J(OP["HALT"], 0x00),        "HALT"),
]

# ---------------------------------------------------------------
# Write file with comments
# ---------------------------------------------------------------
with open("program.mem", "w") as f:
    for instr, comment in program:
        f.write(f"{instr:06X} // {comment}\n")

print(f"✅ program.mem written with {len(program)} instructions and comments (Verilog opcode match).")
