#!/bin/bash
# Phase C+D (node): restore a clone via the CLI, then PROVE /app + /tmp survived.
set +e
exec 2>&1
SBID=$(crictl pods --name kata-pyruntime -q | head -1)
echo "SBID=$SBID"
echo ""
echo "######## C. restore via kata-runtime restore --path ########"
/usr/local/bin/kata-runtime restore --path /run/vc/vm/snapshots/"$SBID" --name pyrt-clone
echo "restore-rc=$?"
echo "--- clone.json (the CLI's auto-allocated tap / IPs) ---"
cat /tmp/pyrt-clone/clone.json 2>/dev/null; echo
GIP=$(grep -oE '"guest_ip": "[0-9.]+' /tmp/pyrt-clone/clone.json 2>/dev/null | grep -oE '[0-9.]+$')
echo "clone guest IP = $GIP"
sleep 3

echo ""
echo "######## D. HEADLINE: did /app and /tmp files survive into the clone? ########"
curl -sS --max-time 15 -X POST "http://$GIP:8888/execute" -H "Content-Type: application/json" \
  -d '{"command":"sh -c \"echo APP:; cat /app/before-app.txt 2>&1; echo TMP:; cat /tmp/before-tmp.txt 2>&1\""}' 2>&1 | head -3
echo ""
echo "######## D2. re-IP confirm: eth0 now dual-IP (original + new) via agent ListInterfaces ########"
AGENT=/kata-containers/src/tools/agent-ctl/target/release/kata-agent-ctl
timeout 15 $AGENT connect --server-address unix:///tmp/pyrt-clone/clone-vm.vsock --hybrid-vsock true -c ListInterfaces 2>&1 \
  | grep -oE 'address: \\"[0-9.]+\\"' | head
