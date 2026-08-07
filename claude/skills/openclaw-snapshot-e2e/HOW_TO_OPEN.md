# How to open the restored openclaw clone in YOUR browser

The skill leaves the clone running and a **socat bridge** on the node:
`node:0.0.0.0:28789  ->  clone 192.168.240.1:18789`.

The clone's IP is only routable on the node, so you reach it in two hops:
**your laptop → admin VM (devtunnel) → node:28789 (socat) → clone:18789.**

## One-command path (run on your Windows host)

This chains a kubectl node-shell port-forward out to the node's socat bridge.
Easiest reliable hop is an SSH local-forward to the admin VM, then a node-shell
relay. Concretely:

1. Open an SSH tunnel from your laptop to the admin VM, forwarding local 18789:
   ```
   ssh -N -L 18789:127.0.0.1:28789 azlinux-dev
   ```
   (This makes `localhost:18789` on your laptop = `admin-vm:28789`. If the socat
   bridge runs on the NODE not the admin VM, add a second relay — see note below.)

2. If the bridge is on the NODE (it is), relay the admin VM to the node first, in a
   separate admin-VM shell:
   ```
   # on the admin VM:
   socat TCP-LISTEN:28789,fork,reuseaddr EXEC:'kubectl node-shell aks-nodepool1-23826427-vmss000000 -- socat - TCP\:127.0.0.1\:28789'
   ```
   (or simpler: run the whole demo from inside the admin VM and point a text browser
   / curl at `http://127.0.0.1:28789/` there.)

3. Open in your browser:
   ```
   http://localhost:18789/#token=dummy-token-for-sandbox
   ```
   The `#token=` fragment is REQUIRED — the gateway rejects unauthenticated UI loads.

## Simplest sanity check (no browser)

From the admin VM, confirm the clone UI is alive through the bridge:
```
curl -s http://127.0.0.1:28789/ | grep -o '<title>[^<]*</title>'
# -> <title>OpenClaw Control</title>
```

## What you're looking at

You are looking at the **restored clone's** Control UI — the same gateway that was
snapshotted, brought back on a fresh cloud-hypervisor with a new IP. It shows the
surviving in-RAM state (workspace, identity, the marker). The original pod is still
running independently on its own `10.244.x` IP (copy-on-write — they diverge).

NOTE: the clone has **no egress** (Mode A limitation), so any action that needs an
outbound LLM call will fail — that's expected and demonstrated in phase E.

## Tear down when done

```
bash ~/.claude/skills/openclaw-snapshot-e2e/run.sh teardown
```
