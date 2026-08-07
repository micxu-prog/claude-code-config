---
name: openclaw-snapshot-e2e
description: "Run the end-to-end Kata Containers snapshot+restore demo on the REAL openclaw agent-gateway (ghcr.io/openclaw/openclaw:2026.3.23) on AKS nodepool0 — the hardest of the three snapshot demos. Use whenever the user wants to snapshot+restore a running openclaw / Moltbot gateway, demo Kata snapshot/restore on a heavy real Node.js web app (not a toy), prove a LIVE web service survived restore, show the restored Control UI in a browser, or asks to 'run the openclaw snapshot demo', 'snapshot openclaw', 'restore openclaw', 'the agent-sandbox demo'. openclaw is a headless Node gateway with a web Control UI on :18789 (NO /execute endpoint — driven via the `openclaw` CLI + HTTP health endpoints). Proof = the restored Mode A clone's gateway serves HTTP 200 + passes all 4 readiness probes (/healthz /readyz /health /ready) = the live service survived, not a relaunch; plus a workspace marker on the RAM overlay; plus the clone's route table shows NO default route (the documented no-egress limitation — an LLM agent turn on the clone would fail). Self-contained: own pod (PVC dropped, state on RAM overlay), full teardown. Leaves a socat bridge so the user opens the clone UI in their browser. Sibling skills: counter-snapshot-e2e (heap proof), harshit-snapshot-e2e (filesystem proof). Requires the Windows->azlinux-dev devtunnel. Do NOT use for the counter or pyruntime apps, for building kata-runtime, or off-node."
---

# openclaw-snapshot-e2e — snapshot/restore the real openclaw agent gateway

## What this is + why it's the hard one

openclaw (formerly Moltbot), `ghcr.io/openclaw/openclaw:2026.3.23`, is a real
**headless Node.js 24 agent gateway** — a web Control UI + WebSocket on **:18789**,
no desktop, no game. Unlike the counter (RAM int) and pyruntime (`/execute` shell
endpoint), openclaw has **NO generic exec endpoint** — you drive it via the
`openclaw` CLI (kubectl exec on the original) and its HTTP health endpoints. It's a
~1.1 GiB image, a real stateful web service. This demo snapshots a RUNNING openclaw
and restores it as a Mode A clone, proving the **live web service survived** (not a
relaunch), then hands you a browser path to the restored UI.

## What this proves (VERIFIED live 2026-06-18)

1. openclaw boots in a 2 GiB Kata guest (uses ~442 MiB, fits easily), serves HTTP 200.
2. `kata-runtime snapshot` captures it (5 files, 2 GiB memory-ranges).
3. `kata-runtime restore` brings up a clone whose **gateway serves HTTP 200 and passes
   ALL 4 readiness probes** (`/healthz /readyz /health /ready` → 200) on a brand-new
   cloud-hypervisor — the live service survived, instantly (no cold-boot delay a
   relaunch would show).
4. A workspace marker written to the RAM overlay before snapshot is part of the
   captured guest RAM.
5. The clone has **NO default route** (route table = on-link only) → the documented
   Mode A no-egress limitation: it serves its surviving UI inbound but a live LLM
   agent turn (outbound) would fail.
6. A **socat bridge** is left running so you open the restored Control UI in a browser.

## How to run it

ACTIVE RUNNER on nodepool0 via the admin VM over the devtunnel:

```
bash ~/.claude/skills/openclaw-snapshot-e2e/run.sh            # full run; leaves clone UP + prints how to open it
bash ~/.claude/skills/openclaw-snapshot-e2e/run.sh teardown   # tear down clone + bridge + pod
```

It does NOT auto-take a screenshot — it leaves the clone live + the socat bridge up and
prints `HOW_TO_OPEN.md` so YOU open the UI and judge it. Self-contained: own
`kata-openclaw` pod, full teardown.

## openclaw specifics baked in (learned live)

- **No `/execute`.** Drive the ORIGINAL via `kubectl exec kata-openclaw -- openclaw <cmd>`
  (`status`, `sessions`, `config`, `agent`...). The CLONE is not a pod → reach it only
  via its HTTP gateway on the clone IP (node-routable) or kata-agent-ctl over vsock.
