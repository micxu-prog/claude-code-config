---
name: harshit-snapshot-e2e
description: "Run the end-to-end Kata Containers snapshot+restore proof using HARSHIT'S real FastAPI image (docker.io/harshitg/python-runtime:1, uvicorn on port 8888, /execute endpoint) on AKS nodepool0. Use whenever the user wants to test/prove/demo `kata-runtime snapshot` + `kata-runtime restore` against Harshit's pyruntime/sandbox image, prove FILESYSTEM-level copy-on-write (files written before snapshot survive into the restored clone; clone-only files stay invisible to the original), verify the restore CLI on a realistic workload, or asks to 'run the harshit snapshot test', 'pyruntime e2e', 'prove FS-level COW', 'run the fastapi snapshot demo'. This is the FILESYSTEM/overlay-level proof (vs the sibling skill `counter-snapshot-e2e` which is the heap/RAM-level counter proof). It uses Harshit's /execute endpoint to write+read files inside the guest and to capture real networking state (dup-IP, no-egress). Self-contained: creates its own kata-pyruntime pod, runs all proof types + negative/edge cases, tears everything down. Requires the Windows->azlinux-dev devtunnel up. Do NOT use for the inline counter app (use counter-snapshot-e2e), for building/deploying kata-runtime, or off-node."
---

# harshit-snapshot-e2e — filesystem-level snapshot/restore COW proof (real FastAPI image)

## What this proves

Uses Harshit's actual demo image `docker.io/harshitg/python-runtime:1` — a FastAPI
app served by uvicorn on **:8888** with an `/execute` endpoint that runs shell
commands inside the guest (plus `/upload`, `/download`, `/list`, `/exists`). Because
the app is a real workload that writes files (not a number in RAM), the proof is at
the **filesystem level**:

1. write `before-app.txt` (to `/app`) and `before-tmp.txt` (to `/tmp`) BEFORE snapshot
2. snapshot via `kata-runtime snapshot --sandbox-id <sbid>`
3. restore a side-by-side clone via `kata-runtime restore --from <sbid>`
4. on the clone, BOTH files are present -> **filesystem state survived the snapshot**
5. write `clone-only.txt` on the clone -> the **original pod never sees it** -> COW isolation

The sibling skill `counter-snapshot-e2e` proves the SAME mechanism at the heap/RAM
level with a counter int. Together: heap-level + FS-level coverage.

### Key empirical finding (settled live by this test)

`/app` is image content on a **read-only erofs lower layer**, but the rootfs is an
**overlay** (erofs RO lower + RAM-backed upper at `/run/kata-containers/<id>/fs`).
A write to `/app/foo.txt` lands in the RAM-backed overlay upper, so it IS captured in
the memory snapshot and **survives** — proven, not assumed. There is NO writable
non-RAM mount, so every writable path (`/app`, `/tmp`, anything on `/`) is RAM-backed.
(The ONLY exception, not exercised here, is a separately-attached writable disk/PVC
volume — that is NOT captured by a RAM snapshot; see CLAUDE.md §15 GAP5.)

## How to run it

ACTIVE RUNNER. Executes on nodepool0 (`aks-nodepool1-23826427-vmss000000`) via the
admin VM (`azlinux-dev`) over the devtunnel. From the Windows host:

```
bash ~/.claude/skills/harshit-snapshot-e2e/run.sh            # full run
bash ~/.claude/skills/harshit-snapshot-e2e/run.sh teardown   # clean up only
```

(As the agent: `scp` the skill's scripts to the VM and drive node-side ones via
`kubectl node-shell ... -- bash -c "$(cat /tmp/...)"`, and host-side ones via
`kubectl exec`. Staged-script transport only, never base64.)

Self-contained: preflight -> create+start pyruntime pod -> write before-files ->
snapshot (default+named) -> restore -> prove survival -> COW isolation -> route/egress
-> negatives -> teardown (`restore kill` + delete pod + delete the 2 test snapshots).

### CRITICAL gotcha — /execute parses argv-style (no shell)

Harshit's `/execute` runs the command via `shlex.split` (NOT `sh -c`). So `>`, `&&`,
`|` are LITERAL unless you wrap the whole thing: `sh -c "echo x > /f; cat /f"`. Every
bundled script that uses shell features already wraps in `sh -c`. Also: the image is
minimal — **no `ip`/`iproute2`/`curl` inside the guest**. Use `kata-agent-ctl`
(ListInterfaces/ListRoutes over hybrid-vsock) for in-guest network state, and `python3`
(present) for any in-guest socket test.

## Bundled files

