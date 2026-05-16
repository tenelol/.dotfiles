local eventTypes = hs.eventtap.event.types
local eventProperties = hs.eventtap.event.properties
local json = hs.json
local keycodes = hs.keycodes
local keyDownEvent = eventTypes.keyDown
local flagsChangedEvent = eventTypes.flagsChanged
local leftMouseDraggedEvent = eventTypes.leftMouseDragged
local pressureEvent = eventTypes.pressure
local scrollWheelEvent = eventTypes.scrollWheel
local forcePressActive = false
local lastZoomToggleAt = 0
local debounceSeconds = 0.5
local controlTapSuppressedUntil = 0
local systemZoomActive = false
local lastSystemZoomStateCheckAt = 0
local zoomScrollAccumulator = 0
local lastZoomScaleStepAt = 0

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

local tmuxPrefixConfig = {
  tapThresholdSeconds = 0.25,
  doubleTapThresholdSeconds = 0.35,
  terminalBundleIDs = {
    ["com.mitchellh.ghostty"] = true,
    ["com.apple.Terminal"] = true,
    ["com.googlecode.iterm2"] = true,
  },
  terminalAppNames = {
    Ghostty = true,
    Terminal = true,
    iTerm2 = true,
  },
}

local zoomScrollConfig = {
  stepThreshold = 32,
  stepIntervalSeconds = 0.08,
  stateRefreshSeconds = 0.5,
}

local leftCommandKeyCode = keycodes.map.cmd
local leftControlKeyCode = keycodes.map.ctrl or 59
local rightControlKeyCode = keycodes.map.rightctrl or 62
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

local function frontmostAppIsTerminal()
  local app = hs.application.frontmostApplication()
  if not app then
    return false
  end

  return tmuxPrefixConfig.terminalBundleIDs[app:bundleID()]
    or tmuxPrefixConfig.terminalAppNames[app:name()]
    or false
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

local function focusSpaceByNativeShortcut(index)
  controlTapSuppressedUntil = hs.timer.secondsSinceEpoch() + 0.5
  hs.eventtap.keyStroke({ "ctrl" }, tostring(index), 0)
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
    focusSpaceByNativeShortcut(index)
  end)

  return true
end

local leftCommandTapState = {
  active = false,
  pressedAt = 0,
  usedAsModifier = false,
}
local controlTapState = {
  active = false,
  pressedAt = 0,
  usedAsModifier = false,
  lastTappedAt = 0,
}

local function resetImeTapState(state)
  state.active = false
  state.pressedAt = 0
  state.usedAsModifier = false
end

local function resetControlTapState()
  resetImeTapState(controlTapState)
  controlTapState.lastTappedAt = 0
end

local function sendTmuxPrefixOnControlDoubleTap()
  if frontmostAppIsTerminal() then
    hs.eventtap.keyStroke({ "ctrl" }, "a", 0)
  end
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

-- Double-tap Control in terminals to send the tmux prefix (Ctrl-a).
_G.controlDoubleTapTmuxPrefix = hs.eventtap.new({ flagsChangedEvent, keyDownEvent }, function(event)
  if hs.timer.secondsSinceEpoch() <= controlTapSuppressedUntil then
    resetControlTapState()
    return false
  end

  local eventType = event:getType()

  if eventType == keyDownEvent then
    if controlTapState.active then
      controlTapState.usedAsModifier = true
    end

    return false
  end

  local keyCode = event:getKeyCode()
  if keyCode ~= leftControlKeyCode and keyCode ~= rightControlKeyCode then
    if controlTapState.active then
      controlTapState.usedAsModifier = true
    end

    return false
  end

  local controlPressed = event:getFlags().ctrl

  if controlPressed and not controlTapState.active then
    controlTapState.active = true
    controlTapState.usedAsModifier = false
    controlTapState.pressedAt = hs.timer.secondsSinceEpoch()
    return false
  end

  if (not controlPressed) and controlTapState.active then
    local now = hs.timer.secondsSinceEpoch()
    local tapped = not controlTapState.usedAsModifier
      and (now - controlTapState.pressedAt) <= tmuxPrefixConfig.tapThresholdSeconds

    resetImeTapState(controlTapState)

    if tapped then
      if (now - controlTapState.lastTappedAt) <= tmuxPrefixConfig.doubleTapThresholdSeconds then
        controlTapState.lastTappedAt = 0
        sendTmuxPrefixOnControlDoubleTap()
      else
        controlTapState.lastTappedAt = now
      end
    end
  end

  return false
end)

local function syncControlDoubleTapTmuxPrefix()
  if not _G.controlDoubleTapTmuxPrefix then
    return
  end

  if frontmostAppIsTerminal() then
    if not _G.controlDoubleTapTmuxPrefix:isEnabled() then
      _G.controlDoubleTapTmuxPrefix:start()
    end
  else
    if _G.controlDoubleTapTmuxPrefix:isEnabled() then
      _G.controlDoubleTapTmuxPrefix:stop()
    end
    resetControlTapState()
  end
