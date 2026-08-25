#include "cpu.h"
#include <iostream>
#include <cstdint>

CPU::CPU(Memory* memory_instance) {
    mem = memory_instance;
    pc = 0x00000000; // Start booting at address 0
    
    // Initialize all registers to 0
    for(int i = 0; i < 32; i++) {
        regs[i] = 0;
    }
}

uint32_t CPU::read_csr(uint16_t addr) {
    // If the CSR doesn't exist in our map yet, this initializes it to 0 and returns 0.
    return csrs[addr]; 
}

void CPU::write_csr(uint16_t addr, uint32_t value) {
    // In a full implementation, you would mask out read-only bits here 
    // (e.g., hardwiring certain bits of mstatus to 0 or 1).
    csrs[addr] = value;
}

void CPU::trap(uint32_t cause, uint32_t tval) {
    // Save the current PC (so the OS knows where to return)
    write_csr(CSR_MEPC, pc);
    
    // Save the cause of the trap (11 = Environment call from M-mode)
    write_csr(CSR_MCAUSE, cause);
    
    // Save trap value (e.g., faulting address, optional but helpful)
    write_csr(CSR_MTVAL, tval);
    
    // Jump to the OS trap handler. 
    // The lowest 2 bits of mtvec define the mode (Direct vs Vectored). 
    // We mask them out to get the base address.
    uint32_t mtvec = read_csr(CSR_MTVEC);
    pc = mtvec & ~0x3; 
}

