{
  description = "Ryra desktop: a server with an on-demand virtual desktop";

  inputs = {
    ryra-services.url = "github:ryanravn/ryra-services";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Cua Driver 0.23.2. Its upstream Nix package is only built when computer
    # control is enabled; pin the source so deployments cannot silently upgrade it.
    cua = {
      url = "github:trycua/cua/e88e9d899ac5effaeae38619527ebaa46b26ce72";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    { self, nixpkgs, herdr-pkgs, disko, sops-nix, ryra-services, cua, ... }@inputs:
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
      checks.x86_64-linux.computer-control = import ./tests/computer-control.nix {
        desktop = self.nixosConfigurations.${hostName};
      };
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Every .nix under `modules/`, rather than a list naming them.
        #
        # Ryra GENERATES several of these: `logins.nix` and `ryra_ca.pub` when it installs, `secrets.nix` and
        # `logins.nix` on every deploy, and more as it learns to. A hardcoded list means the
        # product cannot start writing a file without this template being edited to import it,
        # and the two repositories drifting is not hypothetical: `modules/ryra/settings.nix` is
        # the file `ryra design` creates for per-service settings and never overwrites, it has
        # existed the whole time, and nothing here imported it. Somebody's settings were being
        # read by nobody.
        #
        # Order does not matter: NixOS merges modules rather than applying them in sequence, so a
        # directory listing is as correct as a hand-written list and cannot fall behind one.
        #
        # The cost, stated: a stray .nix under `modules/` is now part of the system. That is the
        # trade this pattern makes everywhere it is used, and it is the reason `secrets/` and the
        # CA's public half live outside `modules/` rather than in it.

        # The pinned herdr reaches `modules/herdr.nix` as `herdrPkgs`, so that module names the
        # version it needs rather than taking whatever nixpkgs has moved to.
        specialArgs = {
          inherit self hostName;
          serviceRegistries = registries;
          serviceModule = ryra-services.nixosModules.services;
          herdrPkgs = herdr-pkgs.legacyPackages."x86_64-linux";
          cuaDriver = cua.packages.x86_64-linux.cua-driver;
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
