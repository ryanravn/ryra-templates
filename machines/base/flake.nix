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
      meta.systems = [ "x86_64-linux" ];

      # One host, named for the machine ryra creates. `ryra org machines buy`
      # renames this to the machine's own name when it writes the checkout, so a
      # template is a starting point and never a shared identity.
      nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Every .nix under `modules/`, rather than a list naming them.
        #
        # Ryra GENERATES several of these: `keys.nix` when it installs, `secrets.nix` and
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
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
        ]
        ++ (builtins.filter (path: nixpkgs.lib.hasSuffix ".nix" (toString path))
          (nixpkgs.lib.filesystem.listFilesRecursive ./modules));
      };
    };
}
