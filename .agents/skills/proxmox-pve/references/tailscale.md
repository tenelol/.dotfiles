# PVE host上のTailscale

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## Tailscale on a PVE host

- Inspect `systemctl is-enabled tailscaled`, `systemctl is-active tailscaled`, `tailscale status --json`, and `tailscale debug prefs` before changing the topology or access policy.
- Keep the PVE host directly reachable when Tailscale is the only remote management path. Moving Tailscale into a guest makes host access depend on that guest starting successfully; treat that as an architecture change and ask before applying it.
- If the PVE host accepts Tailscale DNS and does not need MagicDNS locally, use `tailscale set --accept-dns=false`. This avoids propagating `100.100.100.100` into an LXC that does not run Tailscale.
- Do not make the PVE host a subnet router, exit node, or Tailscale SSH server unless the user explicitly needs that role.
- Inspect the existing tailnet policy and device ownership before narrowing access. Grants are additive, so a broad wildcard grant continues to allow traffic even if a narrower grant is added.
- To isolate the PVE destination safely:
  1. Declare a PVE tag owner and a limited management grant while the device is still user-owned.
  2. Preserve required rules for other user-owned devices, commonly `autogroup:member` to `autogroup:self`.
  3. Preview the compiled rules and save the policy.
  4. Apply the PVE tag, which changes the device from user-owned to tag-owned.
  5. From a separate management client, verify TCP 22 and 8006, verify a non-allowed listening port is denied, and confirm unrelated guest connectivity still works.
- Keep tailnet login names, node keys, auth keys, API tokens, and host-specific policy values out of the skill.
