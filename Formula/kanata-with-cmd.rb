# frozen_string_literal: true

# Installs Kanata's official macOS binary with command actions enabled.
class KanataWithCmd < Formula
  desc "Cross-platform keyboard remapper with command actions enabled"
  homepage "https://github.com/jtroo/kanata"
  url "https://github.com/jtroo/kanata/releases/download/v1.12.0/macos-binaries-arm64.zip"
  sha256 "839769d189911b5881e11550eaa2039705213fb725865d088f5a2e3a6c10de32"
  license "LGPL-3.0-only"

  def install
    bin.install "kanata_macos_cmd_allowed_arm64" => "kanata"
  end

  test do
    system bin/"kanata", "--version"
  end
end
