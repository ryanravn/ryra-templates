export DISPLAY=":$desktop_uid"
export XAUTHORITY="$desktop_runtime/Xauthority"
[[ -s "$desktop_password" ]] || { echo 'Set your desktop password first.' >&2; exit 1; }
touch "$XAUTHORITY"
xauth -f "$XAUTHORITY" add "$DISPLAY" . "$(openssl rand -hex 16)"

# VNC stays on a private socket. The loopback web endpoint still requires
# the user's VNC password because other accounts can reach loopback ports.
Xvnc "$DISPLAY" -geometry 1280x800 -depth 24 -nolisten tcp \
  -auth "$XAUTHORITY" -rfbport 0 -rfbunixpath "$desktop_runtime/vnc.sock" \
  -rfbunixmode 0600 -SecurityTypes VncAuth -PasswordFile "$desktop_password" \
  -AlwaysShared -AcceptSetDesktopSize=1 &
desktop_x_pid=$!
trap 'kill "$desktop_x_pid" 2>/dev/null || true' EXIT
desktop_ready=false
for ((desktop_attempt=0; desktop_attempt<40; desktop_attempt++)); do
  if xdpyinfo >/dev/null 2>&1; then
    desktop_ready=true
    break
  fi
  kill -0 "$desktop_x_pid"
  sleep 0.25
done
if [[ "$desktop_ready" != true ]]; then
  echo 'The virtual display did not become ready.' >&2
  exit 1
fi

dbus-run-session -- openbox-session &
desktop_wm_pid=$!
xterm -title 'Ryra desktop' &
websockify --web "$RYRA_NOVNC" --unix-target "$desktop_runtime/vnc.sock" \
  "127.0.0.1:$desktop_port" &
desktop_web_pid=$!
wait -n "$desktop_x_pid" "$desktop_wm_pid" "$desktop_web_pid"
echo 'A desktop component exited. The session has ended.' >&2
exit 1
