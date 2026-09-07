# The `ryra` command itself, on the machine.
#
# So that somebody who has ssh'd in to fix something can put the fix back where it belongs. The
# break-glass edit in `/etc/nixos` is a REPAIR and is replaced by the next push; without this
# there is no way to promote one from the box, and the only route to a permanent change is a
# laptop somebody may not have with them.
#
# It carries NO credential. The binary is inert until a person signs in as themselves, which is
# the same flow and the same scope a laptop uses. Putting the command here does not make this
# machine able to change the organization; it makes the person at it able to, which they already
# were from somewhere else.
#
# From the published package rather than from source, because the source is private and this is
# the artefact that is public and signed. `autoPatchelfHook` is what makes a generic Linux binary
# run on NixOS at all: without it there is no loader at the path the binary asks for, and it fails
# on every run with a sentence about dynamically linked executables.
#
# PINNED, and it has to be bumped when ryra is released: a `fetchurl` needs a hash, so "latest"
# is not expressible here. The same shape as the herdr pin above it, and no longer the slack one:
# `updates.nix` runs this binary, so a version older than the subcommand it calls is a timer that
# fails every night. 0.1.6 was pinned here while `machines update` existed only on main, and the
# unit died with "unrecognized subcommand" at the first run.
#
# This assumes the pool keeps what it has published. If a version is ever removed from
# pkg.ryra.dev, every machine pinned to it stops building.
{ lib, pkgs, ... }:
let
  version = "0.1.19";

  # Debian's architecture names, which are not nix's. Keyed by system so one file serves both
  # templates rather than two copies drifting apart.
  published = {
    "x86_64-linux" = {
      arch = "amd64";
      sha256 = "0b8654b4679133adf7fc9532a257a933f44d202a067e204e30ddb74b5e2c59a1";
    };
    "aarch64-linux" = {
      arch = "arm64";
      sha256 = "7aa23212506da6d540b4a4fba18a061b60b699ef7ac2b885b0881a24312b15eb";
    };
  };
  package = published.${pkgs.stdenv.hostPlatform.system};

  ryra = pkgs.stdenv.mkDerivation {
    pname = "ryra";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://pkg.ryra.dev/deb/pool/ryra_${version}_${package.arch}.deb";
      inherit (package) sha256;
    };

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.dpkg
    ];
    # libc, libm and libgcc_s, which is everything it asks for.
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];

    unpackPhase = "dpkg-deb -x $src .";
    installPhase = ''
      mkdir -p $out
      cp -r usr/* $out/
    '';

    # Shaped the way nixpkgs shapes a closed-source binary, because that is what this would be
    # submitted AS. Slack, zoom and 1password are all in nixpkgs on exactly these terms: a
    # published artefact, `binaryNativeCode`, and an unfree licence. Building from source is not
    # an option nixpkgs has here and repackaging is not a lesser path, it is the path.
    #
    # `sourceProvenance` is the part that is easy to leave out and is not optional: it is how
    # somebody auditing a closure learns that this came down as a binary rather than being
    # compiled, and 1227 packages in nixpkgs declare it.
    meta = {
      description = "Ryra: machines, secrets, deployments and agent workspaces";
      homepage = "https://ryra.dev";
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      license = lib.licenses.unfree;
      platforms = builtins.attrNames published;
      mainProgram = "ryra";
    };
  };
in
{
  environment.systemPackages = [ ryra ];

  # For units that run it. `environment.systemPackages` puts a binary on a
  # person's PATH and NOT on a systemd unit's, so `updates.nix` asking for
  # `ryra` by name would have failed every night with "command not found".
  _module.args.ryraPackage = ryra;
}
