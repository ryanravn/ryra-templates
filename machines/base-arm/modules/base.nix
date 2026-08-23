# What every machine has, and deliberately little else.
#
# A template is a starting point: once the machine exists its configuration is
# its own directory in the organization's checkout, and anything opinionated
# here is something every machine has to undo rather than something it chose.
{ self, lib, pkgs, hostName, ... }:
{
  # Read by `ryra org` and by anything asking what a box is running. This is the
  # commit a generation was built from, which is what makes "roll back to that
  # point with that configuration" true rather than approximately true: without
  # it a machine knows what it IS and not what it was built FROM.
  # `nixos-version --configuration-revision` reads it back.
  # `self.rev` when the tree is a clean git checkout, `dirtyRev` when it is a checkout with
  # uncommitted changes, and "dirty" when it is not a git tree at all. All three are honest and
  # the third is the one a machine directory hits before anybody commits it. This used to be the
  # literal string "template", which is not a commit and told nobody anything: the comment above
  # described what it was for while the value did not do it.
  system.configurationRevision = self.rev or self.dirtyRev or "dirty";

  # Its own name, from the one file the flake attribute is also read from, so
  # `nixos-rebuild switch` with no arguments finds this configuration.
  networking.hostName = hostName;

  # Every unfree package this machine is allowed, named one by one.
  #
  # In `base.nix` because `nixpkgs.config.allowUnfreePredicate` is ONE function and two modules
  # defining it is a conflict, not a merge. So it cannot live beside each package that needs it,
  # and the list here is the price of that.
  #
  # By name rather than a blanket `allowUnfree`, so a third one stays a decision somebody makes
  # rather than something that slips in. Without a name on this list the machine does not build,
  # and the failure is at BUILD rather than at evaluation: `nix flake check` and reading
  # `systemPackages` both pass happily, which is how the first one reached a commit.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "ryra"
    ];

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # An editor, because a box you can only reach over ssh and cannot edit a file on is a box you
  # have to redeploy to fix a typo in. `vim` rather than a choice: it is what is on every other
  # machine these people already administer, and NixOS ships `nano` in the installer anyway.
  #
  # The rest are what a person or an agent reaches for in the first minute on a box and finds
  # missing: `ripgrep` provides `rg`, and `gh` needs its own login on the machine rather than
  # inheriting one.
  environment.systemPackages = with pkgs; [
    fzf
    gh
    git
    ripgrep
    rsync
    vim
  ];

  # Package updates only, never a configuration change, and never on the box's
  # own initiative. `docs/DESIGN-machines.md`: a self-triggered rebuild has
  # nobody outside to confirm it, so it cannot have the armed-undo net that
  # makes a deploy survivable. The hetzner box pulled and rebuilt on a timer and
  # failed silently for three consecutive nights.
  system.autoUpgrade.enable = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    # Keep enough generations that rolling back is still possible a fortnight
    # later. Garbage collection that removes what you would roll back TO is a
    # rollback story with an expiry date nobody was told about.
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "25.05";
}
