local plugin = require("nix-plugin")

-- A bottom panel squeezes the dashboard, and splitkeep=screen then pushes its
-- hidden cursor off the menu onto the header; when focus returns, the doom theme
-- wraps that cursor to the last entry and the page scrolls up. Keep the page
-- where it was before focus left, and let the cursor reach the window edge.
local function keep_dashboard_in_place()
    local group = vim.api.nvim_create_augroup("DashboardStayPut", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "dashboard",
        callback = function()
            vim.opt_local.scrolloff = 0
        end,
    })

    local entering = false

    vim.api.nvim_create_autocmd("WinLeave", {
        group = group,
        callback = function()
            entering = true
            if vim.bo.filetype ~= "dashboard" then
                return
            end
            local view = vim.fn.winsaveview()
            -- A view saved before focus first left is the resting one.
            if vim.b.dashboard_view then
                view.topline = vim.b.dashboard_view.topline
            end
            vim.b.dashboard_view = view
            vim.fn.winrestview(view)
        end,
    })

    -- Closing a toggleterm hands focus back without WinEnter, so arriving shows up
    -- first as CursorMoved. This autocmd predates the doom theme's own CursorMoved
    -- handler, so the cursor is back on its entry before that runs.
    vim.api.nvim_create_autocmd({ "WinEnter", "CursorMoved" }, {
        group = group,
        callback = function()
            if not entering then
                return
            end
            entering = false
            if vim.bo.filetype == "dashboard" and vim.b.dashboard_view then
                vim.fn.winrestview(vim.b.dashboard_view)
            end
        end,
    })
end

-- The menu is hidden, but its shortcuts still work on the dashboard.
local function map_shortcuts()
    local shortcuts = {
        { "f", "Telescope find_files", "Find file" },
        { "r", "Telescope oldfiles", "Recent files" },
        { "s", function() require("persistence").load() end, "Restore session" },
        { "q", "qa", "Quit" },
    }
    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("DashboardShortcuts", { clear = true }),
        pattern = "dashboard",
        callback = function(event)
            for _, shortcut in ipairs(shortcuts) do
                local key, action, desc = unpack(shortcut)
                vim.keymap.set("n", key, type(action) == "string" and "<Cmd>" .. action .. "<CR>" or action,
                    { buffer = event.buf, nowait = true, silent = true, desc = desc })
            end
        end,
    })
end

