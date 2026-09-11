# This machine's choices. Shared defaults come from the pinned ryra-template input.
{ ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  ryra.desktop.enable = false;
  # ryra.tailscale.enable = true; # After configuring the enrollment secret.
}
