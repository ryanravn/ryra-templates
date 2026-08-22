# The thing this machine is reached BY.
#
# `docs/HERDR.md` calls herdr the connect layer and only that layer: it runs on a box, owns the
# panes, and knows what the agents are doing. Ryra reads it to render a session properly. So a
# machine without herdr is a machine the desktop lists, signs a certificate for, and then cannot
# open: `crates/core/src/remote.rs` holds an ssh tunnel to the box's herdr SOCKET, and a socket
# that is not there is the difference between "unreachable" and "nothing is listening".
#
# That was the state of this template until somebody tried it. It installed git and rsync, the
# access path worked end to end, and connecting from the app arrived at nothing.
#
# # Why a user service and not a system one
#
# The socket is `~/.config/herdr/herdr.sock`, one per person. That is not incidental: herdr owns
# somebody's panes and agent sessions, and a machine several people share is several herdrs, not
# one with everybody's work in it. A system service would put every person's sessions in root's.
#
# # Why it starts on login rather than at boot
#
# `wantedBy = default.target` starts it with the user's session, and the ssh connection that
# opens the tunnel IS that session, so connecting starts it. Lingering would start it at boot
# instead; it is left off because a machine that nobody has logged into has no sessions worth
# keeping warm, and a herdr per declared account running forever on a 4 GB box is exactly the
# memory `modules/memory.nix` is about.
#
# The cost is a race the first time: the tunnel can reach the socket before the service has
# created it. `RemoteState.error` already carries that case in words rather than a blank pane,
# and a second attempt finds it up. If that turns out to be more than a blink, lingering is the
# lever: `users.users.<name>.linger = true`.
{ pkgs, ... }:
{
  # On PATH as well as in the service, because somebody who ssh's in by hand wants the same
  # herdr the app is talking to rather than a second one they installed themselves.
  environment.systemPackages = [ pkgs.herdr ];

  systemd.user.services.herdr = {
    description = "herdr: the terminal workspace this machine's agent sessions live in";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      # `herdr server` with no subcommand is the headless server. Not `herdr`, which launches or
      # attaches to a session and wants a terminal there is none of here.
      ExecStart = "${pkgs.herdr}/bin/herdr server";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
