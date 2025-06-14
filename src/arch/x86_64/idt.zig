//! This file provides the Interrupt Descriptor Table (IDT) implementation.

const std = @import("std");
const arch = @import("arch.zig");

extern const isr_stub_table: []void;

// Number of entries in the IDT
pub const IDT_ENTRIES = 256;

// GDT segment selector for kernel code
pub const GDT_KERNEL_CODE_SEGMENT = 0x08;

// IDT Entry structure (64-bit) Call-Gate Descriptor
pub const IdtEntry = packed struct {
    /// The lower bits of the ISR's address
    isr_low: u16,
    /// The GDT segment selector that the CPU will load into CS before calling the ISR
    kernel_cs: u16,
    /// The IST in the TSS that the CPU will load into RSP; set to zero for now
    ist: Ist,
    /// Attributes
    attributes: IdtAttributes,
    /// Middle 16 bits of handler function address
    offset_mid: u16,
    /// Upper 32 bits of handler function address
    offset_high: u32,
    /// Reserved, should be 0
    reserved: u32 = 0,
};

// Interrupt Stack Table (IST)
pub const Ist = packed struct {
    /// The interrupt stack table offset
    offset: u3,
    /// Reserved, should be 0
    reserved: u35 = 0,
};

// Descriptor Privilege Level (DPL)
pub const DPL = enum(u2) {
    /// DPL for kernel code and data
    KERNEL = 0b00,
    /// DPL for user code and data
    USER = 0b11,
};

// The type of gate the IDT entry represents
pub const GateType = enum(u4) {
    /// Task gate (system call)
    GATE_TASK = 0b0101,
    /// Interrupt gate (system call)
    GATE_INTERRUPT = 0b1110,
    /// Trap gate (exception)
    GATE_TRAP = 0b1111,
};

pub const IdtAttributes = packed struct {
    /// Present bit
    present: u1,
    /// Descriptor Privilege Level (DPL)
    dpl: DPL,
    /// Reserved, should be 0
    reserved: u1 = 0,
    /// Gate type (e.g., interrupt gate, trap gate)
    gate_type: GateType,
};

// IDT Register (IDTR)
pub const IdtRegister = packed struct {
    /// Size of IDT - 1
    limit: u16,
    /// Base address of IDT
    base: u64,
};

/// Interrupt Descriptor Table (IDT)
pub const Idt = struct {
    /// IDT entries; aligned to 16 bytes
    entries: [IDT_ENTRIES]IdtEntry align(0x10),
    /// Vectors that are used by the IDT
    vectors: [IDT_ENTRIES]bool,
    /// IDT register (IDTR)
    idtr: IdtRegister,

    /// Initialize the IDT
    pub fn init() Idt {
        var idt: Idt = Idt{
            .entries = undefined,
            .vectors = undefined,
            .idtr = undefined,
        };

        // Set the IDT entries
        idt.setEntries();

        // Load the IDT
        idt.loadIdt();

        return idt;
    }

    /// Set the IDT entries
    pub fn setEntries(self: *Idt) void {
        for (0..IDT_ENTRIES) |vector| {
            const addr = @intFromPtr(isr_stub_table[vector]);
            self.setDescriptor(vector, addr, IdtAttributes{
                .present = 1,
                .dpl = DPL.KERNEL,
                .gate_type = GateType.GATE_INTERRUPT,
            });
            self.vectors[vector] = true;
        }
    }

    /// Load the IDT
    pub inline fn loadIdt(self: *Idt) void {
        // Create IDT register
        self.idtr = IdtRegister{
            .limit = @sizeOf(@TypeOf(self.entries)) - 1,
            .base = @intFromPtr(&self.entries),
        };

        // Load IDT with LIDT instruction
        asm volatile ("lidt (%[idt_reg])"
            :
            : [idt_reg] "r" (&self.idtr),
        );
        // Enable interrupts
        arch.sti();
    }

    // Set an IDT descriptor entry
    pub fn setDescriptor(self: *Idt, vector: u8, isr: u64, flags: IdtAttributes) void {
        self.entries[vector].isr_low = @truncate(isr & 0xFFFF);
        self.entries[vector].kernel_cs = GDT_KERNEL_CODE_SEGMENT;
        self.entries[vector].ist = 0;
        self.entries[vector].attributes = @bitCast(flags);
        self.entries[vector].offset_mid = @truncate((isr >> 16) & 0xFFFF);
        self.entries[vector].offset_high = @truncate((isr >> 32) & 0xFFFFFFFF);
    }
};
