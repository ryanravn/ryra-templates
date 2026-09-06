# The way in, and the only aspect allowed to decide it.
#
# `docs/DESIGN-machines.md` argues that one aspect holds ssh, the accounts and
# the firewall rules that keep them reachable, and that a service module must
# not be able to unset any of it. That rule exists because it was broken
# somewhere real: on `hetzner-fsn1`, whether ssh is reachable is decided inside
# the Nextcloud module, and two `mkForce` list definitions MERGE rather than
# clash, so an access aspect trying to close a port would silently union with a
# service's and the port would stay open with nothing reporting a conflict.
#
# So the assertion below is the rule with teeth. A service that opens a port
# through a contract is fine; a service that decides whether you can log in is
# not, and this fails the build rather than the machine.
{ config, lib, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # ryra writes the keys and the certificate authority here when it creates the
  # machine. Empty in the template, because a template that carried a key would
  # be a template that let its author into every machine started from it.
  users.users.root.openssh.authorizedKeys.keys = lib.mkDefault [ ];

  assertions = [
    {
      assertion = builtins.elem 22 config.networking.firewall.allowedTCPPorts;
      message = ''
        Something has taken port 22 out of the firewall. Whether this machine is
        reachable is this aspect's decision and no service's: ask for a port
        through a contract instead. Losing ssh is not recoverable from here.
      '';
    }
    {
      assertion = config.services.openssh.enable;
      message = "openssh is off, so nothing could reach this machine after it boots.";
    }
  ];
}
