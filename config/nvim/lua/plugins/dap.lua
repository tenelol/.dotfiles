return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "mfussenegger/nvim-dap-python",
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { silent = true })
      vim.keymap.set("n", "<leader>dc", dap.continue, { silent = true })
      vim.keymap.set("n", "<leader>do", dap.step_over, { silent = true })
      vim.keymap.set("n", "<leader>di", dap.step_into, { silent = true })
      vim.keymap.set("n", "<leader>dO", dap.step_out, { silent = true })
      vim.keymap.set("n", "<leader>dr", dap.repl.open, { silent = true })

      local dap_python = require("dap-python")
      dap_python.setup("python")
      dap_python.test_runner = "pytest"
    end,
  },
}
