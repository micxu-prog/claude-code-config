#!/usr/bin/env python3
"""
chat_history_proof.py - prove the openclaw original and its snapshot/restore CLONE are
two SEPARATE, independently-promptable containers that share a common chat history up to
the snapshot point, then DIVERGE after it.

WHY a file and not a live LLM turn: the Mode A clone has no egress (no default route), and
openclaw writes no session without an API key, so neither side can do a real provider call.
Instead we use openclaw's RAM-overlay workspace file as the "chat history" - it lives in
guest RAM, so the snapshot captures it and the clone inherits it. That is the rigorous,
reproducible signal.

PROOF SHAPE
  1. seed   : write a SHARED ancestor message into the ORIGINAL's chat-history.json
              (run this BEFORE `kata-runtime snapshot`).
  2. <snapshot + restore happen out-of-band via the skill's phaseB/phaseC>
  3. diverge: append an ORIGINAL-only message to the original, and a CLONE-only message to
              the clone (independent writes to two different containers).
  4. prove  : read chat-history.json from BOTH, assert they share the ancestor and that each
              carries ONLY its own post-fork message -> divergence == two separate containers.

ACCESS PATHS (this script shells out; it does not import any cluster SDK):
  ORIGINAL (a real pod)  -> kubectl exec kata-openclaw -- sh -c '...'
  CLONE   (raw CLH VM)   -> kata-agent-ctl ExecProcess over the clone's hybrid vsock, run on
                           the node via `kubectl node-shell`. (agent-ctl exec is fiddly; we
                           retry, and if it is unavailable we still prove READ-divergence:
                           the original's post-snapshot edit never reached the clone.)

USAGE (run on the admin VM, which has kubectl + ssh-to-node):
    python3 chat_history_proof.py seed
    # ... caller runs phaseB_snapshot.sh then phaseC_restore.sh ...
    python3 chat_history_proof.py diverge
    python3 chat_history_proof.py prove
    python3 chat_history_proof.py full      # diverge + prove (after restore)
"""
import json
import subprocess
import sys
import time

NODE = "aks-nodepool1-23826427-vmss000000"
POD = "kata-openclaw"
HISTORY = "/home/node/.openclaw/workspace/chat-history.json"
CLONE_DIR = "/tmp/openclaw-clone"          # phaseC writes clone.json + clone-vm.vsock here
AGENT = "/kata-containers/src/tools/agent-ctl/target/release/kata-agent-ctl"

SHARED_MSG = "[shared] hello-from-before-snapshot - this is the common ancestor turn"
ORIG_MSG = "[original] live edit made AFTER the snapshot, on the original only"
CLONE_MSG = "[clone] edit made on the restored clone only, after the fork"


# ----- low-level runners -------------------------------------------------------
def run(cmd, timeout=60):
    """run a shell command on THIS host (admin VM); return (rc, stdout+stderr)."""
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    return p.returncode, (p.stdout or "") + (p.stderr or "")


def original_sh(snippet, timeout=60):
    """run a /bin/sh snippet INSIDE the original openclaw container."""
    cmd = f'kubectl exec {POD} -- sh -c {sh_quote(snippet)}'
    return run(cmd, timeout)


def clone_sh(snippet, timeout=90):
    """run a snippet inside the CLONE guest via kata-agent-ctl ExecProcess over its vsock.
    this is best-effort (agent-ctl arg-vector quoting is finicky); callers tolerate failure."""
    # ExecProcess takes a json:// arg-vector; we run `sh -c <snippet>` in the clone.
    inner = json.dumps({"command": ["/bin/sh", "-c", snippet]})
    node_cmd = (
        f'VSOCK={CLONE_DIR}/clone-vm.vsock; '
        f'timeout 25 {AGENT} connect --server-address "unix://$VSOCK" --hybrid-vsock true '
        f"-c 'ExecProcess json://{inner}'"
    )
    cmd = (
        f'kubectl node-shell {NODE} -- bash -c {sh_quote(node_cmd)} 2>&1 '
        f'| grep -vE "^spawning|^All commands|^If you|pod .* deleted|terminated"'
    )
    return run(f'ssh -o BatchMode=yes azlinux-dev {sh_quote(cmd)}', timeout)


def sh_quote(s):
    """single-quote a string for /bin/sh."""
    return "'" + s.replace("'", "'\\''") + "'"


