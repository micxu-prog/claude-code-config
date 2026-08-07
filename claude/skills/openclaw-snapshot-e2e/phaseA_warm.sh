#!/bin/bash
# Phase A (host-side via kubectl exec on the ORIGINAL openclaw pod):
# 1) confirm the gateway is HTTP-ready,
# 2) write a survivable MARKER into the RAM-overlay workspace,
# 3) capture the survival ANCHORS: PID 1 + its start-time (field 22 of /proc/1/stat).
# These anchors are what we re-check on the clone to prove "captured live, not relaunched".
set +e
exec 2>&1

echo "=== A1. gateway HTTP-200 on :18789? ==="
kubectl exec kata-openclaw -- sh -c 'curl -sS -m6 -o /dev/null -w "HTTP=%{http_code}\n" http://127.0.0.1:18789/' 2>&1 | head -2

echo ""
echo "=== A2. openclaw self-report (version, sessions path) ==="
kubectl exec kata-openclaw -- sh -c 'openclaw status --json 2>/dev/null | head -c 220; echo' 2>&1 | head -4

echo ""
echo "=== A3. write a survivable MARKER into the RAM-overlay workspace ==="
kubectl exec kata-openclaw -- sh -c 'echo BANANA-42-snapshot-witness > /home/node/.openclaw/workspace/marker.txt; echo "wrote:"; cat /home/node/.openclaw/workspace/marker.txt; ls -la /home/node/.openclaw/workspace/marker.txt' 2>&1 | head -4

echo ""
echo "=== A4. SURVIVAL ANCHORS (record these; we re-check on the clone) ==="
kubectl exec kata-openclaw -- sh -c 'echo "PID1_CMD=$(tr "\000" " " < /proc/1/cmdline)"; echo "PID1_START_TICKS=$(cut -d" " -f22 /proc/1/stat)"; echo "GUEST_UPTIME=$(cut -d" " -f1 /proc/uptime)s"' 2>&1 | head -4
echo "(PID1 should be openclaw-gateway; PID1_START_TICKS is constant for the live process across snapshot/restore; a RELAUNCH would change it)"
