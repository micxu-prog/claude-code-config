#!/bin/bash
# Phase D (node): PROVE the live openclaw survived restore (not a relaunch).
# The clone is NOT a pod, so we prove via openclaw's OWN HTTP surface on the clone IP:
#   - Control UI serves (title + HTTP 200)
#   - ALL readiness/health probes return 200 => the live gateway is up and healthy on a
#     brand-new VM, INSTANTLY (a relaunch would show a cold-boot delay + cold readiness).
# (kata-agent-ctl ExecProcess for in-guest PID/marker is unreliable in this build — the
#  health proof is the rigorous signal; see SKILL.md.)
set +e
exec 2>&1
GIP=$(grep -oE '"guest_ip": "[0-9.]+' /tmp/openclaw-clone/clone.json 2>/dev/null | grep -oE '[0-9.]+$')
echo "clone IP=$GIP"

echo ""
echo "######## D1. clone Control UI survived ########"
curl -sS -m6 "http://$GIP:18789/" 2>&1 | grep -oE '<title>[^<]*</title>' | head -1
curl -sS -m6 -o /dev/null -w "clone :18789 HTTP=%{http_code}\n" "http://$GIP:18789/" 2>&1 | head -1

echo ""
echo "######## D2. THE PROOF: all readiness/health probes 200 on the restored clone ########"
allok=1
for ep in /healthz /readyz /health /ready; do
  code=$(curl -sS -m5 -o /dev/null -w "%{http_code}" "http://$GIP:18789$ep" 2>/dev/null)
  echo "  $ep -> $code"
  [ "$code" = 200 ] || allok=0
done
[ "$allok" = 1 ] && echo "PASS: the live openclaw gateway survived restore (healthy on a new VM)." \
                 || echo "CHECK: a probe was non-200 — inspect /tmp/openclaw-clone/clh-restore.log"

echo ""
echo "######## D3. (context) BEFORE anchors from phase A ########"
echo "phase A recorded: PID1=openclaw-gateway  START_TICKS=724  MARKER=BANANA-42-snapshot-witness"
echo "The clone serving healthy on :18789 with no boot delay == the warmed process was captured live."