end

_G.terminalFocusWatcher = hs.application.watcher.new(function()
  syncControlDoubleTapTmuxPrefix()
end)

local function systemZoomHotkeysEnabled()
  local output, ok = hs.execute("/usr/bin/defaults read com.apple.universalaccess closeViewHotkeysEnabled 2>/dev/null", true)
  return ok and output:match("[1tT]") ~= nil
end

local function readSystemZoomedIn()
  local output, ok = hs.execute("/usr/bin/defaults read com.apple.universalaccess closeViewZoomedIn 2>/dev/null", true)
  return ok and output:match("[1tT]") ~= nil
end

local function refreshSystemZoomState(force)
  local now = hs.timer.secondsSinceEpoch()
  if force or now - lastSystemZoomStateCheckAt > zoomScrollConfig.stateRefreshSeconds then
    systemZoomActive = readSystemZoomedIn()
    lastSystemZoomStateCheckAt = now
  end

  return systemZoomActive
end

local function sendSystemZoomShortcut(key)
  if not systemZoomHotkeysEnabled() then
    hs.alert.show("Enable Accessibility > Zoom > keyboard shortcuts for global zoom.", 5)
    hs.urlevent.openURL("x-apple.systempreferences:com.apple.Accessibility-Settings.extension")
    return false
  end

  hs.eventtap.keyStroke({ "cmd", "alt" }, key, 0)
  return true
end

local function toggleSystemZoom()
  local wasActive = refreshSystemZoomState(true)

  if not sendSystemZoomShortcut("8") then
    return false
  end

  systemZoomActive = not wasActive
  lastSystemZoomStateCheckAt = hs.timer.secondsSinceEpoch()
  zoomScrollAccumulator = 0

  hs.timer.doAfter(0.2, function()
    refreshSystemZoomState(true)
  end)

  return true
end

local function trackpadScrollDelta(event)
  local continuous = event:getProperty(eventProperties.scrollWheelEventIsContinuous) or 0
  if continuous == 0 then
    return nil
  end

  local vertical = event:getProperty(eventProperties.scrollWheelEventPointDeltaAxis1) or 0
  local horizontal = event:getProperty(eventProperties.scrollWheelEventPointDeltaAxis2) or 0

  if vertical == 0 then
    vertical = event:getProperty(eventProperties.scrollWheelEventFixedPtDeltaAxis1) or 0
  end

  if horizontal == 0 then
    horizontal = event:getProperty(eventProperties.scrollWheelEventFixedPtDeltaAxis2) or 0
  end

  if math.abs(vertical) <= math.abs(horizontal) then
    return nil
  end

  return vertical
end

local function scrollGestureEnded(event)
  local phase = event:getProperty(eventProperties.scrollWheelEventScrollPhase) or 0
  return phase == 4 or phase == 8
end

local function scrollIsMomentum(event)
  local momentumPhase = event:getProperty(eventProperties.scrollWheelEventMomentumPhase) or 0
  return momentumPhase ~= 0
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
      toggleSystemZoom()
    end

    return true
  end

  if stage == 0 then
    forcePressActive = false
  end

  return false
end)

-- While zoomed in, use two-finger vertical trackpad scroll to change zoom scale.
_G.forcePressZoomScaleTap = hs.eventtap.new({ scrollWheelEvent }, function(event)
  if not refreshSystemZoomState(false) then
    return false
  end

  if scrollGestureEnded(event) then
    zoomScrollAccumulator = 0
    return true
  end

  if scrollIsMomentum(event) then
    return true
  end

  local delta = trackpadScrollDelta(event)
  if not delta then
    return false
  end

  zoomScrollAccumulator = zoomScrollAccumulator + delta

  if math.abs(zoomScrollAccumulator) < zoomScrollConfig.stepThreshold then
    return true
  end

  local now = hs.timer.secondsSinceEpoch()
  if now - lastZoomScaleStepAt < zoomScrollConfig.stepIntervalSeconds then
    return true
  end

  lastZoomScaleStepAt = now
  if zoomScrollAccumulator > 0 then
    sendSystemZoomShortcut("=")
  else
    sendSystemZoomShortcut("-")
  end

  zoomScrollAccumulator = 0
  return true
end)

-- Ignore drag motion while a force press is active so zooming does not also
-- move the pointer selection/window under the cursor.
_G.forcePressDragSuppressor = hs.eventtap.new({ leftMouseDraggedEvent }, function(_)
  return forcePressActive
end)

if accessibilityEnabled then
  refreshSystemZoomState(true)
  _G.commandTapImeSwitch:start()
  _G.terminalFocusWatcher:start()
  syncControlDoubleTapTmuxPrefix()
  _G.forcePressZoomTap:start()
  _G.forcePressZoomScaleTap:start()
  _G.forcePressDragSuppressor:start()
else
  hs.alert.show("Enable Accessibility for Hammerspoon, then reopen it.", 5)
end
