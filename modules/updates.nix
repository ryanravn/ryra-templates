# Security updates, on the machine, without a laptop being open.
#
# It runs `ryra org machines update`, which is the same command you would type.
# Not a second updater: the schedule is the only thing that lives here, and
# moving it between a laptop and a box changes nothing about what happens.
#
# The checkout is why this needs saying out loud. `update` moves nixpkgs in the
# ORGANIZATION'S FOLDER and applies it with an ordinary switch, so the box needs
# that folder, not just its own /etc/nixos. Bumping /etc/nixos instead was tried
# and is wrong: the next switch rebuilds from the tree and quietly puts the older
# nixpkgs back.
#
# It also needs to be signed in, as itself. A machine that joined the
# organization already holds a service credential, and what it can update is
# whatever its vaults let it open. Being invited into a vault is a decision
# somebody makes; a machine whose vault it cannot open is not updated.
{ config, lib, pkgs, ryraPackage, ... }:
let
  cfg = config.services.ryra-update;
in
{
  options.services.ryra-update = {
    enable = lib.mkEnableOption "nightly security updates";

    org = lib.mkOption {
      type = lib.types.str;
      description = "Organization id or slug.";
    };

    machines = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ config.networking.hostName ];
      description = ''
        Which machines to update. This one by default. A box that updates the
        others is the only way any of them gets an outside confirmation: a
        machine switching itself has nobody to check it came back.
      '';
    };

    checkout = lib.mkOption {
      type = lib.types.path;
      description = "The organization's folder on this machine.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = "Whose ryra session to run as. Its vaults are the reach.";
    };

    dates = lib.mkOption {
      type = lib.types.str;
      default = "04:00";
      description = "systemd OnCalendar expression.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.checkout != null && cfg.org != "" && cfg.machines != [] && builtins.hasAttr cfg.user config.users.users;
      message = "services.ryra-update needs an org, a checkout, at least one machine and an existing local user.";
    }];

    systemd.services.ryra-update = {
      description = "Ryra security updates";
      # Keep the updater alive across the activation it is supervising, including
      # changes to its own pinned binary. Its next run uses the new unit.
      restartIfChanged = false;
      stopIfChanged = false;
      environment.HOME = config.users.users.${cfg.user}.home or "/var/empty";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        WorkingDirectory = cfg.checkout;
        TimeoutStartSec = "2h";
      };
      path = [ pkgs.nix pkgs.nixos-rebuild pkgs.git pkgs.openssh ];
      # By store path. `environment.systemPackages` is a person's PATH, not a
      # unit's, so naming the binary would resolve to nothing here.
      script = ''
        exec ${ryraPackage}/bin/ryra org machines update ${lib.escapeShellArg cfg.org} \
          ${lib.escapeShellArgs cfg.machines}
      '';
    };

    systemd.timers.ryra-update = {
      wantedBy = [ "timers.target" ];
      # Persistent, so a box that was off at four runs when it comes back. The
      # machine that is off most is otherwise the one nobody ever patches.
      timerConfig = {
        OnCalendar = cfg.dates;
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
  };
}
