# Like GNU `make`, but `just` rustier.
# https://just.systems/
# run `just` from this directory to see available commands

alias b := build
alias i := image
alias r := run
alias db := debug
alias c := clean
alias ch := check
alias f := format
alias d := docs
alias w := wasm

# Default command when 'just' is run without arguments
default:
  @just --list

# Build the project
build arch='x86_64':
  @echo "Building..."
  zig build -Dtarget_arch={{arch}}

# Build the project
image arch='x86_64':
  @echo "Building image..."
  zig build image -Dtarget_arch={{arch}}

# Run the project
run arch='x86_64':
  @echo "Running..."
  zig build run -Dtarget_arch={{arch}}

# Debug the project
debug arch='x86_64':
  @echo "Debugging..."
  zig build debug -Doptimize=Debug -Dtarget_arch={{arch}}

# Remove build artifacts and non-essential files
clean:
  @echo "Cleaning..."
  @rm -rf .zig-cache zig-out .img qemu.log

# Run code quality tools
check:
  @echo "Checking..."
  zig build check

# Format the project
format:
  @echo "Formatting..."
  @zig fmt .
  @find . -name "*.nix" -type f -exec nixfmt {} \;

# Generate documentation
docs arch='x86_64':
  @echo "Generating documentation..."
  zig build docs -Dtarget_arch={{arch}}

# Build the project for WASM
wasm arch='x86_64':
  @echo "Building WASM..."
