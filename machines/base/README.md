# ryra/base

The default x86-64 NixOS server preset.

This is a compatibility preset of the shared Ryra machine template. Edit
`configuration.nix` for architecture, desktop and networking choices. The flake
pins the shared modules through the `ryra-template` input; commit `flake.lock`
with your machine configuration. Generated logins, SOPS secrets and service
settings stay in this machine's own `modules/` directory.

The preset name does not bind an existing machine to future template edits.