-- Header art above the logo. header_girl is the previous art, kept as a backup:
-- point `art` below at it to restore.
local header_girl = {
    "                    ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣤⣤⣤⣤⣄⣀⣀⠀⠀⠀                     ",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⠶⣻⠝⠋⠠⠔⠛⠁⡀⠀⠈⢉⡙⠓⠶⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⢋⣴⡮⠓⠋⠀⠀⢄⠀⠀⠉⠢⣄⠀⠈⠁⠀⡀⠙⢶⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⢁⣔⠟⠁⠀⠀⠀⠀⠀⠈⡆⠀⠀⠀⠈⢦⡀⠀⠀⠘⢯⢢⠙⢦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡼⠃⠀⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠸⠀⠀⠀⠀⠀⢳⣦⡀⠀⠀⢯⠀⠈⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⠆⡄⢠⢧⠀⣸⠀⠀⠀⠀⠀⠀⠀⢰⠀⣄⠀⠀⠀⠀⢳⡈⢶⡦⣿⣷⣿⢉⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣯⣿⣁⡟⠈⠣⡇⠀⠀⢸⠀⠀⠀⠀⢸⡄⠘⡄⠀⠀⠀⠈⢿⢾⣿⣾⢾⠙⠻⣾⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⡿⣮⠇⢙⠷⢄⣸⡗⡆⠀⢘⠀⠀⠀⠀⢸⠧⠀⢣⠀⠀⠀⡀⡸⣿⣿⠘⡎⢆⠈⢳⣽⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⢠⡟⢻⢷⣄⠀⠀⠀⠀⠀⠀⣾⣳⡿⡸⢀⣿⠀⠀⢸⠙⠁⠀⠼⠀⠀⠀⠀⢸⣇⠠⡼⡤⠴⢋⣽⣱⢿⣧⠀⢳⠈⢧⠀⢻⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⢀⡿⣠⡣⠃⣿⠃⠀⠀⠀⠀⣸⣳⣿⠇⣇⢸⣿⢸⣠⠼⠀⠀⠀⡇⠀⡀⠉⠒⣾⢾⣆⢟⣳⡶⠓⠶⠿⢼⣿⣇⠈⡇⠘⢆⠈⢿⡘⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠈⢷⣍⣤⡶⣿⡄⠀⠀⠀⢠⣿⠃⣿⠀⡏⢸⣿⣿⠀⢸⠀⠀⢠⡗⢀⠇⠀⢠⡟⠀⠻⣾⣿⠀⠀⠀⠀⡏⣿⣿⡀⢹⡀⠈⢦⠈⢷⣿⡆⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢁⣤⣄⠁⠀⠀⠀⣼⡏⢰⣟⠀⣇⠘⣿⣿⣾⣾⣆⢀⣾⠃⣼⢠⣶⣿⣭⣷⣶⣾⣿⣤⠀⠀⠀⡇⡯⣍⣧⠀⣷⠄⠈⢳⡀⢻⡁⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠺⣿⡿⠀⠀⠀⠀⡿⢀⣾⣧⠀⡗⡄⢿⣿⡙⣽⣿⣟⠛⠚⠛⠙⠉⢹⣿⣿⣦⠀⢸⡿⠀⠀⠀⢰⡯⣌⢻⡀⢸⢠⢰⡄⠹⡷⣿⣦⣤⠤⣶⡇⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠀⣇⣾⣿⢸⢠⣧⢧⠘⣿⡇⠸⣿⢿⡆⠀⠀⠀⠀⠘⣯⠇⣿⠂⣸⢰⠀⠀⢀⣸⡧⣊⣼⡇⢸⣼⣸⣷⢣⢻⣄⠉⠙⠛⠉⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣳⣤⣴⣿⣏⣿⣾⢸⣿⡘⣧⣘⢿⣀⡙⣞⠁⠀⠀⠀⠀⢀⡬⢀⣉⢠⣧⡏⠀⠀⡎⣿⣿⣿⣿⠃⣸⡏⣿⣿⡎⢿⡘⡆⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⣠⣼⣿⣿⣿⣼⣿⣧⢿⣿⣿⣯⡻⠟⠀⠀⠀⠀⠀⠐⢯⠣⡽⢟⣽⠀⠀⢘⡇⣿⣿⣿⡟⣴⣿⣷⣿⣿⣧⣿⣷⡽⠀⠀⠀⠀⠀⠀⠀",
    "⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣼⣹⣿⣇⣸⣿⣿⣿⣻⣚⣿⡿⣿⣿⣦⣤⣀⡉⠃⠀⢀⣀⣤⡶⠛⡏⠀⢀⣼⢸⣿⣿⣿⣿⣿⣿⣿⢋⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀",
    "⣿⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠒⠒⠒⢭⢻⣽⣿⣿⣿⣿⣿⣿⢿⠿⣿⡏⠀⡼⠁⣀⣾⣿⣿⣿⣿⡿⣿⣿⣟⡻⣿⣿⡿⠣⠟⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠸⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢧⢿⣯⡽⠿⠛⠋⣵⢟⣋⣿⣶⣞⣤⣾⣿⣿⡟⢉⡿⢋⠻⢯⡉⢻⡟⢿⡅⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⢻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⡞⣿⣆⡀⠀⡼⡏⠉⠚⠭⢉⣠⠬⠛⠛⢁⡴⣫⠖⠁⠀⠀⣩⠟⠁⣸⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠈⢷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣽⣿⣿⣾⠳⡙⣦⡤⠜⠊⠁⠀⣀⡴⠯⠾⠗⠒⠒⠛⠛⠛⠛⠛⠓⠿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠘⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠰⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢷⣻⣿⣿⠔⢪⠓⠬⢍⠉⣩⣽⢻⣤⣶⣦⠀⠀⠀⢀⣀⣤⣴⣾⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠹⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣾⡏⢦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣯⣿⣿⠀⠀⣇⠀⣠⠎⠁⢹⡎⡟⡏⣷⣶⠿⠛⡟⠛⠛⣫⠟⠉⢿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⢻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠹⣿⣷⠈⢷⡤⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣾⣷⡀⣀⣀⣷⡅⠀⠀⠈⣷⢳⡇⣿⠀⠀⣸⠁⢠⡾⣟⣛⣻⣟⡿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⢷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢯⢻⣏⡵⠿⠿⢤⣄⠀⢀⣿⢸⣹⣿⣀⣴⣿⣴⣿⣛⠋⠉⠉⡉⠛⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠘⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⡎⣿⣥⣶⠖⢉⣿⡿⣿⣿⡿⣿⣟⠿⠿⣿⣿⣿⡯⠻⣿⣿⣿⣷⡽⣿⡗⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠸⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⡘⣿⣩⠶⣛⣋⡽⠿⣷⢬⣙⣻⣿⣿⣿⣯⣛⠳⣤⣬⡻⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀",
    "⠀⣿⣛⣻⣿⡿⠿⠟⠗⠶⠶⠶⠶⠤⠤⢤⠤⡤⢤⣤⣤⣤⣤⣄⣀⣀⣀⣀⣀⣀⣀⣀⣣⢹⣷⣶⣿⣿⣦⣴⣟⣛⣯⣤⣿⣿⣿⣿⣿⣷⣌⣿⣿⣿⣿⣿⣿⣿⣤⣤⣤⣤⣤⣤⣄",
    "⠀⠉⠙⠛⠛⠛⠛⠛⠻⠿⠿⠿⠷⠶⠶⢶⣶⣶⣶⣶⣤⣤⣤⣤⣤⣥⣬⣭⣭⣉⣩⣍⣙⣏⣉⣏⣽⣶⣶⣶⣤⣤⣬⣤⣤⣾⣿⠶⠾⠿⠿⠿⠿⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠃",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠉⠉⠛⠛⠛⠛⠛⠛⠋⠉⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
}

