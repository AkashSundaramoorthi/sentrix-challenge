# Sentrix Mini SOC — Single-Host Integration Map

The demo runs on ONE laptop (SRM Wi-Fi has AP isolation — no laptop-to-laptop).
Everyone develops in isolation, then everything is merged onto the demo host.
This map is the source of truth for what runs where, who owns it, and what conflicts.

## Layers — all 4 mandatory + dashboard (differentiator)

| Layer | Tool(s) | Owner | Status |
|---|---|---|---|
| ❶ Detection (IDS + WAF) | Suricata + ModSecurity/Nginx + DVWA | Member 2 (= me) | ✅ DONE, Docker |
| ❷ SIEM & Visibility | Wazuh manager+indexer+dashboard | Member 3 (= me) | ✅ ingest DONE; panels pending |
| ❸ Identity & Access | Keycloak (realm + RBAC + events) | Member 4 | ⏳ their machine |
| ❹ Automated Response (SOAR) | Flask backend + custom block script | Member 1 | ⏳ their machine |
| ★ Cognitive Dashboard | Flask API + glassmorphic HTML/JS + SQLite | Member 1 + 5 | ⏳ their machines |

## Port map for the single demo host (resolve collisions!)

| Port | Service | Owner | Note |
|---|---|---|---|
| 443 | Wazuh dashboard (https) | M3 | ✅ |
| 9200 | Wazuh indexer | M3 | ✅ |
| 1514/1515/55000 | Wazuh manager | M3 | ✅ |
| 8080 | **WAF (Nginx/ModSecurity)** | M2 | ✅ taken |
| 8081 | **Keycloak** ← REMAP from 8080 | M4 | ⚠️ guide says 8080 = COLLISION with WAF |
| 5000 | **Central Flask backend** `/api/simulate` | M1 | ⚠️ same port as my SOAR webhook — see below |
| 3000 | Glassmorphic dashboard UI | M5 | pick a free port |
| (internal) | DVWA | M2 | not published |

## Critical: the :5000 backend is shared, not duplicated
I (M3) already built a Flask app on :5000 with `POST /api/simulate`, and wired the
Wazuh manager to forward level>=10 alerts to it. Per the strategy doc, that endpoint
is explicitly the seam for **Member 1's central backend**. So on integration:
- Member 1's `backend/app.py` BECOMES the :5000 app (SQLite + brownie logic + REST).
- It MUST keep `POST /api/simulate` (Wazuh already points there — zero rewiring).
- My webhook (soar/webhook_backend/) is the working stand-in until M1's lands; it can
  be retired or merged. Do NOT run two apps on :5000.

## Tech we are CUTTING (allowed by the brief, saves resources)
- ❌ Shuffle SOAR — brief allows "custom scripts that trigger on live alerts"; the Flask
  backend covers SOAR. Drop the Shuffle container + :3001.
- ❌ TheHive (case mgmt) — not mandatory.
- ❌ Separate ELK — Wazuh Indexer (OpenSearch) already is the ELK equivalent.
- ❌ The shared /logs file-drop contract — Wazuh is already the integration bus; the
  backend ingests from Wazuh/webhook directly.

## SOAR block action — adapt for single-host Docker
Member 1's guide blocks via `ssh root@VM2 + iptables`. There is no VM2 here. Options on
one host: `docker network disconnect soc_socnet <attacker>`, an nginx `deny` injected
into the WAF, or an iptables DROP inside the WAF container. Keep it demonstrable + fast
(the judges time attack→block).

## Brownie points (need >=2 or DISQUALIFIED) — where each lives
| Day | Riddle decode | Lives in | Owner |
|---|---|---|---|
| 1 | Stateful threat score w/ time decay (low-and-slow) | backend SQLite `compute_decayed_score()` | M1/M5 |
| 2 | Behavioral anomaly on AUTH patterns (not login events) | Keycloak events + backend logic + UI panel | M4/M5 |
| 3 | Risk-based alert correlation/prioritization | backend correlation + "screened vs escalated" UI | M1/M5 |
| 4 | Statistical anomaly (Z-score) vs signature detection | `calculate_anomaly_z_score()` + Chart.js outliers | M5 |
Recommended 2 to lock first: **Day 1 (decay)** + **Day 3 (correlation)** — both sit on
the backend that already receives my real Wazuh alerts.

## My (Member 3) remaining items
1. SIEM dashboard panels (alert-count-by-type, top source IPs, WAF blocks, auth events)
   — OR confirm Member 5's custom dashboard replaces them (coordinate, don't double-build).
2. Ingest Keycloak auth logs (Member 4 hands me the log file/format) as a 3rd source.
3. Be the integration owner: hand M1 the :5000 contract, help merge onto the demo host.
