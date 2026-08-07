#!/bin/bash
# Phase C (node): restore a Mode A clone via the shipped CLI.
set +e
exec 2>&1
SBID=$(crictl pods --name kata-openclaw -q | head -1)
echo "SBID=$SBID"
echo ""
echo "######## restore via kata-runtime restore --from ########"
/usr/local/bin/kata-runtime restore --from "$SBID" --name openclaw-clone
echo "restore-rc=$?"
echo ""
echo "--- clone.json (the CLI's auto-allocated tap + IPs + MAC; ALWAYS read IP from here) ---"
cat /tmp/openclaw-clone/clone.json 2>/dev/null; echo
GIP=$(grep -oE '"guest_ip": "[0-9.]+' /tmp/openclaw-clone/clone.json 2>/dev/null | grep -oE '[0-9.]+$')
echo "clone guest IP = $GIP"
sleep 3
echo "--- clone gateway reachable on its own IP? ---"
curl -sS -m6 -o /dev/null -w "clone :18789 HTTP=%{http_code}\n" "http://$GIP:18789/" 2>&1 | head -2
