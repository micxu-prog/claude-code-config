#!/bin/bash
# counter-snapshot-e2e RUNNER — drives the full snapshot+restore COW proof on
# nodepool0 using the inline-python counter pod. Run from the admin VM (it shells
# into the node via kubectl node-shell). Self-contained: creates its own pod,
# proves COW (counter survives + diverges), tears everything down.
#
# Usage:  bash run.sh            # full run (setup -> snapshot -> restore -> proof -> teardown)
#         bash run.sh teardown   # just clean up a prior run
set -uo pipefail
NODE=aks-nodepool1-23826427-vmss000000
HERE="$(cd "$(dirname "$0")" && pwd)"

say() { printf '\n========== %s ==========\n' "$1"; }

nodesh() {  # run a staged script on the node in one persistent session
  local script="$1"
  scp -q "$script" azlinux-dev:/tmp/_cse.sh 2>/dev/null || { echo "scp failed (devtunnel down?)"; return 1; }
  ssh -o BatchMode=yes azlinux-dev "kubectl node-shell $NODE -- bash -c \"\$(cat /tmp/_cse.sh)\" 2>&1" \
    | grep -vE "^spawning|^All commands|^If you|pod .* deleted|terminated|^$"
}

host() { ssh -o BatchMode=yes azlinux-dev "$1"; }

if [ "${1:-run}" = teardown ]; then
  say "TEARDOWN"
  nodesh "$HERE/phase_teardown.sh"
  host 'kubectl delete pod kata-counter --ignore-not-found' | tail -1
  exit 0
fi

say "0. PREREQ — confirm node + CLIs + bridge"
host 'echo bridge OK; kubectl get nodes 2>&1 | head -2' || { echo "BRIDGE DOWN — restore devtunnel"; exit 1; }
nodesh "$HERE/phase0_preflight.sh"

say "1+2. CREATE + START the counter pod (fresh, so it spawns the deployed shim)"
host 'cat > ~/kata-counter.yaml' < "$HERE/kata-counter.yaml"
host 'kubectl delete pod kata-counter --ignore-not-found --wait=true 2>&1 | tail -1'
host 'kubectl apply -f ~/kata-counter.yaml 2>&1 | tail -1'
host 'kubectl wait --for=condition=Ready pod/kata-counter --timeout=90s 2>&1 | tail -1'
host 'kubectl get pod kata-counter -o wide 2>&1 | tail -2'

say "3. BUMP counter to 5 (in-RAM state, the only proof of survival)"
host 'for i in 1 2 3 4 5; do kubectl exec kata-counter -- python -c "import urllib.request; print(urllib.request.urlopen(urllib.request.Request(\"http://127.0.0.1:9999\",method=\"POST\")).read().decode(),end=\"\")"; done; echo'

say "4-9. SNAPSHOT via CLI -> RESTORE clone -> PROVE counter survived + COW divergence"
nodesh "$HERE/phase_run.sh"

say "11. ORIGINAL pod unaffected (COW) — from host"
host 'echo -n "[original]: "; kubectl exec kata-counter -- python -c "import urllib.request; print(urllib.request.urlopen(\"http://127.0.0.1:9999\").read().decode(),end=\"\")"; echo'

say "12. TEARDOWN"
nodesh "$HERE/phase_teardown.sh"
host 'kubectl delete pod kata-counter --ignore-not-found' | tail -1
say "DONE — counter E2E complete"
