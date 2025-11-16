{
  pkgs ? import <nixpkgs> { },
}:

let
  # GRUB cross-compilation: target a 32-bit (i386-pc) environment.
  grubPkgs = import <nixpkgs> {
    crossSystem = {
      config = "i686-linux";
    };
    overlays = [
      (final: prev: {
        linux-pam = prev.linux-pam.overrideAttrs (oldAttrs: {
          outputs = builtins.filter (x: x != "man") (
            oldAttrs.outputs or [
              "out"
              "dev"
              "bin"
              "man"
              "doc"
              "scripts"
            ]
          );
        });
      })
    ];
  };

  # Native GRUB for the host system (only needed if not Darwin)
  nativeGrub = if pkgs.stdenv.isDarwin then null else pkgs.grub2;
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    zig_0_14 # Zig compiler 0.14.1
    nixfmt # Nix formatter
    just # Just runner
    xorriso # ISO image creator
    nasm # NASM assembler
    cdrtools # CD-ROM tools
    qemu # For testing the OS
    parted # Partitioning tool

    # Include GRUB packages
    nativeGrub # Native GRUB (needed for installation on Linux host)
    grubPkgs.grub2 # Cross-compiled GRUB for i386-pc (potentially needed for cross-builds)
  ];

  # Shell hook to set up environment
  shellHook = ''
    # Set GRUB_DIR to the cross-compiled GRUB installation containing i386-pc modules
    export GRUB_DIR="${grubPkgs.grub2}/lib/grub"
    # Optionally, display paths for clarity (can be removed if noisy)
    echo "Native GRUB available at: ${nativeGrub}/bin/grub-install"
    echo "Cross GRUB available at: ${grubPkgs.grub2}/bin/grub-install"
    echo "GRUB cross-compilation environment loaded from: $GRUB_DIR"
  '';
}
