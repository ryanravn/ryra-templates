{
  description = "ryra/base-arm: ryra/base, for the arm64 boxes a provider sells cheaper";

  inputs = {
    ryra-services.url = "github:ryanravn/ryra-services";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Match Ryra 0.1.18's bundled Herdr 0.8.2 and protocol 20. Keep this pin
    # independent of the template's general nixpkgs input.
    herdr-pkgs.url = "github:NixOS/nixpkgs/c043004d1c6985732bcc1cbc5a9c9aecbbb4e0f0";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Mounts what `ryra org machines deploy` writes. The machine opens those
    # files with its own ssh host key, so nothing has to carry a key to it.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, herdr-pkgs, disko, sops-nix, ryra-services, ... }@inputs:
    let
      registries = import ./registries.nix inputs;
      # The machine's own name, and the reason it is a FILE rather than a string here.
      #
      # It has to be two things at once: the attribute under `nixosConfigurations`, and
      # `networking.hostName`. `nixos-rebuild switch` with no arguments looks the configuration up
      # by the running hostname, so if those two ever disagree the most ordinary command on NixOS
      # stops working on this machine and says nothing useful about why.
      #
      # One file read in one place makes disagreeing impossible, and leaves ryra writing a name
      # rather than editing nix. `machine` is what a bare template says, so a template still
      # evaluates on its own; `ryra org machines add` overwrites it with the machine's name.
      hostName = nixpkgs.lib.fileContents ./hostname;
    in
    {
      ryraCatalog = builtins.mapAttrs (_: source: {
        flake = "path:${source.outPath}";
        index = source.index;
      }) registries;
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        # Generated modules are discovered automatically. settings.nix is a service
        # attrset, consumed by modules/services.nix rather than imported as a NixOS module.

        # The pinned herdr reaches `modules/herdr.nix` as `herdrPkgs`, so that module names the
        # version it needs rather than taking whatever nixpkgs has moved to.
        specialArgs = {
          inherit self hostName;
          serviceRegistries = registries;
          serviceModule = ryra-services.nixosModules.services;
          herdrPkgs = herdr-pkgs.legacyPackages."aarch64-linux";
        };
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
        ]
        ++ (builtins.filter (path: path != ./modules/ryra/settings.nix && nixpkgs.lib.hasSuffix ".nix" (toString path))
          (nixpkgs.lib.filesystem.listFilesRecursive ./modules));
      };
    };
}
