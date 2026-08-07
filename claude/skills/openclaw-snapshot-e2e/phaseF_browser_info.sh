#!/bin/bash
# Phase F (node): set up + describe how to reach the clone's Control UI from a browser.
# The clone IP (192.168.240.1) is ONLY routable on the node. We start a socat bridge
# from a node-local port -> the clone, so an outer kubectl-port-forward/devtunnel hop
# can reach it. Prints the token URL openclaw itself requires.
set +e
exec 2>&1
GIP=$(grep -oE '"guest_ip": "[0-9.]+' /tmp/openclaw-clone/clone.json 2>/dev/null | grep -oE '[0-9.]+$')
PORT=28789
echo "clone IP=$GIP"
echo ""
echo "######## F1. start a socat bridge on the node: 0.0.0.0:$PORT -> $GIP:18789 ########"
# kill any prior bridge, start detached, scope-escaped so it outlives the node-shell
pkill -f "socat.*:$PORT" 2>/dev/null
systemd-run --unit=openclaw-pf --scope --slice=- --collect --quiet \
  socat TCP-LISTEN:$PORT,fork,reuseaddr TCP:$GIP:18789 </dev/null >/tmp/openclaw-pf.log 2>&1 &
disown
sleep 2
echo "--- bridge up? local curl through it ---"
curl -sS -m6 -o /dev/null -w "via-socat HTTP=%{http_code}\n" "http://127.0.0.1:$PORT/" 2>&1 | head -1
echo ""
echo "######## F2. the token the openclaw gateway requires ########"
echo "OPENCLAW_GATEWAY_TOKEN = dummy-token-for-sandbox"
echo "Dashboard fragment URL:  http://localhost:18789/#token=dummy-token-for-sandbox"
echo ""
echo "Bridge is listening on the NODE at 0.0.0.0:$PORT -> clone $GIP:18789."
echo "See HOW_TO_OPEN.md (printed by run.sh) for the outer hop from your laptop."
