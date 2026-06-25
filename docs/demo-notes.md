# Final Demo — Speaker Notes (Member 2 + 3: Detection & SIEM)

## Pre-flight (BEFORE you enter the room)
```bash
cd ~/Desktop/sentrix-mini-soc
./scripts/soc.sh up        # start everything
./scripts/soc.sh status    # all 6 containers Up, dashboard 302, webhook 200
```
Open **https://localhost:443** (Wazuh) and log in BEFORE you go in. Have a terminal ready.

## The 90-second live demo (exact sequence)
1. **Show the dashboard** (https://localhost:443) — "This is our SIEM, Wazuh, the visibility layer."
2. **Run the attack live**:
   ```bash
   ./scripts/soc.sh attack
   ```
   Say: *"I'm launching SQL injection, a scanner, and a brute-force from inside the network."*
3. **Show the WAF blocked it** — attacks return HTTP 403 (ModSecurity).
4. **Refresh the Wazuh dashboard** — new alerts appear, IDS and WAF as **separate sources**, escalated to high severity (L12 / L10).
5. **Show the forwarding**:
   ```bash
   ./scripts/soc.sh logs
   ```
   Say: *"Every level-10+ alert is automatically forwarded to the response layer's webhook — no human in the loop."*

## Why these tools (judges WILL ask "why this, not that")
- **Suricata (IDS)** — runs on a virtual interface in AF_PACKET mode; works on host-only/Docker networks where promiscuous sniffing is restricted (SRM constraint). Multi-threaded, low latency.
- **ModSecurity + Nginx (WAF)** — fully local, OWASP Core Rule Set out of the box, actively *blocks* (not just detects), and emits a structured JSON audit log we can parse.
- **Wazuh (SIEM)** — Docker-Compose deployable, ships with Suricata + ModSecurity decoders, has its own indexer (OpenSearch = the ELK equivalent, so no second stack), and a built-in integrator to forward alerts. One tool covers collect + correlate + visualize + forward.
- **Why IDS *and* WAF (two detection sources)?** Defense in depth — the WAF blocks at the app layer, the IDS sees the traffic regardless. If one is bypassed, the other still fires.

## The one technical decision to highlight (shows depth)
*"The Wazuh manager runs in a container, so its 127.0.0.1 isn't the host. We forward via host.docker.internal. And on Docker Desktop for Mac, host→container traffic uses a userland proxy that Suricata can't see — so we generate attacks from inside the bridge network. We found that by debugging why Suricata saw zero packets, then fixed the IDS placement to share the WAF's network namespace."*  ← This is exactly the "decision reasoning" judges score.

## Honest framing of scope (if asked about the other layers)
*"I own Detection and SIEM — both live. Our pipeline proves attack → block → detect → SIEM → automated forwarding. The IAM and response-action layers are my teammates' components."*  Don't claim what isn't there.

## Quick recovery if something breaks live
- Dashboard 503 / slow → indexer still warming, wait ~30s, refresh.
- No Suricata alerts → you attacked localhost instead of the bridge; use `./scripts/soc.sh attack`.
- Containers gone → Docker Desktop quit; `./scripts/soc.sh up`.

## Numbers to quote
- 3 detection signatures fire per attack type; IDS + WAF as separate sources.
- Forwarding threshold: Wazuh level ≥ 10 → SOAR webhook (`POST :5000/api/simulate`).
- Whole stack: all Docker, Apple-silicon native, single host, ~1.6 GB.
