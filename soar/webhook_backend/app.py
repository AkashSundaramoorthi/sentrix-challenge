#!/usr/bin/env python3
"""
Sentrix Mini SOC — SOAR webhook backend.

Receives high-severity Wazuh alerts forwarded by the Wazuh Manager's
`custom-webhook` integration (see infra ossec.conf) and the Suricata/Nginx
detection layer. Each alert is logged and appended to a JSONL store so the
correlation/SOAR logic (Member 1) can build on a stable ingestion point.

Endpoints:
  GET  /health         -> liveness probe
  POST /api/simulate   -> primary alert intake (Wazuh integration target)
  GET  /api/alerts     -> last N stored alerts (debug / dashboard)
"""

import json
import logging
import os
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, jsonify, request

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
DATA_DIR.mkdir(exist_ok=True)
ALERT_LOG = DATA_DIR / "alerts.jsonl"

HOST = os.environ.get("SOAR_HOST", "0.0.0.0")
PORT = int(os.environ.get("SOAR_PORT", "5000"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("soar-webhook")

app = Flask(__name__)


def _store(alert: dict) -> None:
    record = {
        "received_at": datetime.now(timezone.utc).isoformat(),
        "source_ip": request.remote_addr,
        "alert": alert,
    }
    with ALERT_LOG.open("a") as fh:
        fh.write(json.dumps(record) + "\n")


def _summarize(alert: dict) -> str:
    """Pull the human-readable bits out of a Wazuh alert envelope."""
    rule = alert.get("rule", {}) if isinstance(alert, dict) else {}
    agent = alert.get("agent", {}) if isinstance(alert, dict) else {}
    return (
        f"level={rule.get('level', '?')} "
        f"rule={rule.get('id', '?')} "
        f"agent={agent.get('name', '?')} "
        f"desc={rule.get('description', alert.get('description', 'n/a'))}"
    )


@app.get("/health")
def health():
    return jsonify(status="ok", service="sentrix-soar-webhook", time=datetime.now(timezone.utc).isoformat())


@app.post("/api/simulate")
def simulate():
    # Wazuh's integrator posts the raw alert JSON as the request body.
    payload = request.get_json(silent=True)
    if payload is None:
        raw = request.get_data(as_text=True).strip()
        if raw:
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                payload = {"raw": raw}
        else:
            payload = {}

    _store(payload)
    log.info("ALERT  %s", _summarize(payload))
    return jsonify(status="received", summary=_summarize(payload)), 200


@app.get("/api/alerts")
def alerts():
    n = int(request.args.get("n", "20"))
    if not ALERT_LOG.exists():
        return jsonify(count=0, alerts=[])
    lines = ALERT_LOG.read_text().splitlines()[-n:]
    return jsonify(count=len(lines), alerts=[json.loads(x) for x in lines])


if __name__ == "__main__":
    log.info("Sentrix SOAR webhook backend starting on %s:%s", HOST, PORT)
    log.info("Alert store: %s", ALERT_LOG)
    app.run(host=HOST, port=PORT)
