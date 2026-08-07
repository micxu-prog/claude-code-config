---
name: voice-to-text
description: Decode a raw voice-to-text / WhisperFlow dictation from the user into clean written text that still sounds like them. Use whenever the user pastes obviously dictated input (missing punctuation, mangled spelling like "eveyrhtign" or "scfipt", run-on sentences, mid-sentence self-corrections), says "here's a voice note", "I dictated this", "clean this up", "decode this", or when a message is clearly spoken rather than typed. Also use to split a rambling dictation into an ordered list of actual asks so nothing gets dropped.
---

Turn dictated speech into clean text **without turning it into someone else's writing**.

The user dictates fast with WhisperFlow. The transcript arrives mangled: letters transposed, spaces missing, punctuation absent, homophones wrong, sentences abandoned halfway and restarted. Their *intent* is almost always recoverable. Your job is recovery, not improvement.

## The one rule

**Decode, don't rewrite.** You are fixing transmission errors, not editing prose. If you find yourself reaching for a better word than the one they said, stop. The word they said is the deliverable.

Three things you may do: fix mangled spelling, insert punctuation and sentence boundaries, resolve obvious homophones.

Everything else is off limits unless they ask. Specifically **never**:

- Upgrade vocabulary ("thing" stays "thing", not "component")
- Add transitions they didn't say ("moreover", "additionally", "that said")
- Add hedges or politeness ("I think maybe", "if you don't mind", "please note")
- Expand short blunt sentences into full ones
- Merge their choppy sentences into flowing paragraphs
- Sand off bluntness, impatience, or profanity
- Add a greeting, sign-off, or summary they didn't dictate
- Invent a number, name, path, flag, or technical detail that wasn't spoken

Their register is short, direct, lowercase-ish, technical, occasionally impatient. That IS the voice. A cleaned version that reads smooth and corporate is a failed decode.

## Handling self-correction

Dictation contains abandoned branches: *"instead of bullet points, actually no, bullet points are good because..."*

Keep the **final** decision. Drop the abandoned branch silently when it's a simple reversal. But if the reversal changed the scope of the ask, say so in one line after the clean text, because the user may not remember they flipped.

Same for repeated words, false starts, and filler ("like", "basically", "um"). Cut them, unless the filler is load-bearing for tone in something they'll send as-is.

## Splitting the asks

Long dictations usually jam several requests together with no punctuation. This is where things get silently dropped.

After the clean text, if the dictation contained **more than one ask**, list them as a numbered checklist in the order given. Do not merge two asks into one. Do not reorder them into what seems logical. If an ask is conditional ("if that works then also do X"), keep the condition attached.

## When you can't tell

Do not guess on: technical terms, file names, paths, flags, numbers, people's names, or anything that changes what gets built.

Write your best reading, mark it `[?]`, and ask in one short line at the end. One question, not a list. Guessing wrong on a path costs more than asking.

If the whole sentence is unrecoverable, quote the raw fragment and ask, rather than inventing a plausible sentence around it.

## Common manglings in this user's transcripts

Observed patterns, useful for fast recovery:

| Mangled | Almost always |
|---|---|
| `eveyrhtign` / `reveything` / `veeyhtign` | everything |
| `scfipt` / `sriprt` / `scirpt` | script |
| `ulrtrahtink` | ultrathink |
| `trnscirtion` | transcription |
| `exprot` / `exprt` | export |
| `artifat` / `arrtifact` | artifact |
| `impronmts` / `improvments` | improvements |
| `compliated` | complicated |
| `qukity` | quality |
| `recorign` | recording |
| `dosent` | doesn't |
| `hwo ot` | how to |
| `decrypt` (about text) | decipher / decode |
| `plz` `u` `ur` `rn` `ima` `wanna` `thx` | leave as-is if informal; expand only for outward-facing text |

Word boundaries drop constantly: `i nrunbook` is `in runbook`, `n rformat` is `in format`. Read for the boundary, not the token.

Domain terms that get mis-transcribed and must never be "corrected" into English words:

`kata` (not "cotton"/"karate") · `containerd` (not "container D") · `crictl` · `kubectl` · `openclaw` · `nodepool` · `EROFS` · `CLH` / cloud-hypervisor · `MSHV` · `AKS` · `devtunnel` · `azl` · `vmss` · `CNI` · `runc` · `PS1` · `ffmpeg` · `Clipchamp`

## Modes

Default is **clean**: return the decoded text and nothing else.

- **clean** (default) — decoded text only. No commentary, no "here's your cleaned version" preamble.
- **asks** — decoded text, then the numbered checklist of every distinct request.
- **draft** — the dictation is raw material for something outward-facing (a message, a doc, a PR description). Decode first, then shape it into that format while keeping their word choices. Say which format you assumed.

Infer the mode from context. If they dictated instructions to you, you usually want **asks**. If they dictated something to send to a person, you want **draft**. If they just said "clean this up", **clean**.

## Output

Return the decoded text directly. No preamble, no "I've cleaned this up for you", no explanation of what you fixed. They can see what they said.

The only things allowed after the text: the numbered ask-list (in `asks` mode), one line about a scope-changing self-correction, and one `[?]` question if something was genuinely unrecoverable.

If the dictation is already clean enough to read, say so in three words and don't touch it.
