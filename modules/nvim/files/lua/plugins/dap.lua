local plugin = require("nix-plugin")

return {
    plugin.spec("nvim-dap", {
        dependencies = {
            plugin.dep("nvim-dap-python"),
            plugin.dep("nvim-dap-ui"),
            plugin.dep("nvim-nio"),
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

            local dap_python = require("dap-python")
            dap_python.setup(vim.fn.exepath("python3"))
            dap_python.test_runner = "pytest"
        end,
    }),
}
