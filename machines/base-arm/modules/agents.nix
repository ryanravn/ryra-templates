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
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    claude-code
    claude-code-acp
    codex
    codex-acp
  ];
}
