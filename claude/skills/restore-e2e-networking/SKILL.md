---
name: restore-e2e-networking
description: Live end-to-end networking proof for the AKS Kata snapshot/restore annotation feature. Brings up a web-server source pod, snapshots it, restores a clone via the io.katacontainers.restore-from annotation, and rigorously proves the RESTORE pod is a real, isolated, fully-networked pod — INGRESS (curl from outside, both source+clone simultaneously, pod->pod) and EGRESS (clone -> pod, cluster DNS, kube-dns service, internet), plus identity-isolation proofs (different guest MAC, zero vmtap0, source snapshot md5 unchanged). Use this whenever validating that a restored Kata pod networks like a genuine standalone pod, e.g. after a new runtime/shim/agent build lands on nodepool0. NOT a perf tool (timing is a separate round) and NOT for the final-target port work.
---

# restore-e2e-networking

Prove a Kata snapshot-restored pod is a **real, isolated, fully-networked Kubernetes pod** —
not just that it boots. The headline test: run the **source and the restored clone at the same
time** and curl BOTH from outside, confirming different IP/MAC and independent state, then prove
the clone does full ingress AND egress like any normal pod.

This skill encodes the exact, proven-on-nodepool0 command sequence (validated 2026-07-21). It is
**read-mostly + apply-a-couple-pods**: it never reimages/reboots the node, never touches CLH
binaries, never edits the PR. It only creates/deletes test pods + one snapshot.

## When to use
- After a new kata runtime/shim/agent build is deployed to nodepool0 and you need to confirm the
  restore path still networks correctly (regression gate).
- To demonstrate the annotation-restore feature end to end (source alive + clone side-by-side).
- Before a perf round (correctness must pass first).

## Hard guardrails (inherit from project CLAUDE.md — do not violate)
- **NEVER** reimage/reboot/deallocate/drain/`vmss`-cycle `aks-nodepool1-23826427-vmss000000` or any node.
- Node commands go through `kubectl node-shell <node> -- ...` (the `kubectl-node_shell` plugin is installed).
- **NEVER** base64/encode scripts across the Windows->Linux bridge. Write a local `.sh`, `scp` it, run it.
  For node-shell: `ssh azlinux-dev "... kubectl node-shell <node> -- bash -c \"\$(cat /tmp/x.sh)\""`.
- `azl`/plain ssh both work; the node kubeconfig is NOT auto-loaded in a bare ssh shell —
  always `export KUBECONFIG=/home/michaelx/.kube/config` first (context `testabc123`).
- Perf/timing is a SEPARATE round; this skill is correctness only.

## Environment facts (verified 2026-07-21; re-verify in Step 0)
- Node: `aks-nodepool1-23826427-vmss000000`. Context: `testabc123`. RuntimeClass: `kata` (handler `kata`).
- Runtime: `/usr/local/bin/kata-runtime` (has `snapshot` + `restore` subcommands). CLH `v51.1`, kernel `6.6.135.mshv2+`.
- Snapshot artifacts dir convention: `/run/vc/vm/snapshots/<name>` (annotation `restore-from: <name>`
  resolves here). Sandbox runtime dirs: `/run/vc/sbs/<id>`, VM dirs: `/run/vc/vm/<uuid>`.
- Manifests (in `/home/michaelx/`): `kata-webcounter.yaml` (source web server), `webdemo-clone.yaml`
  (clone, annotation `restore-from: webdemo`). Both pin `nodeSelector` to nodepool0.
- The web server: python:3.12-slim, an HTTP server on **:9999** returning `counter=<n>` where n
  increments once/sec in a daemon thread. The counter is the snapshot-freshness proof: a clone
  restored from a snapshot taken at counter=126 resumes near 126 and diverges from the live source.

## CLI reference (deployed binary; confirm with `--help` in Step 0)
```
kata-runtime snapshot create --sandbox-id <sbid> --path <dir>   # freeze+save a running sandbox (non-destructive)
kata-runtime snapshot delete --path <dir>                       # remove a snapshot dir
kata-runtime restore --path <dir> [--name <id>]                 # restore standalone (CLI; not the annotation path)
kata-runtime restore kill <id>                                  # stop a CLI-restored sandbox
```
Map a k8s pod to its sandbox id: `crictl pods --name <pod> -q` (run on node).

---

## PROCEDURE

