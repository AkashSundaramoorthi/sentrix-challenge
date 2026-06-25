#!/usr/bin/env python3
# Sentrix Mini SOC — Wazuh custom integration.
# Forwards an alert (level >= threshold, set in ossec.conf) to the SOAR webhook.
# Invoked by the Wazuh integrator daemon as:
#   custom-webhook <alert_file> <api_key> <hook_url> [options]
import json
import sys

import requests

def main():
    if len(sys.argv) < 4:
        sys.exit("usage: custom-webhook <alert_file> <api_key> <hook_url>")

    alert_file = sys.argv[1]
    hook_url = sys.argv[3]

    with open(alert_file) as fh:
        alert = json.load(fh)

    try:
        resp = requests.post(hook_url, json=alert, timeout=10,
                             headers={"Content-Type": "application/json"})
        resp.raise_for_status()
    except Exception as exc:  # noqa: BLE001 - integrator logs to ossec.log
        sys.exit(f"custom-webhook: POST to {hook_url} failed: {exc}")

if __name__ == "__main__":
    main()
