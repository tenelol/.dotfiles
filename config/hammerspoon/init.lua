local eventTypes = hs.eventtap.event.types
local json = hs.json
local keycodes = hs.keycodes
local keyDownEvent = eventTypes.keyDown
local flagsChangedEvent = eventTypes.flagsChanged
local leftMouseDraggedEvent = eventTypes.leftMouseDragged
local pressureEvent = eventTypes.pressure
local forcePressActive = false
local zoomToggledForPress = false
local lastZoomToggleAt = 0
local debounceSeconds = 0.5

hs.autoLaunch(true)
pcall(function()
  hs.ipc.cliInstall()
end)
local accessibilityEnabled = hs.accessibilityState(true)

local imeConfig = {
  englishSourceID = "com.apple.keylayout.ABC",
  japaneseSourceID = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
  tapThresholdSeconds = 0.2,
}

local leftCommandKeyCode = keycodes.map.cmd
local function switchToEnglish()
  if not keycodes.currentSourceID(imeConfig.englishSourceID) then
    hs.alert.show(("Failed to switch to %s"):format(imeConfig.englishSourceID), 2)
  end
end

local function switchToJapanese()
  if not keycodes.currentSourceID(imeConfig.japaneseSourceID) then
    hs.alert.show(("Failed to switch to %s"):format(imeConfig.japaneseSourceID), 2)
  end
end

local function toggleIme()
  local currentSourceID = keycodes.currentSourceID()
  if currentSourceID == imeConfig.japaneseSourceID then
    switchToEnglish()
  else
    switchToJapanese()
  end
end

local function yabaiSpaces()
  local output, ok = hs.execute("/run/current-system/sw/bin/yabai -m query --spaces 2>/dev/null", true)
  if not ok or not output or output == "" then
    return nil, "failed to query yabai spaces"
  end

  local decodeOk, spaces = pcall(json.decode, output)
  if not decodeOk or type(spaces) ~= "table" then
    return nil, "failed to parse yabai spaces"
  end

  return spaces
end

local function spaceIDForIndex(index)
  local spaces, err = yabaiSpaces()
  if not spaces then
    return nil, err
  end

  local targetIndex = tonumber(index)
  for _, space in ipairs(spaces) do
    if tonumber(space.index) == targetIndex then
      return space.id
    end
  end

  return nil, ("space %s was not found"):format(tostring(index))
end

local nativeSpaceShortcutKeys = {
  [1] = "1",
  [2] = "2",
  [3] = "3",
  [4] = "4",
  [5] = "5",
  [6] = "6",
  [7] = "7",
  [8] = "8",
  [9] = "9",
  [10] = "0",
}

local function focusSpaceByNativeShortcut(index)
  local key = nativeSpaceShortcutKeys[tonumber(index)]
  if not key then
    return false
  end

  hs.eventtap.keyStroke({ "ctrl" }, key, 0)
  return true
end

local function focusSpaceByID(spaceID, index)
  if type(hs.spaces.gotoSpace) == "function" then
    local ok, result = pcall(hs.spaces.gotoSpace, spaceID)
    if ok and result ~= false then
      return true
    end
  end

  if focusSpaceByNativeShortcut(index) then
    return true
  end

  hs.alert.show("Failed to focus space " .. tostring(index), 2)
  return false
end

function _G.yabaiFocusSpace(index)
  local spaceID, err = spaceIDForIndex(index)
  if not spaceID then
    hs.alert.show(err, 2)
    return false
  end

  return focusSpaceByID(spaceID, index)
end

function _G.yabaiMoveFocusedWindowToSpace(index)
  local win = hs.window.focusedWindow()
  if not win then
    hs.alert.show("No focused window", 2)
    return false
  end

  local spaceID, err = spaceIDForIndex(index)
  if not spaceID then
    hs.alert.show(err, 2)
    return false
  end

  local ok, moveErr = hs.spaces.moveWindowToSpace(win, spaceID)
  if not ok then
    hs.alert.show(moveErr or ("Failed to move window to space " .. tostring(index)), 2)
    return false
  end

  hs.timer.doAfter(0.05, function()
    focusSpaceByID(spaceID, index)
  end)

  return true
end

local leftCommandTapState = {
  active = false,
  pressedAt = 0,
  usedAsModifier = false,
}

local function resetImeTapState(state)
  state.active = false
  state.pressedAt = 0
  state.usedAsModifier = false
end

-- Tap left Command to toggle between ABC and Japanese input sources.
_G.commandTapImeSwitch = hs.eventtap.new({ flagsChangedEvent, keyDownEvent }, function(event)
  local eventType = event:getType()

  if eventType == keyDownEvent then
    if leftCommandTapState.active then
      leftCommandTapState.usedAsModifier = true
    end

    return false
  end

  if event:getKeyCode() ~= leftCommandKeyCode then
    if leftCommandTapState.active then
      leftCommandTapState.usedAsModifier = true
    end

    return false
  end

  local commandPressed = event:getFlags().cmd

  if commandPressed and not leftCommandTapState.active then
    leftCommandTapState.active = true
    leftCommandTapState.usedAsModifier = false
    leftCommandTapState.pressedAt = hs.timer.secondsSinceEpoch()
    return false
  end

  if (not commandPressed) and leftCommandTapState.active then
    local tapped = not leftCommandTapState.usedAsModifier
      and (hs.timer.secondsSinceEpoch() - leftCommandTapState.pressedAt) <= imeConfig.tapThresholdSeconds
    resetImeTapState(leftCommandTapState)

    if tapped then
      toggleIme()
    end
  end

  return false
end)

local function systemZoomHotkeysEnabled()
  local output, ok = hs.execute("/usr/bin/defaults read com.apple.universalaccess closeViewHotkeysEnabled 2>/dev/null", true)
  return ok and output:match("[1tT]") ~= nil
end

local function toggleSystemZoom()
  if not systemZoomHotkeysEnabled() then
    hs.alert.show("Enable Accessibility > Zoom > keyboard shortcuts for global zoom.", 5)
    hs.urlevent.openURL("x-apple.systempreferences:com.apple.Accessibility-Settings.extension")
    return false
  end

  hs.eventtap.keyStroke({ "cmd", "alt" }, "8", 0)
  return true
end

-- Keep the eventtap in a global so Hammerspoon does not collect it.
_G.forcePressZoomTap = hs.eventtap.new({ eventTypes.gesture }, function(event)
  if not pressureEvent or event:getType(true) ~= pressureEvent then
    return false
  end

  local details = event:getTouchDetails()
  if not details then
    return false
  end

  local stage = details.stage or 0

  if stage >= 2 then
    local now = hs.timer.secondsSinceEpoch()
    if not forcePressActive and now - lastZoomToggleAt > debounceSeconds then
      forcePressActive = true
      lastZoomToggleAt = now
      zoomToggledForPress = toggleSystemZoom()
    end

    return true
  end

  if stage == 0 then
    if forcePressActive and zoomToggledForPress then
      toggleSystemZoom()
      zoomToggledForPress = false
    end

    forcePressActive = false
  end

  return false
end)

-- Ignore drag motion while a force press is active so zooming does not also
-- move the pointer selection/window under the cursor.
_G.forcePressDragSuppressor = hs.eventtap.new({ leftMouseDraggedEvent }, function(_)
  return forcePressActive
end)

if accessibilityEnabled then
  _G.commandTapImeSwitch:start()
  _G.forcePressZoomTap:start()
  _G.forcePressDragSuppressor:start()
else
  hs.alert.show("Enable Accessibility for Hammerspoon, then reopen it.", 5)
end
