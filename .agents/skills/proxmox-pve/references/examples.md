# 運用上の既定値と操作例

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## Practical defaults

- Prefer API tokens over password login
- Prefer SSH keys or an agent over passwords for node or guest shell access
- Prefer least privilege after the workflow is proven
- Prefer reads first, writes second
- Prefer targeting a specific path such as `/vms/103` when the user only needs one guest
- If the user shares a token in chat, recommend rotating or deleting it after the task
- If the user shares SSH credentials in chat, recommend rotating them after the task

## Example sequence

1. `pve-api.sh /version`
2. `pve-api.sh /nodes`
3. `pve-api.sh /nodes/pve/lxc/103/status/current`
4. `pve-lxc-exec.sh 103 -- sh -lc 'hostname && systemctl status nginx --no-pager'`
5. If requested, `pve-api.sh -X POST /nodes/pve/lxc/103/status/reboot`
