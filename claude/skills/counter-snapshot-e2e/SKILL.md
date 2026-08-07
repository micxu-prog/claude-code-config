---
name: counter-snapshot-e2e
description: "Run the end-to-end Kata Containers snapshot+restore proof using the inline-python COUNTER pod on AKS nodepool0. Use whenever the user wants to test / prove / demo `kata-runtime snapshot` + `kata-runtime restore` with the simple counter app, verify copy-on-write (COW) memory survival, run the 'counter 5->7' demo, smoke-test the snapshot or restore CLI on the node, or asks to 'run the counter snapshot test', 'prove snapshot restore works', 'run the counter e2e'. This is the HEAP/RAM-level proof (a counter int living only in guest RAM): snapshot at counter=5, restore a clone, the clone resumes at 5 and diverges to 7 while the original stays 5. Self-contained: creates its own kata-counter pod and tears everything down. Sibling skill `harshit-snapshot-e2e` does the FILESYSTEM-level proof with Harshit's FastAPI image. Requires the Windows->azlinux-dev devtunnel to be up. Do NOT use for the pyruntime/FastAPI image (use harshit-snapshot-e2e), for building/deploying the kata-runtime binary, or off-node."
---

# counter-snapshot-e2e — heap-level snapshot/restore COW proof

## What this proves

Takes a Kata pod whose entire app is a 12-line inline `http.server` holding **one
integer in RAM** (`counter=N`; GET reads, POST increments), on port 9999. Because
that number lives ONLY in guest memory (no disk, no DB), the only way it survives a
VM freeze is if the snapshot truly captured RAM. The test:

1. snapshot at `counter=5` via `kata-runtime snapshot --sandbox-id <sbid>`
2. restore a side-by-side clone via `kata-runtime restore --from <sbid>`
3. clone resumes at **counter=5 instantly** (inherited the live process + its RAM)
4. POST twice on the clone -> **7**; the **original stays 5** -> copy-on-write divergence

This is the simplest possible proof of memory snapshot + COW. The sibling skill
`harshit-snapshot-e2e` proves the SAME mechanism at the filesystem level on
Harshit's real FastAPI image.

## How to run it

This skill is an ACTIVE RUNNER. It executes on AKS nodepool0
(`aks-nodepool1-23826427-vmss000000`) through the admin VM (`azlinux-dev`) via the
devtunnel bridge. From the Windows host:

```
bash ~/.claude/skills/counter-snapshot-e2e/run.sh            # full run
bash ~/.claude/skills/counter-snapshot-e2e/run.sh teardown   # clean up only
```

(Or, as the agent: `scp` the skill's scripts to the VM and drive them via
`kubectl node-shell ... -- bash -c "$(cat /tmp/...)"` — the same pattern the runner
uses. Prefer the staged-script transport, never base64.)

The runner is self-contained: preflight -> create+start the counter pod (fresh, so
it spawns the deployed shim) -> bump to 5 -> snapshot -> restore -> prove -> teardown
(`restore kill` + delete pod + delete snapshot). It leaves the node as it found it.

## Bundled files

- `run.sh` — the orchestrator (full run / teardown).
- `kata-counter.yaml` — the pod (stock `python:3.12-slim`, inline counter, NO
  annotations needed: erofs snapshotter + default_vcpus are already in the node config).
- `phase0_preflight.sh` — confirms snapshot+restore CLIs, kata-agent-ctl, image present.
- `phase_run.sh` — snapshot -> restore -> the proof, in one node session.
- `phase_teardown.sh` — `restore kill counter-clone` + `snapshot delete`.

## Expected output (VERIFIED — these are real captured values, not predicted)

STEP 3 bump:
```
counter=1
counter=2
counter=3
counter=4
counter=5
```

STEP 6 snapshot:
```
/run/vc/vm/snapshots/<sbid>
snapshot-rc=0
-rw------- 1 root root       5136 config.json
-rw------- 1 root root        132 kata-snapshot.json
-rw------- 1 root root 2147483648 memory-ranges
-rw------- 1 root root       xxxx persist.json
-rw------- 1 root root     xxxxx state.json
```

STEP 7-9 restore (CLI prints the clone summary; values shown are from a real run):
```
clone counter-clone up
guest IP: 192.168.249.1   (inbound only - no egress/default route)
restore-rc=0
```

STEP 10 THE PROOF:
```
[clone counter, should be 5]: counter=5
[clone POST -> 6]:            counter=6
[clone POST -> 7]:            counter=7
[clone now, should be 7]:     counter=7
```

STEP 11 original unaffected (COW):
```
[original]: counter=5
```

PASS = clone came up at 5, went to 7, and the original is still 5.

## Known facts / caveats baked into this test

- No containerd restart and NO pod annotations are needed — the per-runtime
  `snapshotter = "erofs"` is in `/etc/containerd/config.toml` and `default_vcpus = 1`
  is in `configuration.toml`. (Cameron-confirmed; the shim is exec'd fresh per pod.)
- The clone is INBOUND-ONLY: after re-IP its eth0 carries BOTH the stale pod IP and
  the new `192.168.x.1`, and has no default route (egress black-holed). Fine for this
  test (we only curl the clone inbound). See `nodepool0-restore-networking-reference.md`.
- The clone holds the source snapshot's `memory-ranges` MAP_PRIVATE — do NOT
  `snapshot delete` the source while a clone is live. The runner deletes the snapshot
  only AFTER `restore kill`.
- If the run fails at snapshot with a socket/404 error, the pod predates the deployed
  shim — the runner always recreates the pod fresh to avoid this.
- If `kata-runtime restore --help` errors, the deployed binary lacks restore; rebuild
  + redeploy (see CLAUDE.md §15/§16) before running.