local header_cat = {
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⢀⣀⣄⣤⣤⣦⣶⣶⣒⠶⣶⣶⣶⣶⣶⢄⢦⣤⣤⣄⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣴⣶⣿⣿⣿⣿⣦⣝⠻⢿⣿⣿⣿⣮⡪⢿⣿⣿⣿⣧⢘⢿⣿⣿⣿⡎⡸⣷⣶⣦⣤⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣶⣿⣿⣿⣷⣵⣹⡹⡻⢿⣿⣿⣿⣦⡍⡻⣿⣿⣿⣦⢙⢿⣿⣿⣇⠪⣿⣿⣿⡇⡊⣿⣿⣿⡟⢈⢾⣷⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣶⣿⣏⣝⢝⢛⠿⢿⢿⣿⣿⣾⣶⣌⢫⢻⢿⣿⣶⣍⠻⣿⣿⣖⢍⢿⣿⣯⠆⢯⢿⣯⢇⢸⣽⣿⡿⠨⣰⣿⡿⣟⠇⠅⣦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡾⣿⢿⣿⣿⣿⣿⣿⣿⣾⣾⣼⣙⡝⠿⣻⣿⣦⣧⣿⣿⣿⣾⣿⣿⣿⣿⣾⣿⣿⡷⣿⣿⣿⡰⣼⡾⣟⢊⡢⣷⣿⡻⢑⠡⡵⣿⢷⠝⠄⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣾⣶⣵⣧⣶⣵⡽⠘⢈⣌⠉⡛⢿⣿⣿⣺⣿⣿⣿⣿⢿⣿⣿⣿⡿⣿⣿⡿⣿⣻⣿⣿⣿⣻⣿⢷⣿⣳⢴⠽⠻⠑⠌⠢⠻⠽⡙⠅⢁⢌⢮⢲⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⢽⣷⣆⡀⠀⠀⠀⠀⠀⡾⢟⢿⠻⡻⢟⡛⠟⠋⣠⣾⣿⡿⠀⢋⣉⡋⡛⠛⠻⠻⣿⣻⣿⣿⣽⣿⣻⣿⣟⣿⡿⣟⣿⣾⡿⡟⠛⢉⣡⣤⣴⣶⣶⣷⣾⣶⣶⣶⣤⣄⣈⠈⠣⠁⠂⢀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣦⣄⠀⠀⢼⣿⣾⣾⣷⣿⠟⢈⣤⣾⣿⡿⡻⡃⠂⣻⣿⣿⣿⣿⣷⣶⣄⡉⠹⢾⣿⣿⣻⡿⣯⣯⣿⢿⡯⠋⣁⣴⣾⣿⣿⢿⢿⢻⡻⣛⣛⡛⡟⠿⡻⣿⣿⡿⡦⣄⠈⠐⢄⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⢯⢻⢿⡷⣄⠉⠻⣿⡿⣿⢁⣴⣿⣿⢿⢫⠣⠑⢅⠂⢸⣻⣝⣝⡻⠻⡿⣿⡽⣕⢄⠉⢿⣷⣟⡯⣟⡿⠉⣠⣾⣿⣿⢟⣯⣷⣿⣿⣿⣿⣿⣿⣿⣯⣿⣬⡪⡨⠫⡻⡽⡵⣄⠀⠂⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⠃⠃⢁⣡⣤⣴⣦⣶⡶⣴⣤⣤⣅⡁⠁⠈⢈⠨⠠⡁⢸⣿⣿⣿⡿⣗⡬⡐⠝⢞⢜⢄⠈⢻⣺⣿⠝⢀⣾⣿⣿⢻⣾⣿⣿⣿⠿⣛⢏⣏⣝⣍⢝⠹⢻⢻⣿⣾⡤⣱⠝⡕⡕⡡⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠟⢁⣴⣾⣿⣿⣿⣗⢸⣿⡆⢿⡿⢨⣿⣿⣿⣦⣄⠀⠊⢄⠰⣿⣿⣾⣿⣯⣟⣲⡠⢅⢣⢑⢁⠀⢷⠕⢠⣿⣿⣿⣳⣿⣿⣿⢯⣣⣷⣿⣿⣿⣿⣿⣿⣯⣧⡢⡪⡷⢯⡋⢇⠕⠡⠢⢁⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⣐⣿⣅⣻⣏⣸⣿⣿⣿⣿⣿⣷⣄⠀⣨⣿⣽⣳⣽⢗⡏⡮⡪⢂⠂⠅⢂⠀⠸⠀⣾⣿⣿⣿⣿⣿⣿⣯⣾⣿⣿⣿⣿⢿⣿⣻⣽⣿⣺⢯⡫⡏⡗⠜⠐⠈⣀⣁⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠘⣟⣮⢳⣓⠳⡑⠅⢊⠠⠁⡈⠀⠄⢈⢨⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣳⣿⣻⣟⡷⣯⡻⡜⡸⢨⠨⢀⣴⣿⣿⣿⣿⢕⡀",
    "⠀⠀⠀⠀⠀⠀⢰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣟⡷⣯⣻⠄⢸⠼⢜⠪⠌⠐⡈⠠⠐⢀⠐⡀⠁⠀⠰⣿⣿⣿⣿⣿⢿⣟⡿⣿⢽⢾⡻⣺⣽⡺⡮⡏⡇⡇⢇⢃⠢⠀⢸⣿⣿⣿⣿⡯⢊⠂",
    "⠀⠀⠀⠀⠀⠀⠸⣿⣯⣉⡙⣛⠙⠿⢿⠟⠿⣿⣿⣿⣿⠿⢿⢿⡽⠚⠵⠫⠳⢹⡃⠠⠡⠡⠁⠌⠄⠠⠁⡐⠠⠐⠀⠀⠢⠀⣿⣿⣿⣽⡿⣝⣗⣟⡯⡗⣝⣝⢎⡎⡮⢪⠪⡊⡂⠅⠀⢂⠀⠸⢿⠿⡿⠟⠕⠀⠂",
    "⠀⠀⣀⡀⠀⠀⠀⢿⠻⠻⠿⣿⣷⣦⣦⣴⣾⣿⣿⣿⣟⣦⣄⣠⡠⡴⡦⣲⣲⣺⠀⠠⠁⠌⡀⠁⠄⢁⠀⢂⠐⠀⠁⠠⠡⠀⠘⣵⣟⢎⣟⡕⡗⢕⢕⢕⢕⢜⠰⡁⡪⠐⡁⠄⡀⠂⡈⠠⠀⢐⣶⣦⣦⡆⠄⢀⠀",
    "⠀⠀⠀⠈⠉⠓⠒⠪⢿⣷⣿⣿⣿⣿⣿⢿⣿⡝⠏⠗⣟⢞⡮⡷⣽⣹⢭⣀⣠⢀⣀⣤⢥⠴⠴⠈⢈⠠⠈⠀⠀⢀⠐⠁⠌⠐⠀⠈⠮⡙⡆⡇⢇⠕⡈⡐⠔⠨⠈⠔⠀⡁⠄⠠⠐⢀⠐⠈⠀⡘⡻⠿⢿⠣⠁⠄⠂",
    "⠀⡀⣀⢀⣀⣀⣀⣀⣀⣙⣻⣿⣿⣻⣾⡻⣳⣻⡂⢰⢯⣻⢞⡿⣾⣞⡿⡛⠉⠁⠁⢀⠠⠀⠐⠈⠀⠀⠀⠠⠐⠀⠄⡁⢈⠈⠄⠂⠀⠑⠰⡡⡑⢌⠂⠌⠐⡈⢀⠂⡁⢀⠐⢐⠀⢂⠀⠁⢰⣿⣷⣶⠄⡀⠀⠐⠀",
    "⠈⠈⠈⠈⠀⠀⠀⠀⠀⠀⣀⣨⠹⠻⢗⡯⣢⡁⡤⣄⣉⣨⡫⡯⠫⠉⣩⣵⣭⣉⡓⠑⠒⠚⠒⠒⠀⠀⠁⠀⠈⠐⠀⠐⠀⠐⠀⠂⠁⠠⠀⠀⠈⠂⠡⠈⠄⠠⠀⠄⠄⠂⠐⡀⠂⠀⣠⣾⣦⡉⠻⠻⠈⢀⠐⠀⠀",
    "⠀⠀⠀⢀⣀⡠⠤⠖⠚⠉⠀⠀⠀⠀⠀⠈⣁⡙⢙⢑⢉⣈⣠⣤⣶⣿⣿⣿⣿⣿⣿⢟⠤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠁⣠⣴⣦⠹⢿⣿⠗⡀⠀⠀⠂⠀⠀⠀",
    "⠀⠀⠈⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠡⠿⡃⠜⡛⡛⡛⠫⠛⡛⠻⢙⠚⡘⠈⠌⢀⠀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⡀⡀⣤⣴⣴⣶⠹⣿⣿⡿⡅⠈⠈⠀⠄⠂⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠀⠐⠀⠠⠀⠡⠐⢀⠡⠐⠠⠀⠡⠈⢀⣴⣿⣿⠇⣸⣿⣿⣷⣷⣷⡖⢰⣶⣶⣶⣾⣶⡂⢾⣿⣿⣿⣿⠠⢿⣿⣿⢿⠅⠈⢃⠁⠂⠄⠀⠈⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⠎⠋⠡⠑⠁⠁⠈⠛⠛⢛⠻⠻⠑⠘⠿⠿⡻⠻⠿⠀⠹⠻⠛⡛⠙⠀⠈⠈⠄⠂⠀⠀⠀⠄⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠈⠀⠠⠁⠀⠀⠐⠀⠂⠐⠠⠀⠀⠌⠐⠀⠈⠀⠀⠁⠀⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
}

local logo = {
    "        ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗       ",
    "        ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║       ",
    "        ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║       ",
    "        ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║       ",
    "        ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║       ",
    "        ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝       ",
    "                                                                 "
}

local art = header_cat

return {
    plugin.spec("dashboard-nvim", {
        event = 'VimEnter',
        config = function()
            keep_dashboard_in_place()
            map_shortcuts()
            require('dashboard').setup {
                theme = 'doom',
                config = {
                    header = vim.list_extend(vim.list_extend({}, art), logo),
                    -- Just the art: no menu and no footer text; map_shortcuts
                    -- keeps the keys. The doom theme parks its cursor on the first
                    -- line after the header, so one blank footer line keeps that
                    -- line in the buffer.
                    center = {},
                    footer = { "" },
                }
            }
        end,
        dependencies = {
            plugin.dep("nvim-web-devicons"),
            plugin.dep("telescope-nvim"),
            plugin.dep("plenary-nvim"),
            plugin.dep("persistence-nvim")
        }
    })
}
