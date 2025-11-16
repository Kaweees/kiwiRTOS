#!/bin/bash

# Creates a bootable disk image from a kernel image
# Usage:
#    image.sh kernel_name image_name

#
#  Private Impl
#

image() {
  local arch
  arch="$(uname -m)"
  local kernel_arch="$3"
  local kernel_file="$1"
  local image_file="$2"
  local offset=$((2048 * 512))
  local mount_point="/mnt/osfiles"
  local boot_files_dir=".img"

  # Create a folder whose structure mirrors that of the desired disk image
  mkdir -p "${boot_files_dir}"
  sudo mkdir -p "${boot_files_dir}/boot/grub"
  sudo cp -r ./src/arch/"${kernel_arch}"/grub.cfg "${boot_files_dir}/boot/grub/"
  sudo cp -r "${kernel_file}" "${boot_files_dir}/boot/kiwirtos.bin"
  # Create a zeroed out disk image file
  dd if=/dev/zero of="${image_file}" bs=512 count=32768
  # Add a Master Boot Record (MBR) to the image
  parted "${image_file}" mklabel msdos
  # Add a File Allocation Table 32 (FAT32) partition to the image
  parted "${image_file}" mkpart primary fat32 2048s 30720s
  # Set the partition boot flag
  parted "${image_file}" set 1 boot on
  # Identify the next two free loopback block devices
  N=$(losetup -f | grep -o '[0-9]*$')
  LOOP_DEVICE1="/dev/loop$N"
  LOOP_DEVICE2="/dev/loop$((N+1))"
  # Setup the loopback devices
  # The entire image
  sudo losetup "${LOOP_DEVICE1}" "${image_file}"
  # The partition (offset = 2048 sectors * 512 bytes = 1048576 bytes)
  sudo losetup "${LOOP_DEVICE2}" "${image_file}" -o "${offset}"
  # Format the partition as FAT32
  sudo mkdosfs -F32 -f 2 "${LOOP_DEVICE2}"
  # Create a mount point for the file system
  sudo mkdir -p "${mount_point}"
  # Mount the partition
  sudo mount "${LOOP_DEVICE2}" "${mount_point}"
  if [ "$arch" = "x86_64" ]; then
    # Install GRUB in the MBR
    sudo grub-install \
      --root-directory="${mount_point}" \
      --no-floppy \
      --modules="normal part_msdos ext2 multiboot" \
      --target=i386-pc \
      --directory="${GRUB_DIR}/i386-pc" \
      "${LOOP_DEVICE1}"
  else
    # Install GRUB in the MBR from another architecture
    sudo grub-install \
      --root-directory="${mount_point}" \
      --target=i386-pc \
      --no-floppy \
      --modules="normal part_msdos ext2 multiboot" \
      --directory="$GRUB_DIR/i386-pc" \
      "${LOOP_DEVICE1}"
  fi
  # Copy files to the image
  sudo cp -r "${boot_files_dir}"/* "${mount_point}"
  # Unmount the partition
  sudo umount -l "${mount_point}"
  # Remove the block devices
  sudo losetup -d "${LOOP_DEVICE1}"
  sudo losetup -d "${LOOP_DEVICE2}"

  # Clean up
  # Ensure loop devices are detached before removing directories
  sudo rm -rf "${mount_point}"
  sudo rm -rf "${boot_files_dir}"

  # Set the ownership of the image file to the current user
  # TODO: This is a hack to get around the fact that the image file is created by root
  # sudo chown $USER:$USER "${image_file}"
}

# Main script logic
set -euo pipefail # Exit on error, print the error message
if [ $# -eq 3 ]; then
  image "$1" "$2" "$3"
else
  echo "Usage: $0 kernel_file image_file kernel_arch"
  exit 1
fi
