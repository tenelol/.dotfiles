local eventTypes = hs.eventtap.event.types
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

local zoomPressConfig = {
  zoomOutStepsOnPress = 24,
  zoomInStepsOnPress = 7,
}

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
  _G.forcePressZoomTap:start()
  _G.forcePressDragSuppressor:start()
else
  hs.alert.show("Enable Accessibility for Hammerspoon, then reopen it.", 5)
end
