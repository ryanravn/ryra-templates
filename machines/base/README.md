# ryra/default

What a machine ryra creates starts life as.

**Not tested on a booted machine yet.** It has been written from a configuration
that is running (`hetzner-nixos-uefi`, in fsn1) rather than invented, and it
evaluates, but nothing has installed it. Read it as a first draft with a known
provenance, not as something proven.

## What is here

| file | why |
|---|---|
| `modules/hardware.nix` | GRUB in UEFI mode with `efiInstallAsRemovable`, GPT via disko, virtio |
| `modules/access.nix` | ssh, the firewall, and an assertion that nothing else may close port 22 |
| `modules/base.nix` | locale, nix settings, garbage collection, and auto-upgrade OFF |

## The three decisions worth arguing with

**Access is one aspect, and it asserts.** `docs/DESIGN-machines.md` says one
aspect holds ssh and the firewall rules that keep it reachable, and a service
module cannot unset them. On `hetzner-fsn1` that rule is broken today: whether
ssh is reachable is decided inside the Nextcloud module, and two `mkForce` list
definitions merge rather than clash, so nothing reports the conflict. The
assertion here fails the build instead of the machine.

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

- **Nothing installs it.** `Platform::Ryra` is refused by the Hetzner driver and
  there is no snapshot; whether this arrives as an image or via
  `nixos-anywhere` against a stock box is undecided, and `nixos-anywhere` would
  make a bought machine and somebody's own rack the same thing.
- **No sops.** Secrets are encrypted to the machine's age recipient, which is
  derived from a host key that does not exist until it boots.
- **`system.configurationRevision` is a placeholder.** It should be the commit,
  which is what makes a generation know what it was built from.
