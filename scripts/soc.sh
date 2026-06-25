#!/bin/sh
# Sentrix Mini SOC — one control script for the whole local stack.
# Usage: ./scripts/soc.sh {up|down|status|attack|logs}
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

wait_docker() {
  if ! docker info >/dev/null 2>&1; then
    echo "[*] Docker daemon down — starting Docker Desktop..."
    open -a Docker
    until docker info >/dev/null 2>&1; do sleep 3; printf .; done
    echo " up"
  fi
}

case "$1" in
  up)
    wait_docker
    # Detection MUST come up first: it (re)creates eve.json / audit.log. If the SIEM
    # manager starts/keeps running before that, its logcollector follows a stale file
    # handle and stops seeing new alerts. So: detection -> SIEM -> re-attach manager.
    echo "[*] Starting Detection stack..."
    (cd "$ROOT/detection" && docker compose up -d)
    echo "[*] Starting Wazuh SIEM stack..."
    (cd "$ROOT/infra/single-node" && docker compose up -d)
    echo "[*] Re-attaching manager logcollector to current detection logs..."
    docker restart single-node-wazuh.manager-1 >/dev/null 2>&1 || true
    echo "[*] SOAR webhook (LaunchAgent):"
    launchctl list | grep -q sentrix && echo "  already loaded" || \
      launchctl load ~/Library/LaunchAgents/com.sentrix.soar-webhook.plist
    printf "[*] Waiting for Wazuh API to be ready (avoids dashboard axios errors)"
    n=0
    until curl -sk -m6 -u 'wazuh-wui:MyS3cr37P450r.*-' -X POST \
        "https://localhost:55000/security/user/authenticate?raw=true" 2>/dev/null | grep -q . || [ $n -ge 30 ]; do
      sleep 3; n=$((n+1)); printf .
    done
    echo " ready"
    echo "[*] Done. Dashboard: https://localhost:443  (admin / SecretPassword)"
    ;;
  refresh)
    # Use after restarting the detection stack: re-attach the SIEM to fresh log files.
    echo "[*] Re-attaching manager logcollector..."
    docker restart single-node-wazuh.manager-1 >/dev/null 2>&1 || true
    echo "[*] Done."
    ;;
  down)
    (cd "$ROOT/detection" && docker compose down)
    (cd "$ROOT/infra/single-node" && docker compose down)
    echo "[*] Containers stopped. (SOAR webhook LaunchAgent left running.)"
    ;;
  status)
    docker ps --format '{{.Names}}\t{{.Status}}' | sort || true
    echo "---"
    curl -sk -m5 -o /dev/null -w "Wazuh dashboard -> %{http_code}\n" https://localhost:443/ || true
    curl -s -m3 -o /dev/null -w "SOAR webhook    -> %{http_code}\n" http://127.0.0.1:5000/health || true
    ;;
  attack)
    "$ROOT/detection/attack.sh"
    ;;
  logs)
    curl -s "http://127.0.0.1:5000/api/alerts?n=20" || true
    ;;
  *)
    echo "Usage: $0 {up|down|status|refresh|attack|logs}"; exit 1 ;;
esac
