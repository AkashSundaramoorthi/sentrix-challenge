# SOAR Webhook Backend (Sentrix Mini SOC)

Ingestion point for high-severity alerts forwarded by the Wazuh Manager
(`custom-webhook` integration). Minimal Flask service — the correlation/SOAR
logic (Member 1) extends this.

## Endpoints
| Method | Path            | Purpose                                   |
|--------|-----------------|-------------------------------------------|
| GET    | `/health`       | Liveness probe                            |
| POST   | `/api/simulate` | Alert intake (Wazuh integration target)   |
| GET    | `/api/alerts?n=20` | Last N stored alerts (debug)           |

Alerts are appended to `data/alerts.jsonl`; stdout/stderr go to `data/server.log`.

## Run (manual)
```bash
./run.sh          # creates .venv, installs Flask, runs on 0.0.0.0:5000
```

## Run (auto-start, installed)
Managed by a macOS LaunchAgent so it survives reboots/login:
`~/Library/LaunchAgents/com.sentrix.soar-webhook.plist`

```bash
launchctl load   ~/Library/LaunchAgents/com.sentrix.soar-webhook.plist   # start
launchctl unload ~/Library/LaunchAgents/com.sentrix.soar-webhook.plist   # stop
launchctl list | grep sentrix                                            # status
```

## How the Wazuh Manager reaches it
The manager runs in a container, so `127.0.0.1` inside it is NOT the Mac.
The integration uses `http://host.docker.internal:5000/api/simulate`.
Config lives in `infra/single-node/config/wazuh_cluster/wazuh_manager.conf`
(the persistent source — the container regenerates `/var/ossec/etc/ossec.conf`
from it on every boot). Integration scripts: `infra/single-node/integrations/`.
