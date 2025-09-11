{
  pkgs ? import <nixpkgs> { },
}:

let
  # Check if we're on Darwin (macOS)
  isDarwin = pkgs.stdenv.isDarwin;

  # GRUB cross-compilation: target a 32-bit (i386-pc) environment.
  grubPkgs = import <nixpkgs> {
    crossSystem = {
      config = "i686-linux";
    };
  };

  # Native GRUB for the host system (only needed if not Darwin)
  nativeGrub = if isDarwin then null else pkgs.grub2;
in
pkgs.mkShell {
  buildInputs = [
    pkgs.neofetch # System information tool
    pkgs.just # Just runner
    pkgs.zig # Zig compiler
    pkgs.xorriso # ISO image creator
    pkgs.nasm # NASM assembler
    pkgs.cdrtools # CD-ROM tools
    pkgs.qemu # For testing the OS
    pkgs.nixfmt # Nix formatter
    pkgs.parted # Partitioning tool
    pkgs.docker # Docker
    pkgs.rootlesskit # RootlessKit
    pkgs.container2wasm # Container to WASM converter

    # Include GRUB packages
    nativeGrub # Native GRUB (needed for installation on Linux host)
    grubPkgs.grub2 # Cross-compiled GRUB for i386-pc (potentially needed for cross-builds)
  ];

  # Shell hook to set up environment
  shellHook = ''
    # Set GRUB_DIR to the cross-compiled GRUB installation containing i386-pc modules
    export GRUB_DIR="${grubPkgs.grub2}/lib/grub"
    # Optionally, display paths for clarity (can be removed if noisy)
    # echo "Native GRUB available at: ${nativeGrub}/bin/grub-install"
    # echo "Cross GRUB available at: ${grubPkgs.grub2}/bin/grub-install"
    # echo "GRUB cross-compilation environment loaded from: $GRUB_DIR"
    # export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
    # fire up a rootless Docker daemon if it isn't running yet
    if ! pgrep -u "$UID" dockerd-rootless > /dev/null; then
      echo "🛠  starting rootless dockerd..."
      dockerd-rootless > /tmp/dockerd-rootless.log 2>&1 &
    fi
    export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
    sleep 2            # tiny pause so the socket appears
  '';
}
