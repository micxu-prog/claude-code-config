#!/bin/bash
# preflight: confirm both CLIs + agent-ctl + python image are deployed on the node.
set +e
exec 2>&1
echo "--- snapshot CLI present? ---"
/usr/local/bin/kata-runtime snapshot --help 2>&1 | head -3
echo "--- restore CLI present? ---"
/usr/local/bin/kata-runtime restore --help 2>&1 | head -3
echo "--- kata-agent-ctl built? ---"
ls /kata-containers/src/tools/agent-ctl/target/release/kata-agent-ctl 2>/dev/null || echo "MISSING agent-ctl (build: cd /kata-containers/src/tools/agent-ctl && cargo build --release)"
echo "--- python:3.12-slim pulled via EROFS? ---"
ctr -n k8s.io images ls 2>/dev/null | grep -c "library/python:3.12-slim" || echo 0
echo "(if 0: ctr -n k8s.io images pull --local --snapshotter erofs --platform linux/amd64 docker.io/library/python:3.12-slim)"
