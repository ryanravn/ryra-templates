# One access policy for the same machine, with or without Tailscale.
{ config, lib, ... }:
let
  cfg = config.ryra;
  privateSSH = !cfg.access.publicSSH;
  exposesSSH = firewall:
    builtins.elem 22 firewall.allowedTCPPorts
    || builtins.any (range: range.from <= 22 && range.to >= 22) firewall.allowedTCPPortRanges;
in
{
  options.ryra = {
    tailscale = {
      enable = lib.mkEnableOption "automatic Tailscale enrollment and private SSH";
      authKeySecret = lib.mkOption {
        type = lib.types.str;
        default = "tailscale-auth";
        description = "Name of the SOPS secret containing this machine's enrollment key.";
      };
    };
    access.publicSSH = lib.mkOption {
      type = lib.types.bool;
      default = !cfg.tailscale.enable;
      description = ''
        Allow SSH on public interfaces. Defaults off with Tailscale.
        Temporarily enable while enrolling an existing public machine, then
        deploy through its Tailscale address before removing this override.
      '';
    };
  };

  config = {
    services.openssh = {
      enable = true;
      # This module owns where SSH is reachable; the upstream default opens
      # its ports globally, including when interface-specific rules exist.
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = lib.optional cfg.access.publicSSH 22;
      interfaces = lib.mkIf cfg.tailscale.enable {
        "${config.services.tailscale.interfaceName}".allowedTCPPorts = [ 22 ];
      };
    };

    # Read from the staged closure by Ryra before activation. Private-only
    # deployment must already have a working connection over Tailscale.
    environment.etc."ryra/access-mode".text = if privateSSH then "tailscale\n" else "public\n";
    users.users.root.openssh.authorizedKeys.keys = lib.mkDefault [ ];

    assertions = [
      {
        assertion = config.services.openssh.enable && config.networking.firewall.enable;
        message = "Ryra machine access requires OpenSSH and the firewall to remain enabled.";
      }
      {
        assertion = !privateSSH || cfg.tailscale.enable;
        message = "Enable ryra.tailscale before disabling ryra.access.publicSSH.";
      }
      {
        assertion = !cfg.tailscale.enable || (
          config.services.tailscale.enable
          && builtins.elem 22 config.services.openssh.ports
          && exposesSSH config.networking.firewall.interfaces.${config.services.tailscale.interfaceName}
        );
        message = "Tailscale mode requires tailscaled and SSH on its private interface.";
      }
      {
        assertion = !cfg.access.publicSSH || exposesSSH config.networking.firewall;
        message = "Public SSH mode requires TCP port 22.";
      }
      {
        assertion = !privateSSH || (
          !config.services.openssh.openFirewall
          && !exposesSSH config.networking.firewall
          && builtins.all (name: name == "lo") config.networking.firewall.trustedInterfaces
          && builtins.all (name:
            name == config.services.tailscale.interfaceName
            || !exposesSSH config.networking.firewall.interfaces.${name}
          ) (builtins.attrNames config.networking.firewall.interfaces)
        );
        message = "Private SSH must not be exposed by global ports, port ranges, trusted interfaces, or non-Tailscale interface rules.";
      }
    ];
  };
}