bool CPU::step() {
    uint32_t instruction = mem->read32(pc);
    uint32_t opcode = instruction & 0x7F;
    
    // Core instruction format fields
    uint32_t rd     = (instruction >> 7)  & 0x1F;
    uint32_t funct3 = (instruction >> 12) & 0x07;
    uint32_t rs1    = (instruction >> 15) & 0x1F;
    uint32_t rs2    = (instruction >> 20) & 0x1F;
    uint32_t funct7 = (instruction >> 25) & 0x7F;

    switch(opcode) {
        
        case 0x37: // LUI (Load Upper Immediate)
            if (rd != 0) {
                // Keep upper 20 bits, zero out lower 12 bits
                regs[rd] = instruction & 0xFFFFF000; 
            }
            pc += 4;
            return true;

        case 0x17: // AUIPC (Add Upper Immediate to PC)
            if (rd != 0) {
                regs[rd] = pc + (instruction & 0xFFFFF000);
            }
            pc += 4;
            return true;

        case 0x13: // I-Type (ALU Immediate Operations)
            {
                // Sign-extend the 12-bit immediate to 32 bits
                int32_t imm = ((int32_t)instruction) >> 20; 
                uint32_t shamt = imm & 0x1F; // For shift operations

                if (rd != 0) { 
                    switch(funct3) {
                        case 0x0: regs[rd] = regs[rs1] + imm; break; // ADDI
                        case 0x2: // SLTI (Set Less Than Immediate)
                            regs[rd] = ((int32_t)regs[rs1] < imm) ? 1 : 0; 
                            break;
                        case 0x3: // SLTIU (Set Less Than Immediate Unsigned)
                            regs[rd] = (regs[rs1] < (uint32_t)imm) ? 1 : 0; 
                            break;
                        case 0x4: regs[rd] = regs[rs1] ^ imm; break; // XORI
                        case 0x6: regs[rd] = regs[rs1] | imm; break; // ORI
                        case 0x7: regs[rd] = regs[rs1] & imm; break; // ANDI
                        
                        case 0x1: regs[rd] = regs[rs1] << shamt; break; // SLLI
                        case 0x5: 
                            // Check bit 30 (which is part of funct7) to differentiate SRLI and SRAI
                            if ((instruction >> 30) & 1) { 
                                // SRAI (Arithmetic Shift Right - preserves sign)
                                regs[rd] = (int32_t)regs[rs1] >> shamt; 
                            } else { 
                                // SRLI (Logical Shift Right - fills with zeros)
                                regs[rd] = regs[rs1] >> shamt; 
                            }
                            break;
                    }
                }
                pc += 4; 
            }
            return true;

        case 0x33: // R-Type (ALU & M-Extension Register-Register Operations)
            {
                if (rd != 0) {
                    if (funct7 == 0x01) { 
                        // --- M EXTENSION (Multiplication & Division) ---
                        switch(funct3) {
                            case 0x0: // MUL
                                regs[rd] = (uint32_t)((int32_t)regs[rs1] * (int32_t)regs[rs2]); 
                                break;
                            case 0x1: // MULH (Signed * Signed)
                                regs[rd] = (uint32_t)(((int64_t)(int32_t)regs[rs1] * (int64_t)(int32_t)regs[rs2]) >> 32); 
                                break;
                            case 0x2: // MULHSU (Signed * Unsigned)
                                regs[rd] = (uint32_t)(((int64_t)(int32_t)regs[rs1] * (uint64_t)regs[rs2]) >> 32);
                                break;
                            case 0x3: // MULHU (Unsigned * Unsigned)
                                regs[rd] = (uint32_t)(((uint64_t)regs[rs1] * (uint64_t)regs[rs2]) >> 32);
                                break;
                            case 0x4: // DIV (Signed)
                                if (regs[rs2] == 0) {
                                    regs[rd] = 0xFFFFFFFF; // Division by zero returns -1
                                } else if (regs[rs1] == 0x80000000 && regs[rs2] == 0xFFFFFFFF) {
                                    regs[rd] = 0x80000000; // Overflow handles INT_MIN
                                } else {
                                    regs[rd] = (uint32_t)((int32_t)regs[rs1] / (int32_t)regs[rs2]);
                                }
                                break;
                            case 0x5: // DIVU (Unsigned)
                                if (regs[rs2] == 0) {
                                    regs[rd] = 0xFFFFFFFF; // Division by zero returns max unsigned val
                                } else {
                                    regs[rd] = regs[rs1] / regs[rs2];
                                }
                                break;
                            case 0x6: // REM (Signed)
                                if (regs[rs2] == 0) {
                                    regs[rd] = regs[rs1]; // Division by zero returns dividend
                                } else if (regs[rs1] == 0x80000000 && regs[rs2] == 0xFFFFFFFF) {
                                    regs[rd] = 0; // Overflow returns 0
                                } else {
                                    regs[rd] = (uint32_t)((int32_t)regs[rs1] % (int32_t)regs[rs2]);
                                }
                                break;
                            case 0x7: // REMU (Unsigned)
                                if (regs[rs2] == 0) {
                                    regs[rd] = regs[rs1]; // Division by zero returns dividend
                                } else {
                                    regs[rd] = regs[rs1] % regs[rs2];
                                }
                                break;
                        }
                    } else {
                        // --- Base ALU Operations ---
                        switch(funct3) {
                            case 0x0:
                                if (funct7 == 0x20) {
                                    regs[rd] = regs[rs1] - regs[rs2]; // SUB
                                } else {
                                    regs[rd] = regs[rs1] + regs[rs2]; // ADD
                                }
                                break;
                            case 0x1: 
                                // SLL (Shift Left Logical) - shift amount is lower 5 bits of rs2
                                regs[rd] = regs[rs1] << (regs[rs2] & 0x1F); 
                                break;
                            case 0x2: // SLT (Set Less Than - signed)
                                regs[rd] = ((int32_t)regs[rs1] < (int32_t)regs[rs2]) ? 1 : 0;
                                break;
                            case 0x3: // SLTU (Set Less Than Unsigned)
                                regs[rd] = (regs[rs1] < regs[rs2]) ? 1 : 0;
                                break;
                            case 0x4: 
                                regs[rd] = regs[rs1] ^ regs[rs2]; // XOR
                                break; 
                            case 0x5:
                                if (funct7 == 0x20) {
                                    // SRA (Arithmetic Shift Right)
                                    regs[rd] = (int32_t)regs[rs1] >> (regs[rs2] & 0x1F);
                                } else {
                                    // SRL (Logical Shift Right)
                                    regs[rd] = regs[rs1] >> (regs[rs2] & 0x1F);
                                }
                                break;
                            case 0x6: 
                                regs[rd] = regs[rs1] | regs[rs2]; // OR
                                break; 
                            case 0x7: 
                                regs[rd] = regs[rs1] & regs[rs2]; // AND
                                break; 
                        }
                    }
                }
                pc += 4;
            }
            return true;

        case 0x03: // I-Type (Load Operations)
            {
                // Sign-extend the 12-bit immediate
                int32_t imm = ((int32_t)instruction) >> 20; 
                uint32_t addr = regs[rs1] + imm;

                if (rd != 0) {
                    switch(funct3) {
                        case 0x0: // LB (Load Byte - sign extended)
                            regs[rd] = (int32_t)(int8_t)mem->read8(addr);
                            break;
                        case 0x1: // LH (Load Halfword - sign extended)
                            regs[rd] = (int32_t)(int16_t)mem->read16(addr);
                            break;
                        case 0x2: // LW (Load Word)
                            regs[rd] = mem->read32(addr);
                            break;
                        case 0x4: // LBU (Load Byte Unsigned)
                            regs[rd] = mem->read8(addr);
                            break;
                        case 0x5: // LHU (Load Halfword Unsigned)
                            regs[rd] = mem->read16(addr);
                            break;
                    }
                }
                pc += 4;
            }
            return true;

        case 0x23: // S-Type (Store Operations)
            {
                // Reconstruct and sign-extend the 12-bit immediate for S-Type
                int32_t imm = ((int32_t)(instruction & 0xFE000000) >> 20) | ((instruction >> 7) & 0x1F);
                uint32_t addr = regs[rs1] + imm;

                switch(funct3) {
                    case 0x0: // SB (Store Byte)
                        mem->write8(addr, regs[rs2] & 0xFF);
                        break;
                    case 0x1: // SH (Store Halfword)
                        mem->write16(addr, regs[rs2] & 0xFFFF);
                        break;
                    case 0x2: // SW (Store Word)
                        mem->write32(addr, regs[rs2]);
                        break;
                }
                pc += 4;
            }
            return true;

        case 0x63: // B-Type (Branch Operations)
            {
                // Reconstruct and sign-extend the 13-bit immediate
                int32_t imm = ((int32_t)(instruction & 0x80000000) >> 19) | // Sign extend and bit 12
                              ((instruction & 0x80) << 4) |                 // bit 11
                              ((instruction >> 20) & 0x7E0) |               // bits 10:5
                              ((instruction >> 7) & 0x1E);                  // bits 4:1

                bool take_branch = false;
                switch(funct3) {
                    case 0x0: take_branch = (regs[rs1] == regs[rs2]); break;                   // BEQ
                    case 0x1: take_branch = (regs[rs1] != regs[rs2]); break;                   // BNE
                    case 0x4: take_branch = ((int32_t)regs[rs1] < (int32_t)regs[rs2]); break;  // BLT
                    case 0x5: take_branch = ((int32_t)regs[rs1] >= (int32_t)regs[rs2]); break; // BGE
                    case 0x6: take_branch = (regs[rs1] < regs[rs2]); break;                    // BLTU
                    case 0x7: take_branch = (regs[rs1] >= regs[rs2]); break;                   // BGEU
                }

                if (take_branch) {
                    pc += imm;
                } else {
                    pc += 4;
                }
            }
            return true;

        case 0x6F: // J-Type (JAL - Jump And Link)
            {
                // Reconstruct and sign-extend the 21-bit immediate
                int32_t imm = ((int32_t)(instruction & 0x80000000) >> 11) | // Sign extend and bit 20
                              (instruction & 0x000FF000) |                  // bits 19:12
                              ((instruction & 0x00100000) >> 9) |           // bit 11
                              ((instruction >> 20) & 0x7FE);                // bits 10:1

                if (rd != 0) {
                    regs[rd] = pc + 4; // Save return address
                }
                pc += imm; // Jump
            }
            return true;

        case 0x67: // I-Type (JALR - Jump And Link Register)
            {
                // 12-bit signed immediate
                int32_t imm = ((int32_t)instruction) >> 20; 
                
                // Target address is obtained by adding imm to rs1, then setting least-significant bit to 0
                uint32_t next_pc = (regs[rs1] + imm) & ~1; 

                if (rd != 0) {
                    regs[rd] = pc + 4; // Save return address
                }
                pc = next_pc; // Jump
            }
            return true;

        case 0x2F: // AMO (Atomic Memory Operations - A Extension)
            {
                // The specific AMO operation is defined by the top 5 bits of funct7
                uint32_t funct5 = (instruction >> 27) & 0x1F;
                uint32_t addr = regs[rs1];
                
                // For a basic single-core emulator, atomic operations can just execute 
                // sequentially without needing bus locks, as no other core is interrupting.
                
                if (funct5 == 0x02) { 
                    // LR.W (Load-Reserved Word)
                    if (rd != 0) {
                        regs[rd] = mem->read32(addr);
                    }
                    // Note: A true multi-core emulator would set a reservation flag for 'addr' here.
                } 
                else if (funct5 == 0x03) { 
                    // SC.W (Store-Conditional Word)
                    mem->write32(addr, regs[rs2]);
                    if (rd != 0) {
                        regs[rd] = 0; // 0 indicates success in a basic single-core setup
                    }
                    // Note: A true multi-core would check the reservation flag before writing.
                } 
                else {
                    // Standard Read-Modify-Write AMO operations
                    uint32_t t = mem->read32(addr); // Read original value
                    uint32_t result = 0;

                    switch(funct5) {
                        case 0x01: result = regs[rs2]; break; // AMOSWAP.W
                        case 0x00: result = t + regs[rs2]; break; // AMOADD.W
                        case 0x04: result = t ^ regs[rs2]; break; // AMOXOR.W
                        case 0x0C: result = t & regs[rs2]; break; // AMOAND.W
                        case 0x08: result = t | regs[rs2]; break; // AMOOR.W
                        case 0x10: // AMOMIN.W (Signed)
                            result = ((int32_t)t < (int32_t)regs[rs2]) ? t : regs[rs2];
                            break;
                        case 0x14: // AMOMAX.W (Signed)
                            result = ((int32_t)t > (int32_t)regs[rs2]) ? t : regs[rs2];
                            break;
                        case 0x18: // AMOMINU.W (Unsigned)
                            result = (t < regs[rs2]) ? t : regs[rs2];
                            break;
                        case 0x1C: // AMOMAXU.W (Unsigned)
                            result = (t > regs[rs2]) ? t : regs[rs2];
                            break;
                        default:
                            std::cout << "Unknown AMO funct5: 0x" << std::hex << funct5 << std::endl;
                            break;
                    }
                    
                    mem->write32(addr, result); // Write back modified value
                    
                    if (rd != 0) {
                        regs[rd] = t; // AMO always loads the ORIGINAL value into rd
                    }
                }
                pc += 4;
            }
            return true;


        case 0x0F: // FENCE
            // In a basic single-core emulator, memory ordering FENCE is essentially a NOP
            pc += 4;
            return true;

        case 0x73: // SYSTEM & Zicsr Extension
            {
                uint16_t csr_addr = instruction >> 20;
                uint32_t zimm = rs1; // For immediate variants, rs1 field acts as a 5-bit zero-extended immediate
                
                switch(funct3) {
                    case 0x0: 
                        // ECALL, EBREAK, MRET
                        if (instruction == 0x00000073) {
                            // ECALL: Trigger a trap with cause 11 (M-mode ecall)
                            trap(11);
                            return true; // Note: We do NOT increment PC; trap() sets the new PC.
                            
                        } else if (instruction == 0x00100073) {
                            // EBREAK: Trigger a trap with cause 3 (Breakpoint)
                            trap(3, pc);
                            return true;
                            
                        } else if (instruction == 0x30200073) {
                            // MRET: Return from OS trap handler
                            pc = read_csr(CSR_MEPC);
                            // Note: A full OS implementation would also restore mstatus interrupt bits here
                            return true; 
                        } else {
                            std::cout << "Unknown SYSTEM Privileged Instruction at PC: 0x" << std::hex << pc << std::endl;
                            return false;
                        }
                        break;
                        
                    case 0x1: // CSRRW (Read / Write)
                        {
                            uint32_t t = read_csr(csr_addr);
                            write_csr(csr_addr, regs[rs1]);
                            if (rd != 0) regs[rd] = t;
                        }
                        break;
                        
                    case 0x2: // CSRRS (Read / Set)
                        {
                            uint32_t t = read_csr(csr_addr);
                            // RISC-V spec: If rs1=x0, instruction shouldn't write to CSR (avoids side effects)
                            if (rs1 != 0) write_csr(csr_addr, t | regs[rs1]);
                            if (rd != 0) regs[rd] = t;
                        }
                        break;
                        
                    case 0x3: // CSRRC (Read / Clear)
                        {
                            uint32_t t = read_csr(csr_addr);
                            if (rs1 != 0) write_csr(csr_addr, t & ~regs[rs1]);
                            if (rd != 0) regs[rd] = t;
                        }
                        break;
                        
                    case 0x5: // CSRRWI (Read / Write Immediate)
                        {
                            uint32_t t = read_csr(csr_addr);
                            write_csr(csr_addr, zimm);
                            if (rd != 0) regs[rd] = t;
                        }
                        break;
                        
                    case 0x6: // CSRRSI (Read / Set Immediate)
                        {
                            uint32_t t = read_csr(csr_addr);
                            if (zimm != 0) write_csr(csr_addr, t | zimm);
                            if (rd != 0) regs[rd] = t;
                        }
                        break;
                        
                    case 0x7: // CSRRCI (Read / Clear Immediate)
                        {
                            uint32_t t = read_csr(csr_addr);
                            if (zimm != 0) write_csr(csr_addr, t & ~zimm);
                            if (rd != 0) regs[rd] = t;
                        }
                        break;
                        
                    default:
                        std::cout << "Unknown CSR funct3: 0x" << std::hex << funct3 << std::endl;
                        return false;
                }
                
                pc += 4; // Advance PC for CSR instructions
            }
            return true;
        
        default:
            std::cout << "Unknown opcode: 0x" << std::hex << opcode << " at PC: 0x" << pc << std::endl;
            return false; // Stop on error
    }
    return false; // Default fallback
}