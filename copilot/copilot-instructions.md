# Global Copilot Instructions

## Copilot CLI behavior

- This machine's source-of-truth agent configuration is `C:\Users\t-michaelxu\claude-code-config`.
- Treat the Windows setup as Copilot CLI-first. Claude Code files in this repo are legacy/compatible config, not the primary Windows workflow.
- Read `C:\Users\t-michaelxu\docs\` for persistent machine/project reference before starting work that touches MCPs, tools, project setup, or prior investigation context. In particular, check `C:\Users\t-michaelxu\docs\mcp.md` and any relevant Markdown under `C:\Users\t-michaelxu\docs\project\`.
- Be concise and direct.
- Keep explanations short, direct, and technical by default. Only give long, detailed explanatory answers when the user explicitly includes the keyword `eli5`.
- Use Windows-style paths with backslashes when working on the Windows host.
- Prefer precise tool use: read/search enough context first, make surgical changes, and validate the exact requested behavior.
- Do not auto-commit, create branches, push, or trigger remote pipelines without explicit confirmation.
- Before any git commit, branch, or push that needs a message/name, ask for the exact commit message or branch name.
- Use Zellij for long-running terminal workflows. Keep one pane for the agent, one for shell/test commands, and another only when logs or watch processes are useful.

## Devbox / Linux VM access

Preferred topology for this machine:

- Original Windows machine runs VS Code, Copilot CLI, Zellij, and the devtunnel client.
- Azure Core Windows devbox hosts the Hyper-V Azure Linux VM.
- Azure Linux VM is the real development target for Linux work.
- Connection path: original Windows -> devtunnel -> Azure Linux VM inside the Windows devbox.
- Do not target the Windows devbox itself for Linux work; it is only the VM host.

Current Linux VM details:

- Linux user: `michaelx`
- Dev tunnel ID: `azldev`
- SSH port: `22`
- VS Code Remote-SSH host alias: `azlinux-dev`
- Recommended SSH config on original Windows:

```sshconfig
Host azlinux-dev
    HostName 127.0.0.1
    User michaelx
    Port 22
    IdentityFile C:\Users\t-michaelxu\.ssh\azlinux-dev
    IdentitiesOnly yes
