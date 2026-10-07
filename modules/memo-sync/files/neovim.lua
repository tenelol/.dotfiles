local M = {}
local uv = vim.uv
local root, command, tracked = nil, nil, {}
local labels = {
  in_sync = '同期済', converged = '同期済', format_changed = '同期済',
  push_pending = '同期待ち', pull_pending = '更新待ち', waiting = '同期待ち',
  conflict = '競合', interrupted = '同期停止', move_interrupted = '移動停止',
  unsupported = '形式非対応', unavailable = '接続待ち', folder_changed = '移動確認',
  read_only = '読み取り専用', disabled = '同期オフ', unsaved = '未保存',
  unknown = '登録待ち', metadata_error = '管理情報エラー',
  local_missing = 'ファイル欠落', remote_missing = 'メモ欠落',
  deleted = '削除済', delete_interrupted = '削除停止', create_interrupted = '作成停止',
}

local function read(path)
  local stat = uv.fs_lstat(path)
  if not stat or stat.type ~= 'file' or stat.size > 16 * 1024 * 1024 then return nil end
  local fd = uv.fs_open(path, 'r', 0)
  if not fd then return nil end
  local text = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return text
end

local function json(path)
  local text = read(path)
  if not text then return nil end
  local ok, value = pcall(vim.json.decode, text)
  return ok and type(value) == 'table' and value or nil
end

local function safe_relative(name)
  if type(name) ~= 'string' or name == '' or name:sub(1,1) == '/' or name:find('\\',1,true) then return false end
  for part in name:gmatch('[^/]+') do
    if part:sub(1,1) == '.' or part:find('%c') then return false end
  end
  return true
end

