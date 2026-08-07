#!/bin/bash
# Phase E (node): COW isolation write + route table + the 3 negatives.
set +e
exec 2>&1
AGENT=/kata-containers/src/tools/agent-ctl/target/release/kata-agent-ctl
VSOCK=/tmp/pyrt-clone/clone-vm.vsock
GIP=$(grep -oE '"guest_ip": "[0-9.]+' /tmp/pyrt-clone/clone.json 2>/dev/null | grep -oE '[0-9.]+$')
SBID=$(crictl pods --name kata-pyruntime -q | head -1)
echo "GIP=$GIP SBID=$SBID"

echo ""
echo "######## E1. write a clone-only file (original must NOT see it later) ########"
curl -sS --max-time 12 -X POST "http://$GIP:8888/execute" -H "Content-Type: application/json" \
  -d '{"command":"sh -c \"echo only-on-clone > /app/clone-only.txt; echo only-on-clone > /tmp/clone-only.txt; ls /app/clone-only.txt /tmp/clone-only.txt\""}' 2>&1 | head -2

echo ""
echo "######## E2. clone route table (no default route after re-IP -> egress black-holed) ########"
timeout 15 $AGENT connect --server-address unix://$VSOCK --hybrid-vsock true -c ListRoutes 2>&1 \
  | grep -oE 'dest: \\"[^\\]*\\"' | head
echo "(expect only on-link 10.244.0.0/16 + 192.168.x.0/24 + fe80::/64 ; NO 0.0.0.0 default)"

echo ""
echo "######## E3. INBOUND still works ########"
curl -sS --max-time 10 "http://$GIP:8888/" 2>&1 | head -1

echo ""
echo "######## NEG1. collision - 2nd restore while clone live (must refuse) ########"
/usr/local/bin/kata-runtime restore --path /run/vc/vm/snapshots/"$SBID" --name pyrt-clone 2>&1 | head -2
echo ""
echo "######## NEG2. bad --path ########"
/usr/local/bin/kata-runtime restore --path /run/vc/vm/snapshots/does-not-exist-xyz 2>&1 | head -2
echo ""
echo "######## NEG3. snapshot bogus sbid ########"
/usr/local/bin/kata-runtime snapshot create --path /tmp/bogus-snap --sandbox-id bogus-sbid-123 2>&1 | head -2
