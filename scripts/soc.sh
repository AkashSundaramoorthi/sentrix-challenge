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
    echo "[*] Starting Wazuh SIEM stack..."
    (cd "$ROOT/infra/single-node" && docker compose up -d)
    echo "[*] Starting Detection stack..."
    (cd "$ROOT/detection" && docker compose up -d)
    echo "[*] SOAR webhook (LaunchAgent):"
    launchctl list | grep -q sentrix && echo "  already loaded" || \
      launchctl load ~/Library/LaunchAgents/com.sentrix.soar-webhook.plist
    echo "[*] Done. Dashboard: https://localhost:443  (wait ~1 min for indexer)"
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
    echo "Usage: $0 {up|down|status|attack|logs}"; exit 1 ;;
esac
