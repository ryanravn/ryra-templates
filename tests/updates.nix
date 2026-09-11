let
  flake = builtins.getFlake ("path:" + toString ../.);
  base = (flake.lib.mkMachine { self = ../machines/base; }).nixosConfigurations.machine;
  c = (base.extendModules { modules = [{ services.ryra-update = {
    enable = true;
    org = "example";
    user = "root";
    checkout = "/var/lib/ryra/organization";
  }; }]; }).config;
in {
  survivesActivation = !c.systemd.services.ryra-update.restartIfChanged && !c.systemd.services.ryra-update.stopIfChanged;
  persistent = c.systemd.timers.ryra-update.timerConfig.Persistent;
  home = c.systemd.services.ryra-update.environment.HOME;
  unit = c.systemd.units."ryra-update.service".text;
  failures = map (a: a.message) (builtins.filter (a: !a.assertion) c.assertions);
}
