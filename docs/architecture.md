Day 1 status:
- Mac: Wazuh manager + indexer + dashboard running via Docker, all healthy
- Mac local IP: 10.9.206.161 (en0 / Wi-Fi)
- Windows: Kali + Metasploitable2 VMs on host-only network (pending confirmation)
- Tomorrow: connect Wazuh agent from Windows side, install Suricata

Day 2 status (Member 3 — SIEM & Infrastructure):
- Dashboard reachable at https://localhost:443 (NOT :5601 — this stack maps 5601->443)
- Manager listens for remote agents on 1514/1515 (events/enrollment) + 55000 (API),
  all bound to 0.0.0.0 -> remote VMs enroll with WAZUH_MANAGER='10.9.206.161'
  (use wazuh-agent 4.9.2 to match the manager; the old guide said 4.4.5)
- SOAR alert forwarding (Step 4) DONE:
  * SOAR webhook backend built at soar/webhook_backend/ (Flask, :5000), POST /api/simulate
  * Auto-starts via LaunchAgent com.sentrix.soar-webhook (survives reboot)
  * Wazuh custom integration 'custom-webhook' forwards level>=10 alerts
    via http://host.docker.internal:5000/api/simulate (container can't use 127.0.0.1)
  * Persistent config: infra/single-node/config/wazuh_cluster/wazuh_manager.conf
    (container regenerates /var/ossec/etc/ossec.conf from this on boot)
  * End-to-end verified: integratord 'Enabling integration for: custom-webhook',
    test level-12 alert reached and stored in the backend
Day 2 status (Member 2 — Perimeter & Detection, absorbed onto the Mac as Docker):
- Built all-local in Docker (no VMs; arm64; ~1.6 GB) at detection/docker-compose.yml:
  * soc-dvwa (vulnerables/web-dvwa) — vulnerable target
  * soc-waf (owasp/modsecurity-crs:nginx) — WAF, OWASP CRS, BLOCKS attacks (403),
    JSON audit log, exposes :8080
  * soc-suricata (jasonish/suricata) — IDS, shares WAF netns to sniff eth0,
    custom rules in detection/suricata/rules/local.rules (sids 1000001-1000099)
- KEY GOTCHA: on Docker Desktop Mac, host->container traffic to localhost:8080 goes
  through a userland proxy and Suricata MISSES it. Must attack from INSIDE the bridge:
  docker run --rm --network soc_socnet ... http://soc-waf:8080  (see detection/attack.sh)
- SIEM integration (Member 3): manager bind-mounts detection/logs at /var/log/detection;
  localfile blocks in wazuh_manager.conf read Suricata eve.json + ModSec audit.log as
  SEPARATE sources. Custom Wazuh rules detection/wazuh-rules/local_rules.xml
  (-> /var/ossec/etc/rules/local_rules.xml): rule 100100 escalates Suricata web-attack
  sigs to L12; rule 100110 raises L10 on a ModSecurity block. Both >=10 -> trigger SOAR.
- VERIFIED end-to-end: ./attack.sh -> WAF 403 + Suricata alerts -> Wazuh L12 IDS / L10 WAF
  -> SOAR webhook stores them. Full attack->detect->SIEM->response chain works.

- Still pending (other members):
  * SIEM dashboard panels (Member 3): alert-count-by-type, top source IPs, WAF blocks, auth events
  * IAM layer — Keycloak/Authelia protecting a service + auth logs into SIEM (Member 4)
  * SOAR action playbook on the webhook intake — e.g. block attacker IP (Member 1)
  * 2+ Brownie Points (mandatory): Day1 correlation + Day3 risk-scoring both sit on the Wazuh layer
