# Global Preferences

- Always use maximum reasoning effort and thoroughness (equivalent to /effort max).

## Behavior

- This machine's source-of-truth agent configuration lives in `C:\Users\t-michaelxu\claude-code-config`.
- Read `C:\Users\t-michaelxu\docs\` for persistent machine/project reference before work that touches MCPs, tools, project setup, or prior investigation context. In particular check `C:\Users\t-michaelxu\docs\mcp.md` and any relevant Markdown under `C:\Users\t-michaelxu\docs\project\`.

## docs-scout subagent (USE IT A LOT)

- `docs-scout` is the dedicated read-only librarian subagent for the `C:\Users\t-michaelxu\docs\` knowledge base. It deep-reads the ~27 project Markdown files in its OWN isolated context and returns a compact, citation-backed summary, so the main session never has to load all those docs and bloat its context.
- DEFAULT TO CALLING `docs-scout` instead of reading `docs\project\*.md` (or `mcp.md`) yourself. Reach for it early and often — at the START of any task that touches the Kata/AKS nodepool0 work, VM templating, app snapshot/restore, CLH/MSHV/EROFS, devtunnel/`azl`, onboarding, repo maps, or any prior-investigation context. When in doubt, call the scout; that is what it is for.
- HOW TO CALL IT: hand it a detailed 3-4 paragraph request naming the project/area, the specific topic, the exact questions, and what you intend to do with the answer. Thin/vague prompts get bounced back for specifics, so be concrete.
- It is read-only (Read/Grep/Glob only). If it returns a `CONTRADICTIONS` section proposing a doc fix, YOU apply the edit — the scout never writes to the docs itself.
- Only read the docs directly yourself when the scout is unavailable, or when you need to apply an edit it proposed.
- IN `Workflow` SCRIPTS: when you author a workflow whose subject touches the project (Kata/AKS/nodepool0, VM templating, snapshot/restore, CLH/MSHV/EROFS, containerd config, devtunnel/`azl`, intern-project, repo maps — i.e. the same keyword set above), make a `docs-scout` context-gathering call the FIRST, blocking phase, and thread its cited summary into the prompts of every downstream phase so no agent re-derives project context. Skeleton:
  ```js
  phase('Context')
  const ctx = await agent(
    `<3-4 paragraph docs-scout request: name the project/area, the exact topic, the specific questions this workflow must answer from the docs, and what the workflow will do with it>`,
    { agentType: 'docs-scout', label: 'docs-scout: project context' }
  )
  // every later phase embeds ctx so downstream agents act on real, cited context:
  phase('Work')
  await parallel(items.map(it => () => agent(`Using this project context:\n${ctx}\n\nNow <do X for ${it}>`, { /* ... */ })))
  ```
  Do NOT add this prelude to workflows unrelated to the docs corpus (e.g. a repo-wide rename or generic lint sweep) — it would waste an Opus scout call. Keyword-gated, same as normal scout use.
- Be concise and direct. Keep explanations short, direct, and technical by default. Only give long, detailed explanatory answers when the user explicitly includes the keyword `eli5`.
- No emojis.
- AskUserQuestion hygiene (this tool fails validation ~30% of the time in practice, almost always a malformed call — not a harness bug): BEFORE sending, verify EVERY question object has ALL of `question` (the full question string — most commonly dropped on rich fork/option calls), `header` (<=12 chars), `multiSelect` (bool), and `options` (2-4 items, each with both `label` and `description`); and that `questions` is a real array, not a JSON-stringified string. If a call still fails validation, do NOT retry the tool in a loop — immediately re-ask the same options in plain text and continue.
  - THE #1 RECURRING BUG (fix it every time): I keep dropping the top-level `question` field on each question object. It is REQUIRED and is NOT the same as `header` or the option labels. `header` is the <=12-char chip; `question` is the full sentence ending in `?`. Write `question` FIRST in every object, before `header`/`options`.
  - Mandatory shape — every question object MUST look exactly like this (all four keys present):
    ```json
    {"question": "<full sentence ending in ?>", "header": "<=12 chars", "multiSelect": false, "options": [{"label": "...", "description": "..."}, {"label": "...", "description": "..."}]}
    ```
  - Pre-send checklist (run mentally on EACH object): (1) `question` present + ends with `?`; (2) `header` present, <=12 chars; (3) `multiSelect` present (bool); (4) `options` 2-4 items, each with BOTH `label` and `description`. If any object is missing `question`, the whole call 400s.
- Use Windows-style paths with backslashes when working on the Windows host.
- Prefer precise tool use: read/search enough context first, make surgical changes, and validate the exact requested behavior.

## Git Safety

- NEVER run `git commit`, `git branch`, `git push`, or any git command that requires a message/name without FIRST asking for the exact commit message or branch name. Always ask; never use defaults or suggestions without explicit input.
- Do not auto-commit, auto-push, create branches, or trigger remote pipelines without explicit confirmation. Show the command and let the user run it.

## Coding Style

- Use clear, readable code.
- Add comments only when logic isn't self-evident; comments should be ALL lowercase/casual except for acronyms.

## Acronym Tracking

- Whenever you encounter ANY acronym you are not 100% sure about, APPEND it to `~/Desktop/Acronyms.md`.
- Format: one line per acronym -> `ACRONYM (context where you found it)`.
- Only append, never overwrite or reorganize the file.

## Confluence

- Whenever a Confluence link is sent, confirm you can read/open the contents or say so before starting work.
- Look through the Confluence MCP ONLY when directed.

## SharePoint design docs via WorkIQ (USE FOR DESIGN-DOC INGEST)

Design docs (Kata VM templating, snapshot/restore, agentic-workload proposals, etc.)
live on SharePoint/OneDrive as `.docx`. Many agents will need to read, summarize, or
fully ingest them. The working access path is the **WorkIQ MCP**, NOT WebFetch
(WebFetch fails on auth-gated SharePoint URLs).

- **Primary method:** `mcp__workiq__ask_work_iq` with the `fileUrls` parameter set to
  `[<the SharePoint doc URL>]` plus a `question` describing what to extract. It is
  already authorized with the M365 account — no EULA/sign-in wall in practice (proven
  2026-07-01 ingesting the "Kata CLH VM Templating" doc end to end).
- **Page through long docs:** one call rarely returns the whole doc. Make SEVERAL
  calls, each asking for a specific section (intro/goals, then architecture, then
  implementation, then testing/limitations, then comments/appendix). Reviewer comment
  threads usually need their own dedicated call to come back untrimmed.
- **Avoid the word "verbatim"** — it trips a soft "can't reproduce copyrighted internal
  content" refusal. Instead ask it to "reproduce faithfully, section by section, every
  heading/table/list/code block and technical detail," or ask factual cross-reference
  questions.
- **Fidelity caveat:** WorkIQ reads content, it does NOT pixel-render.
  Structure/tables/section-order/comments come back faithful; exact body-paragraph
  PROSE is paraphrased; per-figure numbers not printed in the text are WorkIQ's own
  visual estimate (it usually flags these). Treat structure as faithful, exact wording
  as near-faithful.
- **For byte-exact prose or figure pixel values:** fall back to the Playwright browser
  MCP — `mcp__playwright__browser_navigate` to the URL (Word web viewer, already signed
  in), then `browser_snapshot` / `browser_evaluate` to pull the rendered body. Caveat:
  this can hit a profile lock ("Browser is already in use ... use --isolated") if
  another session holds the Chrome profile — don't force it.
- **EULA is a HUMAN gate:** if WorkIQ returns an EULA-not-accepted error, an agent
  CANNOT accept it (`mcp__workiq__accept_eula` requires the user's explicit
  confirmation). Capture the exact error/debug link and surface it to the user; do NOT
  loop on it.
- **Isolate the ingest:** dispatch a standalone sub-agent whose whole job is
  access + extract + report, so raw doc content does not bloat the main session context.

## Devbox / Azure Linux VM access

Preferred topology for this machine:

- This Windows machine runs the editor, the agent, and the devtunnel client.
- An Azure Core Windows devbox hosts a Hyper-V Azure Linux VM.
- The Azure Linux VM is the real development target for Linux work.
- Connection path: this Windows host -> devtunnel -> Azure Linux VM inside the Windows devbox.
- Do not target the Windows devbox itself for Linux work; it is only the VM host.

Current Linux VM details:

- Linux user: `michaelx`
- Dev tunnel ID: `azldev`
- SSH port: `22`
- Remote-SSH host alias: `azlinux-dev`
- SSH config on this Windows host:

```sshconfig
Host azlinux-dev
    HostName 127.0.0.1
    User michaelx
    Port 22
    IdentityFile C:\Users\t-michaelxu\.ssh\azlinux-dev
    IdentitiesOnly yes
