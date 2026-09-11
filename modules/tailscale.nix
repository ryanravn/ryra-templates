# Enrollment uses the per-machine key delivered by Ryra's SOPS/age flow.
{ config, lib, ... }:
let
  cfg = config.ryra.tailscale;
  secret = config.sops.secrets.${cfg.authKeySecret} or null;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = secret != null;
        message = "Tailscale needs the SOPS secret '${cfg.authKeySecret}'. Declare its Tailscale mint and deploy the secrets first.";
      }
      {
        assertion = secret == null || ((secret.owner == "root" || (secret.owner == null && secret.uid == 0)) && secret.mode == "0400" && !secret.neededForUsers);
        message = "The Tailscale enrollment secret must be owned by root with mode 0400.";
      }
    ];

    services.tailscale = {
      enable = true;
      authKeyFile = if secret == null then null else secret.path;
      # Enables direct encrypted transport; this is not an application port.
      openFirewall = true;
      # Ryra uses OpenSSH certificates. Do not replace OpenSSH with Tailscale SSH.
      # Tailscale's default netfilter rules accept all traffic on tailscale0.
      # NixOS owns the interface-specific port policy instead.
      extraUpFlags = [ "--ssh=false" "--netfilter-mode=off" ];
      extraSetFlags = [ "--ssh=false" "--netfilter-mode=off" ];
    };
    systemd.services.tailscaled-autoconnect = {
      # Older configurations decrypt in activation scripts, before units start.
      # Do not require a nonexistent systemd unit in that mode.
      requires = lib.optional config.sops.useSystemdActivation "sops-install-secrets.service";
      after = lib.optional config.sops.useSystemdActivation "sops-install-secrets.service";
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStartSec = "60s";
      };
    };

    # This daemon is part of the way in, so protect it like SSH under load.
    systemd.services.tailscaled.serviceConfig = {
      CPUWeight = 1000;
      IOWeight = 1000;
      MemoryLow = "64M";
    };
    systemd.slices.system.sliceConfig.MemoryLow = "128M";
  };
}
