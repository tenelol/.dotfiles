{ pkgs, nvim }:
{
  enable = true;
  defaultEditor = true;
  viAlias = true;
  vimAlias = true;
  wrapRc = true;
  nixpkgs.useGlobalPackages = true;
  version.enableNixpkgsReleaseCheck = false;
  withNodeJs = true;
  withPython3 = true;
  withRuby = false;
  env.NVIM_SYSTEM_RPLUGIN_MANIFEST = "${nvim.moltenRemotePluginManifest}";
  extraConfigLuaPre = ''
    if vim.fn.has("wsl") == 1 and vim.fn.executable("clip.exe") == 1 and vim.fn.executable("powershell.exe") == 1 then
      vim.g.clipboard = {
        name = "wsl-clipboard",
        copy = {
          ["+"] = { "clip.exe" },
          ["*"] = { "clip.exe" },
        },
        paste = {
          ["+"] = {
            "powershell.exe",
            "-NoLogo",
            "-NoProfile",
            "-Command",
            "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-Clipboard -Raw",
          },
          ["*"] = {
            "powershell.exe",
            "-NoLogo",
            "-NoProfile",
            "-Command",
            "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-Clipboard -Raw",
          },
        },
        cache_enabled = 0,
      }
    end

    local is_wsl = vim.fn.has("wsl") == 1
    if is_wsl then
      vim.keymap.set({ "n", "i", "v" }, "<C-h>", "<Left>", { noremap = true, silent = true, desc = "Move left" })
      vim.keymap.set({ "n", "i", "v" }, "<C-j>", "<Down>", { noremap = true, silent = true, desc = "Move down" })
      vim.keymap.set({ "n", "i", "v" }, "<C-k>", "<Up>", { noremap = true, silent = true, desc = "Move up" })
      vim.keymap.set({ "n", "i", "v" }, "<C-l>", "<Right>", { noremap = true, silent = true, desc = "Move right" })
    else
      vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })
      vim.keymap.set("t", "<C-h>", "<Cmd>wincmd h<CR>", { noremap = true, silent = true })
      vim.keymap.set("t", "<C-j>", "<Cmd>wincmd j<CR>", { noremap = true, silent = true })
      vim.keymap.set("t", "<C-k>", "<Cmd>wincmd k<CR>", { noremap = true, silent = true })
      vim.keymap.set("t", "<C-l>", "<Cmd>wincmd l<CR>", { noremap = true, silent = true })
    end
  ''
  + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
    vim.g.clipboard = {
      name = "pbcopy",
      copy = {
        ["+"] = "/usr/bin/pbcopy",
        ["*"] = "/usr/bin/pbcopy",
      },
      paste = {
        ["+"] = { "/usr/bin/pbpaste" },
        ["*"] = { "/usr/bin/pbpaste" },
      },
      cache_enabled = 0,
    }
  ''
  + ''
    vim.opt.fillchars:append({ eob = " " })

    if vim.fn.exists(":lsp") == 2 and vim.fn.exists(":LspInfo") == 0 then
      vim.api.nvim_create_user_command("LspInfo", "checkhealth vim.lsp", {
        desc = "Show LSP health and client status",
      })
    end
  '';
  extraConfigLua = ''
    require("core.plugin-loader")
  '';
  extraPlugins = builtins.attrValues nvim.nixManagedPlugins;
  extraFiles."lua".source = nvim.nvimLuaConfig;
  globals = {
    mapleader = " ";
    maplocalleader = " ";
  };
  opts = {
    autoindent = true;
    clipboard = "unnamedplus";
    completeopt = [
      "menu"
      "menuone"
      "noselect"
    ];
    cursorline = true;
    expandtab = true;
    hidden = true;
    ignorecase = true;
    number = true;
    pumblend = 12;
    relativenumber = false;
    scrolloff = 8;
    shiftwidth = 2;
    signcolumn = "yes";
    smartcase = true;
    smartindent = true;
    softtabstop = 2;
    splitbelow = true;
    splitright = true;
    sidescrolloff = 8;
    tabstop = 2;
    termguicolors = true;
    timeoutlen = 300;
    undofile = true;
    updatetime = 250;
    winblend = 12;
  };
  diagnostic.settings = {
    severity_sort = true;
    signs = true;
    underline = true;
    update_in_insert = false;
    virtual_text = false;
    virtual_lines = false;
    float = {
      border = "rounded";
      header = "";
      prefix = "";
      source = "if_many";
    };
  };
  filetype.extension = {
    js = "javascript";
    mjs = "javascript";
    cjs = "javascript";
    jsx = "javascriptreact";
    tsx = "typescriptreact";
    ino = "cpp";
  };
  userCommands.SelectAll = {
    command = "normal! ggVG";
    desc = "Select the entire buffer";
  };
  autoGroups.IndentSettings.clear = true;
  autoCmd = [
    {
      event = "FileType";
      group = "IndentSettings";
      pattern = [ "python" ];
      callback.__raw = ''
        function()
          vim.opt_local.expandtab = true
          vim.opt_local.shiftwidth = 4
          vim.opt_local.tabstop = 4
          vim.opt_local.softtabstop = 4
        end
      '';
    }
    {
      event = "FileType";
      group = "IndentSettings";
      pattern = [
        "html"
        "css"
        "sass"
        "scss"
        "javascript"
        "typescript"
        "typescriptreact"
        "javascriptreact"
        "astro"
        "nix"
        "json"
        "jsonc"
        "markdown"
      ];
      callback.__raw = ''
        function()
          vim.opt_local.expandtab = true
          vim.opt_local.shiftwidth = 2
          vim.opt_local.tabstop = 2
          vim.opt_local.softtabstop = 2
        end
      '';
    }
    {
      event = "FileType";
      group = "IndentSettings";
      pattern = [ "go" ];
      callback.__raw = ''
        function()
          vim.opt_local.expandtab = false
          vim.opt_local.shiftwidth = 4
          vim.opt_local.tabstop = 4
          vim.opt_local.softtabstop = 0
        end
      '';
    }
  ];
  keymaps = [
    {
      mode = "i";
      key = "kj";
      action = "<Esc>";
      options.silent = true;
    }
    {
      mode = "t";
      key = "<C-s>";
      action = "<C-\\><C-n>";
      options = {
        noremap = true;
        silent = true;
      };
    }
    {
      mode = [
        "n"
        "i"
        "v"
      ];
      key = "<leader>va";
      action = "<Esc>ggVG";
      options = {
        silent = true;
        desc = "Select all";
      };
    }
    {
      mode = "n";
      key = "K";
      action.__raw = ''
        function()
          for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
            if client:supports_method("textDocument/hover") then
              vim.lsp.buf.hover({
                border = "rounded",
                focus = false,
                focusable = false,
                max_width = math.min(80, math.floor(vim.o.columns * 0.6)),
                max_height = math.min(12, math.floor(vim.o.lines * 0.35)),
              })
              return
            end
          end
        end
      '';
      options = {
        silent = true;
        desc = "Hover";
      };
    }
    {
      mode = "n";
      key = "<C-Tab>";
      action = "<Cmd>BufferLineCycleNext<CR>";
      options = {
        silent = true;
        desc = "Next buffer";
      };
    }
    {
      mode = "n";
      key = "<C-S-Tab>";
      action = "<Cmd>BufferLineCyclePrev<CR>";
      options = {
        silent = true;
        desc = "Previous buffer";
      };
    }
    {
      mode = "t";
      key = "<C-Tab>";
      action.__raw = ''function() vim.cmd("BufferLineCycleNext") end'';
      options = {
        silent = true;
        desc = "Next buffer";
      };
    }
    {
      mode = "t";
      key = "<C-S-Tab>";
      action.__raw = ''function() vim.cmd("BufferLineCyclePrev") end'';
      options = {
        silent = true;
        desc = "Previous buffer";
      };
    }
    {
      mode = "t";
      key = "]b";
      action.__raw = ''function() vim.cmd("BufferLineCycleNext") end'';
      options = {
        silent = true;
        desc = "Next buffer";
      };
    }
    {
      mode = "t";
      key = "[b";
      action.__raw = ''function() vim.cmd("BufferLineCyclePrev") end'';
      options = {
        silent = true;
        desc = "Previous buffer";
      };
    }
  ]
  ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    {
      mode = [
        "n"
        "i"
        "v"
      ];
      key = "<D-a>";
      action = "<Esc>ggVG";
      options = {
        silent = true;
        desc = "Select all";
      };
    }
  ];
  extraPython3Packages = nvim.jupyterPythonPackages;
  extraLuaPackages = ps: [
    ps.magick
  ];

  extraPackages = with pkgs; [
    lua-language-server
    clang-tools
    pyright
    gopls
    nil
    nvim.jupyterPython
    imagemagick
    vscode-langservers-extracted
    fd
    lazygit
    ripgrep
    stylua
    nixfmt
    gofumpt
    gotools
    deno
  ];
}
