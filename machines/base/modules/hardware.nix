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

  # The network, which a hand-written hardware aspect has to say out loud.
  #
  # NixOS enables DHCP through the `hardware-configuration.nix` that
  # `nixos-generate-config` writes, and a machine installed from a template
  # never runs that. Left out, the install SUCCEEDS: it partitions, copies the
  # closure, reboots, and comes up with no route to anything. The provider says
  # the server is running and ssh times out, which is the most expensive shape
  # of failure available here, because nothing is wrong that you can see.
  #
  # That happened. It is why this comment is longer than the setting.
  networking.useDHCP = lib.mkDefault true;
  # Hetzner routes a single address per machine and hands it out over DHCP on
  # the first interface, so predictable names are not needed and `useDHCP`
  # covers it. A machine with several interfaces would name them.

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
