local eventTypes = hs.eventtap.event.types
local keycodes = hs.keycodes
local keyDownEvent = eventTypes.keyDown
local flagsChangedEvent = eventTypes.flagsChanged
local leftMouseDraggedEvent = eventTypes.leftMouseDragged
local leftMouseDownEvent = eventTypes.leftMouseDown
local leftMouseUpEvent = eventTypes.leftMouseUp
local pressureEvent = eventTypes.pressure
local forcePressActive = false
local zoomToggledForPress = false
local lastZoomToggleAt = 0
local debounceSeconds = 0.5
local hoverFocusIntervalSeconds = 0.05
local hoverFocusSuppressSeconds = 0.2

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

local leftCommandTapState = {
  active = false,
  pressedAt = 0,
  usedAsModifier = false,
}

local hoverFocusState = {
  lastPoint = nil,
  suppressedUntil = 0,
  windowID = nil,
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

local function pointInFrame(point, frame)
  return point.x >= frame.x
    and point.x < (frame.x + frame.w)
    and point.y >= frame.y
    and point.y < (frame.y + frame.h)
end

local function windowAtPoint(point)
  for _, window in ipairs(hs.window.orderedWindows()) do
    if window:isStandard() and window:isVisible() then
      local frame = window:frame()
      if pointInFrame(point, frame) then
        return window
      end
    end
  end

  return nil
end

local function suppressHoverFocus()
  hoverFocusState.suppressedUntil = hs.timer.secondsSinceEpoch() + hoverFocusSuppressSeconds
end

local function updateHoverFocus()
  local now = hs.timer.secondsSinceEpoch()
  if now < hoverFocusState.suppressedUntil then
    return
  end

  if hs.eventtap.checkMouseButtons().left then
    return
  end

  local point = hs.mouse.absolutePosition()
  local lastPoint = hoverFocusState.lastPoint
  if lastPoint and point.x == lastPoint.x and point.y == lastPoint.y then
    return
  end
  hoverFocusState.lastPoint = point

  local window = windowAtPoint(point)
  if not window then
    hoverFocusState.windowID = nil
    return
  end

  local windowID = window:id()
  if not windowID or windowID == hoverFocusState.windowID then
    return
  end

  hoverFocusState.windowID = windowID
  window:focus()
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

_G.hoverFocusMouseTap = hs.eventtap.new({ leftMouseDownEvent, leftMouseUpEvent }, function(_)
  suppressHoverFocus()
  return false
end)

_G.hoverFocusTimer = hs.timer.new(hoverFocusIntervalSeconds, updateHoverFocus)

if accessibilityEnabled then
  _G.commandTapImeSwitch:start()
  _G.forcePressZoomTap:start()
  _G.forcePressDragSuppressor:start()
  _G.hoverFocusMouseTap:start()
  _G.hoverFocusTimer:start()
else
  hs.alert.show("Enable Accessibility for Hammerspoon, then reopen it.", 5)
end
