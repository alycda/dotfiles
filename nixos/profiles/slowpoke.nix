# slowpoke: the mid-2012 15" Retina MacBook Pro (MacBookPro10,1) that
# docker/CLAUDE.md describes from inside a container. Same hardware, booted
# natively into NixOS alongside the Catalina install - the 8 GB Docker VM,
# grpcfuse, the 1 GB swap and the Catalina software ceilings all go away;
# the "no AVX2" CPU baseline does not.
#
# Machine name: placeholder in the spirit of ditto and shesfast. Renaming is
# the attribute in flake.nix, these two files, and `networking.hostName`.
{ lib, pkgs, ... }:

let
  # The 15" 2012 has two GPUs behind Apple's gmux chip: Intel HD 4000 and an
  # NVIDIA GT 650M (Kepler). EFI hands Linux the *discrete* GPU with the
  # integrated one not initialised, so nouveau drives the panel - hotter,
  # shorter battery, and on some kernels a black screen at boot. Writing the
  # gmux ports from GRUB before the kernel loads switches the panel to the
  # Intel GPU and powers the NVIDIA one down (ArchWiki, "MacBookPro10,x").
  #
  # Trade-off: the external display ports are wired to the discrete GPU, so
  # with this on they are dead. Set false to get them back (and nouveau).
  # Which side of that trade the hardware actually forces is what the
  # live-USB test decides; it cannot be evaluated from a checkout.
  forceIntegratedGpu = true;
in
{
  imports = [ ./slowpoke-hardware.nix ];

  networking = {
    hostName = "slowpoke";
    networkmanager.enable = true;
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;

    # BCM4331 WiFi: the in-tree b43 driver plus the proprietary firmware it
    # needs (unfree; cut out of Broadcom's driver by b43-fwcutter at build
    # time). Pinned to the 6.30.163.46 blob explicitly rather than through
    # `networking.enableB43Firmware`, because the BCM4331's HT-PHY is only in
    # that newer firmware and the option's choice of version is not something
    # to depend on from a checkout that cannot evaluate it. No live ISO ships
    # this, which is why the first boot happens over Ethernet or USB
    # tethering. The alternative, broadcom_sta (`wl`), is an out-of-tree
    # module that breaks on kernel bumps - b43 does not.
    firmware = [ pkgs.b43Firmware_6_30_163_46 ];
    # Not enabled: the FaceTime HD camera (`hardware.facetimehd.enable`) is an
    # out-of-tree driver whose firmware is extracted from Apple's own at build
    # time. Off until there is a reason - one fewer unverifiable piece on the
    # first boot.
  };

  boot.loader = {
    # Apple firmware ignores the NVRAM boot entries efibootmgr writes, so the
    # usual systemd-boot + canTouchEfiVariables recipe leaves nothing the
    # Option-key picker can find. Install GRUB at the fallback path every
    # firmware is hardcoded to try (EFI/BOOT/BOOTX64.EFI) instead; NixOS
    # requires canTouchEfiVariables off for that. GRUB rather than
    # systemd-boot because only GRUB can run the `outb` writes below.
    efi.canTouchEfiVariables = false;
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
      # No useOSProber: macOS boots from its APFS preboot volume, which
      # os-prober cannot chainload. Hold Option at power-on to pick macOS.
      #
      # extraConfig lands in grub.cfg before the menu entries, so the gmux
      # writes run once at GRUB start and apply to whichever entry boots.
      # `iorw` is the module that provides `outb`; GRUB autoloads it, the
      # insmod just makes that explicit.
      extraConfig = lib.optionalString forceIntegratedGpu ''
        insmod iorw
        outb 0x728 1
        outb 0x710 2
        outb 0x740 2
        outb 0x750 0
      '';
    };
  };

  services = {
    # COSMIC: System76's Rust desktop, the thing Pop!_OS 24.04 ships, straight
    # from nixpkgs. Wayland-only, which on this GPU is the second thing the
    # live USB has to prove. If it black-screens on nouveau, the fallback with
    # an X11 session still in it is plasma6 + sddm.
    desktopManager.cosmic.enable = true;
    displayManager.cosmic-greeter.enable = true;
  };

  # Retina panel, 2880x1800 at 15": the default console font is unreadable.
  # COSMIC's own HiDPI scaling is set in its Settings app, not here.
  console = {
    packages = [ pkgs.terminus_font ];
    font = "ter-132n";
  };

  users.users.alyssa = {
    isNormalUser = true;
    description = "Alyssa";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };
}
