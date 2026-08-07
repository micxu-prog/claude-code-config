#!/bin/bash
# preflight for the Harshit pyruntime E2E.
set +e
exec 2>&1
echo "--- snapshot CLI ---"; /usr/local/bin/kata-runtime snapshot --help 2>&1 | head -2
echo "--- restore CLI ---";  /usr/local/bin/kata-runtime restore  --help 2>&1 | head -2
echo "--- kata-agent-ctl ---"; ls /kata-containers/src/tools/agent-ctl/target/release/kata-agent-ctl 2>/dev/null || echo "MISSING (cd /kata-containers/src/tools/agent-ctl && cargo build --release)"
echo "--- harshit image pulled via EROFS? (expect 1) ---"
ctr -n k8s.io images ls 2>/dev/null | grep -c "harshitg/python-runtime:1"
echo "(if 0: ctr -n k8s.io images pull --local --snapshotter erofs --platform linux/amd64 docker.io/harshitg/python-runtime:1)"
