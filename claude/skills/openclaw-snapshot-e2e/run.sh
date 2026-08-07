#!/bin/bash
# openclaw-snapshot-e2e RUNNER — snapshot a RUNNING openclaw agent-gateway and
# restore it as a Mode A clone on nodepool0, proving the LIVE process + its
# RAM-overlay workspace state survived (not a relaunch), then port-forward the
# clone's Control UI so you can open it in your own browser.
#
# openclaw (ghcr.io/openclaw/openclaw:2026.3.23) is a headless Node.js gateway,
# Control UI on :18789. NO /execute endpoint (unlike pyruntime) — we drive it via
# the `openclaw` CLI (kubectl exec on the ORIGINAL) and via its HTTP/CLI on the clone.
#
# Usage:  bash run.sh            # full run (leaves the clone UP + prints how to open it)
#         bash run.sh teardown   # tear the clone + pod down
set -uo pipefail
NODE=aks-nodepool1-23826427-vmss000000
HERE="$(cd "$(dirname "$0")" && pwd)"
say() { printf '\n========== %s ==========\n' "$1"; }
nodesh() { scp -q "$1" azlinux-dev:/tmp/_ocse.sh 2>/dev/null || { echo "scp failed (devtunnel down?)"; return 1; }
  ssh -o BatchMode=yes azlinux-dev "kubectl node-shell $NODE -- bash -c \"\$(cat /tmp/_ocse.sh)\" 2>&1" \
    | grep -vE "^spawning|^All commands|^If you|pod .* deleted|terminated|^$"; }
host() { ssh -o BatchMode=yes azlinux-dev "$1"; }
hostscript() { ssh -o BatchMode=yes azlinux-dev "bash -s" < "$1"; }

if [ "${1:-run}" = teardown ]; then
  say "TEARDOWN"; nodesh "$HERE/phase_teardown.sh"
  host 'kubectl delete pod kata-openclaw --ignore-not-found; kubectl delete configmap openclaw-config --ignore-not-found' | tail -2; exit 0
fi

say "0. PREREQ — node + CLIs + openclaw image + bridge"
host 'echo bridge OK; kubectl get nodes 2>&1 | head -2' || { echo "BRIDGE DOWN — restore devtunnel"; exit 1; }
nodesh "$HERE/phase0_preflight.sh"

say "1+2. CREATE + START openclaw (plain Pod, PVC dropped, fresh -> deployed shim)"
host 'cat > ~/kata-openclaw.yaml' < "$HERE/kata-openclaw.yaml"
host 'kubectl delete pod kata-openclaw --ignore-not-found --wait=true 2>&1 | tail -1'
host 'kubectl apply -f ~/kata-openclaw.yaml 2>&1 | tail -2'
host 'kubectl wait --for=condition=Ready pod/kata-openclaw --timeout=120s 2>&1 | tail -1'
host 'kubectl get pod kata-openclaw -o wide 2>&1 | tail -2'

say "A. WARM to a snapshot-worthy state + capture the survival ANCHORS (PID/start + marker)"
hostscript "$HERE/phaseA_warm.sh"

say "B. SNAPSHOT the running openclaw via the shipped CLI"
nodesh "$HERE/phaseB_snapshot.sh"

say "C. RESTORE a Mode A clone via the shipped CLI"
nodesh "$HERE/phaseC_restore.sh"

say "D. PROVE the LIVE app survived: same PID+start-time, marker file present"
nodesh "$HERE/phaseD_prove.sh"

say "E. (teaching beat) an agent turn on the clone hits the no-egress wall"
nodesh "$HERE/phaseE_noegress.sh"

say "F. OPEN IT YOURSELF — port-forward the clone Control UI to your browser"
nodesh "$HERE/phaseF_browser_info.sh"
cat "$HERE/HOW_TO_OPEN.md"

say "DONE — clone is UP. Run 'bash run.sh teardown' when finished demoing."
