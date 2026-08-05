# The disk and the bootloader, for a Hetzner Cloud VM.
#
# # Both boot paths, because guessing wrong is invisible
#
# This machine may be BIOS or UEFI and nothing in the configuration can ask.
# Hetzner Cloud x86 instances have historically booted SeaBIOS; arm64 and newer
# types are UEFI. An earlier version of this file installed a UEFI-only GRUB,
# copied from `hetzner-nixos-uefi` whose name says what it assumed.
#
# The failure that produces is the worst available here: `nixos-anywhere`
# reports `### Done! ###`, the disk is written correctly, the provider says the
# server is running, and the machine never boots. There is nothing to see and no
# error anywhere. Two machines went that way before this comment existed.
#
# So the disk carries a BIOS boot partition AND an ESP, and GRUB is installed to
# both. It costs 1 MB and a few seconds, and it removes a question that can only
# be answered by buying a machine and watching it not come back.
{ lib, ... }:
{
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    # The firmware does not persist a boot entry, so the loader goes where a
    # machine with no entry looks by default.
    efiInstallAsRemovable = true;
    # And the MBR, for the firmware that never looks at an ESP at all.
    devices = [ "/dev/sda" ];
  };

  # virtio, or the installed system cannot see its own disk or network.
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_scsi"
    "virtio_net"
    "ahci"
    "sd_mod"
  ];
  services.qemuGuest.enable = true;

  # The network, which a hand-written hardware aspect has to say out loud.
  #
  # NixOS enables DHCP through the `hardware-configuration.nix` that
  # `nixos-generate-config` writes, and a machine installed from a template
  # never runs that. Left out, the install succeeds and the machine comes up
  # with no route to anything.
  networking.useDHCP = lib.mkDefault true;

  disko.devices.disk.main = {
    device = lib.mkDefault "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        # 1 MB, no filesystem, type ef02. GRUB puts its core image here when the
        # firmware is BIOS and the table is GPT: without it, a BIOS machine has
        # nowhere to boot from on a GPT disk and fails silently at install time.
        boot = {
          size = "1M";
          type = "EF02";
          priority = 1;
        };
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
