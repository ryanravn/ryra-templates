# Azure Gen 2 / x86-64 / SCSI OS disk. The installer verifies these assumptions.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/virtualisation/azure-common.nix") ];

  # Ryra retains the template's hostname and certificate-managed accounts. Azure's
  # agent remains available for fabric health and extensions; cloud-init must not
  # recreate the old image's users, SSH keys or host keys on this existing VM.
  services.cloud-init.enable = lib.mkForce false;
  services.cloud-init.network.enable = lib.mkForce false;
  services.waagent.settings = {
    Provisioning.Enable = false;
    Provisioning.Enabled = false;
    Provisioning.Agent = "disabled";
    ResourceDisk.Format = false;
    ResourceDisk.EnableSwap = false;
  };
  networking.useDHCP = lib.mkForce false;
  systemd.network.enable = true;
  systemd.network.networks."10-azure" = {
    matchConfig.Driver = "hv_netvsc";
    networkConfig.DHCP = "yes";
    dhcpV4Config.RouteMetric = 100;
  };
  virtualisation.azure.acceleratedNetworking = true;
  services.qemuGuest.enable = lib.mkForce false;

  # Gen 2 boots via the removable EFI path. Never install an MBR on a guessed disk.
  boot.loader.grub.devices = lib.mkForce [ "nodev" ];
  disko.devices.disk.main.device = lib.mkForce "/dev/sda";
}
