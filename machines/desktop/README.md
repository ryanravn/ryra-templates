# ryra/desktop

An x86-64 NixOS server with an on-demand Openbox desktop, accessed through SSH.

After deployment, run in a Ryra terminal pane (omit `--remote HOST` when already on the machine):

```sh
ryra desktop password --remote HOST
ryra desktop start --remote HOST
ryra desktop --remote HOST
```

Enter your password in the viewer. Closing it disconnects; `ryra desktop stop --remote HOST` ends the session. Sessions need at least 512 MiB of available RAM to start; GPU drivers are not included.

Computer control is optional and off by default. To install the pinned, MIT-licensed
[Cua Driver](https://github.com/trycua/cua), add a module to the machine's `modules/`
directory and deploy it:

```nix
{ ... }: {
  ryra.desktop.computerControl.enable = true;
}
```

Use a Ryra build that includes computer control support. Then enable it for the
account running the agent in that server's
`~/.config/ryra/config.toml` (merge into any existing `[tools]` section):

```toml
[tools]
computer_control = true
```

Restart any running desktop and the agent session. Ryra launches `cua-driver mcp
--direct` on the server and connects it to that account's virtual display. Cua
telemetry and update checks are disabled; no hosted Cua service or listening Cua
daemon is used. The agent's model provider still receives tool results, including
screenshots. Applications such as Blender must be installed separately.

Remove the account preference to stop exposing computer control to new agent
sessions, or disable the Nix option and deploy to remove the package. Other machine
templates need no changes. Existing machines need this template's Cua input,
`cuaDriver` special argument, module and desktop session changes copied into their
configuration before enabling the option.

Booted Linux verification is still required before release. Helper tests live in
[tests/control.rs](tests/control.rs); run them with `rustc --test tests/control.rs
-o /tmp/ryra-desktop-tests && /tmp/ryra-desktop-tests` from this directory.
`nix eval --raw .#checks.x86_64-linux.computer-control.drvPath` checks both complete
NixOS configurations and the optional package/accessibility wiring without a Linux
builder. A Linux package build and live desktop control still require Linux.
