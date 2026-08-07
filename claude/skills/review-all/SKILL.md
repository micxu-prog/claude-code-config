---
name: review-all
description: "v0.4. Master post-change review orchestrator for the AKS Kata snapshot/restore project (and generic repos). After any code or design change, fan out to many review agents and synthesize one combined report. READ-ONLY — never mutates the working tree or the docs wiki. For PROJECT-SCOPED changes (kata-containers, src/runtime/*, michaelx/* branch, CLH/MSHV/EROFS keywords) it: (1) captures the diff from the REAL remote source tree over the azl bridge, not the local Windows git; (2) runs a FIRST, blocking scout invariant gate (a read-only docs-scout call against C:\\Users\\t-michaelxu\\docs\\, threaded into every downstream reviewer); (3) verifies via the counter/harshit/openclaw node e2e proofs (CI is informational, never the gate); (4) runs code-review + security-review + /review + simplify/polish suggestions; (5) ends with a false-positive-suppression / severity-deflation synthesis pass. --adversarial adds a deep Workflow fan-out (code + design); --scout forces the generic wiki Workflow on a non-project repo; --no-scout skips the gate; --all enables the opt-in tiers. Use when the user says 'review all', 'run all the reviews', 'full review', 'master review', or wants the end-of-change quality gate. Do NOT use for a single targeted review (invoke that one skill directly)."
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - Skill
  - Workflow
  - Task
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# review-all — master post-change review (v0.4)

## Status

