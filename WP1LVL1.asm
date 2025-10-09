; Example: compute y = a*b + c
LOAD R1, [a]      ; load a
LOAD R2, [b]      ; load b
MUL  R3, R1, R2   ; R3 = a*b
LOAD R4, [c]      ; load c
ADD  R5, R3, R4   ; R5 = a*b + c
STORE R5, [y]     ; store result
HALT
