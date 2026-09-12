この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

# Proxmox VE Operations

Use the Proxmox VE HTTPS API for lifecycle and config operations, and use SSH for shell-level work.

## When to use

- The user wants to inspect or operate Proxmox VE from Codex
- The user provides a Proxmox Web UI URL, node name, VMID, or CTID
- The task is about node status, VM/LXC status, config, start/stop/reboot, snapshots, backups, or shell commands inside a guest
- The task needs shell access through node SSH, `pct exec`, or direct guest SSH

## Required inputs

Ask for or confirm these when missing:

- `PVE_HOST`
- `PVE_TOKEN_ID`
- `PVE_TOKEN_SECRET`
- Node name when not discoverable from `/nodes`
- Target ID and type when ambiguous (`qemu` or `lxc`)
- SSH path for shell work:
  - Node SSH: `PVE_SSH_HOST`, `PVE_SSH_USER`, and key or agent access
  - Guest SSH when available: guest host/IP and user

Do not store secrets in repo files or inside the skill. Prefer one-shot environment variables in the current shell session.
If the user wants persistence across sessions, prefer a local config file such as `~/.config/proxmox-pve/config.env` with restrictive permissions instead of repo-local files.

## Workflow

1. Confirm reachability first.
- Probe `https://$PVE_HOST:8006/api2/json/version` with the API token.
- If the user only gives a Web UI URL, extract the host and ignore the `#...` fragment.

2. Start with read-only inspection.
- Check `/version`, `/nodes`, and then the target resource.
- Prefer status and config reads before any change.
- If the target type is unclear, inspect `/nodes/<node>/lxc` and `/nodes/<node>/qemu`.

3. Handle permissions explicitly.
- `401 Authentication failed` means token or secret is wrong.
- `Permission check failed` means the token lacks ACLs for the target path or privilege separation is blocking inherited permissions.
- If privilege separation is on, add API token ACLs explicitly or temporarily disable separation for initial validation.

4. Choose the shell path pragmatically.
- For LXC shell work, prefer SSH to the Proxmox node and run `pct exec <vmid> -- ...`.
- For LXC interactive troubleshooting, use node SSH and `pct enter <vmid>` only when an interactive TTY is truly needed.
- For QEMU shell work, prefer direct SSH to the guest OS.
- Only consider `qm guest exec` if the QEMU guest agent is installed and direct SSH is unavailable.

5. Only make state changes after explicit user intent.
- Safe reads can proceed without reconfirmation.
- For start, stop, reboot, snapshot creation, restore, delete, or config mutation, ensure the user actually asked for that action.

6. Report outcomes in practical terms.
- Include node, VMID/CTID, type, current status, and any task UPID returned by write operations.
- For shell work, include the exact command path used: node SSH, `pct exec`, or guest SSH.

## Default command path

Prefer the bundled helper:

```bash
/Users/tener/.agents/skills/proxmox-pve/scripts/pve-api.sh /version
```

The helpers auto-load this file when present:

```bash
~/.config/proxmox-pve/config.env
```

It expects:

```bash
export PVE_HOST='100.122.252.38'
export PVE_TOKEN_ID='root@pam!codex'
export PVE_TOKEN_SECRET='...'
export PVE_SSH_HOST='100.122.252.38'
export PVE_SSH_USER='root'
export PVE_SSH_OPTS='-i /Users/tener/.ssh/id_ed25519_proxmox_pve -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes'
```

If needed, inline `curl` is acceptable:

```bash
curl -ksS \
  -H "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}" \
  "https://${PVE_HOST}:8006/api2/json/version"
```

For node shell access:

```bash
/Users/tener/.agents/skills/proxmox-pve/scripts/pve-node-ssh.sh hostname
```

For LXC commands through the node:

```bash
/Users/tener/.agents/skills/proxmox-pve/scripts/pve-lxc-exec.sh 103 -- uname -a
```

## Common API paths

Read operations:

```bash
... /version
... /nodes
... /nodes/<node>/lxc
... /nodes/<node>/qemu
... /nodes/<node>/lxc/<vmid>/status/current
... /nodes/<node>/qemu/<vmid>/status/current
... /nodes/<node>/lxc/<vmid>/config
... /nodes/<node>/qemu/<vmid>/config
```

State changes:

```bash
... /nodes/<node>/lxc/<vmid>/status/start
... /nodes/<node>/lxc/<vmid>/status/stop
... /nodes/<node>/lxc/<vmid>/status/reboot
... /nodes/<node>/qemu/<vmid>/status/start
... /nodes/<node>/qemu/<vmid>/status/stop
... /nodes/<node>/qemu/<vmid>/status/reboot
```

Use `POST` for state changes.

## Shell patterns

Node shell:

```bash
pve-node-ssh.sh hostname
pve-node-ssh.sh pct list
```

LXC shell via node SSH:

```bash
pve-lxc-exec.sh 103 -- sh -lc 'id && hostname && pwd'
pve-node-ssh.sh pct enter 103
```

VM shell:

```bash
ssh user@guest-ip
```

Prefer direct guest SSH for VMs. Only fall back to `qm guest exec` when the guest agent is known to be installed and the task specifically needs it.
