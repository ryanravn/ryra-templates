# The agents a session on this machine can be, and the adapters Ryra speaks to them through.
#
# An agent session is the product: `docs/SESSIONS.md` has them living in a pane on the machine
# rather than in a daemon somewhere, which means the agent has to BE on the machine. A box with
# herdr and no agent is a box you can open a terminal on.
#
# # Why the adapters are separate packages
#
# Ryra drives an agent over ACP, not over its terminal: `crates/core/src/acp.rs` starts a command
# and speaks the protocol to it, which is what makes a session structured rather than a wall of
# characters. Neither CLI speaks it directly. `claude-code` needs `claude-code-acp`, and `codex`
# needs `codex-acp` because its own subcommands are `mcp`, `mcp-server` and `app-server` and none
# of them is this.
#
# Packaged rather than `npx -y @zed-industries/claude-code-acp`, which is what acp.rs documents
# and what a laptop does. On a machine that is the wrong shape twice: it fetches from the network
# at first use, so a box without one has no agent and says so late, and it resolves to whatever
# npm published this morning, which is the opposite of what a machine built from a pinned flake
# is for.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    claude-code
    claude-code-acp
    codex
    codex-acp
  ];
}
