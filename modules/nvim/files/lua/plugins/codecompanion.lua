local plugin = require("nix-plugin")

return {
  plugin.spec("codecompanion-nvim", {
    dependencies = {
      plugin.dep("plenary-nvim"),
      plugin.dep("nvim-treesitter"),
    },
    keys = {
      { "<leader>ic", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "Toggle chat" },
      { "<leader>ia", "<cmd>CodeCompanionActions<cr>",     mode = { "n", "v" }, desc = "Actions" },
      { "<leader>ii", "<cmd>CodeCompanion<cr>",            mode = { "n", "v" }, desc = "Inline assist" },
      { "<leader>is", "<cmd>CodeCompanionChat Add<cr>",    mode = "v",          desc = "Add selection to chat" },
    },
    config = function()
      require("codecompanion").setup({
        adapters = {
          copilot = function()
            return require("codecompanion.adapters").extend("copilot", {
              schema = {
                model = { default = "claude-sonnet-4.6" },
              },
            })
          end,
        },
        opts = {
          log_level = "ERROR",
        },
        interactions = {
          chat = {
            adapter = "copilot",
            keymaps = {
              send = {
                modes = { n = "<CR>", i = "<C-s>" },
                description = "Send",
              },
            },
            opts = {
              system_prompt = function(ctx)
                return ctx.default_system_prompt
                  .. "\n\n追加指示:\n"
                  .. "- 常に日本語で回答してください。\n"
                  .. "- ローカルのコードやファイルに関する相談では、まずワークスペース内のファイルや変更を確認してから回答してください。\n"
                  .. "- 最新情報や外部情報が必要な場合にのみ web_search ツールを使ってください。"
              end,
            },
            tools = {
              opts = {
                default_tools = { "agent" },
              },
              read_file = {
                opts = {
                  require_approval_before = false,
                },
              },
              grep_search = {
                opts = {
                  require_approval_before = false,
                },
              },
              get_diagnostics = {
                opts = {
                  require_approval_before = false,
                },
              },
              web_search = {
                opts = {
                  adapter = "tavily",
                },
              },
            },
          },
          inline = { adapter = "copilot" },
          agent = { adapter = "copilot" },
        },
        display = {
          chat = {
            window = {
              layout = "vertical",
              width = 0.35,
            },
          },
        },
      })
    end,
  }),
}
