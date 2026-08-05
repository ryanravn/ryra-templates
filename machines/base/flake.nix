{
  description = "ryra/default: what a machine ryra creates starts life as";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    { nixpkgs, disko, sops-nix, ... }:
    {
      # One host, named for the machine ryra creates. `ryra org machines buy`
      # renames this to the machine's own name when it writes the checkout, so a
      # template is a starting point and never a shared identity.
      nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./modules/hardware.nix
          ./modules/access.nix
          ./modules/keys.nix
          ./modules/secrets.nix
          ./modules/base.nix
        ];
      };
    };
}