local function relative(buf)
  local path = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
  path = uv.fs_realpath(path) or ((uv.fs_realpath(vim.fs.dirname(path)) or vim.fs.dirname(path)) .. '/' .. vim.fs.basename(path))
  if path:sub(1,#root+1) ~= root .. '/' then return nil end
  local name = path:sub(#root+2)
  return safe_relative(name) and name:sub(-3) == '.md' and name or nil
end

local function readonly(buf, blocked)
  local t = tracked[buf]
  if blocked and t.readonly == nil then
    t.readonly = vim.bo[buf].readonly
    vim.bo[buf].readonly = true
  elseif not blocked and t.readonly ~= nil then
    vim.bo[buf].readonly = t.readonly
    t.readonly = nil
  end
end

local function refresh(buf, capture)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then return end
  local name = relative(buf)
  if not name then
    if tracked[buf] then
      readonly(buf,false)
      vim.bo[buf].backupcopy=tracked[buf].backupcopy
      tracked[buf]=nil
    end
    vim.b[buf].memo_sync_status = nil
    return
  end
  local t = tracked[buf] or {path=name,backupcopy=vim.bo[buf].backupcopy}
  local previous_path=t.path
  tracked[buf] = t
  vim.bo[buf].backupcopy='yes'
  local state = json(root .. '/.memo-sync/state.json')
  local id, record
  if state and state.version == 1 and type(state.notes) == 'table' then
    for key, value in pairs(state.notes) do
      if type(value) == 'table' and not value.deleted and
        (value.file == name or (value.pending_move and value.pending_move.target == name)) then
        id, record = key, value;break
      end
    end
    if not record and t.id and state.notes[t.id] and not state.notes[t.id].deleted then
      local candidate = state.notes[t.id]
      local current=uv.fs_stat(root .. '/' .. name)
      local destination_stat=safe_relative(candidate.file) and uv.fs_stat(root .. '/' .. candidate.file) or nil
      if candidate.file ~= t.path and destination_stat and (not current or
        (current.dev==destination_stat.dev and current.ino==destination_stat.ino)) then
        local destination = root .. '/' .. candidate.file
        local other = vim.fn.bufnr(destination)
        if other == -1 or other == buf then
          vim.api.nvim_buf_set_name(buf,destination)
          name, t.path, id, record = candidate.file, candidate.file, t.id, candidate
        end
      end
    end
  end
  if record and record.file == name and vim.fs.basename(vim.api.nvim_buf_get_name(buf)) ~= vim.fs.basename(name) then
    vim.api.nvim_buf_set_name(buf, root .. '/' .. name)
  end
  local contents = read(root .. '/' .. name)
  local hash = contents and vim.fn.sha256(contents) or nil
  if capture or not t.captured or (t.path ~= name and not hash) then
    t.path, t.hash, t.captured = name, hash, true
  end
  t.path=name
  if id then t.id=id end
  local phase, reason, blocked = 'unknown', nil, false
  local report = id and json(root .. '/.memo-sync/reports/' .. vim.fn.sha256(id) .. '.json') or nil
  if not state or state.version ~= 1 or type(state.notes) ~= 'table' then
    phase, reason, blocked = 'metadata_error', 'state.jsonを確認できません。同期管理情報を復旧してください。', true
  elseif record then
    if not record.sync_enabled and record.pull_enabled then
      phase, reason, blocked = 'read_only', record.write_blocked or '標準メモで編集してください。', true
      if report and report.baseline == record.base and report.local_hash == hash and
        (report.status == 'push_pending' or report.status == 'conflict') then
        reason = reason .. ' ローカルの追記は未反映です。:MemoSyncDiff で確認できます。'
      end
    elseif not record.sync_enabled and not record.pull_enabled then
      phase = 'disabled'
    elseif record.pending_move then
      phase, reason = 'move_interrupted', record.pending_move.error
    elseif record.pending and record.pending.error then
      phase, reason = 'interrupted', record.pending.error
    elseif report and report.baseline == record.base and report.local_hash == hash then
      phase, reason = report.status, report.error
    else
      phase = 'push_pending'
    end
  else
    local errors = json(root .. '/.memo-sync/directory-errors.json') or {}
    reason = errors[name]
    if state.creates and state.creates[name] then reason=state.creates[name].error end
    if reason then phase='interrupted' end
  end
  local errors = json(root .. '/.memo-sync/local-errors.json') or {}
  if errors[name] then phase, reason='unsupported',errors[name] end
  reason = type(reason) == 'string' and reason or nil
  if vim.bo[buf].modified and not blocked then
    if hash ~= t.hash then
      phase, reason = 'conflict', 'ディスク側も更新されています。未保存の編集は保持しています。:MemoSyncDiff で確認してください。'
    else phase='unsaved' end
  elseif not blocked and not reason and hash ~= t.hash and hash and vim.fn.mode():sub(1,1) ~= 'i' then
    vim.bo[buf].autoread = true
    if previous_path ~= name then
      vim.api.nvim_buf_call(buf,function() vim.cmd('silent keepalt edit') end)
    else
      vim.cmd('silent! checktime ' .. buf)
    end
    if not vim.bo[buf].modified then t.hash=hash end
  end
  readonly(buf,blocked)
  t.phase, t.reason, t.blocked = phase, type(reason)=='string' and reason or nil, blocked
  vim.b[buf].memo_sync_state = phase
  vim.b[buf].memo_sync_status = 'メモ: ' .. (labels[phase] or phase)
  if record and record.literal then
    vim.b[buf].memo_sync_status = vim.b[buf].memo_sync_status .. '・原文'
  end
  if t.reason and t.reason ~= t.notified then
    vim.notify(vim.fs.basename(name) .. ': ' .. t.reason, vim.log.levels.WARN, {title='memo-sync'})
    t.notified=t.reason
  elseif not t.reason then t.notified=nil end
end

function M.stop()
  if M.timer then M.timer:stop();M.timer:close();M.timer=nil end
  for buf,t in pairs(tracked) do
    if vim.api.nvim_buf_is_valid(buf) then readonly(buf,false);vim.bo[buf].backupcopy=t.backupcopy end
  end
end

function M.setup(directory, executable)
  if _G.memo_sync then _G.memo_sync.stop() end
  _G.memo_sync=M
  root = vim.fs.normalize(directory or vim.fn.expand('~/Documents/memo'))
  root = uv.fs_realpath(root) or root
  command = executable or 'memo-sync'
  local group=vim.api.nvim_create_augroup('MemoSync',{clear=true})
  vim.api.nvim_create_autocmd({'BufReadPost','BufNewFile','BufWritePost'}, {group=group,callback=function(a) refresh(a.buf,true) end})
  vim.api.nvim_create_autocmd('BufEnter',{group=group,callback=function(a) refresh(a.buf,false) end})
  vim.api.nvim_create_autocmd('BufWritePre',{group=group,callback=function(a)
    refresh(a.buf,false)
    local t=tracked[a.buf]
    if not t then return end
    if t.blocked then error('memo-sync: ' .. (t.reason or '読み取り専用です。')) end
    local text=read(root .. '/' .. t.path)
    if (text and vim.fn.sha256(text) or nil) ~= t.hash then
      error('memo-sync: 外部更新との競合です。未保存の編集を別名で保存するか、:MemoSyncDiff で確認してください。')
    end
  end})
  vim.api.nvim_create_autocmd('BufWipeout',{group=group,callback=function(a) tracked[a.buf]=nil end})
  vim.api.nvim_create_autocmd('VimLeavePre',{group=group,callback=M.stop})
  vim.api.nvim_create_user_command('MemoSyncStatus',function()
    local buf=vim.api.nvim_get_current_buf();refresh(buf,false);local t=tracked[buf]
    vim.api.nvim_echo({{t and ((vim.b[buf].memo_sync_status or labels[t.phase] or t.phase) .. (t.reason and ': '..t.reason or '')) or 'memo-syncの対象外です。'}},true,{})
  end,{force=true})
  vim.api.nvim_create_user_command('MemoSyncDiff',function()
    local buf=vim.api.nvim_get_current_buf();refresh(buf,false);local t=tracked[buf]
    if not t then return end
    local function show(text)
      vim.cmd('botright new')
      vim.bo.buftype='nofile';vim.bo.bufhidden='wipe';vim.bo.swapfile=false
      vim.api.nvim_buf_set_lines(0,0,-1,false,vim.split(text ~= '' and text or '差分はありません。','\n',{plain=true}))
      vim.bo.filetype='diff';vim.bo.modifiable=false
    end
    if vim.bo[buf].modified then
      local draft=table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n') .. (vim.bo[buf].endofline and '\n' or '')
      show('--- disk\n+++ Neovim\n' .. vim.diff(read(root .. '/' .. t.path) or '',draft,{result_type='unified'}))
    else
      vim.system({command,'--root',root,'diff',t.path},{text=true},function(result)
        vim.schedule(function() show(result.code == 0 and result.stdout or result.stderr) end)
      end)
    end
  end,{force=true})
  M.timer=uv.new_timer()
  M.timer:start(1000,1000,vim.schedule_wrap(function()
    for _,buf in ipairs(vim.api.nvim_list_bufs()) do refresh(buf,false) end
    vim.cmd('redrawstatus')
  end))
  for _,buf in ipairs(vim.api.nvim_list_bufs()) do refresh(buf,false) end
end

return M
