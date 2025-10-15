class SimpleProcessor:
    def __init__(self, memory_size=9000):
        self.memory = [0] * memory_size  # Memory array
        self.registers = [0] * 10        # R0-R9 registers
        self.pc = 0                      # Program counter
        
    def load_program(self, instructions):
        # Load program into memory
        for i, instr in enumerate(instructions):
            self.memory[i] = instr
    
    def load_data(self, address, data):
        # Load data into memory at specified address
        if isinstance(data, (list, tuple)):
            for i, val in enumerate(data):
                self.memory[address + i] = val
        else:
            self.memory[address] = data
    
    def execute_instruction(self, instr):
        parts = instr.strip().split()
        op = parts[0].upper()
        
        if op == 'LOAD':
            rd = int(parts[1][1])  # Get register number from R1, R2, etc.
            addr = parts[2].strip('[]')
            if addr.isdigit():  # Direct address
                self.registers[rd] = int(addr)
            else:  # Memory access
                addr = int(addr)
                self.registers[rd] = self.memory[addr]
                
        elif op == 'STORE':
            rs = int(parts[1][1])
            addr = int(parts[2].strip('[]'))
            self.memory[addr] = self.registers[rs]
            
        elif op == 'ADD':
            rd = int(parts[1][1])
            r1 = int(parts[2][1])
            r2 = int(parts[3][1])
            self.registers[rd] = self.registers[r1] + self.registers[r2]
            
        elif op == 'SUB':
            rd = int(parts[1][1])
            r1 = int(parts[2][1])
            r2 = int(parts[3][1])
            self.registers[rd] = self.registers[r1] - self.registers[r2]
            
        elif op == 'MUL':
            rd = int(parts[1][1])
            r1 = int(parts[2][1])
            r2 = int(parts[3][1])
            self.registers[rd] = self.registers[r1] * self.registers[r2]
            
        elif op == 'JMP':
            addr = int(parts[1])
            self.pc = addr - 1  # -1 because pc will be incremented
            
        elif op == 'BEQ':
            r1 = int(parts[1][1])
            r2 = int(parts[2][1])
            addr = int(parts[3])
            if self.registers[r1] == self.registers[r2]:
                self.pc = addr - 1  # -1 because pc will be incremented
                
        elif op == 'HALT':
            return False
            
        return True

    def run(self, debug=False):
        running = True
        while running and self.pc < len(self.memory):
            instr = self.memory[self.pc]
            if isinstance(instr, str) and instr.strip():  # Valid instruction
                if debug:
                    print(f"PC={self.pc}, Executing: {instr.strip()}")
                    print(f"Registers before: {self.registers}")
                
                running = self.execute_instruction(instr)
                
                if debug:
                    print(f"Registers after: {self.registers}\n")
            
            self.pc += 1
        
        if debug:
            print("Program finished.")