# Hardware description for slowpoke, standing in for the
# `nixos-generate-config` output until the install exists.
#
# nixos-generate-config writes filesystems by UUID, and UUIDs do not exist
# before the disk is partitioned - but CI evaluates every configuration in
# this flake (.github/scripts/eval-configurations.sh), and a NixOS config
# without a root filesystem fails that evaluation. Labels break the
# dependency: format the partitions with these labels at install time and
# this file is already correct.
#
#   mkfs.fat -F32 -n BOOT /dev/sdaN     # the new ESP
#   mkfs.ext4 -L nixos    /dev/sdaM     # root
#
# After the install, diff against the generated /etc/nixos/
# hardware-configuration.nix for the initrd module list; this file stays the
# source of truth.
#
# Dual boot: Catalina stays. Shrink the APFS container from Disk Utility
# first; the freed space takes a NEW 1 GB ESP for GRUB plus the ext4 root.
# Apple's own 200 MB ESP is left alone - too small to share once kernels are
# copied into it, and the firmware boots from any FAT partition that carries
# EFI/BOOT/BOOTX64.EFI.
_:

{
  # The platform lives here rather than as a `system` argument to
  # nixosSystem in flake.nix, so it is defined exactly once.
  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    # SATA SSD behind Apple's connector, USB 3 via xHCI - the set
    # nixos-generate-config produces for this generation of MacBook.
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "sd_mod" "usbhid" ];
    kernelModules = [ "kvm-intel" ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };

  # 16 GB soldered RAM (docker/CLAUDE.md). No swap partition to label:
  # compressed RAM is enough headroom and needs nothing on disk.
  zramSwap.enable = true;
}
