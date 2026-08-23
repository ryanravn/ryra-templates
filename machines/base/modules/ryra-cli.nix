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
# is not expressible here. The same shape as the herdr pin above it, and with less urgency, since
# an old CLI is merely old rather than refused by a protocol check.
#
# This assumes the pool keeps what it has published. If a version is ever removed from
# pkg.ryra.dev, every machine pinned to it stops building.
{ pkgs, ... }:
let
  version = "0.1.3";

  # Debian's architecture names, which are not nix's. Keyed by system so one file serves both
  # templates rather than two copies drifting apart.
  published = {
    "x86_64-linux" = {
      arch = "amd64";
      sha256 = "53430e4fb5021e4d51bcf6d05393d7f74a927e0c22baea355f597dc5a59d4b6f";
    };
    "aarch64-linux" = {
      arch = "arm64";
      sha256 = "df70c8e2c84160256eaa03ab4d533ebe9e195df877dcd2e67743e02002716f8f";
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
  };
in
{
  environment.systemPackages = [ ryra ];
}
