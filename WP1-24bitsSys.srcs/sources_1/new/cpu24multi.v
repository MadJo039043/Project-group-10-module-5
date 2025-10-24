`timescale 1ns/1ps

module cpu24multi #( 
  parameter INSTR_AW  = 10,
  parameter DATA_AW   = 14,
  parameter DataR     = 24,
  parameter INSTR_HEX = "program.mem",
  parameter DATA_HEX_X = "X_q_data.mem",
  parameter DATA_HEX_W = "W_q_data.mem",
  parameter DATA_HEX_B = "b_q_data.mem"
)(
  input  wire clk,
  output wire halt
);

  // ------------------------
  // Program Counter / Fetch
  // ------------------------
  reg  [INSTR_AW-1:0] pc;
  wire [23:0]         instr;

  // 24-bit instruction ROM (word-addressed)
  instr_ROM24 #(.address_parameter(INSTR_AW), .hexcode(INSTR_HEX)) IROM (
    .clk  (clk),
    .addr (pc),
    .instr(instr)
  );

  // ------------------------
  // Architectural register file (64 x 24)
  // ------------------------
  reg  [23:0] R [0:63];

  // ------------------------
  // Micro-architectural holding regs (multi-cycle)
  // ------------------------
  reg [23:0] IR, A, B, ALUOut, MDR;

  // ------------------------
  // Decode fields (from IR)
  // ------------------------
  wire [5:0] rd, rs1, rs2;
  wire [23:0] imm8, off8, off20;
  
  // Immediate variants (built from IR)
wire [23:0] imm8_se  = imm8;                 // sign-extended (from decoder)
wire [23:0] imm8_zx  = {16'd0,  IR[7:0]};    // zero-extended (ORI)
wire [23:0] imm8_lui = {        IR[7:0],16'd0}; // shift-left 16 (LUI)
  // Opcode from IR
  wire [3:0] opcode = IR[23:20];

  // Instr-class helpers
  wire is_HALT  = (opcode == 4'h0);
  wire is_ADD   = (opcode == 4'h1);
  wire is_MUL   = (opcode == 4'h3);
  wire is_LI    = (opcode == 4'h4);
  wire is_LOAD  = (opcode == 4'h5);
  wire is_STORE = (opcode == 4'h6);
  wire is_BEQ   = (opcode == 4'h7);
  wire is_JMP   = (opcode == 4'h8);
  wire is_LUI   = (opcode == 4'h9);
  wire is_ORI   = (opcode == 4'hA); //10
  
  // Pick the right immediate for this instruction
wire [23:0] alu_b_imm =
    is_LI  ? imm8_se  :
    is_LUI ? imm8_lui :
    is_ORI ? imm8_zx  :
             off8;    


  // NOTE: we only use field extraction from decoder24; control comes from FSM.
  decoder24 DEC (
    .instr(IR),
    .rd (rd),  .rs1(rs1),  .rs2(rs2),
    .imm8 (imm8), .off8(off8), .off20(off20)
  );

  // STORE quirk: data reg is 'rd' field
  wire [5:0] rs2_eff = (IR[23:20] == 4'h6) ? rd : rs2;

  // ------------------------
  // ALU (driven from A/B and imm/off under FSM)
  // ALUop codes (same as your single-cycle): 0=ADD, 1=MUL, 2=PASS_B, 3=ADDR_ADD
  // ------------------------
  reg  [2:0] ALUop;        // from FSM
  reg        ALUSrc;       // 0: use B, 1: use imm/off
  // Final B input to ALU
wire [23:0] alu_b_mux = ALUSrc ? alu_b_imm : B;
  wire [23:0] alu_result;
  wire        aluZ;

  ALU24 ALU0 (
    .A    (A),
    .B    (alu_b_mux),
    .ALUop(ALUop),
    .Y    (alu_result),
    .Z    (aluZ)
  );

  // ------------------------
  // Data memory (word-addressed, 24-bit words)
  // ------------------------
  wire [23:0] mem_data;
    // Reg/Memory control
  reg IRwe, Awe, Bwe, ALUOutwe, MDRwe;
  reg RegWrite, MemRead, MemToReg ,MemWrite;

  RAM24 #(
    .ADDRESS_WIDTH(DATA_AW),
    .DATA_WIDTH   (DataR),
    .X_hexcode    (DATA_HEX_X),
    .W_hexcode    (DATA_HEX_W),
    .B_hexcode    (DATA_HEX_B)
  ) DMEM (
    .clk     (clk),
    .we      (MemWrite),
    .addr    (ALUOut[DATA_AW-1:0]),   // address came from A+off8 -> ALUOut
    .data_in (B),                      // STORE writes 'B'
    .data_out(mem_data)
  );

  // ------------------------
  // Multi-cycle controller (FSM)
  // ------------------------

  // States
  localparam S_FETCH1=3'd0,S_FETCH2=3'd1, S_DEC=3'd2, S_EXEC=3'd3, S_MEM=3'd4, S_WB=3'd5, S_HALT=3'd6;
  reg [2:0] state, nstate;

  // PC control
  localparam PC_PLUS1 = 2'd0, PC_BRANCH = 2'd1, PC_JUMP = 2'd2;
  reg       PCWrite;
  reg [1:0] PCSrc;

  // FSM: next-state & control decode
  always @(*) begin
    // defaults (deassert everything)
    nstate   = state;

    IRwe     = 1'b0;
    Awe      = 1'b0;
    Bwe      = 1'b0;
    ALUOutwe = 1'b0;
    MDRwe    = 1'b0;

    RegWrite = 1'b0;
    MemRead  = 1'b0;
    MemWrite = 1'b0;
    MemToReg = 1'b0;

    PCWrite  = 1'b0;
    PCSrc    = PC_PLUS1;

    ALUop    = 3'd0;
    ALUSrc   = 1'b0;

    case (state)
// S0: FETCH1 - increment PC
S_FETCH1: begin
  PCWrite = 1'b1;
  PCSrc   = PC_PLUS1;
  nstate  = S_FETCH2;   // go to second fetch phase
end

// S1: FETCH2 - latch instruction
S_FETCH2: begin
  IRwe    = 1'b1;       // capture instr AFTER PC has updated and ROM settled
  nstate  = S_DEC;
end
      // S1: DECODE/REG READ - A<=R[rs1], B<=R[rs2_eff]
      S_DEC: begin
        Awe     = 1'b1;
        Bwe     = 1'b1;
        nstate  = S_EXEC;
      end

      // S2: EXEC - ALU/branch/jump/address calc
      S_EXEC: begin
        if (is_LI) begin
          ALUop    = 3'b010;   // PASS_B
          ALUSrc   = 1'b1;   // use imm8
          ALUOutwe = 1'b1;
          nstate   = S_WB;
        end else if (is_ADD) begin
          ALUop    = 3'b000;   // ADD
          ALUSrc   = 1'b0;   // use B
          ALUOutwe = 1'b1;
          nstate   = S_WB;
        end else if (is_MUL) begin
          ALUop    = 3'b001;   // MUL
          ALUSrc   = 1'b0;
          ALUOutwe = 1'b1;
          nstate   = S_WB;
        end else if (is_LOAD || is_STORE) begin
          ALUop    = 3'b011;   // address add (same as ADD)
          ALUSrc   = 1'b1;   // use off8
          ALUOutwe = 1'b1;   // latch address into ALUOut
          nstate   = S_MEM;
          end else if (is_LUI)begin
        ALUop  =  3'b101;
        ALUSrc =  1'b1; 
        ALUOutwe = 1'b1;
        nstate = S_WB;
        end else if (is_ORI) begin
        ALUop = 3'b100;
        ALUSrc   = 1'b1;  
        ALUOutwe = 1'b1;
        nstate   = S_WB;
        end else if (is_BEQ) begin
          if (A == B) begin
           $display(">>> BEQ taken at PC=%0d (A=%0d, B=%0d, off8=%0d)", pc, A, B, off8);
            PCWrite = 1'b1;
            PCSrc   = PC_BRANCH;
            end else begin
              $display(">>> BEQ not taken at PC=%0d (A=%0d, B=%0d)", pc, A, B);
          end
          nstate = S_FETCH1;
        end else if (is_JMP) begin
          PCWrite = 1'b1;
          PCSrc   = PC_JUMP;
              $display(">>> JMP: PC=%0d + off20=%0d", pc, off20);
          nstate  = S_FETCH1;
        end else if (is_HALT) begin
          nstate  = S_HALT;
        end else begin
          nstate  = S_FETCH1; // treat unknown as NOP
        end
      end

      // S3: MEM - LOAD: read -> MDR; STORE: write
      S_MEM: begin
        if (is_LOAD) begin
          MemRead  = 1'b1;   // (informational; RAM is synchronous)
          MDRwe    = 1'b1;   // capture mem_data
          nstate   = S_WB;
        end else begin
          MemWrite = 1'b1;   // write B to DMEM[ALUOut]
          nstate   = S_FETCH1;
        end
      end

      // S4: WB - write back to register file
      S_WB: begin
        RegWrite = 1'b1;
        MemToReg = is_LOAD;  // LOAD uses MDR; others use ALUOut
        nstate   = S_FETCH1;
      end

      // S_HALT: hold
      S_HALT: begin
        nstate = S_HALT;
      end
    endcase
  end

  // State register
  initial state = S_FETCH1;
  always @(posedge clk) 
  state <= nstate;

  // ------------------------
  // Datapath updates (clocked)
  // ------------------------

  // IR/A/B/ALUOut/MDR latches
  always @(posedge clk) begin
    if (IRwe)     IR     <= instr;                 // IMEM → IR
    if (Awe)      A      <= R[rs1];                // R[rs1] → A
    if (Bwe)      B      <= R[rs2_eff];            // R[rs2 or rd] → B
    if (ALUOutwe) ALUOut <= alu_result;            // ALU → ALUOut
    if (MDRwe)    MDR    <= mem_data;              // DMEM → MDR

    // PC update
    if (PCWrite) begin
      case (PCSrc)
        PC_PLUS1:  pc <= pc + 1'b1;
        PC_BRANCH: pc <= pc + off8 [INSTR_AW-1:0];
        PC_JUMP:   pc <= pc + off20[INSTR_AW-1:0];
        default: ;
      endcase
    end
  end

  // Write-back (uses dest rule: LI/LOAD write rt; R-type write rd)
  wire [5:0] dest = ( is_ORI || is_LUI || is_LI || is_LOAD) ? rs2 : rd;
  wire [23:0] wb  = MemToReg ? MDR : ALUOut;

  always @(posedge clk) if (RegWrite) R[dest] <= wb;

  // ------------------------
  // Halt output and init
  // ------------------------
  assign halt = (state == S_HALT);

  integer i;
  initial begin
    pc = {INSTR_AW{1'b0}};
    for (i=0; i<64; i=i+1) R[i] = 24'd0;
  end
 always @(posedge clk)
if (IRwe)
  $display("IR loaded: instr=%h  (PC=%0d)", instr, pc);

always @(negedge clk)
  $display(">> After clock: PC=%0d (state=%0d)", pc, state);
  always @(posedge clk)
  $display("STATE=%0d -> NSTATE=%0d (PC=%0d opcode=%h)", state, nstate, pc, IR[23:20]);


endmodule
