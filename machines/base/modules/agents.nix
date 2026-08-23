# The agents, and the adapters ryra speaks to them through.
#
# Ryra drives an agent over ACP rather than over its terminal, which is what makes a session
# structured instead of a wall of characters. Neither CLI speaks it: `codex` offers `mcp`,
# `mcp-server` and `app-server` and no `acp` at all, so the adapters are a requirement rather
# than a convenience.
#
# From nixpkgs rather than `npx -y @zed-industries/claude-code-acp`, which is what ryra's own
# docs still suggest and is the laptop answer. On a machine built from a pinned flake, fetching
# an adapter from npm on first use means a network round trip, tens of seconds before a pane
# opens, and whatever version npm published that morning. These arrive in the closure, work with
# no network, and start immediately.
{ lib, pkgs, ... }:
{
  # `claude-code` is the one unfree package on a ryra machine, and the permission is here rather
  # than a blanket `allowUnfree` so that adding a second one stays a decision somebody makes.
  # Without it every build of this machine fails, and the failure is at BUILD rather than at
  # evaluation: `nix flake check` and reading `systemPackages` both pass happily.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];

  environment.systemPackages = with pkgs; [
    claude-code
    claude-code-acp
    codex
    codex-acp
  ];
}