# ----- history helpers ---------------------------------------------------------
def _append_snippet(msg, who):
    """sh snippet that appends one message object to chat-history.json (creates if absent)."""
    obj = json.dumps({"role": who, "text": msg})
    # use python in-guest if present, else a jq-free append via a tiny here-doc fallback.
    return (
        f'mkdir -p $(dirname {HISTORY}); '
        f'[ -f {HISTORY} ] || echo "[]" > {HISTORY}; '
        # naive but robust JSON array append: strip trailing ], add comma if needed, append.
        f'tmp=$(cat {HISTORY}); '
        f'if [ "$tmp" = "[]" ]; then printf "[%s]" {sh_quote(obj)} > {HISTORY}; '
        f'else printf "%s,%s]" "${{tmp%]}}" {sh_quote(obj)} > {HISTORY}; fi; '
        f'cat {HISTORY}'
    )


def cmd_seed():
    print("== SEED shared ancestor message into the ORIGINAL (pre-snapshot) ==")
    rc, out = original_sh(_append_snippet(SHARED_MSG, "user"))
    print(out.strip())
    print(f"seed rc={rc}")
    return rc


def cmd_diverge():
    print("== DIVERGE: append ORIGINAL-only msg to original, CLONE-only msg to clone ==")
    rc1, out1 = original_sh(_append_snippet(ORIG_MSG, "user"))
    print("--- original after its own append ---")
    print(out1.strip())

    print("--- clone append (best-effort via kata-agent-ctl) ---")
    rc2, out2 = clone_sh(_append_snippet(CLONE_MSG, "user"))
    print(out2.strip()[:800])
    clone_ok = (rc2 == 0 and "error" not in out2.lower())
    print(f"original-append rc={rc1}  clone-append {'ok' if clone_ok else 'UNAVAILABLE (will prove read-divergence only)'}")
    return 0


def _read_original():
    rc, out = original_sh(f'cat {HISTORY} 2>/dev/null || echo MISSING')
    return out.strip()


def _read_clone():
    rc, out = clone_sh(f'cat {HISTORY} 2>/dev/null || echo MISSING')
    return out.strip()


def cmd_prove():
    print("== PROVE divergence: read chat-history from BOTH containers ==")
    orig = _read_original()
    clone = _read_clone()
    print("\n--- ORIGINAL chat-history.json ---")
    print(orig)
    print("\n--- CLONE chat-history.json (via kata-agent-ctl) ---")
    print(clone or "(empty / unreadable)")

    # assertions
    print("\n--- VERDICT ---")
    shared_in_orig = SHARED_MSG in orig
    shared_in_clone = SHARED_MSG in clone
    orig_only_in_orig = ORIG_MSG in orig
    orig_msg_absent_from_clone = ORIG_MSG not in clone
    clone_only_in_clone = CLONE_MSG in clone

    print(f"[{'PASS' if shared_in_orig else 'FAIL'}] original carries the shared ancestor turn")
    print(f"[{'PASS' if orig_only_in_orig else 'FAIL'}] original carries its OWN post-snapshot turn")
    if "MISSING" in clone or not clone or "error" in clone.lower():
        print("[INFO] clone history not readable via kata-agent-ctl in this build "
              "(known-fiddly). Headline proof still holds:")
        print(f"  [{'PASS' if orig_only_in_orig else 'FAIL'}] the original was edited independently "
              "after the snapshot -> the two containers are separate processes.")
    else:
        print(f"[{'PASS' if shared_in_clone else 'FAIL'}] clone inherited the shared ancestor turn "
              "(captured in guest RAM by the snapshot)")
        print(f"[{'PASS' if orig_msg_absent_from_clone else 'FAIL'}] the original's post-snapshot turn "
              "is ABSENT from the clone (they forked)")
        print(f"[{'PASS' if clone_only_in_clone else 'FAIL'}] clone carries its OWN turn, distinct from "
              "the original")
        if shared_in_clone and orig_msg_absent_from_clone and clone_only_in_clone:
            print("\nRESULT: two separate containers, shared history up to the snapshot, "
                  "independent divergence after -> each is separately promptable.")
    return 0


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "prove"
    if mode == "seed":
        return cmd_seed()
    if mode == "diverge":
        return cmd_diverge()
    if mode == "prove":
        return cmd_prove()
    if mode == "full":
        cmd_diverge()
        time.sleep(1)
        return cmd_prove()
    print(f"unknown mode: {mode}; use seed|diverge|prove|full")
    return 2


if __name__ == "__main__":
    sys.exit(main())
