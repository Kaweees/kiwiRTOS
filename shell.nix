{ pkgs ? import <nixpkgs> { } }:

let
  # Check if we're on Darwin (macOS)
  isDarwin = pkgs.stdenv.isDarwin;
in pkgs.mkShell {
  buildInputs = with pkgs; [
    neofetch # System information tool
    just # Just runner
    zig # Zig compiler
    xorriso # ISO image creator
    cdrtools # CD-ROM tools
    qemu # For testing the OS

    # Include tools conditionally based on platform
    (lib.optional (!isDarwin) grub2) # GRUB bootloader (Linux only)
  ];

  # Shell hook to set up environment
  shellHook = "";
}
