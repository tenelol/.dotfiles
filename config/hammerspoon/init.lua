local eventTypes = hs.eventtap.event.types
local keycodes = hs.keycodes
local keyDownEvent = eventTypes.keyDown
local flagsChangedEvent = eventTypes.flagsChanged
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
  englishLayout = "ABC",
  japaneseMethod = "Japanese",
  tapThresholdSeconds = 0.2,
}

local leftCommandKeyCode = keycodes.map.cmd
local rightCommandKeyCode = keycodes.map.rightcmd

local function switchToEnglish()
  if not keycodes.setLayout(imeConfig.englishLayout) then
    hs.alert.show(("Failed to switch to %s"):format(imeConfig.englishLayout), 2)
  end
end

local function switchToJapanese()
  if not keycodes.setMethod(imeConfig.japaneseMethod) then
    hs.alert.show(("Failed to switch to %s"):format(imeConfig.japaneseMethod), 2)
  end
end

local imeTapStates = {
  [leftCommandKeyCode] = {
    active = false,
    pressedAt = 0,
    usedAsModifier = false,
    onTap = switchToEnglish,
  },
  [rightCommandKeyCode] = {
    active = false,
    pressedAt = 0,
    usedAsModifier = false,
    onTap = switchToJapanese,
  },
}

local function resetImeTapState(state)
  state.active = false
  state.pressedAt = 0
  state.usedAsModifier = false
end

-- Tap left/right Command for explicit Eisu/Kana switching.
_G.commandTapImeSwitch = hs.eventtap.new({ flagsChangedEvent, keyDownEvent }, function(event)
  local eventType = event:getType()

  if eventType == keyDownEvent then
    for _, state in pairs(imeTapStates) do
      if state.active then
        state.usedAsModifier = true
      end
    end

    return false
  end

  local state = imeTapStates[event:getKeyCode()]
  if not state then
    return false
  end

  local commandPressed = event:getFlags().cmd

  if commandPressed and not state.active then
    state.active = true
    state.usedAsModifier = false
    state.pressedAt = hs.timer.secondsSinceEpoch()
    return false
  end

  if (not commandPressed) and state.active then
    local tapped = not state.usedAsModifier
      and (hs.timer.secondsSinceEpoch() - state.pressedAt) <= imeConfig.tapThresholdSeconds
    local onTap = state.onTap
    resetImeTapState(state)

    if tapped then
      onTap()
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

if accessibilityEnabled then
  _G.commandTapImeSwitch:start()
  _G.forcePressZoomTap:start()
else
  hs.alert.show("Enable Accessibility for Hammerspoon, then reopen it.", 5)
end
