# ryra/base

What a machine ryra creates starts life as.

**Not tested on a booted machine yet.** It has been written from a configuration
that is running (`hetzner-nixos-uefi`, in fsn1) rather than invented, and it
evaluates, but nothing has installed it. Read it as a first draft with a known
provenance, not as something proven.

## What is here

| file | why |
|---|---|
| `modules/hardware.nix` | GRUB on both boot paths, root on btrfs via disko, virtio, the pre-switch snapshot |
| `modules/access.nix` | ssh, the firewall, and an assertion that nothing else may close port 22 |
| `modules/memory.nix` | zram and an OOM killer, so a full machine stays reachable |
| `modules/herdr.nix` | herdr, per user, so the machine can actually be connected to |
| `modules/base.nix` | locale, nix settings, garbage collection, and auto-upgrade OFF |

## The four decisions worth arguing with

**Access is one aspect, and it asserts.** `docs/DESIGN-machines.md` says one
aspect holds ssh and the firewall rules that keep it reachable, and a service
module cannot unset them. On `hetzner-fsn1` that rule is broken today: whether
ssh is reachable is decided inside the Nextcloud module, and two `mkForce` list
definitions merge rather than clash, so nothing reports the conflict. The
assertion here fails the build instead of the machine.

**Root is btrfs.** This was ext4 until somebody asked why, and the honest
answer was that nobody had decided it: the file was written from
`hetzner-nixos-uefi`, which is root on ZFS, and the disk layout is the one part
of a template that evaluating cannot check, so the simplification was never
caught. The list you are reading is the evidence, because the filesystem was not
on it.

What a snapshotting filesystem is for here is the armed undo.
`docs/DESIGN-machines.md` calls that the most load-bearing mechanism in the
design and then says what limits it: a generation restores CONFIGURATION, not
DATA. Roll back a bad deploy on ext4 and you get yesterday's configuration
pointed at today's mangled state, and somebody who rolls back and finds it did
not help is worse off than somebody who never trusted it.
`system.preSwitchChecks.btrfsSnapshot` is the other half.

btrfs rather than ZFS, which is what the machine it was copied from runs. ZFS
caches in the ARC rather than the page cache, and the ARC costs a few hundred
megabytes even capped hard and half of RAM left alone. These machines are
commonly 4 GB and run a browser and an agent session, so that is the wrong
trade; btrfs uses the page cache and costs about what ext4 costs. What is given
up is a real read cache and multi-disk, neither of which a single-disk cloud VM
has any use for. `nix/host.nix` in the ryra repo stays on ZFS, where the box is
larger and Postgres makes the ARC worth its memory.

The standing cost is copy-on-write: anything doing small random writes wants
`chattr +C` on its directory, and a full filesystem reports confusingly because
data and metadata are allocated separately.

**No keys in the template.** `authorizedKeys` is empty. ryra writes the key and
the certificate authority when it creates the machine, because a template
carrying a key is a template that lets its author into every machine started
from it.

**Auto-upgrade is off.** Package updates are a commit, not an activation: a
self-triggered rebuild has nobody outside to confirm it, so it cannot have the
armed-undo net that makes a deploy survivable. The hetzner box pulled and
rebuilt on a timer and failed silently for three nights in July.

## A template is a starting point, not a binding

Once a machine exists, its configuration is its own directory in the
organization's checkout. Changing this repo does not reach back: a machine that
silently followed a remote somebody else controls is a machine whose
configuration you do not own.

## What is missing

- **`system.configurationRevision` is a placeholder.** It should be the commit,
  which is what makes a generation know what it was built from.

Two entries left this list rather than being fixed here, because they were
answered elsewhere and the note outlived them. `nixos-anywhere` installs this,
decided in `crates/core/src/design/install.rs` and argued there against the
snapshot it was weighed against. And sops arrived: `modules/secrets.nix` ships
empty and `ryra org machines deploy` fills it, keyed to the host key the old
note was worried about.
