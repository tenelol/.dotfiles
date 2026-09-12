# SSHの設定・診断

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## SSH setup notes

- For root SSH on Proxmox VE, the practical cluster-wide key location is `/etc/pve/priv/authorized_keys`
- On a clustered setup, adding a public key there once propagates to all nodes in the cluster
- If node SSH fails with `Permission denied (publickey,password)`, verify that the correct public key is present in `/etc/pve/priv/authorized_keys`
- After adding a key, verify node SSH first, then verify guest shell access through `pct exec`

Verification sequence:

```bash
PVE_SSH_HOST=host PVE_SSH_USER=root PVE_SSH_OPTS='-i /path/to/key' pve-node-ssh.sh hostname
PVE_SSH_HOST=host PVE_SSH_USER=root PVE_SSH_OPTS='-i /path/to/key' pve-lxc-exec.sh 103 -- sh -lc 'id && hostname'
```
