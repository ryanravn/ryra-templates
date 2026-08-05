{
  description = "ryra/default: what a machine ryra creates starts life as";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, disko, ... }:
    {
      # One host, named for the machine ryra creates. `ryra org machines buy`
      # renames this to the machine's own name when it writes the checkout, so a
      # template is a starting point and never a shared identity.
      nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./modules/hardware.nix
          ./modules/access.nix
          ./modules/keys.nix
          ./modules/base.nix
        ];
      };
    };
}