```

Required running processes:

1. Inside the Azure Linux VM, keep the tunnel host running:

```bash
$HOME/bin/devtunnel host azldev
```

This currently runs inside tmux:

```bash
tmux attach -t devtunnel
```

Detach without stopping it using Ctrl+B, then D.

2. On original Windows, keep the client tunnel running:

```powershell
devtunnel connect azldev
```

Then VS Code on original Windows can connect via Remote-SSH to `azlinux-dev`.

Long-term improvement: replace the tmux-hosted `devtunnel host azldev` with a systemd service inside the Azure Linux VM so it starts automatically after VM reboot.

## Azure Linux devtunnel setup gotchas

The official devtunnel install script assumes `apt-get`, which fails on Azure Linux. Use direct binary install instead:

```bash
sudo dnf install -y icu libsecret openssh-server tmux
mkdir -p "$HOME/bin"
curl -L "https://tunnelsassetsprod.blob.core.windows.net/cli/linux-x64-devtunnel" > "$HOME/bin/devtunnel"
chmod +x "$HOME/bin/devtunnel"
"$HOME/bin/devtunnel" --version
```

If `libsecret` is not found, enable the Azure Linux extended repo first.

## Windows Copilot CLI to Azure Linux SSH bridge

Use this workflow when Copilot CLI is running on the original Windows machine but the real development target is the Azure Linux VM.

Important rules:

- Copilot CLI stays on Windows; it does not literally run inside SSH unless Copilot is installed in the VM.
- For Linux/devbox work from Windows Copilot CLI, run commands through SSH to `azlinux-dev`.
- Prefer `azl` instead of raw `ssh` for one-shot commands because it handles remote cwd and quoting more reliably.
- Do not run Linux build/test/dev commands directly on Windows unless explicitly asked.

Windows helper commands:

```powershell
C:\Users\t-michaelxu\bin\azl.cmd
C:\Users\t-michaelxu\bin\azl.ps1
C:\Users\t-michaelxu\bin\azl-git-apply.cmd
C:\Users\t-michaelxu\bin\azl-git-apply.ps1
```

Basic remote command:

```powershell
azl 'hostname && whoami && pwd && uname -a'
```

Run a command in a remote repo/directory:

```powershell
azl -Cwd /home/michaelx/myrepo 'git status'
azl -Cwd /home/michaelx/myrepo 'npm test'
azl -Cwd /home/michaelx/myrepo 'make test'
```

If PATH has not picked up `C:\Users\t-michaelxu\bin` yet, use the full wrapper path:

```powershell
C:\Users\t-michaelxu\bin\azl.cmd -Cwd /home/michaelx 'pwd'
```

Raw SSH fallback:

```powershell
ssh azlinux-dev
ssh azlinux-dev 'hostname && whoami && pwd'
```

Dev tunnel requirements:

```powershell
devtunnel connect azldev
```

Inside Azure Linux, the tunnel host should already be running in tmux:

```bash
tmux attach -t devtunnel
$HOME/bin/devtunnel host azldev
```

Detach from tmux without stopping the tunnel:

```text
Ctrl+B, then D
```

Apply edits to a Linux git repo from Windows Copilot CLI:

1. Generate a local unified diff patch.
2. Check it remotely:

```powershell
azl-git-apply -Cwd /home/michaelx/myrepo -PatchFile C:\path\to\change.patch -CheckOnly
```

3. Apply it remotely:

```powershell
azl-git-apply -Cwd /home/michaelx/myrepo -PatchFile C:\path\to\change.patch
```

Kubernetes/node-shell from Windows Copilot CLI:

```powershell
azl 'k version --client'
azl 'k get nodes'
azl 'k node-shell aks-nodepool1-23826427-vmss000000'
```

`k node-shell` is interactive. Copilot can start it and verify it spawns a pod, but should not hold a long interactive shell inside chat. Prefer non-interactive Kubernetes commands, or pass a specific command if the installed node-shell plugin supports command execution.

Known working node-shell test:

```powershell
azl 'timeout 30s k node-shell aks-nodepool1-23826427-vmss000000'
```

Expected behavior: it spawns an `nsenter-*` pod on the node, then times out/deletes the pod if no interactive input is provided.

Current AKS Kata project shortcuts:

- Persistent project handoff: `C:\Users\t-michaelxu\docs\project\aks-kata-node-context.md`.
- Kubernetes context: `testabc123`.
- Custom Kata experiment node: `aks-nodepool1-23826427-vmss000000`.
- Final target nodepool family: original normal Azure Linux `nodepool1` with MSHV. `erofspool` / ACL is diagnostic proof only, not final.
- Current custom runtime source checkout on that AKS node: `/kata-containers`.
- Current build/deploy path on that AKS node:

```bash
cd /kata-containers/tools/osbuilder/node-builder/azure-linux
make all
make deploy
```

- Keep using existing RuntimeClass `kata` and manifest `/home/michaelx/kata-busybox-long-pod.yaml` unless explicitly asked to change them.
- Prefer existing node-debugger pods for non-interactive node commands instead of spawning new shells:

```powershell
azl 'k exec -n default node-debugger-aks-nodepool1-23826427-vmss000000-bw5nx -- chroot /host /bin/bash -lc "<node command>"'
```

- Kata logs from the AKS node:

```powershell
azl 'k exec -n default node-debugger-aks-nodepool1-23826427-vmss000000-bw5nx -- chroot /host journalctl --no-hostname -o cat -t kata -n 200'
```

Current AKS Kata final-target guardrails:

- Final target must be normal Microsoft Azure Linux AKS with MSHV, matching the original `nodepool1` style as closely as possible.
- Do not use Azure Container Linux (ACL/BYOI) as the final project target. It is diagnostic proof only that EROFS + VM-template can work when prerequisites exist.
- Preserve MSHV as the final hypervisor/kernel path; do not switch the final target to KVM unless explicitly asked.
- Cameron already booted nodepool0 into a locally rebuilt MSHV+EROFS kernel: `aks-nodepool1-23826427-vmss000000` now runs `6.6.135.mshv2+` with `CONFIG_EROFS_FS=y`.
- Current final-target work should use nodepool0 (`aks-nodepool1-23826427-vmss000000`), not ACL/erofspool.
- The next final-target step is rerunning Harshit's VM-template proof on nodepool0 with the custom `6.6.135.mshv2+` kernel and EROFS-enabled containerd.
- Prefer the user's `k` alias in Kubernetes examples/commands.
- Only use Kubernetes/node-shell command patterns already used in this project or present in shell history unless explicitly approved.
- Known-safe command shapes include:

```bash
k get nodes -o wide
k get runtimeclass
k get pod <pod> -o wide
k logs <pod>
k describe pod <pod>
k get pod <pod> -o yaml
k get events --sort-by=.lastTimestamp
k node-shell <node>
k exec -n default <node-debugger-pod> -- chroot /host /bin/bash -lc '<node command>'
```
