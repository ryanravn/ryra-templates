# ryra/desktop

An x86-64 NixOS server with an on-demand Openbox desktop, accessed through SSH.

After deployment, run in a Ryra terminal pane (omit `--remote HOST` when already on the machine):

```sh
ryra desktop password --remote HOST
ryra desktop start --remote HOST
ryra desktop --remote HOST
```

Enter your password in the viewer. Closing it disconnects; `ryra desktop stop --remote HOST` ends the session. Sessions need at least 512 MiB of available RAM to start; GPU drivers are not included.

Booted Linux verification is still required before release. Helper tests live in [tests/control.rs](tests/control.rs).
