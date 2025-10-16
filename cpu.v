`timescale 1ns/1ps

module cpu #(
  parameter INSTR_AW  = 10,              // 2^10 = 1024 instructions
  parameter DATA_AW   = 12,              // 2^12 = 4096 data words
  parameter INSTR_HEX = "program.hex",
  parameter DATA_HEX  = "data.hex"
)(
  input  wire clk,
  output wire halt
);

  // ------------------------
  // Fetch / PC 
  // ------------------------
  reg  [INSTR_AW-1:0] pc;
  wire [INSTR_AW-1:0] pc_plus_1 = pc + 1'b1;

  wire [31:0] instr;

  // 32-bit instruction ROM
  instr_rom #(.address_parameter(INSTR_AW), .hexcode(INSTR_HEX)) IROM (
    .clk  (clk),
    .addr (pc),
    .instr(instr)                 // 32-bit out
  );

  // ------------------------
  // Decode
  // ------------------------
  wire [2:0] rd, rs1, rs2;
  wire [31:0] imm25, off16, off22, off28;
  wire RegWrite, MemRead, MemWrite, MemToReg, ALUSrc, Branch, Jump;
  wire [1:0] ALUop; // 0=ADD, 1=MUL, 2=PASS_B (LI), 3=ADDR_ADD

  decoder DEC (
    .instr    (instr),
    .rd       (rd), .rs1(rs1), .rs2(rs2),
    .imm25    (imm25), .off16(off16), .off22(off22), .off28(off28),
    .RegWrite (RegWrite), .MemRead(MemRead), .MemWrite(MemWrite),
    .MemToReg (MemToReg), .ALUSrc(ALUSrc), .ALUop(ALUop),
    .Branch   (Branch), .Jump(Jump), .Halt(halt)
  );

  // ------------------------
  // Register file (8 x 32) - no reset
  // ------------------------
  reg  [31:0] R [0:7];
  wire [31:0] rs1_data = R[rs1];
  wire [31:0] rs2_data = R[rs2];

  // ------------------------
  // ALU
  // ------------------------
  wire [31:0] imm_or_off = (ALUop==2'd2) ? imm25 : off16; // PASS_B→imm25, LOAD/STORE→off16
  wire [31:0] alu_b      = ALUSrc ? imm_or_off : rs2_data;

  wire [31:0] alu_result;
  wire        aluZ; // unused for BEQ

  ALU ALU0 (
    .A    (rs1_data),
    .B    (alu_b),
    .ALUop(ALUop),
    .Y    (alu_result),
    .Z    (aluZ)
  );

  // ------------------------
  // Data memory (word-addressed)
  // ------------------------
  wire [31:0] mem_data;

  Ram #(.address_parameter(DATA_AW), .hexcode(DATA_HEX)) DMEM (
    .clk     (clk),
    .we      (MemWrite),
    .addr    (alu_result[DATA_AW-1:0]),
    .data_in (rs2_data),
    .data_out(mem_data)
  );

  // ------------------------
  // Write-back
  // ------------------------
  wire [31:0] rd_data = MemToReg ? mem_data : alu_result;

  // ------------------------
  // Branch / Jump (use equality, not ALU Z)
  // ------------------------
  wire        eq = (rs1_data == rs2_data);
  wire        take_branch = Branch & eq;

  wire [INSTR_AW-1:0] pc_branch = pc_plus_1 + off22[INSTR_AW-1:0];
  wire [INSTR_AW-1:0] pc_jump   = pc_plus_1 + off28[INSTR_AW-1:0];

  wire [INSTR_AW-1:0] next_pc =
      Jump        ? pc_jump   :
      take_branch ? pc_branch :
                    pc_plus_1;

  // ------------------------
  // State updates (no reset)
  // ------------------------
  integer i;
  always @(posedge clk) begin
    // regfile write
    if (RegWrite) R[rd] <= rd_data;

    // PC update (hold on HALT)
    if (!halt) pc <= next_pc;
  end

  // Optional: SIMULATION-ONLY init for determinism (ignored in ASIC; FPGA may still init to 0)
  initial begin
    pc = {INSTR_AW{1'b0}};
    for (i=0; i<8; i=i+1) R[i] = 32'd0;
  end

endmodule

