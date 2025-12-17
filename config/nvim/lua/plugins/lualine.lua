local function setup_lualine()
  -- 色コードをまとめて設定。各プラグインの色設定で使用
  local colors = {
    fg = '#ffffff',
    fg2 = '#353535',
    fg3 = '#a8a8a8',
    bg = '#525252',
    bg3 = '#353535',
    white = '#ffffff',
    black = '#000000',
    yellow = '#ffec50',
    orange = '#ffaf00',
    red = '#ff6510',
    magenta = '#e0898d',
    cyan = '#7bbfff',
    blue = '#235bc8',
    darkblue = '#3672a4',
    green = '#78ff94',
    darkbrown = '#542d24',
  }

  -- 独自テーマの設定
  local custom_theme = {
    normal = {
      a = { fg = colors.fg2, bg = colors.cyan, gui = 'bold' },
      b = { fg = colors.fg, bg = colors.darkblue },
      c = { fg = colors.fg, bg = colors.bg },
    },
    insert = { a = { fg = colors.fg2, bg = colors.yellow, gui = 'bold' } },
    visual = { a = { fg = colors.fg2, bg = colors.magenta, gui = 'bold' } },
    replace = { a = { fg = colors.fg2, bg = colors.green, gui = 'bold' } },
    command = { a = { fg = colors.fg2, bg = colors.red, gui = 'bold' } },
    terminal = { a = { fg = colors.fg2, bg = colors.orange, gui = 'bold' } },
    inactive = {
      a = { fg = colors.fg, bg = colors.bg3, gui = 'bold' },
      b = { fg = colors.fg3, bg = colors.bg3 },
      c = { fg = colors.fg3, bg = colors.bg3 },
    },
  }

  -- fileformatをタイプ別に色分け
  local function fileformat_color()
    local format = vim.bo.fileformat
    if format == 'unix' then
      return { fg = colors.red }
    elseif format == 'dos' then
      return { fg = colors.cyan }
    elseif format == 'mac' then
      return { fg = colors.green }
    end
  end

  -- modeの表示文字列を変更
  local function custom_mode()
    local mode_map = {
      n = 'N', -- Normal モード
      i = 'INS', -- Insert モード
      v = 'VIS', -- Visual モード
      V = 'V-L', -- Visual-Line モード
      [''] = 'V-B', -- Visual-Block モード
      c = 'CMD', -- Command モード
      R = 'REP', -- Replace モード
      t = 'TERM', -- Terminal モード
    }
    local current_mode = vim.fn.mode()
    return mode_map[current_mode] or current_mode
  end

  -- 猫ちゃん連れてく
  local function mycat()
    -- 候補：
    -- 󰄛 ,󰆚 ,󰩃 ,󰇥 ,󱖿 ,󱗂 ,󰈺 ,󰊠 ,󱕘 ,󱜿 ,󰏩 ,󰻀 ,󰐁 ,󰤇 ,󰚩 ,󱌧 ,󰚌 ,󱙷 ,󰴻 ,󱅼 , ,
    -- 󰉊 ,󰣠 ,󰋑 ,󱁏 ,󰮣 ,󰟟 ,󰫕 ,󰜃 ,󰮿 ,󰟪 ,󰑣 ,󰚬 ,󱕬 ,󰴺 ,󰓿 ,󰔬 ,󰯙 ,󱂖 ,󰕊 , , ,
    return '󰄛'
  end

  local win_width = vim.api.nvim_win_get_width(0) -- ウィンドウ幅

  require('lualine').setup {
    options = {
      theme = custom_theme,
      -- component_separators = { left = '', right = '' },
      -- component_separators = { left = '|', right = '|' },
      component_separators = { left = '', right = '' },
      -- section_separators = { left = '', right = '' },
      -- section_separators = { left = '', right = '' },
      section_separators = win_width > 80 and {
        left = '',
        right = '',
      } or {
        left = '',
        right = '',
      },
      globalstatus = false, -- ウィンドウごとに異なるステータスライン
    },
    sections = {
      lualine_a = {
        {
          mycat,
          padding = { left = 1, right = 0 },
          color = { fg = colors.darkbrown },
          cond = function()
            return win_width > 80
          end,
        },
        {
          custom_mode, -- モードをカスタム表示。'mode'の置き換え
        },
      },
      lualine_b = {
        {
          'branch',
          icon = '',
          padding = { left = 0, right = 1 },
          fmt = function(branch_name)
            if not branch_name or branch_name == '' then
              return '' -- Git管理外の場合は空文字列を返す
            end

            if win_width > 100 then
              return ' ' .. branch_name -- アイコン＋テキスト
            else
              return '' -- アイコンのみ
            end
          end,
        },
        {
          'diff',
          symbols = { added = ' ', modified = ' ', removed = ' ' },
          -- symbols = { added = '➕ ', modified = '✏️ ', removed = '❌ ' }
          padding = { left = 0, right = 1 },
          fmt = function(str)
            if win_width > 90 then
              return str
            else
              return str:gsub('%d+', '') -- 数字を削除してアイコンのみを返す
            end
          end,
        },
      },
      lualine_c = {
        {
          'filename',
          path = 0, -- 1:ファイルパスを表示、0:非表示
          -- symbols = { modified = '● ', readonly = '[RO]' },
          symbols = { modified = '●', readonly = '' },
          -- symbols = { modified = ' ', readonly = ' ' },
          -- symbols = { modified = '[+]', readonly = '[-]' },
        },
        {
          'diagnostics',
          update_in_insert = false, -- 挿入モードでは更新しない
          padding = { left = 0, right = 1 },
          symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' },
          diagnostics_color = {
            error = { fg = colors.red },
            warn = { fg = colors.yellow },
            info = { fg = colors.green },
            hint = { fg = colors.cyan },
          },
          fmt = function(str)
            if win_width > 80 then
              return str
            else
              return str:gsub('%d+', '') -- 数字を削除してアイコンのみを返す
            end
          end,
        },
      },
      lualine_x = {
        {
          'filetype',
          icon_only = win_width <= 90,
        },
        {
          'fileformat',
          symbols = { unix = '', dos = '', mac = '' }, --  , ,
          color = fileformat_color,
          padding = { left = 0, right = 1 },
        },
        {
          'encoding',
          padding = { left = 0, right = 1 },
          cond = function()
            return win_width > 70
          end,
        },
      },
      lualine_y = {
        {
          'progress',
          cond = function()
            return win_width > 80
          end,
        },
      },
      lualine_z = {
        {
          'location',
          padding = 1,
          cond = function()
            return win_width > 70
          end,
        },
      },
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { 'filename' },
      lualine_x = { 'location' },
      lualine_y = {},
      lualine_z = {},
    },
    tabline = {},
    winbar = {},
    inactive_winbar = {},
    extensions = {},
  }
end

-- 本体
return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    -- 上記の設定を適用
    setup_lualine()

    -- アクティブウィンドウ切り替えやサイズ変更時に再設定
    vim.api.nvim_create_autocmd({ 'WinEnter', 'WinResized' }, {
      callback = function()
        setup_lualine()
      end,
    })
  end,
  event = 'VeryLazy',
}

