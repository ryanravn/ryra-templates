{
  description = "ryra/base-arm: ryra/base, for the arm64 boxes a provider sells cheaper";

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
      # What this template can be built for, as nix spells it.
      #
      # Read by `ryra org machines buy` before it picks a box. A machine declares what it must BE
      # (so many vCPU, so much memory) and the cheapest thing in a catalogue that clears that says
      # nothing about instruction set: a Hetzner CAX21 clears "4 vCPU, 8 GB" perfectly and cannot
      # run this. One was bought that way, and nothing would have said so until the install failed
      # on a machine already billing.
      #
      # A pure value on purpose. Ryra reads it with `nix eval --json`, which costs no nixpkgs and
      # no evaluation of the system below, so a picker can consult it without instantiating
      # anything. A template that omits it is treated as x86_64-linux, which is what every one
      # written before this was.
      meta.systems = [ "aarch64-linux" ];

      # One host, named for the machine ryra creates. `ryra org machines buy`
      # renames this to the machine's own name when it writes the checkout, so a
      # template is a starting point and never a shared identity.
      nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./modules/hardware.nix
          ./modules/access.nix
          ./modules/keys.nix
          ./modules/secrets.nix
          ./modules/logins.nix
          ./modules/memory.nix
          ./modules/herdr.nix
          ./modules/base.nix
        ];
      };
    };
}
