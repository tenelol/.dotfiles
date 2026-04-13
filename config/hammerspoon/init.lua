local eventTypes = hs.eventtap.event.types
local pressureEvent = eventTypes.pressure
local forcePressActive = false
local lastSmartZoomAt = 0
local debounceSeconds = 0.5

hs.autoLaunch(true)
pcall(function()
  hs.ipc.cliInstall()
end)
local accessibilityEnabled = hs.accessibilityState(true)

local function smartZoom()
  local event = hs.eventtap.event.newGesture("smartMagnify")
  if event then
    event:post()
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
    if not forcePressActive and now - lastSmartZoomAt > debounceSeconds then
      forcePressActive = true
      lastSmartZoomAt = now
      smartZoom()
    end

    return true
  end

  if stage == 0 then
    forcePressActive = false
  end

  return false
end)

if accessibilityEnabled then
  _G.forcePressZoomTap:start()
else
  hs.alert.show("Enable Accessibility for Hammerspoon, then reopen it.", 5)
end
