{ serviceRegistries, serviceModule, ... }:
let
  enabled = builtins.fromJSON (builtins.readFile ./ryra/services.json);
  settings = import ./ryra/settings.nix;
in {
  imports = [
    (serviceModule {
      registries = serviceRegistries;
      services = builtins.listToAttrs (map (name: {
        inherit name;
        value = settings.${name} or {};
      }) enabled);
      # Web services declare infrastructure requirements in their catalog metadata.
      # Configure the domain, certificates and other service providers here when needed.
    })
  ];
}