- **PVC dropped.** Upstream mounts a 2Gi RWO PVC at `~/.openclaw/workspace`; we replace
  it with an emptyDir so ALL state is on the RAM overlay (= captured by the snapshot).
  A real disk PVC is NOT captured (CLAUDE.md GAP5).
- **Auth-free proof.** An `openclaw agent` turn needs an API key (no key → no session
  written), so the survival proof uses the **health endpoints + a workspace marker**,
  NOT a chat session.
- **Token UI.** The gateway requires `#token=dummy-token-for-sandbox` in the URL; bare
  loads get rejected. PID 1 renames itself to `openclaw-gateway`.
- **kata-agent-ctl ExecProcess is unreliable** for reading in-clone PID/marker (json://
  arg-vector quoting + sandbox-namespace targeting are fiddly) — DON'T depend on it;
  the HTTP readiness proof is the rigorous signal.

## Expected output (VERIFIED — real captured values)

Phase A (warm, on original):
```
A1 gateway HTTP=200
A3 marker: BANANA-42-snapshot-witness  -> /home/node/.openclaw/workspace/marker.txt
A4 anchors: PID1_CMD=openclaw-gateway  PID1_START_TICKS=724  GUEST_UPTIME=~593s
```

Phase B (snapshot):
```
/run/vc/vm/snapshots/<sbid>   snapshot-rc=0
config.json(13325) kata-snapshot.json(132) memory-ranges(2147483648) persist.json(17443) state.json(230466)
```

Phase C (restore):
```
clone openclaw-clone up
guest IP: 192.168.240.1   (inbound only - no egress/default route)
clone.json: tap kat0, host_ip 192.168.240.2/24, guest_ip 192.168.240.1/24, unit clh-openclaw-clone
clone :18789 HTTP=200
```

Phase D (SURVIVAL PROOF — the headline):
```
<title>OpenClaw Control</title>      clone HTTP=200
/healthz -> 200   /readyz -> 200   /health -> 200   /ready -> 200
```
→ the restored gateway is fully healthy on a new VM = the live service survived.

Phase E (no-egress teaching beat):
```
clone routes: 10.244.0.0/16 ; 192.168.240.0/24 ; fe80::/64   (NO 0.0.0.0 default)
```
→ clone serves inbound but cannot call out; a live LLM agent turn would fail here.

Phase F (browser bridge):
```
socat TCP-LISTEN:28789,fork -> 192.168.240.1:18789   (systemd --scope, persists across node-shell)
via-socat HTTP=200
Dashboard: http://localhost:18789/#token=dummy-token-for-sandbox
```

## How YOU open the restored UI

See `HOW_TO_OPEN.md` (run.sh prints it). Short version: the skill leaves a socat
bridge on the node (`node:28789 -> clone:18789`); hop from your laptop → admin VM →
node:28789, then open `http://localhost:18789/#token=dummy-token-for-sandbox`. The
`#token=` is required. Simplest sanity check from the admin VM:
`curl -s http://127.0.0.1:28789/ | grep -o '<title>[^<]*</title>'` → `OpenClaw Control`.

## Bundled files

`run.sh` (orchestrator), `kata-openclaw.yaml` (plain Pod, PVC dropped),
`phase0_preflight.sh`, `phaseA_warm.sh`, `phaseB_snapshot.sh`, `phaseC_restore.sh`,
`phaseD_prove.sh`, `phaseE_noegress.sh`, `phaseF_browser_info.sh`, `HOW_TO_OPEN.md`,
`phase_teardown.sh`.

## Caveats

- Runs on the deployed node binary (commit 0448b608) which carries both the snapshot
  and restore commits (verified). The clone is a Mode A PoC: dup-IP (keeps stale
  10.244.x + new 192.168.240.1), no egress, shares the original's RNG/clock (the CLI
  prints this warning) — fine for an inbound UI-survival demo, not a production tenant.
- Do NOT `snapshot delete` the source while the clone is live (clone holds it
  MAP_PRIVATE). Teardown order: `restore kill` first, then delete the snapshot.
- Full clone networking truth: `nodepool0-restore-networking-reference.md`.
