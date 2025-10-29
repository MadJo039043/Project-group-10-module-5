`timescale 1ns/1ps

module cpu24multi #( 
  parameter INSTR_AW   = 10,
  parameter DATA_AW    = 14,
  parameter DataR      = 24,
  parameter INSTR_HEX  = "program.mem",
  parameter DATA_HEX_X = "X_q_data.mem",
  parameter DATA_HEX_W = "W_q_data.mem",
  parameter DATA_HEX_B = "b_q_data.mem"
)(
  input  wire clk,
  input  wire rst,
  input  wire chk_receive_done,
  
  // External memory interface
  output wire        mem_we_ext,
  output wire [DATA_AW-1:0] mem_addr_ext,
  output wire [23:0] mem_data_in_ext,
  input  wire [23:0] mem_data_out_ext,

  // CPU datapath outputs
  output wire [23:0] alu_result,
  output reg  [2:0]  ALUop,
  output wire [3:0]  opcode,
  output reg  [INSTR_AW-1:0] pc,
  output wire [23:0] instr,
  output wire [23:0] data_out,
  output reg Notifier,
  output reg halt
);

  // ------------------------
  // Instruction ROM
  // ------------------------
  instr_ROM24 #(
    .address_parameter(INSTR_AW),
    .hexcode(INSTR_HEX)
  ) IROM (
    .clk(clk),
    .addr(pc),
    .instr(instr)
  );

  // ------------------------
  // Register File
  // ------------------------
  reg signed [23:0] R [0:63];

  // ------------------------
  // Internal holding registers
  // ------------------------
  reg [23:0] IR, A, B, ALUOut, MDR;

  // ------------------------
  // Decode fields
  // ------------------------
  wire [5:0] rd, rs1, rs2;
  wire [23:0] imm8, off8, off20;

  decoder24 DEC (
    .instr(IR),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm8(imm8),
    .off8(off8),
    .off20(off20)
  );

  // Immediate variants
  wire [23:0] imm8_se  = imm8;
  wire [23:0] imm8_zx  = {16'd0, IR[7:0]};
  wire [23:0] imm8_lui = {IR[7:0], 8'd0};

  assign opcode = IR[23:20];

  // Effective rs2 for STORE
  wire [5:0] rs2_eff = (opcode == 4'h6) ? rd : rs2;

  // ------------------------
  // ALU
  // ------------------------
  reg ALUSrc;  // 0: B, 1: imm/off
  wire [23:0] alu_b_mux = ALUSrc ? (
    (opcode==4'h4) ? imm8_se :   // LI
    (opcode==4'h9) ? imm8_lui :  // LUI
    (opcode==4'hA) ? imm8_zx :   // ORI
    off8
  ) : B;

  wire aluZ;
  ALU24 ALU0 (
    .A(A),
    .B(alu_b_mux),
    .ALUop(ALUop),
    .Y(alu_result),
    .Z(aluZ)
  );

  reg MemWrite;

  // ------------------------
  // External/shared RAM interface
  // ------------------------
  assign mem_we_ext       = MemWrite;                        
  assign mem_addr_ext     = ALUOut[DATA_AW-1:0];     
  assign mem_data_in_ext  = B;                               
  assign data_out         = mem_data_out_ext;

  // ------------------------
  // CPU FSM
  // ------------------------
  localparam S_FETCH1=3'd0, S_FETCH2=3'd1, S_DEC=3'd2, S_EXEC=3'd3,
             S_MEM=3'd4, S_WB=3'd5, S_HALT=3'd6;

  reg [2:0] state, nstate;

  localparam PC_PLUS1 = 2'd0, PC_BRANCH = 2'd1, PC_JUMP = 2'd2;
  reg PCWrite;
  reg [1:0] PCSrc;

  // Control signals
  reg IRwe, Awe, Bwe, ALUOutwe, MDRwe;
  reg RegWrite, MemRead, MemToReg;

  // ------------------------
  // FSM combinational logic
  // ------------------------
  always @(*) begin
    // Defaults
    nstate   = S_FETCH1;
    IRwe     = 0; Awe = 0; Bwe = 0; ALUOutwe = 0; MDRwe = 0;
    RegWrite = 0; MemRead = 0; MemWrite = 0; MemToReg = 0;
    PCWrite = 0; PCSrc = PC_PLUS1; ALUop = 3'd0; ALUSrc = 0;

    case (state)
  S_FETCH1: begin
    PCWrite = 1; 
    PCSrc   = PC_PLUS1; 
    nstate  = S_FETCH2; 
    halt    = 0;
  end

  S_FETCH2: begin
    IRwe   = 1; 
    nstate = S_DEC; 
  end

  S_DEC: begin
    Awe   = 1; 
    Bwe   = 1; 
    nstate = S_EXEC; 
  end

  S_EXEC: begin
    if      (opcode==4'h4) begin ALUop=3'b010; ALUSrc=1; ALUOutwe=1; nstate=S_WB; end
    else if (opcode==4'h1) begin ALUop=3'b000; ALUSrc=0; ALUOutwe=1; nstate=S_WB; end
    else if (opcode==4'h3) begin ALUop=3'b001; ALUSrc=0; ALUOutwe=1; nstate=S_WB; end
    else if (opcode==4'h5 || opcode==4'h6) begin ALUop=3'b011; ALUSrc=1; ALUOutwe=1; nstate=S_MEM; end
    else if (opcode==4'h9) begin ALUop=3'b101; ALUSrc=1; ALUOutwe=1; nstate=S_WB; end
    else if (opcode==4'hA) begin ALUop=3'b100; ALUSrc=1; ALUOutwe=1; nstate=S_WB; end
    else if (opcode==4'h7) begin 
      if (A==B) begin PCWrite=1; PCSrc=PC_BRANCH; end
      nstate = S_FETCH1; 
    end
    else if (opcode==4'h8) begin 
      PCWrite=1; 
      PCSrc=PC_JUMP; 
      nstate=S_FETCH1; 
    end
    else if (opcode==4'h0) nstate=S_HALT; 
    else nstate = S_FETCH1;
  end

  S_MEM: begin
    if (opcode==4'h5) begin MemRead=1; MDRwe=1; nstate=S_WB; end
    else begin MemWrite=1; nstate=S_FETCH1; end
  end

  S_WB: begin
    RegWrite=1; 
    MemToReg=(opcode==4'h5); 
    nstate=S_FETCH1; 
  end

  S_HALT: if(~chk_receive_done) begin nstate = S_FETCH1;
   end else begin
   nstate=S_HALT;
   halt <= 1;
   end
  default: nstate = S_FETCH1;
endcase

  end

  // ------------------------
  // State register
  // ------------------------
  always @(posedge clk) begin
    if (rst) state <= S_FETCH1;
    else state <= nstate;
  end

    
  // ------------------------
  // Latches and PC update
  // ------------------------
  always @(posedge clk) begin
    if (rst) begin
      pc <= 0; IR <= 0; A <= 0; B <= 0; ALUOut <= 0; MDR <= 0; halt <= 0;
    end else begin
      if (IRwe) IR <= instr;
      if (Awe)  A  <= R[rs1];
      if (Bwe)  B  <= R[rs2_eff];
      if (ALUOutwe) ALUOut <= alu_result;
      if (MDRwe) MDR <= mem_data_out_ext;
      if (PCWrite) begin
        case (PCSrc)
          PC_PLUS1:  if (chk_receive_done) pc <= pc + 1; 
          PC_BRANCH: pc <= off8[INSTR_AW-1:0];
          PC_JUMP:   pc <= off20[INSTR_AW-1:0];
        endcase
      end
    end
  end

  // ------------------------
  // Write-back
  // ------------------------
  wire [5:0] dest = (opcode==4'h4 || opcode==4'h5 || opcode==4'h9 || opcode==4'hA) ? rs2 : rd;
  wire [23:0] wb = MemToReg ? MDR : ALUOut;
  
  integer i;
  always @(posedge clk) begin
    if (rst) begin
      for (i=0;i<64;i=i+1) R[i] <= 24'd0;
    end else begin
      if (RegWrite && dest != 6'd0) R[dest] <= wb;
      R[0] <= 24'd0;
    end
  end

  // ------------------------
  // Halt and notifier
  // ------------------------
  // Notifier logic (driven by CPU opcode)
always @(posedge clk or posedge rst) begin
    if (rst)
        Notifier <= 1'b0;
    else
        Notifier <= (opcode == 6);
end

// ------------------------
// R3 snapshot array
// ------------------------
reg [23:0] R3_snapshot [0:9];
reg [3:0]  R3_idx;
integer j;

always @(posedge Notifier or posedge rst) begin
    if (rst) begin
        for (j = 0; j < 10; j = j + 1)
            R3_snapshot[j] <= 24'd0;
        R3_idx <= 0;
    end else if (R3_idx < 10) begin
        R3_snapshot[R3_idx] <= R[3];
        R3_idx <= R3_idx + 1;
    end
end

endmodule