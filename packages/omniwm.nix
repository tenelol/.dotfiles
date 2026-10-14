{ omniwm, fetchurl }:
# The pinned release predates the fix for swallowed two-finger scrolling.
omniwm.overrideAttrs (final: _: {
  version = "0.7.6";
  src = fetchurl {
    url = "https://github.com/OmniNull/OmniWM/releases/download/v${final.version}/OmniWM-v${final.version}.zip";
    hash = "sha256-7IxhRqbyGnnhxArHDWESF2K5PPU80wjmPrROis4g/Nw=";
  };
})
