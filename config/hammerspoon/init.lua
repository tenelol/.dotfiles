local eventTypes = hs.eventtap.event.types
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

local zoomPressConfig = {
  zoomOutStepsOnPress = 24,
  zoomInStepsOnPress = 7,
}

local leftControlKeyCode = keycodes.map.ctrl or 59
local rightControlKeyCode = keycodes.map.rightctrl or 62

local function frontmostAppIsTerminal()
  local app = hs.application.frontmostApplication()
  if not app then
    return false
  end

  return tmuxPrefixConfig.terminalBundleIDs[app:bundleID()]
    or tmuxPrefixConfig.terminalAppNames[app:name()]
    or false
end

local controlTapState = {
  active = false,
  pressedAt = 0,
  usedAsModifier = false,
  lastTappedAt = 0,
}

local function resetTapState(state)
  state.active = false
  state.pressedAt = 0
  state.usedAsModifier = false
end

local function resetControlTapState()
  resetTapState(controlTapState)
  controlTapState.lastTappedAt = 0
end

local function sendTmuxPrefixOnControlDoubleTap()
  if frontmostAppIsTerminal() then
    hs.eventtap.keyStroke({}, "f12", 0)
  end
end

-- Double-tap Control in terminals to send the tmux prefix (F12).
_G.controlDoubleTapTmuxPrefix = hs.eventtap.new({ flagsChangedEvent, keyDownEvent }, function(event)
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

    resetTapState(controlTapState)

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

local function toggleSystemZoom()
  if not systemZoomHotkeysEnabled() then
    hs.alert.show("Enable Accessibility > Zoom > keyboard shortcuts for global zoom.", 5)
    hs.urlevent.openURL("x-apple.systempreferences:com.apple.Accessibility-Settings.extension")
    return false
  end

  hs.eventtap.keyStroke({ "cmd", "alt" }, "8", 0)
  return true
end

local function normalizeActiveSystemZoomScale()
  for _ = 1, zoomPressConfig.zoomOutStepsOnPress do
    hs.eventtap.keyStroke({ "cmd", "alt" }, "-", 0)
  end

  for _ = 1, zoomPressConfig.zoomInStepsOnPress do
    hs.eventtap.keyStroke({ "cmd", "alt" }, "=", 0)
  end
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
      if zoomToggledForPress then
        hs.timer.doAfter(0.05, function()
          if forcePressActive and zoomToggledForPress then
            normalizeActiveSystemZoomScale()
          end
        end)
      end
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
  _G.terminalFocusWatcher:start()
  syncControlDoubleTapTmuxPrefix()
  _G.forcePressZoomTap:start()
  _G.forcePressDragSuppressor:start()
else
  hs.alert.show("Enable Accessibility for Hammerspoon, then reopen it.", 5)
end
