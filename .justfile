# Like GNU `make`, but `just` rustier.
# https://just.systems/
# run `just` from this directory to see available commands

alias r := run
alias b := build
alias i := image
alias c := clean
alias db := debug
alias ch := check
alias f := format
alias d := docs
alias w := wasm

# Default command when 'just' is run without arguments
default:
  @just --list

# Run the project with specified architecture
run arch='x86_64':
  zig build run -Dtarget_arch={{arch}}

# Build the project
build arch='x86_64':
  zig build -Dtarget_arch={{arch}}

# Build the project
image arch='x86_64':
  zig build image -Dtarget_arch={{arch}}

# Debug the project
debug arch='x86_64':
  zig build debug -Doptimize=Debug -Dtarget_arch={{arch}}

# Clean the project
clean:
  @# Remove cached files
  @rm -rf .zig-cache zig-out .img qemu.log

# Run code quality tools
check:
  zig build check

# Format the project
format:
  zig fmt .
  @find . -name "*.nix" -type f -exec nixfmt {} \;

# Generate documentation
docs arch='x86_64':
  zig build docs -Dtarget_arch={{arch}}

# Build the project for WASM
wasm arch='x86_64':
  cd vendors/qemu-wasm && docker buildx create --use --name qemu-builder || true && docker buildx build --platform linux/$(uname -m) -t buildqemu - < Dockerfile
