# The configuration this machine was built from, readable on the machine.
#
# For the moment ryra is not there. The control plane is down, or the laptop that holds the tree
# is in a bag somewhere, and a box needs changing now. Without this the machine carries no answer
# to "what am I": `/etc/nixos` is empty, the flake is in the store under a hashed name nobody can
# guess, and the only copy anybody can read is somewhere else entirely.
#
# So the machine keeps its own source. `flake.lock` comes with it, which is what makes a rebuild
# here reproducible and possible with no network: every input is already in this machine's store,
# because that is what built the system running now.
#
#   cp -r /etc/nixos/source/. /etc/nixos/
#   $EDITOR /etc/nixos/modules/whatever.nix
#   nixos-rebuild switch --flake /etc/nixos#machine
#
# READ ONLY, and that is the point rather than a limitation. It is a store path, so nothing here
# can be edited in place and nobody can mistake it for the thing that decides. `/etc/nixos` itself
# stays an ordinary writable directory, which is where a copy goes when somebody is fixing
# something at two in the morning.
#
# What happens on the next `ryra org machines switch`: the machine is built from the TREE and
# whatever was done here is gone. That is not a flaw to design around, it is what declarative
# means. A change worth keeping goes into the tree, into git, and gets reviewed like any other. A
# change made here is a repair, and repairs are supposed to be temporary.
#
# Why not put the authoritative flake here instead: because then a fleet has one config per
# machine and one in the tree, and the two drift. That is the failure ryra names in Terraform,
# and every tool that manages more than one NixOS box, colmena and deploy-rs and morph among
# them, pushes from one repository for the same reason.
{ ... }:
{
  environment.etc."nixos/source".source = ./..;
}