### Step 0 — verify the node is live and the runtime is deployed (never assume)
Run on node via node-shell. Confirm: `kata-runtime` exists + lists `snapshot`/`restore`; CLH version;
kernel `mshv2`; **node uptime is DAYS (NOT freshly reimaged)**; RuntimeClass `kata` present.
```bash
# on node:
ls -la /usr/local/bin/kata-runtime && /usr/local/bin/kata-runtime --version
/usr/local/bin/kata-runtime snapshot --help; /usr/local/bin/kata-runtime restore --help
/usr/bin/cloud-hypervisor --version; uname -r; uptime
# from admin VM:
kubectl get runtimeclass kata -o jsonpath='{.handler}'
```
If uptime is minutes, AKS auto-reimaged the node (custom kernel/runtime may be gone) — STOP and tell the user.

### Step 1 — bring up the SOURCE web-server pod, prove baseline ingress
```bash
kubectl apply -f /home/michaelx/kata-webcounter.yaml
kubectl wait --for=condition=Ready pod/kata-webcounter --timeout=90s
kubectl get pod kata-webcounter -o wide            # record IP_src
# baseline ingress from node host netns (counter must increment):
kubectl node-shell <node> -- bash -c 'for i in 1 2 3; do curl -s -m5 -w " [http:%{http_code}]\n" http://IP_src:9999; sleep 1; done'
```
PASS: HTTP 200, `counter=` increasing.

