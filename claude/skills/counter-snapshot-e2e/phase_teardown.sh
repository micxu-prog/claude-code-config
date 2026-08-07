#!/bin/bash
# teardown: kill the counter clone via the shipped verb, clean its snapshot.
set +e
exec 2>&1
echo "--- restore kill counter-clone ---"
/usr/local/bin/kata-runtime restore kill counter-clone 2>&1 | head -4
echo "--- delete the snapshot this run made ---"
SBID=$(crictl pods --name kata-counter -q 2>/dev/null | head -1)
[ -n "$SBID" ] && /usr/local/bin/kata-runtime snapshot delete --sandbox-id "$SBID" 2>&1 | head -2
echo "--- verify clone gone ---"
ip link show tap2 2>/dev/null || echo "tap gone"
ls -d /tmp/counter-clone 2>/dev/null || echo "/tmp/counter-clone gone"
ps -ef | grep -E "cloud-hypervisor.*counter-clone" | grep -v grep | head || echo "no clone CLH (good)"
