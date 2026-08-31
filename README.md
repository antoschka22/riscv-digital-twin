``` mermaid
flowchart LR
    %% Styling
    classDef core fill:#2d3436,stroke:#74b9ff,stroke-width:2px,color:#fff
    classDef bus fill:#e17055,stroke:#d63031,stroke-width:2px,color:#fff
    classDef mem fill:#0984e3,stroke:#0097e6,stroke-width:2px,color:#fff
    classDef physical fill:#00b894,stroke:#00cec9,stroke-width:2px,color:#fff

    subgraph Core ["1. RISC-V CPU Core (C++ / Verilog)"]
        direction TB
        PC[Program Counter] --> ROM[Instruction ROM]
        ROM --> CU[Instruction Decoder]
        CU --> ALU[ALU]
        CU --> REGS[(Register File)]
        ALU <--> REGS
        CSR[CSR & Trap Logic] -.->|Forces PC Jump| PC
    end
    class PC,ROM,CU,ALU,REGS,CSR core

    Bus{MMIO Data Bus}
    class Bus bus

    ALU --> |Address Output| Bus
    REGS --> |Data Output| Bus
    Bus --> |Data Input| REGS

    subgraph Peripherals ["2. Memory Map & MMIO"]
        direction TB
        RAM[(Main RAM\n0x00000000)]
        CLINT[CLINT Timer\n0x02000000]
        KBD[Keyboard Reg\n0x03000000]
        VRAM[(Dual-Port VRAM\n0x04000000)]
        UART[UART TX\n0x10000000]
    end
    class RAM,CLINT,KBD,VRAM,UART mem

    Bus <--> RAM
    Bus <--> CLINT
    Bus --> KBD
    Bus --> VRAM
    Bus <--> UART

    CLINT -.-> |timer_interrupt| CSR

    subgraph External ["3. External Interfaces"]
        direction TB
        Keyboard((Host Keyboard / Buttons))
        DisplayController[VGA/HDMI Controller]
        Monitor((Physical Monitor))
        Terminal((Mac Serial Console))
    end
    class Keyboard,DisplayController,Monitor,Terminal physical

    Keyboard -.-> |Input Event| KBD
    VRAM --> |Port B Continuous Read| DisplayController
    DisplayController --> |TMDS / Sync Pulses| Monitor
    UART --> |TX Pin @ 115200 Baud| Terminal
```