# ryra-templates

What an organization or a machine starts life as.

**Not booted yet.** `machines/base` is written from a configuration that runs
(`hetzner-nixos-uefi`, in fsn1) rather than invented, and it evaluates, but no
machine has come up on it. Read it as a first draft with a known provenance.

```
organizations/default/    the shape a company needs on day one
  organization.toml       vaults, groups
  aspects/base.nix        what every machine here runs
  machines/box/flake.nix  the machine it declares, referencing machines/base
machines/base/            one box: disk, bootloader, ssh, firewall
```

## Two kinds, because they answer different questions

An **organization** template gets somebody from nothing to a working company,
which means it declares a machine: an organization with none is not working,
and declaring costs nothing because `apply` prices it and asks first.
A **machine** template gets one box booting, and is still needed six months
later when somebody adds a machine that the organization template never saw.

## Referenced, not copied

```nix
inputs.base.url = "github:ryanravn/ryra-templates?dir=machines/base";
```

Nix reads a flake from a subdirectory natively, `flake.lock` pins the commit,
and overriding it is a `follows` rather than a fork. So an organization that
wants its own base changes one line, and one that wants ours moves when it
chooses, in a commit, with a diff.

Submodules would give the same pinning with more pain and would fight the lock
rather than complement it.

## A template is a starting point, not a binding

`ryra org init --template` and `ryra org machines buy --template` copy these
into a checkout the organization then owns. Changing this repo does not reach
back: a company whose structure somebody else could change is not its own.

## Your own

Nothing here is privileged. `ryra/default` is a name, and
`git+ssh://git.acme.internal/infra/templates` is as good a one. An organization
template is a checkout with the identifiers stripped, so making one from a
setup that works is mostly deleting: take the repo, remove the org id, the real
people and the bought machines, commit what is left.
