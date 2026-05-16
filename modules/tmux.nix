{ delib, pkgs, ... }:
delib.module {
  name = "tmux";

  home.always = {
    programs.tmux = {
      enable = true;
      package = pkgs.tmux;

      prefix = "F12";
      keyMode = "vi";
      mouse = true;
      focusEvents = true;
      baseIndex = 1;
      clock24 = true;
      customPaneNavigationAndResize = true;
      escapeTime = 10;
      historyLimit = 50000;
      resizeAmount = 5;
      terminal = "tmux-256color";

      extraConfig = ''
        set -g renumber-windows on
        set -g detach-on-destroy off
        set -g set-clipboard on
        set -g allow-passthrough on
        set -ga terminal-features ",xterm-ghostty:RGB,ghostty:RGB,tmux-256color:RGB,xterm-256color:RGB,screen-256color:RGB"

        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
        bind c new-window -c "#{pane_current_path}"
        bind p display-popup -E -d "#{pane_current_path}" -w 75% -h 60%
        bind r source-file "~/.config/tmux/tmux.conf" \; display-message "tmux.conf reloaded"

        set -g status off

        set -g pane-border-style "fg=colour238"
        set -g pane-active-border-style "fg=colour81"
        set -g message-style "bg=colour24,fg=colour15"
        set -g mode-style "bg=colour24,fg=colour15"
      '';
    };
  };
}
