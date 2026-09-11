{ lib, machineDir, serviceRegistries, serviceModule, ... }:
let
  enabled = builtins.fromJSON (builtins.readFile (machineDir + "/modules/ryra/services.json"));
  settings = import (machineDir + "/modules/ryra/settings.nix");
in {
  imports = lib.optional (enabled != [])
    (serviceModule {
      registries = serviceRegistries;
      services = builtins.listToAttrs (map (name: {
        inherit name;
        value = settings.${name} or {};
      }) enabled);
      # Web services declare infrastructure requirements in their catalog metadata.
      # Configure the domain, certificates and other service providers here when needed.
    });
}