- `run.sh` — orchestrator (full run / teardown).
- `kata-pyruntime.yaml` — the pod (Harshit's image, port 8888, NO annotations needed).
- `phase0_preflight.sh` — CLIs + agent-ctl + image present.
- `phaseA_fs_and_write.sh` (host) — overlay fs model + write the before-files via /execute.
- `phaseB_snapshot.sh` (node) — snapshot default + --name + coexistence.
- `phaseCD_restore_and_survive.sh` (node) — restore + the /app+/tmp survival proof + dual-IP.
- `phaseE_isolation_route_negatives.sh` (node) — clone-only write + route table + 3 negatives.
- `phaseE_original_check.sh` (host) — the original pod must NOT see clone-only files.
- `phase_teardown.sh` (node) — `restore kill` + delete the 2 test snapshots.

## Expected output (VERIFIED 2026-06-18 — real captured values, not predicted)

Phase A — overlay fs model:
```
overlay on / type overlay (rw,relatime,lowerdir=/run/kata-containers/virtual-volumes/...,
   upperdir=/run/kata-containers/<id>/fs,workdir=.../work,uuid=on)
df: /, /app, /tmp  ->  all "overlay  overlay  398M"
(any non-RAM writable mount: NONE)
```

Phase B — snapshot:
```
/run/vc/vm/snapshots/<sbid>
snapshot-rc=0
config.json (8190)  kata-snapshot.json (132)  memory-ranges (2147483648)  persist.json (11640)  state.json (149512)
--name pyrt-named -> /run/vc/vm/snapshots/pyrt-named   (coexists with <sbid> dir)
```

Phase C — restore (clone.json, real auto-allocated values):
```
clone pyrt-clone up
{ "id":"pyrt-clone", "tap":"kat0", "host_ip":"192.168.240.2/24",
  "guest_ip":"192.168.240.1/24", "unit":"clh-pyrt-clone",
  "vsock":"/tmp/pyrt-clone/clone-vm.vsock", "sock":"/tmp/pyrt-clone/clh.sock",
  "source":"/run/vc/vm/snapshots/<sbid>" }
```

Phase D — THE HEADLINE (both files survived):
```
{"stdout":"APP:\nhello-from-original-APP\nTMP:\nhello-from-original-TMP\n","exit_code":0}
```
D2 dual-IP after auto re-IP: eth0 has BOTH `10.244.0.53` (original) and `192.168.240.1` (new).

Phase E1 — clone writes clone-only.txt to /app + /tmp (exit 0).
Phase E2 — clone route table (NO default route -> egress black-holed):
```
dest: "10.244.0.0/16" ; dest: "192.168.240.0/24" ; dest: "fe80::/64"     (no 0.0.0.0)
```
Phase E (original-side isolation — THE SECOND HEADLINE):
```
APP_CLONE_ONLY:  ls: cannot access '/app/clone-only.txt': No such file or directory
TMP_CLONE_ONLY:  ls: cannot access '/tmp/clone-only.txt': No such file or directory
ORIG_BEFORE_STILL_THERE: hello-from-original-APP
```

Negatives (real error text):
```
NEG1 collision: clone "pyrt-clone" already exists; run `kata-runtime restore kill pyrt-clone` first
NEG2 bad --from: snapshot not found: /run/vc/vm/snapshots/does-not-exist-xyz
NEG3 bogus sbid: Error ... fails to stat /run/vc/sbs/bogus-sbid-123/shim-monitor.sock ...
```

Teardown:
```
cleaned pyrt-clone   (CLH gone, kat0 gone, /tmp/pyrt-clone gone)
+ delete pyrt-named + <sbid> snapshots ; pre-existing snapshots preserved
```

PASS = both before-files survive on the clone; original never sees clone-only files
but keeps its own before-app.txt; all 3 negatives refuse cleanly; teardown leaves
the node as found.

## Known facts / caveats baked into this test

- **The restore CLI auto-allocates its own networking** (tap `kat0`, host
  `192.168.240.2/24`, guest `192.168.240.1/24`) and auto-runs `UpdateInterface` — you
  do NOT manually set tap2/192.168.249.x as in the old manual flow. clone.json records
  the actual values; always read the guest IP from there.
- **Clone MAC is randomized** by the CLI (e.g. `1A:B1:13:7E:17:58`), different from the
  source pod's MAC — so no MAC collision even though both run.
- **Clone is INBOUND-ONLY**: eth0 ends dual-IP (stale `10.244.x` + new `192.168.x`),
  no default route -> egress black-holed. Full captured networking truth (before/after
  ListInterfaces+ListRoutes, exact routes/MACs): `nodepool0-restore-networking-reference.md`.
- **Do NOT `snapshot delete` the source while the clone is live** — the clone holds the
  source `memory-ranges` MAP_PRIVATE (H4). Teardown deletes snapshots only AFTER
  `restore kill`.
- The restore CLI also prints a security warning: the clone shares the original's RNG
  state + wall clock — unsafe for secret-minting / time-dependent workloads (RNG reseed
  + clock sync are future work; security-review §13).
- No containerd restart / no pod annotations needed (per-runtime erofs snapshotter +
  default_vcpus already in the node config; shim exec'd fresh per pod).
