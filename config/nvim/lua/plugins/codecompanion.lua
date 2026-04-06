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
          system_prompt = function(_)
            return "あなたは優秀なプログラミングアシスタントです。常に日本語で回答してください。最新情報や不確かな情報が必要な場合は、積極的に web_search ツールを使って検索してください。"
          end,
        },
        strategies = {
          chat = {
            adapter = "copilot",
            keymaps = {
              send = {
                modes = { n = "<CR>", i = "<C-s>" },
                description = "Send",
              },
            },
          },
          inline = { adapter = "copilot" },
          agent  = { adapter = "copilot" },
        },
        interactions = {
          chat = {
            tools = {
              web_search = {
                opts = {
                  adapter = "tavily",
                },
              },
            },
          },
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