```

Required running processes:

1. Inside the Azure Linux VM, keep the tunnel host running (`$HOME/bin/devtunnel host azldev`), currently inside tmux (`tmux attach -t devtunnel`; detach with Ctrl+B then D).
2. On this Windows host, keep the client tunnel running (`devtunnel connect azldev`).

## Windows → Azure Linux SSH bridge

Use this when the agent runs on this Windows host but the real target is the Azure Linux VM.

- For Linux/devbox work, run commands through SSH to `azlinux-dev`.
- Prefer `azl` over raw `ssh` for one-shot commands (it handles remote cwd and quoting more reliably).
- Do not run Linux build/test/dev commands directly on Windows unless explicitly asked.
- **NEVER base64-encode scripts or use `certutil -encodehex` / `Convert.ToBase64String` to transport script payloads across the bridge.** This trips Defender/AV "encoded payload" security warnings. Instead: write the script locally with the `Write` tool, then `scp` it directly: `scp -q "C:\path\to\local\script.sh" azlinux-dev:/tmp/script.sh && ssh -o BatchMode=yes azlinux-dev "bash /tmp/script.sh"`. For node-shell commands, do the same scp, then `ssh ... "kubectl node-shell <node> -- bash -c \"\$(cat /tmp/script.sh)\""`.

Windows helper commands: `C:\Users\t-michaelxu\bin\azl.cmd` / `.ps1`, `C:\Users\t-michaelxu\bin\azl-git-apply.cmd` / `.ps1`.

```powershell
azl 'hostname && whoami && pwd && uname -a'
azl -Cwd /home/michaelx/myrepo 'git status'
azl -Cwd /home/michaelx/myrepo 'make test'
```

Apply edits to a Linux git repo from Windows: generate a local unified diff patch, check remotely with `azl-git-apply -Cwd <repo> -PatchFile <patch> -CheckOnly`, then apply by dropping `-CheckOnly`.

### Script transport safety (NEVER trip security tooling)

- NEVER base64-encode files or scripts to move them across the Windows -> Azure Linux bridge. `[Convert]::ToBase64String`, `-EncodedCommand`, and similar encode/decode staging match malware payload-staging patterns and trip "Suspicious PowerShell" alerts. Do not use them.
- NEVER use `powershell.exe -NoProfile -Command` (or `-nop`) with reflective `[IO.File]::` / `[Convert]::` calls to read, encode, or stage files. This whole shape is banned.
- To get a script onto the Azure Linux VM, use one of these instead:
  - Run the commands directly on the VM one at a time via `azl '<command>'` (preferred for short sequences).
  - Use the git-patch flow above (`azl-git-apply`) for repo file edits.
  - Write the script with a normal editor/Write tool and copy it over with a plain file-transfer mechanism (e.g. `scp`/`rsync` over the existing `azlinux-dev` SSH host), not by encoding its bytes.
- If a transport approach would require encoding, obfuscation, or a single packed PowerShell one-liner, STOP and pick a plainer method or ask first.

## AKS Kata project context

- **NEVER REIMAGE, RESTART, REBOOT, DEALLOCATE, UPGRADE, or `az vmss`-cycle the node `aks-nodepool1-23826427-vmss000000` (nodepool0) — or ANY AKS node — under ANY circumstances, ever.** A reimage/reboot WIPES the custom EROFS+MSHV kernel, the custom snapshot/restore kata-runtime + shim, containerd erofs config, the VM-template factory, and kata-agent-ctl — costing hours of rebuild. This is the single most destructive thing that can happen to this project. Do NOT run `kubectl drain`, `kubectl delete node`, `az aks nodepool upgrade/scale`, `az vmss restart/reimage/deallocate`, `systemctl reboot`, or anything that recreates/cycles the node VM. If a task seems to *require* reimaging or rebooting the node, STOP and ask first — assume the answer is no. (AKS itself auto-reimages these nodes periodically for node-image upgrades; that is NOT something the agent does or can prevent, but the agent must NEVER initiate one. When the node comes back reimaged, that was AKS auto-upgrade, never the agent — verify with `kubectl get node -o jsonpath={.metadata.creationTimestamp}` + node `uptime`.)
- **CLH BINARY CHANGES — ALWAYS USE CAMERON'S IN-PLACE METHOD.** When testing/deploying a new cloud-hypervisor build on nodepool0, replace the real system binary in place (Cameron's proven flow), do NOT use the side-by-side `--clh-bin /usr/bin/cloud-hypervisor-fix` trick. Steps: on the node, `git clone`/checkout the fork branch, `cargo build --target=x86_64-unknown-linux-gnu --features "mshv"`, then `cp target/x86_64-unknown-linux-gnu/debug/cloud-hypervisor /usr/bin/cloud-hypervisor`. If `cp` fails with `Text file busy`, the running CLH VMs are holding it open — they must exit first (this is expected; deleting/recreating the demo pods is acceptable and is how Cameron does it). BEFORE overwriting, back up the current binary (`cp /usr/bin/cloud-hypervisor /usr/bin/cloud-hypervisor.orig-backup`) if no backup exists. Do NOT `dnf remove cloud-hypervisor` (it cascades into removing kata + the mshv kernel); if the RPM is ever needed back use `dnf reinstall cloud-hypervisor` then re-`cp` the custom binary on top. This is the required method going forward — side-by-side `--clh-bin` was a one-off and is deprecated for CLH changes.
- **GHOST-ZOMBIE `/run` LEAK — the #1 silent node killer for this project (root-caused 2026-07-23).** Restore/snapshot churn can wedge the node by filling the small `/run` tmpfs (13 GiB RAM-disk) with INVISIBLE deleted-but-mmapped memory files. TWO stacked bugs: (A) snapshots + restore VM memory live ON `/run` (`/run/vc/vm/snapshots/<name>/memory-ranges` = 2 GiB each); restore symlinks memory-ranges into the clone VM dir, CLH `mmap`s it MAP_PRIVATE then CLOSES the fd. (B) when a clone's `containerd-shim` dies (force-delete / "Dead agent"), cleanup BAILS (`"failed to clean up after shim disconnected" ... open /run/vc/sbs/<id>: no such file or directory`) and NEVER kills the CLH child → orphaned CLH keeps a DELETED 2 GiB mapping alive for DAYS. N orphans × 2 GiB fills `/run` → CNI fails `no space left on device` → no new pods. **DETECTION (critical): the leak is INVISIBLE to `df`+`du` (unlinked file), `/proc/pid/fd` (fd closed after mmap), `kubectl`, and `crictl` (pods gone). ONLY `/proc/*/maps` shows it** — scan for `memory-ranges (deleted)` mappings: `for p in $(pgrep -f cloud-hypervisor); do grep -q 'memory-ranges.*deleted' /proc/$p/maps && echo "GHOST $p"; done`. Confirm the gap with `df -h /run` (100%) vs `du -xsh /run` (tiny). **SAFE FIX:** `kill -9` each orphaned CLH that has NO owning shim AND holds a deleted memory-ranges map (verify `shim=NONE` first so you never kill a live VM), then `rm -rf /run/vc/vm/<vmid>`. This reclaims the space instantly (proven: 13G/13G → 454M/13G). **NEVER `systemctl restart containerd` to fix this** — it does NOT release the mappings (the holders are the CLH, not containerd) and it BREAKS new kata shims with `ttrpc: closed` (learned the hard way 2026-07-23). To PREVENT recurrence in the harness: reap clone CLH on every teardown, and don't delete a snapshot while a clone still maps it. Full evidence + code fixes: `docs\project\restore-final-refactor-docs\ROOTCAUSE-run-tmpfs-ghost-zombies-EVIDENCE.md`.
- Persistent project handoff: `C:\Users\t-michaelxu\docs\project\aks-kata-node-context.md`.
- Kubernetes context: `testabc123`. Prefer the user's `k` alias in Kubernetes commands.
- Custom Kata experiment node: `aks-nodepool1-23826427-vmss000000`.
- Final target nodepool family: normal Microsoft Azure Linux `nodepool1` with MSHV (matching the original `nodepool1` style as closely as possible). `erofspool` / ACL is diagnostic proof only, not the final target.

### Snapshot/restore: Mode A vs Mode B (SUPER IMPORTANT — two distinct restore modes)

The kata snapshot/restore feature has TWO modes. Do not conflate them. (Authoritative
post-ship detail lives in `docs\project\CLAUDE.md` §16 + `nodepool0-mode-b-design.md`;
this block is the compressed memory.)

- **Mode A — CLONE / side-by-side (SHIPPED 2026-06-17).** Restore a SECOND copy of a container that runs alongside the still-alive original. Two containers on one wire → IP collision → the clone is re-IP'd via `kata-agent-ctl UpdateInterface`. COW comes from CLH opening the snapshot's `memory-ranges` MAP_PRIVATE (`.memory.shared=false`); the original RAM file is never written. PROVEN green on nodepool0 (counter clone serves its snapshotted value on its own IP while the original keeps incrementing). Shipped as `kata-runtime restore` on branch `michaelx/kata-runtime-snapshot` (squashed to 2 commits: snapshot `6e8ca48bd` + restore `be1d90f60`; restore_test.go + how-to kept LOCAL/uncommitted). Surface simplified to `--from <name|path> [--name <id>]` + `restore kill <id>` (networking auto-allocated, binary flags hidden). N>1 clones now coexist: clone N gets tap `kat<N>` + subnet `192.168.<240+N>.x`, so first clone = `192.168.240.1`, second = `192.168.241.1` (NOT the old fixed `192.168.249.1`). All CodeRabbit/Copilot review findings fixed (path-traversal guards, killClh `--api-socket` match, memory-ranges symlinked not copied, IP token-match). MAC swap DEFERRED (clones sit on isolated unbridged taps so dup-MAC is latent — Cameron: "handle once we encounter it").
- **Mode B — stop/free the original, restore as-it-died (FUTURE TODO; REFRAMED by Cameron 2026-06-17).** NOT a separate command and NOT `restore --in-place`. Cameron: it's *"a nice feature to make real quick in your snapshot api — a new parameter to `--stop/kill/resume(default)` the snapshotted UVM."* So it collapses into a SNAPSHOT lifecycle flag: what to do with the original after snapshot. `--resume` (default) = original stays alive = Mode A clone (re-IP needed). `--kill` = original gone, ~2 GB freed = restore later as the same container, same IP, NO re-IP — IF the CNI netns/veth survive the kill (the gating, still-UNPROVEN experiment; Mode A never killed an original). Phase it: freeze/thaw-in-place first, then stop-and-restore. Git: next commit on the snapshot branch, not restore.go.

- **NORTH-STAR (the real product, per `intern-project-overview.md`): the clone should have its OWN kata runtime.** Today's Mode A is the demo proof — `restore.go` hand-plays the shim (raw CLH, no shim/sandbox/containerd owner, hand-plumbed tap/MAC/re-IP). The goal is a restored clone that is a REAL kata-managed sandbox (its own `containerd-shim-kata-v2`, kubelet-visible, CNI-networked, cgroup-owned, reaped normally). That auto-fixes the v1 hacks: CNI gives a fresh veth+MAC+real IP+egress (kills the manual UpdateInterface, dup-MAC M1, inbound-only H1, root-slice-orphan C2). Documented path: extend the `VCSandbox`/Hypervisor interface with a `RestoreVMFrom(srcDir)` mirroring the shipped `SaveVMTo` seam; have the shim CREATE a new Sandbox around the restored VM (the gap: a CRI "RunPodSandbox-from-snapshot" / `RehydratePodIdentity` path — named in docs, not yet designed). Cameron's `clh.go RestoreVM(path)` (kata-owned, re-runs CNI) — "wrong model" for the raw clone — becomes the RIGHT primitive once the shim owns the result. This also unlocks Cameron's LIVE MIGRATION roadmap (`docs\project\CLAUDE.md §14`) and eventual runtime-rs parity. See `nodepool0-mode-b-design.md` + the snapshot-CLI plan's `Checkpoint` stub notes.

- Current custom runtime source checkout on that AKS node: `/kata-containers`. Build/deploy path:

```bash
cd /kata-containers/tools/osbuilder/node-builder/azure-linux
make all
make deploy
```

### kata-containers git workflow (admin VM is source of truth, node is read-only consumer)

There are TWO independent clones of kata-containers:

- **ADMIN VM** `/home/michaelx/kata-containers` — the writable one. All edits, commits, and pushes happen here.
- **NODE** `/kata-containers` — read-only for our purposes. Pull only. Never commit or push from the node.

Remotes on the admin VM:
- `origin` = `github.com/microsoft/kata-containers`
- `michael` = `github.com/michaelxu2288/kata-containers` (the user's personal fork)

Rules:
- ALWAYS write/edit code and create commits on the ADMIN VM only.
- Before pushing an existing PR, resolve its actual GitHub head repository and head ref.
  After explicit push authorization, push directly to that exact branch so the existing
  PR updates. PR branches hosted on `origin` must be pushed to `origin`; new/fork work
  should normally be pushed to `michael`.
- Never silently create a parallel fork branch or a second PR as a substitute for an
  existing PR branch. If authorization for the real head branch fails, report the auth
  failure and ask for a compliant login instead of redirecting the push elsewhere.
- ALWAYS pull on the node — never commit/push. The node's tree is just a consumer of whatever the admin VM published to `michael`.
- The two clones do NOT auto-sync. After a push from admin VM, explicitly `git fetch michael && git checkout michaelx/test-log && git reset --hard michael/michaelx/test-log` (or `git pull michael <branch>`) on the node before rebuilding the shim.
- The "No credential store" / "fatal: No credential store has been selected" errors from GCM on the admin VM are NOISE — pushes still succeed via device-code auth completing in-memory. Ignore them.
- Never run `git reset --hard` without confirming the user agrees — even though it doesn't touch untracked files, it DOES discard committed changes (recoverable from reflog for ~90 days via `git reset --hard <sha-from-reflog>`).

- Keep using existing RuntimeClass `kata` and manifest `/home/michaelx/kata-busybox-long-pod.yaml` unless explicitly asked to change them.
- Prefer existing node-debugger pods for non-interactive node commands instead of spawning new shells:

```powershell
azl 'k exec -n default node-debugger-aks-nodepool1-23826427-vmss000000-bw5nx -- chroot /host /bin/bash -lc "<node command>"'
azl 'k exec -n default node-debugger-aks-nodepool1-23826427-vmss000000-bw5nx -- chroot /host journalctl --no-hostname -o cat -t kata -n 200'
```

Final-target guardrails:

- Final target must be normal Microsoft Azure Linux AKS with MSHV. Do not use Azure Container Linux (ACL/BYOI) as the final target — it is diagnostic proof only.
- Preserve MSHV as the final hypervisor/kernel path; do not switch to KVM unless explicitly asked.
- nodepool0 (`aks-nodepool1-23826427-vmss000000`) now runs `6.6.135.mshv2+` with `CONFIG_EROFS_FS=y`; current final-target work uses nodepool0, not ACL/erofspool.
- Only use Kubernetes/node-shell command patterns already used in this project or present in shell history unless explicitly approved.

github pat:
- when pushing use this pat <REDACTED-REVOKE-THIS-TOKEN>
