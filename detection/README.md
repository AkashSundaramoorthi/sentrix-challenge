# Detection Layer (Member 2) — Perimeter & Detection

Layer 1 of the Mini SOC: a vulnerable target behind a WAF, with an IDS watching the
traffic. Runs entirely in Docker (arm64-native, ~1.6 GB) — no VMs needed.

```
attacker (bridge) ─▶ ModSecurity/Nginx WAF (blocks + logs) ─▶ DVWA (target)
                              ▲
                         Suricata IDS (shares WAF netns, sniffs eth0)
                              │
              eve.json + modsec/audit.log ─▶ Wazuh manager (SIEM) ─▶ SOAR webhook
```

## Components
| Service | Image | Role |
|---|---|---|
| `soc-dvwa` | `vulnerables/web-dvwa` | Deliberately vulnerable target |
| `soc-waf` | `owasp/modsecurity-crs:nginx` | WAF (OWASP CRS), blocks attacks, JSON audit log, exposes `:8080` |
| `soc-suricata` | `jasonish/suricata` | IDS, shares WAF netns, custom rules in `suricata/rules/local.rules` |

## Run
```bash
docker compose up -d           # start target + WAF + IDS
./attack.sh                    # generate the demo attacks
```

## IMPORTANT — generate attacks from inside the bridge
On Docker Desktop for Mac, host→container traffic to `localhost:8080` goes through a
userland proxy, so **Suricata does not see it**. Always attack from a container on
`soc_socnet` targeting `http://soc-waf:8080` (this is what `attack.sh` does). Real
tools work the same way, e.g.:
```bash
docker run --rm --network soc_socnet instrumentisto/nmap -sV soc-waf
docker run --rm --network soc_socnet ... sqlmap -u "http://soc-waf:8080/..." 
```

## How it feeds the SIEM (Member 3 integration)
- Logs are written to `./logs/{suricata,modsec,nginx}/`.
- The Wazuh manager bind-mounts `./logs` at `/var/log/detection` (see `infra/single-node/docker-compose.yml`)
  and reads them via `localfile` blocks in `wazuh_manager.conf` — IDS and WAF as **separate sources**.
- Custom Wazuh rules (`wazuh-rules/local_rules.xml`, installed at `/var/ossec/etc/rules/local_rules.xml`):
  - `100100` escalates our Suricata web-attack signatures to **level 12**
  - `100110` raises a **level 10** alert when ModSecurity blocks a request
  - Both are level ≥10, so they trigger the SOAR webhook forwarding (attack → detect → SIEM → response).

## Verify end-to-end
```bash
./attack.sh
# Wazuh alerts:
docker exec single-node-wazuh.manager-1 sh -c 'tail -200 /var/ossec/logs/alerts/alerts.json' | grep -E '100100|100110'
# SOAR received:
curl -s 'http://127.0.0.1:5000/api/alerts?n=50'
```
