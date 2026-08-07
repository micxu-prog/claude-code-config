#!/bin/bash
# harshit-snapshot-e2e RUNNER — full snapshot+restore proof on nodepool0 using
# Harshit's FastAPI image (docker.io/harshitg/python-runtime:1, /execute endpoint).
# Proves FILESYSTEM-level COW: files written before snapshot survive into the clone,
# clone-only files stay invisible to the original. Plus dup-IP + no-egress networking
# truth captured from inside the guest. Self-contained: own pod, full teardown.
#
# Usage:  bash run.sh            # full run
#         bash run.sh teardown   # clean up a prior run
set -uo pipefail
NODE=aks-nodepool1-23826427-vmss000000
HERE="$(cd "$(dirname "$0")" && pwd)"
say() { printf '\n========== %s ==========\n' "$1"; }
nodesh() { scp -q "$1" azlinux-dev:/tmp/_hse.sh 2>/dev/null || { echo "scp failed (devtunnel down?)"; return 1; }
  ssh -o BatchMode=yes azlinux-dev "kubectl node-shell $NODE -- bash -c \"\$(cat /tmp/_hse.sh)\" 2>&1" \
    | grep -vE "^spawning|^All commands|^If you|pod .* deleted|terminated|^$"; }
host() { ssh -o BatchMode=yes azlinux-dev "$1"; }

if [ "${1:-run}" = teardown ]; then
  say "TEARDOWN"; nodesh "$HERE/phase_teardown.sh"
  host 'kubectl delete pod kata-pyruntime --ignore-not-found' | tail -1; exit 0
fi

say "0. PREREQ — node + CLIs + Harshit image + bridge"
host 'echo bridge OK; kubectl get nodes 2>&1 | head -2' || { echo "BRIDGE DOWN — restore devtunnel"; exit 1; }
nodesh "$HERE/phase0_preflight.sh"

say "1+2. CREATE + START the pyruntime pod (fresh -> deployed shim)"
host 'cat > ~/kata-pyruntime.yaml' < "$HERE/kata-pyruntime.yaml"
host 'kubectl delete pod kata-pyruntime --ignore-not-found --wait=true 2>&1 | tail -1'
host 'kubectl apply -f ~/kata-pyruntime.yaml 2>&1 | tail -1'
host 'kubectl wait --for=condition=Ready pod/kata-pyruntime --timeout=90s 2>&1 | tail -1'
host 'kubectl get pod kata-pyruntime -o wide 2>&1 | tail -2'

say "A. in-guest filesystem model + WRITE before-snapshot proof files (/app + /tmp)"
host "bash -s" < "$HERE/phaseA_fs_and_write.sh"

say "B. snapshot via CLI (default + --name + coexistence)"
nodesh "$HERE/phaseB_snapshot.sh"

say "C+D. restore clone via CLI, then PROVE /app + /tmp survived"
nodesh "$HERE/phaseCD_restore_and_survive.sh"

say "E. COW isolation (clone-only file invisible to original) + route table + negatives"
nodesh "$HERE/phaseE_isolation_route_negatives.sh"
say "E (original-side isolation check)"
host "bash -s" < "$HERE/phaseE_original_check.sh"

say "TEARDOWN — restore kill + delete snapshots + delete pod"
nodesh "$HERE/phase_teardown.sh"
host 'kubectl delete pod kata-pyruntime --ignore-not-found' | tail -1
say "DONE — Harshit pyruntime E2E complete"
