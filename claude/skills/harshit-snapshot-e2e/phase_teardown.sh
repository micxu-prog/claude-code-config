#!/bin/bash
# Teardown (node): kill the pyrt-clone via the shipped verb, clean test snapshots.
# Leaves any pre-existing snapshots untouched.
set +e
exec 2>&1
echo "--- restore kill pyrt-clone ---"
/usr/local/bin/kata-runtime restore kill pyrt-clone 2>&1 | head -4
echo "--- verify clone gone ---"
ps -ef | grep -E "cloud-hypervisor.*pyrt-clone" | grep -v grep | head || echo "no clone CLH (good)"
ip link show kat0 2>/dev/null || echo "kat0 gone (good)"
ls -d /tmp/pyrt-clone 2>/dev/null || echo "/tmp/pyrt-clone gone (good)"
echo "--- delete the 2 snapshots this run made ---"
/usr/local/bin/kata-runtime snapshot delete --name pyrt-named 2>&1 | head -1
SBID=$(crictl pods --name kata-pyruntime -q 2>/dev/null | head -1)
[ -n "$SBID" ] && /usr/local/bin/kata-runtime snapshot delete --sandbox-id "$SBID" 2>&1 | head -1
echo "--- remaining snapshots (pre-existing only) ---"
ls -d /run/vc/vm/snapshots/*/ 2>/dev/null
