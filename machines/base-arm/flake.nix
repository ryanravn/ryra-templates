{
  description = "ryra/base-arm: ryra/base, for the arm64 boxes a provider sells cheaper";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # herdr, pinned, and ONLY herdr.
    #
    # Ryra announces a client protocol version and herdr refuses both directions: a client older
    # than the server and a client newer than it. So the two have to agree, and the number moves
    # with herdr's minor releases. 0.8.0 speaks 19, which is what `stream.rs` announces; 0.8.2
    # speaks 20 and refuses us.
    #
    # These templates carry no `flake.lock` on purpose, because what a template pins decides what
    # every machine built from it gets. That is right for nixpkgs as a whole and wrong for this
    # one package: without it, two machines installed a week apart get two herdrs, and the newer
    # one cannot be attached to. A pane that will not open is the product not working.
    #
    # Revert this the moment ryra speaks 20. It is a pin against a protocol we have not caught up
    # with, not a preference, and `just attach-check` is what says we have.
    herdr-pkgs.url = "github:NixOS/nixpkgs/2c423e03bbafcff28bfadc6781a4a8257f205cb5";
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
    { self, nixpkgs, herdr-pkgs, disko, sops-nix, ... }:
    let
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
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
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
          herdrPkgs = herdr-pkgs.legacyPackages."aarch64-linux";
        };
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
        ]
        ++ (builtins.filter (path: nixpkgs.lib.hasSuffix ".nix" (toString path))
          (nixpkgs.lib.filesystem.listFilesRecursive ./modules));
      };
    };
}
