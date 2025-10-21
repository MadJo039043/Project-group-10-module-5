`timescale 1ns/1ps

module cpu24 #( 
  parameter INSTR_AW  = 10,
  parameter DATA_AW   = 14,
  parameter DataR=24,
  parameter INSTR_HEX = "program.mem",
  parameter DATA_HEX_X = "X_q_data.hex",
  parameter DATA_HEX_W = "W_q_data.hex",
  parameter DATA_HEX_B =  "b_q_data.hex"
)(
  input  wire clk,
  output wire halt
);

//
  // ------------------------
  // Fetch / PC
  // ------------------------
  reg  [INSTR_AW-1:0] pc;
  wire [INSTR_AW-1:0] pc_plus_1 = pc + 1'b1;

  wire [23:0] instr;

  // 24-bit instruction ROM
  instr_ROM24 #(.address_parameter(INSTR_AW), .hexcode(INSTR_HEX)) IROM (
    .clk  (clk),
    .addr (pc),
    .instr(instr)
  );

  // ------------------------
  // Decode (6-bit reg fields, 24-bit immediates)
  // ------------------------
  wire [5:0] rd, rs1, rs2;              // 64 registers
  wire [23:0] imm8, off8, off20;
  wire RegWrite, MemRead, MemWrite, MemToReg, ALUSrc, Branch, Jump;
  wire [1:0] ALUop;

  decoder24 DEC (
    .instr    (instr),
    .rd       (rd), .rs1(rs1), .rs2(rs2),
    .imm8     (imm8), .off8(off8), .off20(off20),
    .RegWrite (RegWrite), .MemRead(MemRead), .MemWrite(MemWrite),
    .MemToReg (MemToReg), .ALUSrc(ALUSrc), .ALUop(ALUop),
    .Branch   (Branch), .Jump(Jump), .Halt(halt)
  );

  // ------------------------
  // Register file (64 x 24) - no reset
  // ------------------------
  reg  [23:0] R [0:63];
  wire [23:0] rs1_data = R[rs1];

  // STORE quirk: data register is 'rd' field
  wire is_store = (instr[23:20] == 4'h6);
  wire [5:0] rs2_eff = is_store ? rd : rs2;
  wire [23:0] rs2_data = R[rs2_eff];

  // ------------------------
  // ALU
  // ------------------------
  wire [23:0] imm_or_off = (ALUop==2'd2) ? imm8 : off8;  // PASS_B→imm8, LOAD/STORE→off8
  wire [23:0] alu_b      = ALUSrc ? imm_or_off : rs2_data;

  wire [23:0] alu_result;
  wire        aluZ; // unused

  ALU24 ALU0 (
    .A    (rs1_data),
    .B    (alu_b),
    .ALUop(ALUop),
    .Y    (alu_result),
    .Z    (aluZ)
  );

  // ------------------------
  // Data memory (word-addressed, 24-bit words)
  // ------------------------
  wire [23:0] mem_data;

  RAM24 #(.ADDRESS_WIDTH(DATA_AW),.DATA_WIDTH(DataR)
  ,.X_hexcode(DATA_HEX_X), .W_hexcode(DATA_HEX_W),.B_hexcode(DATA_HEX_B)) DMEM (
    .clk     (clk),
    .we      (MemWrite),
    .addr    (alu_result[DATA_AW-1:0]),
    .data_in (rs2_data),
    .data_out(mem_data)
  );

  // ------------------------
  // Write-back
  // ------------------------
  wire [23:0] rd_data = MemToReg ? mem_data : alu_result;

  // ------------------------
  // Branch / Jump
  // ------------------------
  wire        eq = (rs1_data == rs2_data);
  wire        take_branch = Branch & eq;

  wire [INSTR_AW-1:0] pc_branch = pc_plus_1 + off8 [INSTR_AW-1:0];   // BEQ uses off8
  wire [INSTR_AW-1:0] pc_jump   = pc_plus_1 + off20[INSTR_AW-1:0];   // JMP uses off20

  wire [INSTR_AW-1:0] next_pc =
      Jump        ? pc_jump   :
      take_branch ? pc_branch :
                    pc_plus_1;
                    
  // ------------------------
  // State updates (no reset)
  // ------------------------
  integer i;
  always @(posedge clk) begin
    if (RegWrite) R[rd] <= rd_data; // write selected dest
    if (!halt) pc <= next_pc;
  end

  initial begin
    pc = {INSTR_AW{1'b0}};
    for (i=0; i<64; i=i+1) R[i] = 24'd0;
  end

//Multi-cycle registers
reg [23:0] IR,A,B,S,M;

//Enable from contoller/FSM 
reg IRwe,Awe,Bwe,Swe,Mwe;

//doing the register thing when the we's are active
always @(posedge clk) begin
if(IRwe) 
IR <= instr;
if(Awe)  
A <= R[rs1];
if(Bwe)
B <= R[rs2];
if(Swe)
S <= ALUop ;
if(Mwe)
M <= mem_data;
end

//// In WRITEBACK state:
//wire [5:0] dest = (isLI | isLOAD) ? rt : rd;
//wire [23:0] wb  = MemToReg ? MDR : ALUOut;
//always @(posedge clk) if (RegWrite) R[dest] <= wb;

endmodule