### Step 2 — snapshot the running source into `webdemo`
Delete any STALE `webdemo` first (a leftover snapshot restores stale memory). Record the source
counter value at snapshot time, and md5 the artifacts (to prove restore doesn't mutate the source).
```bash
SB=$(crictl pods --name kata-webcounter -q)        # on node
kata-runtime snapshot delete --path /run/vc/vm/snapshots/webdemo; rm -rf /run/vc/vm/snapshots/webdemo
kata-runtime snapshot create --sandbox-id "$SB" --path /run/vc/vm/snapshots/webdemo
ls -la /run/vc/vm/snapshots/webdemo                # config.json state.json persist.json kata-snapshot.json memory-ranges(=VM mem, e.g. 2GB)
md5sum /run/vc/vm/snapshots/webdemo/*              # RECORD memory-ranges md5
crictl pods --name kata-webcounter                 # source STILL Ready (snapshot is freeze+resume)
```
PASS: all 5 artifacts present, `memory-ranges` == VM memory size, source still Running.

### Step 3 — restore the CLONE alongside the live source
Record `IP_src` counter just before, then apply the clone (annotation `restore-from: webdemo`).
```bash
# reference: curl IP_src once, note counter
kubectl apply -f /home/michaelx/webdemo-clone.yaml
kubectl wait --for=condition=Ready pod/kata-webcounter-clone --timeout=120s
kubectl get pods -o wide | grep webcounter         # record IP_clone; MUST differ from IP_src
```
PASS: both Running, `IP_clone != IP_src`.

### Step 4 — INGRESS: curl BOTH simultaneously (the headline proof)
```bash
kubectl node-shell <node> -- bash -c '
for r in 1 2 3; do echo "--- round $r ---"
  ( curl -s -m5 -w " [src http:%{http_code}]" http://IP_src:9999 & \
    curl -s -m5 -w " [clone http:%{http_code}]" http://IP_clone:9999 & wait ); echo; sleep 2
done'
```
PASS: BOTH return 200 every round; counters are INDEPENDENT (clone tracks the frozen value, source
runs ahead). This is the isolation headline — two live pods, two IPs, two counters.

Also pod->pod ingress with a throwaway probe:
```bash
kubectl run netprobe --image=busybox:1.36 --restart=Never \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"<node>"}}}' --command -- sleep 3600
kubectl wait --for=condition=Ready pod/netprobe --timeout=60s
kubectl exec netprobe -- wget -qO- -T5 http://IP_clone:9999      # 200 counter=
kubectl exec netprobe -- wget -qO- -T5 http://IP_src:9999        # 200 counter=
kubectl delete pod netprobe --grace-period=5
```

### Step 5 — EGRESS from the CLONE (pod, DNS, service, internet)
python:3.12-slim has no curl; use python one-liners inside the clone.
```bash
# E1 clone -> source pod (reverse pod->pod)
kubectl exec kata-webcounter-clone -- python -c "import urllib.request;print(urllib.request.urlopen('http://IP_src:9999',timeout=5).read().decode().strip())"
# E2 clone -> cluster DNS (kube API service)
kubectl exec kata-webcounter-clone -- python -c "import socket;print(socket.gethostbyname('kubernetes.default.svc.cluster.local'))"   # -> 10.0.0.1
# E3 clone -> kube-dns service
kubectl exec kata-webcounter-clone -- python -c "import socket;print(socket.gethostbyname('kube-dns.kube-system.svc.cluster.local'))" # -> 10.0.0.10
# E4 clone -> internet (TCP connect)
kubectl exec kata-webcounter-clone -- python -c "import socket;s=socket.create_connection(('mcr.microsoft.com',443),timeout=8);print('OK',s.getpeername());s.close()"
```
PASS: each returns the expected reachability. If egress is intentionally restricted in the cluster,
mark E4 N/A explicitly (do not silently skip).

### Step 6 — IDENTITY ISOLATION proofs (why it's a distinct pod, not an alias)
```bash
# different guest MAC (source vs clone eth0):
kubectl exec kata-webcounter       -- python -c "print(open('/sys/class/net/eth0/address').read().strip())"
kubectl exec kata-webcounter-clone -- python -c "print(open('/sys/class/net/eth0/address').read().strip())"
# zero vmtap0 on the node (CLH must use the real kata taps, never the vmtap0 fallback):
kubectl node-shell <node> -- bash -c 'ip link | grep -c vmtap0'      # -> 0
# source snapshot memory-ranges md5 UNCHANGED vs Step 2 (COW / MAP_PRIVATE, source not mutated):
kubectl node-shell <node> -- bash -c 'md5sum /run/vc/vm/snapshots/webdemo/memory-ranges'
```
PASS: MACs DIFFER; vmtap0 count == 0; md5 identical to Step 2.

### Step 7 — teardown (GHOST-SAFE ordering — do NOT `--force`, do NOT delete the snapshot early)

**Why this ordering matters:** `clh.go terminate()` shuts CLH down with a COOPERATIVE `ShutdownVMM`
API call and has NO SIGKILL fallback (it only `WaitLocalProcess` with `Signal(0)`, a liveness check).
A restored clone often has a dead agent/socket, so the cooperative shutdown can silently fail and
leave CLH running = an orphan holding a MAP_PRIVATE `memory-ranges` mapping. If you then `--force`
(SIGKILLs the shim before it can clean up) or delete the snapshot while a clone still maps it, the
2 GB `memory-ranges` becomes a deleted-but-mmap'd GHOST that fills `/run` tmpfs and wedges the node
(invisible to `du` and `/proc/*/fd`; only `/proc/*/maps` sees it). So: graceful delete → wait → verify
maps → reap orphan → and only THEN touch the snapshot.

```bash
# 1. GRACEFUL delete each clone — NEVER --force (force is the #1 ghost cause). Kick it off in the
#    background: on a dead-agent restored clone the shim's terminate() can block INDEFINITELY (the
#    cooperative ShutdownVMM has no SIGKILL fallback), so the pod stays Terminating for many minutes
#    / forever. Do NOT sit and wait on it — go straight to the reap, which is what actually unsticks it.
kubectl delete pod kata-webcounter-clone --grace-period=30 &

# 2. REAP the orphaned CLH (THE unstick step for restore clones — not just a safety net). Killing the
#    orphaned cloud-hypervisor lets the shim/kubelet finish and the pod terminate. Any hit here is a
#    ghost holding a deleted memory-ranges mapping that would otherwise leak into /run tmpfs.
kubectl node-shell <node> -- bash -c 'for p in $(pgrep -f cloud-hypervisor); do grep -q "memory-ranges.*deleted" /proc/$p/maps 2>/dev/null && { vd=$(tr "\0" "\n" < /proc/$p/cmdline | grep -oE "/run/vc/vm/[0-9a-f-]+" | head -1); echo "reap pid=$p vmdir=$vd"; kill -9 $p; sleep 1; rm -rf $vd; }; done; echo done'

# 3. Confirm the clone object is gone (after the reap it should clear within seconds).
kubectl wait --for=delete pod/kata-webcounter-clone --timeout=60s
#    If it STILL will not go (BUG-B not yet fixed on this node), force it as a last resort — but you
#    already reaped the CLH in step 2, so no ghost is created:
#    kubectl delete pod kata-webcounter-clone --grace-period=0 --force

# 4. ONLY NOW delete the source pod and the snapshot (never while a clone still maps memory-ranges).
kubectl delete pod kata-webcounter --grace-period=30
kubectl node-shell <node> -- /usr/local/bin/kata-runtime snapshot delete --path /run/vc/vm/snapshots/webdemo

# 5. Final safety net — confirm /run is healthy and no deleted-memory-ranges maps linger.
kubectl node-shell <node> -- bash -c "df -h /run | tail -1; grep -l 'memory-ranges.*deleted' /proc/*/maps 2>/dev/null | wc -l"
```

**KNOWN LIMITATIONS on restored clones (agent not fully rehydrated — networking is fine, lifecycle is not):**
- `kubectl exec` into a restored clone can HANG (agent exec RPC on the restored VM). Use host-side ARP
  for the MAC (`kubectl node-shell <node> -- ip neigh show | grep <clone_ip>`) instead of `exec ... cat
  /sys/class/net/eth0/address`.
- **Graceful delete of a restored clone can hang for MINUTES or effectively forever** (measured 5+ min,
  and one run never completed in 10 min) — the pod sits in `Terminating` because `clh.go terminate()`'s
  cooperative `ShutdownVMM` has no SIGKILL fallback, so a dead-agent clone's CLH is never killed and the
  shim/kubelet never get a clean stop. The **reap in step 2 is the fix that unsticks it** (killing the
  orphaned CLH lets termination complete). The permanent fix is the kata BUG-B hardening: a defensive
  `SIGKILL` in `terminate()` after cooperative shutdown fails/times out (proposed for PR #4).

## PASS/FAIL summary table (fill each run)
| Check | Expected | Got |
|---|---|---|
| source ingress baseline | 200, counter++ | |
| snapshot artifacts | 5 files, memory-ranges==VM mem | |
| clone IP != source IP | different | |
| BOTH curl simultaneously | both 200, independent counters | |
| pod->pod ingress (probe) | 200 both | |
| egress -> source pod | 200 | |
| egress -> cluster DNS | 10.0.0.1 | |
| egress -> kube-dns | 10.0.0.10 | |
| egress -> internet | connect OK / N/A | |
| guest MAC differs | src != clone | |
| zero vmtap0 | 0 | |
| snapshot md5 unchanged | == Step 2 | |

## Reference values from the 2026-07-21 PASS run (sanity anchors, not literals to expect)
Source `10.244.0.252` MAC `66:be:62:88:2d:52`; clone `10.244.0.48` MAC `ee:48:a3:8b:be:98`; snapshot
taken at counter=126; simultaneous curl src 155/157/159 vs clone 131/133/135; egress all green;
0 vmtap0; memory-ranges md5 `52609c98…` unchanged. Deployed `kata-runtime 3.27.0` commit `30f3eb09`.

---

## FUTURE TODO — make this skill more sophisticated (edge cases + deeper networking)
These are deliberately deferred; the current skill is the "happy path" isolation proof. Each bullet
is a concrete next increment.

### Deeper networking correctness
- [ ] **Bidirectional throughput + latency**, not just reachability: run `iperf3` client in the clone
      against an `iperf3` server pod (there are `tests/metrics/network/iperf3_kubernetes/` manifests in
      the repo) — TCP + UDP, ingress and egress direction, record Mbps + jitter. Compare clone vs a
      cold-booted (non-restored) kata pod to show net_fds adds no throughput penalty.
- [ ] **NetworkPolicy enforcement on the restored pod:** apply an allow/deny `NetworkPolicy`
      selecting the clone, confirm the restored pod's traffic is actually filtered (proves the clone
      is a first-class CNI citizen, not bypassing policy via a ghost interface).
- [ ] **Kubernetes Service front-end:** put the clone behind a `ClusterIP` (and `NodePort`) Service,
      curl via the service VIP + via kube-proxy from another pod — proves the restored pod IP is
      registered in Endpoints/EndpointSlices and load-balances correctly.
- [ ] **Long-lived + reconnect:** hold an open TCP connection (e.g. `nc`/websocket) to the clone
      across the fence-activate window; verify no reset. Also test a connection OPENED before restore
      completes (race the readiness).
- [ ] **Concurrent-connection storm:** hammer the clone with N parallel curls (`ab`/`hey`/`wrk`) to
      confirm the single guest NIC + tap handle concurrency, not just a single sequential request.
- [ ] **MTU / large-payload / fragmentation:** POST a multi-MB body both directions; test with a
      lowered pod MTU to catch tap-redirect MTU mismatches.
- [ ] **IPv6 / dual-stack** (if the cluster is dual-stack): repeat ingress+egress on the v6 address;
      the restore identity-rewrite path handles v6 addrs differently (`update_routes` v6 arm).
- [ ] **ARP / neighbor correctness:** confirm the clone's ARP table + the host's ARP entry for the
      clone resolve to the NEW MAC (ties to the `addARPNeighbors` code path); check for stale ARP from
      the source identity.
- [ ] **Egress source-IP correctness (SNAT):** from the clone, hit an echo service that reports the
      observed source IP — confirm it's the clone's pod IP (or the expected SNAT), not the source
      pod's IP leaking through.

### Edge cases / scale
- [ ] **N>1 clones from one snapshot:** restore 2-3 clones simultaneously from `webdemo`; confirm each
      gets a distinct IP/MAC (per docs: clone N gets tap `kat<N>` + subnet `192.168.<240+N>.x`), all
      serve concurrently, no IP/MAC collision, no cross-talk.
- [ ] **Mode B (kill-original) restore:** snapshot with the `--kill/--stop` original lifecycle, then
      restore as the SAME identity (same IP, no re-IP) — verify the CNI netns/veth survive the kill and
      the restored pod reuses them (the still-unproven Mode B experiment).
- [ ] **Different workloads:** FastAPI (filesystem COW), a stateful app with an open DB socket, a pod
      with multiple containers, a pod with an init container — confirm restore networking for each.
- [ ] **Larger memory snapshots** (8/16 GB) — confirm net_fds + fence timing don't regress with mem size.
- [ ] **Restore onto a DIFFERENT node** than the source (cross-node): does the annotation path find the
      snapshot, and does CNI give a valid IP in the new node's pod CIDR?
- [ ] **Snapshot while under load:** snapshot the source mid-request-storm; confirm the restored clone
      resumes cleanly (no half-open sockets in the frozen memory breaking the NIC).

### Failure-mode / negative testing (the fence + fail-only contract)
- [ ] **Fence correctness:** assert there is NO window where the clone answers on the SOURCE identity
      (tcpdump the tap during restore; the tap-up/no-redirect fence must gate traffic until identity is
      verified). Prove no source-MAC frames escape.
- [ ] **Missing/corrupt snapshot:** apply the annotation with a non-existent / truncated snapshot —
      confirm the restore ABORTS and reaps the VM (fail-only), no orphaned shim/CLH/tap.
- [ ] **Rejected pod shapes:** hooked pods / multi-NIC / projected-SA-token pods — confirm they are
      rejected with a clear error, not silently mis-restored.
- [ ] **vmtap0 regression alarm:** turn "zero vmtap0" into a hard assertion that fails loudly (this is
      the canary for the B1 net_fds-marker-erase bug returning).

### Automation / harness
- [ ] Convert the manual steps into a single idempotent `restore-e2e.sh` that takes `--node`,
      `--snap-name`, `--src-manifest`, `--clone-manifest`, auto-discovers IPs/sandbox-id, runs all
      checks, and emits the PASS/FAIL table as machine-readable output (JSON) for CI-style gating.
- [ ] Auto-generate a fresh clone manifest from the source (so the annotation snapshot name is wired
      automatically instead of hand-editing `SNAPSHOT_NAME`).
- [ ] Capture `journalctl -t kata` around each restore for post-mortem, tagged by iteration.
- [ ] Parameterize the web server to expose `/whoami` (returns hostname + IP + MAC) so identity proofs
      don't need node-shell.

## Related
- Correctness only; the per-layer restore-ms PERF round is separate (see
  `docs/project/restore-final-refactor-docs/E2E-restore-networking-and-perf-plan.md`, PERF DESIGN).
- Mode A vs Mode B, the net_fds 3-layer model, and the guest-identity rewrite rationale live in the
  project CLAUDE.md + `nodepool0-mode-b-design.md`.
