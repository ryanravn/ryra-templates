# What every machine in this organization runs, before anything specific to it.
#
# Shared rather than copied: five machines running the same thing are this file
# and five references, not five files that drift. A machine names it with
# `aspects = ["base"]`, which `ryra org machines buy --aspect` writes.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ git htop ripgrep ];

  # Anything reachable from outside belongs in the access aspect, which is the
  # one place allowed to decide it. A service that opened a port here would be
  # a service deciding who can reach the machine.
  networking.firewall.enable = true;
}