Benchmarked against the project's own labeled review corpus (the `*-review*.md`
artifacts under `docs\project\`) and rewired for how review/verify ACTUALLY work on
the Kata project. Every reviewer choice lives in the **ROSTER** table.

Locked:
1. verify + run are **collapsed into one** reviewer. For project-scoped changes it
   invokes the three **node e2e proofs** (counter/harshit/openclaw), not "run the app".
2. simplify & polish **always run but only produce SUGGESTIONS** — never edit the tree.
3. adversarial reviews **both the code change and the design** (separate agents).
4. `/review` is gated on an **upstream (fork→microsoft) PR**; branch-only is the common
   skip case (`n/a — branch-only`, never fabricate a PR). **CI is non-gating** — the
   node e2e is the gate.
5. **scout is the FIRST, blocking invariant gate** for project-scoped changes (default
   on; `--no-scout` to skip). It's a single read-only docs-scout call, not a Workflow.

## What this does (one sentence)

After a code or design change, fan out to many independent review agents, collect each
one's terse verdict, run a false-positive-suppression pass, and print one combined
report. **Nothing here mutates code or the wiki — every reviewer is read-only /
suggestion-only.**

## Core mechanics (verified on CC 2.1.178)

- **The master runs INLINE in the main session.** It must NOT declare `context: fork`
  in its own frontmatter — that would run the whole orchestrator inside one fork and
  defeat the fan-out. Its job is to *spawn* reviewers.
- **Fork is PREFERRED, not required.** A fork inherits the ENTIRE conversation (system
  prompt, tools, model, history, shared prompt cache), so it already knows what changed
  and *why*. Fallback when fork mode is off: a normal `Agent` with the Phase-0 diff
  pasted in. Per-reviewer choice is the roster's `mechanism` column (`fork→agent`).
- **Forks/agents can invoke skills** via the Skill tool (`/verify`, `/run`,
  `/code-review`, `/simplify`, `/review`, `/security-review`).
- **A fork CANNOT nest another fork.** So `/polish` (itself a `context: fork` skill)
  must be invoked from the **main session**, never wrapped in an `Agent(fork)` call.
- **The scout gate is a DIRECT read-only docs-scout subagent call, not a Workflow.**
  This keeps it default-on for project-scoped changes while preserving the
  Workflow-opt-in invariant (the generic discover+ingest Workflow stays behind
  `--scout`). If docs-scout is unavailable, degrade gracefully (see Phase 0.5 fallback).
- **Opt-in Workflow tiers.** The deep adversarial fan-out and the generic scout wiki
  review use the **`Workflow` tool** and are opt-in (`--adversarial`, `--scout`). This
  skill instructing you to call `Workflow` in those phases IS the sanctioned opt-in.
- **Bounded returns (protect the main context).** The main session ingests only each
  reviewer's **verdict + findings array** (severity + file:line + one-line title) —
  never diffs, logs, or transcripts. Opt-in Workflows self-reduce to a single capped,
  deduped list inside their own isolated context before returning (`return confirmed`).
- **Read-only, always** — including the docs wiki. docs-scout `CONTRADICTIONS` are
  surfaced for the USER to apply; the skill never edits the wiki.

## Arguments / tier selection

- **(no args)** →
  - **project-scoped:** Phase 0.5 **scout invariant gate first (blocking)**, then the
    default tier (verify via node e2e, code-review, security-review, review-if-PR,
    simplify/polish suggestions), then the FP-suppression synthesis pass.
  - **generic repo:** the default tier only (no scout gate unless `--scout`).
- `--no-scout` → skip the scout invariant gate even for a project-scoped change.
- `--adversarial` → also run the deep adversarial Workflow (code + design). Opt-in.
- `--scout` → force the **generic** discover+ingest wiki Workflow (for a non-project
  repo that still has an internal wiki). Opt-in.
- `--all` → default tier + adversarial (+ generic scout if non-project).
- a **path** arg → scope reviewers to that path where the underlying skill supports it.

(No `--simplify` / `--polish` flags: they always run in suggestion mode.)

## THE ROSTER

`mechanism`: `fork→agent` = try a history-inheriting fork, else a normal Agent with the
diff pasted; `subagent` = a direct read-only subagent call (docs-scout); `workflow` =
`Workflow` fan-out; `workflow+subagent` = Workflow that dispatches scout sub-agents;
`main` = invoked from the main session; `worktree` = spawned in a throwaway
`isolation: "worktree"` agent whose edits are captured as a diff then discarded.
`mode`: `ro` read-only; `suggest` = runs isolated/dry-run, emits proposals, applies
nothing. `tier`: when it runs.

| # | reviewer | invokes | mechanism | mode | tier | notes |
|---|----------|---------|-----------|------|------|-------|
| 0 | **scout invariant gate** | docs-scout vs `C:\Users\t-michaelxu\docs\` | subagent | ro | **FIRST + blocking, project-scoped (default; `--no-scout` skips)** | checks Mode A/B, MSHV/EROFS + config ordering, never-reimage-node, admin-VM-source-of-truth + git-flow, Cameron layering, clone-networking-non-fatal; each finding carries doc file:line + change file:line; threads a PROJECT-CONTEXT blob into every downstream reviewer |
| 1 | verify | project: `counter-`/`harshit-`/`openclaw-snapshot-e2e`; generic: `/verify` (`/run` fallback) | fork→agent | ro | **default** | project verification = the node e2e proofs on node-shell (needs the Windows→azlinux-dev devtunnel); CI is informational |
| 2 | code-review | `/code-review` | fork→agent | ro | **default** | correctness-bug hunt; report only (no `--fix`); rubric dimensions injected |
| 3 | security-review | `/security-review` | fork→agent | ro | **default** | built-in via Skill tool; path-traversal / input-validation / secrets |
| 4 | review (PR) | `/review <pr>` | fork→agent | ro | **default, only if an upstream PR exists** | PR = fork→upstream object (michael → microsoft/kata-containers); branch-only ⇒ `n/a — branch-only`, never fabricate; CI informational |
| 5 | simplify | `/simplify` in a worktree | worktree | **suggest** | **default** | runs isolated; its diff surfaced as suggestions, worktree discarded — main tree untouched |
| 6 | polish | `polish --dry-run` (online plugin) | main | **suggest** | **default** | `--dry-run` = analyze/report only; whole-codebase sweep (cost not a constraint) |
| 7 | adversarial | Workflow: code track + design track → verify | workflow | ro | **opt-in `--adversarial`** | deep fan-out; receives `args.projectContext` from the scout gate |
| 8 | scout (generic wiki) | Workflow + scout sub-agents | workflow+subagent | ro | **opt-in `--scout` (non-project)** | discover internal wiki → sub-scouts ingest md → review change vs docs |

Resolved earlier: polish stays a full unscoped sweep; adversarial goes deep (wide
lenses, multiple skeptics/lens, multi-vote verify, loop-until-dry). Cost is not a
constraint.

## Execution plan

### Phase 0 — Preflight (main session, always)

Parse args. **Detect project scope FIRST** (kata-containers repo, `src/runtime/*`,
`michaelx/*` branch, or CLH/MSHV/EROFS keyword set). Scope decides where the diff comes
from and whether the scout gate + e2e verify apply.

**Project-scoped** — capture the change from the REAL remote tree over the `azl` bridge
(the kata source is on the admin VM + node, NOT the Windows host — a local `git diff`
here returns empty):

```bash
# admin VM is source of truth; node is a read-only consumer
azl -Cwd /home/michaelx/kata-containers 'git status --short && echo "---" && git diff --stat && echo "---DIFF---" && git diff && echo "---LOG---" && git log --oneline -5'
BRANCH=$(azl -Cwd /home/michaelx/kata-containers 'git rev-parse --abbrev-ref HEAD')
# committed-but-unmerged branch delta (snapshot/restore work is usually branch-only, no PR)
azl -Cwd /home/michaelx/kata-containers "git diff \$(git merge-base HEAD origin/main 2>/dev/null || echo HEAD~5)...HEAD"
# fork-aware PR probe, ||-guarded so SAML/auth failure degrades to an echo (never errors)
azl -Cwd /home/michaelx/kata-containers "gh pr view --json number,title,url 2>/dev/null \
  || gh pr list --repo microsoft/kata-containers --head michaelxu2288:\$(git rev-parse --abbrev-ref HEAD) --json number,title,url 2>/dev/null \
  || echo 'no upstream PR — branch-only'"
```

**Generic repo** — local capture:

```bash
git status --short && git diff --stat && git diff && git log --oneline -5
git rev-parse --abbrev-ref HEAD
gh pr view --json number,title,url 2>/dev/null || echo "no PR for current branch"
```

Summarize in 2-3 lines: what changed, files, committed?, branch, PR-or-branch-only.
**Stop only if there is neither a working-tree diff nor an unmerged branch delta.** If
roster #4 is on but it's branch-only, mark it `n/a — branch-only` (not a failure).

### Phase 0.5 — Scout invariant gate (NEW; blocking-FIRST; project-scoped; skip on `--no-scout`)

Before any code reviewer speaks, dispatch ONE read-only `docs-scout` subagent call
against `C:\Users\t-michaelxu\docs\`. It returns:

1. A **PROJECT-CONTEXT blob** (cited invariants relevant to this change) — threaded into
   every downstream reviewer prompt and into the adversarial Workflow's
   `args.projectContext`. This is a blocking barrier: it completes before Phase 1.
2. **Per-class invariant findings**, each with the doc file:line it derives from + the
   change file:line it flags. Invariant classes to check:
   - Mode A (clone/side-by-side) vs Mode B (stop/restore-in-place) — conflation is a bug
   - MSHV / EROFS constraints + config ordering (e.g. `.memory.shared=false` AND
     `.memory.zones[0].shared=false` for COW)
   - **never reimage/reboot/deallocate/drain/scale/upgrade the node**
   - admin-VM-is-source-of-truth + git-flow (push to `michael`, never `origin`)
   - Cameron layering (shim-owned vs raw-clone model)
   - clone-networking-is-non-fatal (dup-MAC latent, no-egress documented)

**Catastrophic short-circuit** — if the change would reimage/reboot the node, switch
MSHV→KVM, push to `origin`, or embed a live secret, lead the report with
**NEEDS-DECISION** — but still run the remaining read-only reviewers (it flags +
foregrounds, never halts).

**Fallback (docs-scout unavailable):** don't stall the run. Read the 2-3 key invariant
docs inline (`docs\CLAUDE.md`, `docs\project\CLAUDE.md`,
`docs\project\aks-kata-node-context.md`) or note *"scout unavailable — invariants
unchecked"* and proceed to the code reviewers. Every other reviewer has a fallback; so
does this one.

### Phase 1 — Default read-only reviewers (parallel)

Launch roster rows #1-#4 (row #4 only if an upstream PR exists) **in a single message**.
Thread the Phase-0.5 PROJECT-CONTEXT blob into every prompt so reviewers don't
re-derive Kata context.

- Preferred: `Agent` with `subagent_type: "fork"` — inherits the change + intent.
- Fallback: normal `Agent`, **paste the Phase-0 diff + PROJECT-CONTEXT into the prompt**.

**Row #1 verify (project-scoped):** invoke the node e2e proof skills —
`counter-snapshot-e2e` (heap/COW + re-snapshot), `harshit-snapshot-e2e` (filesystem
COW), `openclaw-snapshot-e2e` (~2 GB real workload). Requires the Windows→azlinux-dev
devtunnel. Verdict = did the proof pass. Generic-scoped: `/verify` (`/run` fallback).

**Rows #2/#3 (code-review, security-review):** inject the rubric's review dimensions
into the prompt:
- **timeout** — never `getClhSnapshotTimeout()`≈1s or CLI `defaultTimeout=3s`; a
  client-side timeout that silently negates a server-side fix (finding C1) is Critical
- **CLH lifecycle / orphan-reaping** — kill needles must match the actual launch cmd
  even under `--clh-bin` override (finding F1)
- **per-clone identity** — MAC / IP-route / vsock-cid / host-singletons uniqueness
- **guest-state divergence** — RNG / clock / monotonic must be consciously deferred,
  never silently shared
- **snapshot/restore consistency** — self-contained dir; `.file` rewritten, not just
  `shared` (findings BUG2/H4)
- **code-quality** — `%w` wrapping; reuse the generated CLH client not raw HTTP; no
  shelling-out where an in-tree API exists

**Row #4 rider:** inject the resolved upstream PR number/URL into the spawned reviewer
and state that CI is informational, never a blocker (roster notes don't auto-propagate
to sub-agents).

Reviewer prompt shape:

> You already know the change under review (in this conversation / pasted below) and
> the PROJECT-CONTEXT invariants. Invoke the `<X>` skill / run the `<proof>`. Return
> ONLY a terse verdict PASS/FAIL/CONCERNS, then bulleted findings, each with a severity
> (blocker / major / minor / nit), a file:line, and a one-line title. No diffs or
> transcripts back.

### Phase 1b — Suggestion tier (simplify + polish, no mutation) — default, parallel

Always run, never change the working tree:
- **simplify** — spawn `Agent` with `isolation: "worktree"` invoking `/simplify` inside
  the fresh worktree; capture its `git diff` as the **suggestions list**; discard the
  worktree. Main checkout untouched.
- **polish** — invoke the `polish` skill from the **main session** with `--dry-run`
  (report only). Do NOT wrap it in `Agent(fork)` (it self-forks). Collect proposals.

Both feed a **Suggestions** section — the designer decides. (Background agents notify
you as they finish; do NOT poll/sleep — continue to any opt-in tiers, then synthesize.)

### Phase 2 — Adversarial review (Workflow) — only if `--adversarial` / `--all`

Go **deep** — cost is not a constraint. Two tracks (attack the **code change** and the
**design**), each with a wide lens set, multiple independent skeptics per lens, a
perspective-diverse multi-vote verify, and a loop-until-dry outer loop. The Workflow
receives `args.projectContext` (the scout blob) and prepends it to each attacker/critic
so skeptics attack against real documented invariants.

```js
export const meta = {
  name: 'review-all-adversarial',
  description: 'Deep adversarial fan-out over the code change AND the design',
  phases: [{ title: 'Attack-Code' }, { title: 'Attack-Design' }, { title: 'Verify' }],
}
const FINDINGS_SCHEMA = {
  type: 'object', required: ['findings'],
  properties: { findings: { type: 'array', items: {
    type: 'object', required: ['title','severity'],
    properties: {
      title: { type: 'string' },
      severity: { type: 'string', enum: ['blocker','major','minor','nit'] },
      file: { type: 'string' }, line: { type: 'number' },
      dimension: { type: 'string' }, evidence: { type: 'string' },
    } } } },
}
const VERDICT_SCHEMA = {
  type: 'object', required: ['confirmed'],
  properties: {
    confirmed: { type: 'boolean' },
    disposition: { type: 'string', enum: ['kept','killed','softened'] },
    steelman: { type: 'string' }, rationale: { type: 'string' },
    adjustedSeverity: { type: 'string', enum: ['blocker','major','minor','nit'] },
  },
}
const ctx = args.projectContext ? `PROJECT-CONTEXT invariants:\n${args.projectContext}\n\n` : ''
const CODE_LENSES = ['correctness','edge-cases','concurrency','error-handling','security',
  'performance','resource-leaks','api-contract','backward-compat','hidden-state',
  'input-validation','failure-modes','test-coverage','timeout','clh-lifecycle',
  'per-clone-identity','guest-state-divergence','snapshot-consistency']
const DESIGN_AXES = ['fit-with-system','alternatives-not-taken','future-proofing',
  'interface-contract','complexity-budget','operability','data-model',
  'failure-blast-radius','migration-safety','mode-a-vs-b']
const SKEPTICS_PER = 3, MAX_ROUNDS = 4, DRY_STREAK = 2
const seen = new Set(), confirmed = []
const key = f => `${f.file || f.dimension}:${f.line || ''}:${(f.title||'').slice(0,60)}`
let dry = 0
for (let round = 0; round < MAX_ROUNDS && dry < DRY_STREAK; round++) {
  const codeThunks = CODE_LENSES.flatMap(lens =>
    Array.from({length: SKEPTICS_PER}, (_, k) => () =>
      agent(`${ctx}Round ${round} attacker #${k} on the ${lens} lens. Adversarially review this CHANGE — try to BREAK it, find a defect the others will miss. Diff:\n${args.diff}\nConcrete findings with severity + file:line, or "no defect found".`,
        { label: `adv-code:${lens}#${k}`, phase: 'Attack-Code', schema: FINDINGS_SCHEMA })))
  const designThunks = DESIGN_AXES.flatMap(axis =>
    Array.from({length: SKEPTICS_PER}, (_, k) => () =>
      agent(`${ctx}Round ${round} critic #${k} on the "${axis}" axis. Critique the DESIGN — what would a senior reviewer object to? Change:\n${args.diff}\nContext:\n${args.summary}\nConcrete design objections with severity, or "design sound".`,
        { label: `adv-design:${axis}#${k}`, phase: 'Attack-Design', schema: FINDINGS_SCHEMA })))
  const found = (await parallel([...codeThunks, ...designThunks]))
    .filter(Boolean).flatMap(r => r.findings || [])
  const fresh = found.filter(f => !seen.has(key(f)))
  if (!fresh.length) { dry++; log(`round ${round}: no new findings (dry ${dry}/${DRY_STREAK})`); continue }
  dry = 0; fresh.forEach(f => seen.add(key(f)))
  const LENSES_V = ['does-it-actually-reproduce','is-it-in-scope-of-this-change','severity-honest']
  const judged = await parallel(fresh.map(f => () =>
    parallel(LENSES_V.map(v => () =>
      agent(`${ctx}Verify finding via the "${v}" lens. Default to refuted if uncertain: ${JSON.stringify(f)}`,
        { label: `verify:${v}`, phase: 'Verify', schema: VERDICT_SCHEMA })))
      .then(votes => ({ f, ok: votes.filter(Boolean).filter(x => x.confirmed).length > LENSES_V.length/2 }))))
  confirmed.push(...judged.filter(j => j.ok).map(j => j.f))
  log(`round ${round}: ${fresh.length} fresh, ${judged.filter(j=>j.ok).length} confirmed`)
}
return confirmed  // dedup is vs `seen`, so rejected findings don't re-appear each round
```

### Phase 3 — Generic scout wiki review (Workflow) — only if `--scout` on a non-project repo

For a non-project repo that still has an internal wiki. (Project-scoped changes use the
Phase-0.5 gate instead.)

```js
export const meta = {
  name: 'review-all-scout',
  description: 'Discover internal wiki, ingest, review change against it',
  phases: [{ title: 'Discover' }, { title: 'Ingest' }, { title: 'Review' }],
}
const ROOTS_SCHEMA = { type: 'object', required: ['clusters'], properties: { clusters: {
  type: 'array', items: { type: 'object', required: ['name','paths'], properties: {
    name: { type: 'string' }, paths: { type: 'array', items: { type: 'string' } } } } } } }
const SUMMARY_SCHEMA = { type: 'object', required: ['rules'], properties: { rules: {
  type: 'array', items: { type: 'object', required: ['rule','source'], properties: {
    rule: { type: 'string' }, source: { type: 'string' } } } } } }
const roots = await agent(
  `Find this repo's internal knowledge base: docs/, wiki/, .github/, ADRs, RFCs, root *.md, CONTRIBUTING/ARCHITECTURE. Return dirs/files holding durable conventions.`,
  { label: 'scout:discover', phase: 'Discover', schema: ROOTS_SCHEMA })
const summaries = await parallel(roots.clusters.map(c => () =>
  agent(`Ingest these docs, extract only rules/invariants/conventions relevant to a code change: ${c.paths.join(', ')}. Cite file paths. Compact.`,
    { label: `scout:${c.name}`, phase: 'Ingest', schema: SUMMARY_SCHEMA })))
return await agent(
  `Documented conventions:\n${JSON.stringify(summaries)}\nChange:\n${args.diff}\nList where the change VIOLATES or DRIFTS from documented rules. severity + file:line + the doc it violates.`,
  { label: 'scout:review', phase: 'Review', schema: FINDINGS_SCHEMA })
```

### Phase 4 — FP-suppression / severity-deflation (NEW; before the final gate)

This is the discipline the project's own reviews are built on (the swarms killed 43+
findings and *downgraded* H2/H5/H7). Before printing the report, disposition every
survived finding:

1. **Re-read exact source on the CURRENT branch HEAD** (over `azl` for project scope) —
   confirm the cited file:line still says what the finding claims.
2. **Per-finding steelman** — argue against the finding in good faith. If the steelman
   holds, mark it KILLED.
3. **2-of-3-skeptic majority kill** — three differently-primed skeptics vote; refuted by
   ≥2 ⇒ dropped.
4. Disposition each as **KEPT / KILLED / SOFTENED** (softened = real but lower severity
   than first claimed, e.g. High-security → Medium foot-gun).
5. **Shared dedup** — collapse duplicate findings on a canonical key
   (normalized-path:line ±3 + fuzzy title) with a `raised-by:` list. **Record the
   severity SPREAD; do NOT auto-escalate to the highest claimed severity** (that would
   re-inflate exactly the findings the team deflated). Flag divergence for the designer.

Known must-NOT-fabricate false positives from the corpus (if any reviewer raises these,
kill them): "VCSandbox missing Save/PauseVM/SaveVMTo" (all declared, all backends
implement); "s.ctx/s.id unverified" (present in service.go).

### Phase 5 — Synthesize (main session)

```
## review-all report — <branch> @ <short-sha>   scope: <project|generic>
change: <1-line summary>   files: <n>   PR: <url | n/a — branch-only>   tiers: <default|+adversarial|+scout>
CI: <informational — not a gate>

### scout invariant gate (leads the report)
- <invariant violations as HARD GATES, each with doc file:line → change file:line>
- doc CONTRADICTIONS surfaced for the USER to apply (skill never edits the wiki)

| reviewer        | verdict  | blockers | major | minor |
|-----------------|----------|----------|-------|-------|
| scout-gate      | ...      | ...      | ...   | ...   |
| verify (e2e)    | PASS     | 0        | 0     | 1     |
| code-review     | CONCERNS | 1        | 2     | 0     |
| security-review | PASS     | 0        | 0     | 0     |
| adversarial     | (skipped — pass --adversarial)     |

### blockers (must fix)
### major   (each tagged KEPT/SOFTENED + severity spread if reviewers diverged)
### suggestions (from simplify + polish — designer's call, nothing applied)
- simplify: ...
- polish:   ...
### killed by FP-suppression (shown for transparency)
```

Show opt-in tiers that weren't requested as `skipped`. **CI red/pending is a note, never
forces FIX-FIRST** — the gate is the change working (the e2e proof). End with a single
gate: **SHIP / FIX-FIRST / NEEDS-DECISION** (catastrophic-invariant hit forces
NEEDS-DECISION).

## Guardrails

- **Read-only, including the docs wiki.** Default reviewers report only; simplify/polish
  run isolated/dry-run; docs-scout CONTRADICTIONS are surfaced for the user to apply.
- **never-touch-the-node is a hard invariant** the gate checks AND the skill obeys — no
  reimage/reboot/deallocate/drain/scale/upgrade, ever.
- Respect git-safety: never commit/branch/push without the user giving the exact
  message/name; push to `michael`, never `origin`.
- Keep reviewer return payloads terse — verdict + findings array, never transcripts.
```
