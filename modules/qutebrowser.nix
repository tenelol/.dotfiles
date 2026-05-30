{
  delib,
  host,
  pkgs,
  ...
}:
delib.module {
  name = "qutebrowser";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    programs.qutebrowser = {
      enable = true;
      package = if pkgs.stdenv.hostPlatform.isDarwin then null else pkgs.qutebrowser;

      aliases = {
        q = "quit";
        qa = "quit --save";
        source = "config-source";
        wq = "quit --save";
      };

      keyMappings = {
        "<Ctrl-[>" = "<Escape>";
      };

      searchEngines = {
        DEFAULT = "https://www.google.com/search?q={}";
        d = "https://duckduckgo.com/?q={}";
        g = "https://www.google.com/search?q={}";
        gh = "https://github.com/search?q={}";
        mdn = "https://developer.mozilla.org/search?q={}";
        no = "https://search.nixos.org/options?channel=unstable&query={}";
        np = "https://search.nixos.org/packages?channel=unstable&query={}";
        nw = "https://wiki.nixos.org/w/index.php?search={}";
        yt = "https://www.youtube.com/results?search_query={}";
      };

      settings = {
        auto_save.session = true;
        colors.webpage.preferred_color_scheme = "auto";
        completion.height = "35%";
        content = {
          autoplay = false;
          blocking = {
            enabled = true;
            method = "both";
          };
          cookies.accept = "no-3rdparty";
          geolocation = false;
          notifications.enabled = "ask";
          pdfjs = true;
        };
        downloads = {
          location.directory = "~/Downloads";
          position = "bottom";
        };
        editor.command = [
          "ghostty"
          "-e"
          "nvim"
          "{file}"
          "+call cursor({line}, {column})"
        ];
        hints.chars = "asdfghjkl";
        input.insert_mode = {
          auto_enter = true;
          auto_load = true;
        };
        scrolling.smooth = true;
        session.lazy_restore = true;
        statusbar.show = "in-mode";
        tabs = {
          background = true;
          last_close = "close";
          mousewheel_switching = false;
          new_position = {
            related = "next";
            unrelated = "last";
          };
          show = "multiple";
          title.format = "{audio}{index}: {current_title}";
        };
        url = {
          default_page = "https://www.google.com";
          open_base_url = true;
          start_pages = [ "https://www.google.com" ];
        };
        window.hide_decoration = true;
      };

      keyBindings = {
        normal = {
          "<Ctrl-Shift-Tab>" = "tab-prev";
          "<Ctrl-Tab>" = "tab-next";
          "<Ctrl-r>" = "reload";
          ",S" = "open -t qute://settings";
          ",h" = "open -t qute://help";
          ",r" = "restart";
          ",s" = "config-source";
          "J" = "tab-prev";
          "K" = "tab-next";
          "R" = "reload -f";
          "X" = "undo";
          "gH" = "open -t qute://help";
          "gS" = "open -t qute://settings";
          "x" = "tab-close";
          "xo" = "tab-only";
        };
        insert = {
          "<Ctrl-[>" = "mode-leave";
        };
        prompt = {
          "<Ctrl-y>" = "prompt-yes";
        };
      };
    };

    programs.fish.shellAliases = {
      qb = "qutebrowser";
      qute = "qutebrowser";
    };
  };
}
