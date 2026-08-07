#!/bin/bash
# Teardown (node): kill the socat bridge, restore-kill the clone, delete the snapshot.
set +e
exec 2>&1
echo "--- stop the socat browser bridge ---"
systemctl stop openclaw-pf.scope 2>/dev/null
pkill -f "socat.*:28789" 2>/dev/null
echo "--- restore kill openclaw-clone (shipped teardown verb) ---"
/usr/local/bin/kata-runtime restore kill openclaw-clone 2>&1 | head -4
echo "--- verify clone gone ---"
ps -ef | grep -E "cloud-hypervisor.*openclaw-clone" | grep -v grep | head || echo "no clone CLH (good)"
ls -d /tmp/openclaw-clone 2>/dev/null || echo "/tmp/openclaw-clone gone (good)"
echo "--- delete the snapshot this run made ---"
SBID=$(crictl pods --name kata-openclaw -q 2>/dev/null | head -1)
[ -n "$SBID" ] && /usr/local/bin/kata-runtime snapshot delete --sandbox-id "$SBID" 2>&1 | head -1
echo "--- remaining snapshots (pre-existing only) ---"
ls -d /run/vc/vm/snapshots/*/ 2>/dev/null
