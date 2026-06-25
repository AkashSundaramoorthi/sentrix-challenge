#!/bin/sh
# Sentrix Mini SOC — demo attack runner (Member 2).
# Generates attack traffic FROM INSIDE the docker bridge so Suricata (which shares
# the WAF network namespace) actually sees it. On Docker Desktop for Mac, hitting
# localhost:8080 from the host goes through a userland proxy and Suricata misses it.
#
# Each attack: (1) is blocked by ModSecurity (WAF, 403), and (2) detected by Suricata (IDS).
# Both surface in Wazuh as separate sources and the high-severity ones trigger the SOAR webhook.
set -e
NET=soc_socnet
TARGET=http://soc-waf:8080
run() { docker run --rm --network "$NET" curlimages/curl:latest -s -o /dev/null "$@" >/dev/null 2>&1 || true; }

echo "[*] Attacking $TARGET from inside $NET ..."

echo "  - SQL injection (UNION SELECT)"
for i in 1 2 3; do run "$TARGET/vulnerabilities/sqli/?id=1%27%20UNION%20SELECT%20user,password%20FROM%20users--%20"; done

echo "  - SQLMap scanner (User-Agent)"
for i in 1 2 3; do run -A "sqlmap/1.7.2#stable" "$TARGET/vulnerabilities/sqli/?id=1"; done

echo "  - Nmap / scanner recon (User-Agent)"
for i in 1 2 3; do run -A "Mozilla/5.0 Nmap Scripting Engine" "$TARGET/"; done

echo "  - Login brute force (rapid POST)"
for i in $(seq 1 15); do run -X POST -d "username=admin&password=p$i&Login=Login" "$TARGET/login.php"; done

echo "  - XSS attempt"
run "$TARGET/?q=<script>alert(1)</script>"

echo "[*] Done. Check: Wazuh dashboard, alerts.json, and the SOAR webhook (/api/alerts)."
