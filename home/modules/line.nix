{ ... }:
{
  home.file.".local/bin/line-firefox" = {
    source = ../../config/scripts/line-firefox;
    executable = true;
  };

  xdg.desktopEntries.line-web = {
    name = "LINE";
    comment = "Open LINE extension in Firefox";
    exec = "line-firefox";
    icon = "line";
    categories = [ "Network" "Chat" ];
    terminal = false;
  };
}
