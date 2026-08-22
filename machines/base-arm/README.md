# ryra/base-arm

`ryra/base`, for the arm64 boxes a provider sells cheaper. Hetzner's CAX line is
roughly half the price of the x86 equivalent, which is the only reason this
exists.

**Not tested on a booted machine yet**, and less tested than `ryra/base`, which
has at least been installed onto real hardware. Read it as a first draft.

## What differs from `ryra/base`, and nothing else does

Two files. Everything else in this directory is a byte-for-byte copy.

| file | difference |
|---|---|
| `flake.nix` | `system` and `meta.systems` are `aarch64-linux` |
| `modules/hardware.nix` | UEFI only: no BIOS boot partition, no MBR install |

arm64 on Hetzner is UEFI, so the 1 MB EF02 partition and `devices = [ "/dev/sda" ]`
that `ryra/base` carries are answering a question this hardware does not ask. That
file explains at length what a UEFI-only GRUB cost on x86, where the firmware
really is ambiguous; copying the fix here would be copying a scar rather than the
lesson.

## Why two templates rather than one with a conditional

A template is a thing somebody **forks**. A fork full of branches for hardware
they do not own is worse than a short file for the machine they have.

The cost is real and is stated here rather than left to be discovered: a fix to
any shared module has to be made in both directories. `fetch_template` copies a
single subdirectory, so a template cannot reference files outside its own root,
and there is nowhere shared to put them.

If the copies drift far enough that this stops being worth it, the answer is one
template whose `hardware.nix` branches on `pkgs.stdenv.hostPlatform.isAarch64`,
and `meta.systems` listing both. That is a worse file and a better repository,
and which one wins depends on how many of these there are.

## Which one you get

`ryra org machines buy` reads `meta.systems` and offers only machines a template
can be built for. Declaring `template = "ryra/base-arm"` is what gets you an arm64
box; declaring nothing gets you `ryra/base`, and therefore x86.
