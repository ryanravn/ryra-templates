desktop_fail() {
  jq -cn --arg message "$1" '{state:"failed", message:$message}'
}

desktop_status() {
  if systemctl --user is-active --quiet ryra-desktop.service; then
    if [[ -S "$desktop_runtime/vnc.sock" ]] && curl --fail --silent --max-time 2 \
      "http://127.0.0.1:$desktop_port/vnc.html" >/dev/null; then
      jq -cn --argjson port "$desktop_port" '{state:"running",port:$port}'
    else
      desktop_fail 'The desktop is starting or its viewer is unavailable. Check journalctl --user -u ryra-desktop.'
    fi
  elif systemctl --user is-failed --quiet ryra-desktop.service; then
    desktop_fail 'The desktop service failed. Check journalctl --user -u ryra-desktop, then retry ryra desktop start.'
  elif [[ ! -s "$desktop_password" ]]; then
    printf '%s\n' '{"state":"needs_password"}'
  else
    printf '%s\n' '{"state":"stopped"}'
  fi
}

case "${1:-status}" in
  status) desktop_status ;;
  password)
    if systemctl --user is-active --quiet ryra-desktop.service; then
      echo 'Stop your desktop before changing its password.' >&2
      exit 1
    fi
    mkdir -p "$desktop_config"
    desktop_temp=$(mktemp "$desktop_config/passwd.XXXXXX")
    trap 'rm -f "$desktop_temp"' EXIT
    vncpasswd "$desktop_temp"
    mv "$desktop_temp" "$desktop_password"
    echo 'Desktop password saved. Start it with ryra desktop start.'
    ;;
  start)
    if systemctl --user is-active --quiet ryra-desktop.service; then
      desktop_status
      exit 0
    fi
    if [[ ! -s "$desktop_password" ]]; then
      printf '%s\n' '{"state":"needs_password"}'
      exit 0
    fi
    desktop_available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    if [[ ! "$desktop_available" =~ ^[0-9]+$ ]] || (( desktop_available < 524288 )); then
      desktop_fail 'Less than 512 MiB of available RAM. Free memory before starting a desktop.'
      exit 0
    fi
    if ! systemctl --user start ryra-desktop.service; then
      desktop_fail 'Could not start the desktop. Check journalctl --user -u ryra-desktop.'
      exit 0
    fi
    for ((desktop_attempt=0; desktop_attempt<40; desktop_attempt++)); do
      if [[ -S "$desktop_runtime/vnc.sock" ]] && curl --fail --silent --max-time 0.25 \
        "http://127.0.0.1:$desktop_port/vnc.html" >/dev/null; then
        desktop_status
        exit 0
      fi
      if systemctl --user is-failed --quiet ryra-desktop.service; then
        break
      fi
      sleep 0.25
    done
    desktop_fail 'The desktop did not become ready. Check its status and journalctl --user -u ryra-desktop.'
    ;;
  stop)
    systemctl --user stop ryra-desktop.service
    systemctl --user reset-failed ryra-desktop.service
    printf '%s\n' '{"state":"stopped"}'
    ;;
  *) echo 'Usage: ryra-desktop {status|password|start|stop}' >&2; exit 2 ;;
esac
