# The disk and the bootloader, for a Hetzner Cloud VM.
#
# GRUB in UEFI mode with `efiInstallAsRemovable`, because Hetzner's firmware does
# not persist a boot entry: installing as removable puts the loader where the
# firmware looks by default, and a machine that installs cleanly and then does
# not come back is the worst outcome available at this layer.
#
# Taken from a configuration that is running rather than invented: see
# `hetzner-nixos-uefi`, which has booted this shape in fsn1 for months.
{ lib, ... }:
{
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  # `qemu-guest` for the virtio drivers the disk and network are behind. Without
  # it the installer builds a system that cannot see its own root.
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "ahci" "sd_mod" ];
  services.qemuGuest.enable = true;

  disko.devices.disk.main = {
    device = lib.mkDefault "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
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
