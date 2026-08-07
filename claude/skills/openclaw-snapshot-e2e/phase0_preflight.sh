#!/bin/bash
# preflight for the openclaw e2e.
set +e
exec 2>&1
echo "--- snapshot CLI ---"; /usr/local/bin/kata-runtime snapshot --help 2>&1 | head -2
echo "--- restore CLI ---";  /usr/local/bin/kata-runtime restore  --help 2>&1 | head -2
echo "--- deployed commit (must carry both snapshot+restore) ---"; /usr/local/bin/kata-runtime --version 2>&1 | grep -i commit
echo "--- kata-agent-ctl ---"; ls /kata-containers/src/tools/agent-ctl/target/release/kata-agent-ctl 2>/dev/null || echo "MISSING"
echo "--- openclaw image pulled via EROFS? (expect 1) ---"
ctr -n k8s.io images ls 2>/dev/null | grep -c "openclaw/openclaw:2026.3.23"
echo "(if 0: ctr -n k8s.io images pull --local --snapshotter erofs --platform linux/amd64 ghcr.io/openclaw/openclaw:2026.3.23)"
echo "--- socat for the browser port-forward? ---"; command -v socat 2>/dev/null || echo "no socat (skill falls back to kubectl port-forward on the original; clone needs socat)"
