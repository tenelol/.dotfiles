{ pkgs, lib, ... }:

{
  # 既存の incus.service の PATH の「後ろに」 zstd を足す
  systemd.services.incus.path = lib.mkAfter [ pkgs.zstd ];
}

