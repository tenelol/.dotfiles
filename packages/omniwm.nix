{ omniwm, fetchurl }:
# The pinned release predates the fix for swallowed two-finger scrolling.
omniwm.overrideAttrs (final: _: {
  version = "0.8.0";
  src = fetchurl {
    url = "https://github.com/OmniNull/OmniWM/releases/download/v${final.version}/OmniWM-v${final.version}.zip";
    hash = "sha256-b3+z4hHeOoPncrExgAaAyz0g1MY4gRofAhIP0iXwPMc=";
  };
})
