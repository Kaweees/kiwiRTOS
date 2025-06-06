//! This file provides an interface to the Intel 8042 PS/2 controller.

const arch = @import("../arch/arch.zig");
const std = @import("std");

/// PS/2 controller data port
pub const PS2_DATA_PORT = arch.PS2_DATA_PORT;

/// PS/2 controller status port
pub const PS2_STATUS_PORT = arch.PS2_STATUS_PORT;

/// PS/2 controller command port
pub const PS2_COMMAND_PORT = arch.PS2_COMMAND_PORT;

/// PS/2 controller commands
pub const ControllerCommand = enum(u8) {
    /// Read configuration byte
    READ_CONFIG = 0x20,
    /// Write configuration byte
    WRITE_CONFIG = 0x60,
    /// Disable first PS/2 port
    DISABLE_PORT1 = 0xAD,
    /// Disable second PS/2 port
    DISABLE_PORT2 = 0xA7,
    /// Enable first PS/2 port
    ENABLE_PORT1 = 0xAE,
    /// Enable second PS/2 port
    ENABLE_PORT2 = 0xA8,
    /// Test controller
    TEST_CONTROLLER = 0xAA,
    /// Test first PS/2 port
    TEST_PORT1 = 0xAB,
    /// Test second PS/2 port
    TEST_PORT2 = 0xA9,
};

/// PS/2 controller configuration byte
pub const ConfigurationByte = packed struct {
    /// First PS/2 port interrupt (1 = enabled, 0 = disabled)
    port1Interrupt: u1,
    /// Second PS/2 port interrupt (1 = enabled, 0 = disabled)
    port2Interrupt: u1,
    /// System Flag (1 = system passed POST, 0 = your OS shouldn't be running)
    systemFlag: u1,
    /// Should be zero
    reserved1: u1,
    /// First PS/2 port clock (1 = disabled, 0 = enabled)
    port1Clock: u1,
    /// Second PS/2 port clock (1 = disabled, 0 = enabled, only if 2 PS/2 ports supported)
    port2Clock: u1,
    /// First PS/2 port translation (1 = enabled, 0 = disabled)
    port1Translation: u1,
    /// Must be zero
    reserved2: u1,
};

/// PS/2 controller status register
pub const StatusRegister = packed struct {
    /// Output buffer status (0 = empty, 1 = full)
    outputBuffer: u1,
    /// Input buffer status (0 = empty, 1 = full)
    inputBuffer: u1,
    /// System Flag (0 = cleared, 1 = set after self-test pass)
    systemFlag: u1,
    /// Command/data flag (0 = data for PS/2 device, 1 = for PS/2 command)
    commandData: u1,
    /// Unknown/chipset-specific, possibly keyboard lock
    unknown1: u1,
    /// Unknown/chipset-specific, possibly receive time-out or second port
    unknown2: u1,
    /// Time-out error (0 = no error, 1 = error)
    timeoutError: u1,
    /// Parity error (0 = no error, 1 = error)
    parityError: u1,
};

/// PS/2 Controller Status Bits
pub const StatusBits = enum(u8) {
    pub const OUTPUT: u8 = 0x01;
    pub const INPUT: u8 = 0x02;
};

/// PS/2 controller responses
pub const Response = enum(u8) {
    pub const ACK: u8 = 0xFA;
    pub const RESEND: u8 = 0xFE;
    pub const SELF_TEST_PASS: u8 = 0xAA;
    pub const PORT_TEST_PASS: u8 = 0x00;
};

/// PS/2 controller driver
pub const Ps2Driver = struct {
    /// PS/2 controller data port (port-mapped)
    data_port: u16,
    /// PS/2 controller status port (port-mapped)
    status_port: u16,
    /// PS/2 controller command port (port-mapped)
    command_port: u16,

    /// PS/2 controller configuration byte
    config: ConfigurationByte,
    /// PS/2 controller status register
    status: StatusRegister,

    /// Initialize a PS/2 controller driver
    pub fn init(data_port: u16, status_port: u16, command_port: u16) Ps2Driver {
        var driver: Ps2Driver = Ps2Driver{
            .data_port = data_port,
            .status_port = status_port,
            .command_port = command_port,
            .config = undefined,
            .status = undefined,
        };

        // Disable devices connected to both PS/2 ports
        driver.writeCommand(ControllerCommand.DISABLE_PORT1);
        driver.writeCommand(ControllerCommand.DISABLE_PORT2);

        // Read the PS/2 configuration byte
        driver.readConfig();

        // TODO: Ask the order in which I should enable the clock and interrupts on both PS/2 ports

        // Enable the clock and interrupts on both PS/2 ports
        driver.config.port1Clock = 0;
        // driver.config.port1Interrupt = 1;
        driver.config.port2Clock = 0;
        // driver.config.port2Interrupt = 1;
        driver.writeConfig(driver.config);

        // Enable devices connected to both PS/2 ports
        driver.writeCommand(ControllerCommand.ENABLE_PORT1);
        driver.writeCommand(ControllerCommand.ENABLE_PORT2);

        return driver;
    }

    /// Wait for controller input buffer to be empty (ready for write)
    pub fn waitForInput(self: *Ps2Driver) void {
        var status: StatusRegister = undefined;
        while (status.inputBuffer == 1) {
            status = self.readStatus();
        }
        self.status = status;
    }

    /// Wait for controller output buffer to be full (data available)
    pub fn waitForOutput(self: *Ps2Driver) void {
        var status: StatusRegister = undefined;
        while (status.outputBuffer == 0) {
            status = self.readStatus();
        }
        self.status = status;
    }

    /// Read the status register
    pub fn readStatus(self: *Ps2Driver) StatusRegister {
        return @as(StatusRegister, @bitCast(arch.inb(self.status_port)));
    }

    /// Read data from the data port
    pub fn readData(self: *Ps2Driver) u8 {
        // Wait for the output buffer to be full
        self.waitForOutput();
        // Read the data from the data port
        return arch.inb(self.data_port);
    }

    /// Write data to the data port
    pub fn writeData(self: *Ps2Driver, data: u8) void {
        // Wait for the input buffer to be empty
        self.waitForInput();
        // Write the data to the data port
        arch.outb(self.data_port, data);
    }

    /// Write a controller command
    pub fn writeCommand(self: *Ps2Driver, cmd: ControllerCommand) void {
        // Wait for input buffer to be empty
        self.waitForInput();
        arch.outb(self.command_port, @intFromEnum(cmd));
    }

    /// Read the configuration byte
    pub fn readConfig(self: *Ps2Driver) void {
        // Send command to read config
        // self.writeCommand(ControllerCommand.READ_CONFIG);
        self.writeCommand(ControllerCommand.READ_CONFIG);
        // Read the config data
        self.config = @bitCast(self.readData());
    }

    /// Write the configuration byte
    pub fn writeConfig(self: *Ps2Driver, config: ConfigurationByte) void {
        // Update internal config
        self.config = config;

        // Send command to write config
        self.writeCommand(ControllerCommand.WRITE_CONFIG);

        // Send the config data
        self.writeData(@bitCast(config));
    }
};
