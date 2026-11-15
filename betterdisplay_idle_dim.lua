-- BetterDisplay dual-monitor physical-input idle dimmer v2.3.0 (software-only public release)
-- Preserves per-monitor SOFTWARE brightness. Never writes hardware/DDC brightness.
-- Dedicated native HID timer distinguishes many synthetic events, but not all automation methods.
-- Improvements: retained timers, robust activity detection, wake restoration, watchdog, on-disk log.

local IDLE_SECONDS = 600  -- 10 minutes
local DIM_LEVEL = 0.0  -- zero percent SOFTWARE brightness (Mac image only)
local POLL_SECONDS = 2
local REMOTE_POLL_SECONDS = 10
local MANUAL_HOLD_SECONDS = 1800
local ENABLE_SCREEN_SHARING_DETECTION = true
local EVENT_THRESHOLD_SECONDS = 0.40
local WATCHDOG_SECONDS = 8
local WATCHDOG_STALL_SECONDS = 14
local LOG_HEARTBEAT_SECONDS = 300

local HOME = os.getenv('HOME')
local BETTERDISPLAY = '/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay'
local HID_QUERY = HOME .. '/.hammerspoon/physical_idle_query'
local LOG_FILE = HOME .. '/.hammerspoon/betterdisplay_idle_dim.log'
local SNAPSHOT_FILE = HOME .. '/.hammerspoon/betterdisplay_idle_dim.snapshot'
local DISABLE_FILE = HOME .. '/.hammerspoon/.betterdisplay_idle_dim.disabled'
local SNAPSHOT_KEY = 'betterdisplay_idle_dim_saved_software_v23' -- separate from legacy combined snapshot
local log = hs.logger.new('BD-HIDDim', 'info')
local screens = {
  {key = 'main', selector = '-displayWithMainStatus'},
  {key = 'other', selector = '-displayWithNonMainStatus'},
}

local saved = hs.settings.get(SNAPSHOT_KEY)
local dimmed = type(saved) == 'table'
local remoteConnected = false
local remoteCheckedAt = 0
local manualHoldUntil = 0
local lastProbeErrorAt = 0
local lastHeartbeatAt = 0
local lastPollAt = hs.timer.secondsSinceEpoch()
local lastInputEventAt = nil

local function writeLog(level, message)
  local entry = os.date('%Y-%m-%d %H:%M:%S') .. ' [' .. level .. '] ' .. message
  if level == 'ERROR' then log.e(message) else log.i(message) end
  local f = io.open(LOG_FILE, 'a')
  if f then f:write(entry, '\n'); f:close() end
end

local function runBrightness(operation, selector, value, feature)
  local cmd = string.format('%q %s %s -%s', BETTERDISPLAY, operation, selector, feature or 'softwareBrightness')
  if value ~= nil then cmd = cmd .. '=' .. string.format('%.4f', value) end
  local output, ok = hs.execute(cmd, false)
  if not ok then
    writeLog('ERROR', 'BetterDisplay CLI failed: ' .. cmd .. ' / ' .. tostring(output))
    return nil
  end
  return output
end

local function readBrightness(selector)
  local output = runBrightness('get', selector)
  if not output then return nil end
  local n = tonumber(output:match('^%s*(%d+%.?%d*)%s*$'))
  if not n or n < 0 or n > 1 then
    writeLog('ERROR', 'Unexpected BetterDisplay brightness: ' .. tostring(output))
    return nil
  end
  return n
end

local function writeBrightness(selector, value)
  -- All write calls in this module use softwareBrightness only.
  return runBrightness('set', selector, value, 'softwareBrightness') ~= nil
end

local function hardwareBrightness(selector)
  -- Read-only DDC diagnostic: no -hardwareBrightness writes.
  local output = runBrightness('get', selector, nil, 'hardwareBrightness')
  if not output then return nil end
  return tonumber(output:match('^%s*(%d+%.?%d*)%s*$'))
end

local function logHardwareLevels(phase)
  local a = hardwareBrightness(screens[1].selector)
  local b = hardwareBrightness(screens[2].selector)
  writeLog('INFO', string.format('%s hardware (read-only) main=%s other=%s',
    phase, tostring(a), tostring(b)))
end

local function restore(reason)
  if not dimmed or type(saved) ~= 'table' then return true end
  local allOK = true
  for _, screen in ipairs(screens) do
    local value = saved[screen.key]
    if type(value) ~= 'number' or not writeBrightness(screen.selector, value) then
      allOK = false
    end
  end
  if allOK then
    dimmed = false
    saved = nil
    hs.settings.clear(SNAPSHOT_KEY)
    os.remove(SNAPSHOT_FILE)
    writeLog('INFO', 'Restored both monitors; reason=' .. tostring(reason or 'activity'))
  else
    writeLog('ERROR', 'Restore incomplete; saved brightness snapshot retained')
  end
  return allOK
end

local function dim()
  if dimmed then return end
  local levels = {}
  for _, screen in ipairs(screens) do
    local value = readBrightness(screen.selector)
    if value == nil then
      writeLog('ERROR', 'Dimming cancelled: could not read both brightness values')
      return
    end
    levels[screen.key] = value
  end
  -- Plain-text safety snapshot makes recovery possible without Hammerspoon.
  -- Do not darken the monitors if the recovery file could not be saved.
  local snapshot, err = io.open(SNAPSHOT_FILE, 'w')
  if not snapshot then
    writeLog('ERROR', 'Dimming cancelled: cannot write recovery snapshot: ' .. tostring(err))
    return
  end
  snapshot:write(string.format('mode=software\nmain=%.4f\nother=%.4f\n', levels.main, levels.other))
  logHardwareLevels('before dim')
  snapshot:close()
  saved = levels
  dimmed = true
  hs.settings.set(SNAPSHOT_KEY, saved)
  for _, screen in ipairs(screens) do
    if not writeBrightness(screen.selector, DIM_LEVEL) then
      writeLog('ERROR', 'Dimming failed; attempting immediate restore')
      restore('dim command failed')
      return
    end
  end
  logHardwareLevels('after dim')
  writeLog('INFO', string.format('Both Mac images dimmed to %.1f%% SOFTWARE only; saved main=%.3f other=%.3f', DIM_LEVEL * 100, levels.main, levels.other))
end

local function physicalIdleSeconds()
  local output, ok = hs.execute(string.format('%q', HID_QUERY), false)
  if not ok then return nil end
  local n = tonumber(output:match('^%s*([%d%.]+)%s*$'))
  if not n or n < 0 or n > 315360000 then return nil end
  return n
end

local function checkScreenSharing(now)
  if not ENABLE_SCREEN_SHARING_DETECTION then return false end
  if now - remoteCheckedAt < REMOTE_POLL_SECONDS then return remoteConnected end
  remoteCheckedAt = now
  -- Best effort: native macOS Screen Sharing over TCP/5900, not every remote tool.
  local output = hs.execute('/usr/sbin/lsof -nP -iTCP:5900 -sTCP:ESTABLISHED 2>/dev/null', false)
  local connected = type(output) == 'string' and output:find('TCP') ~= nil
  if connected ~= remoteConnected then
    remoteConnected = connected
    writeLog('INFO', 'Apple Screen Sharing TCP 5900 ' .. (connected and 'connected' or 'disconnected'))
  end
  return remoteConnected
end

local function manualRestore()
  manualHoldUntil = hs.timer.secondsSinceEpoch() + MANUAL_HOLD_SECONDS
  restore('emergency hotkey')
  writeLog('INFO', 'Emergency manual hold enabled for ' .. MANUAL_HOLD_SECONDS .. ' seconds')
end

local function poll()
  local now = hs.timer.secondsSinceEpoch()
  lastPollAt = now
  local idle = physicalIdleSeconds()
  if idle == nil then
    if now - lastProbeErrorAt > 60 then
      lastProbeErrorAt = now
      writeLog('ERROR', 'HID query failed; restoring for safety')
    end
    restore('HID query failed')
    return
  end

  -- HID idle can be large after hours of inactivity. Derive the last physical
  -- event time, rather than requiring idle < 3s on exactly one poll.
  local eventAt = now - idle
  local newPhysicalInput = false
  if lastInputEventAt == nil then
    lastInputEventAt = eventAt
  elseif eventAt > lastInputEventAt + EVENT_THRESHOLD_SECONDS then
    newPhysicalInput = true
    lastInputEventAt = eventAt
  elseif eventAt < lastInputEventAt - 120 then
    -- Clock jump or HID counter reset: prefer a visible screen to a dark one.
    lastInputEventAt = eventAt
    restore('HID time jump/reset')
  end

  local remote = checkScreenSharing(now)
  local manualHold = now < manualHoldUntil
  if dimmed then
    if newPhysicalInput then
      restore(string.format('new physical HID input (idle=%.2fs)', idle))
    elseif remote then
      restore('Screen Sharing connected')
    elseif manualHold then
      restore('manual hold')
    elseif now - lastHeartbeatAt >= LOG_HEARTBEAT_SECONDS then
      lastHeartbeatAt = now
      writeLog('INFO', string.format('heartbeat dimmed=true HID_idle=%.1fs poll_timer_alive=%s', idle, tostring(_G.BDIdleDimTimer ~= nil and _G.BDIdleDimTimer:running())))
    end
  elseif idle >= IDLE_SECONDS and not remote and not manualHold then
    dim()
  end
end

local function safePoll()
  local ok, err = xpcall(poll, debug.traceback)
  if not ok then
    writeLog('ERROR', 'Poll exception: ' .. tostring(err))
    manualHoldUntil = hs.timer.secondsSinceEpoch() + 120
    pcall(restore, 'poll exception')
  end
end

local function onPowerEvent(event)
  local w = hs.caffeinate.watcher
  if event == w.systemDidWake or event == w.screensDidWake or
     event == w.sessionDidBecomeActive or event == w.screensDidUnlock then
    manualHoldUntil = hs.timer.secondsSinceEpoch() + 60
    restore('wakeup/session activation event ' .. tostring(event))
    -- Re-baseline HID event detection following a real wake/session change.
    lastInputEventAt = nil
    writeLog('INFO', 'Wake/session event observed; dimming deferred for 60 seconds')
  end
end

local function watchdog()
  local now = hs.timer.secondsSinceEpoch()
  if not _G.BDIdleDimTimer or not _G.BDIdleDimTimer:running() then
    writeLog('ERROR', 'Poll timer stopped; restarting and restoring for safety')
    manualHoldUntil = now + 120
    pcall(restore, 'poll timer stopped')
    if _G.BDIdleDimTimer then _G.BDIdleDimTimer:start() end
    lastPollAt = now
  elseif now - lastPollAt > WATCHDOG_STALL_SECONDS then
    writeLog('ERROR', string.format('Poll stalled for %.1fs; restoring for safety', now - lastPollAt))
    manualHoldUntil = now + 120
    pcall(restore, 'poll timer stalled')
    lastPollAt = now
  end
end

-- Diagnostic query from Hammerspoon Console: print(BDIdleDimStatus())
_G.BDIdleDimStatus = function()
  local idle = physicalIdleSeconds()
  return string.format('v2.3 SOFTWARE ONLY dimmed=%s HID_idle=%s poll_alive=%s watchdog_alive=%s last_poll_age=%.1fs remote=%s manual_hold_remaining=%.0fs log=%s',
    tostring(dimmed), tostring(idle),
    tostring(_G.BDIdleDimTimer ~= nil and _G.BDIdleDimTimer:running()),
    tostring(_G.BDIdleWatchdogTimer ~= nil and _G.BDIdleWatchdogTimer:running()),
    hs.timer.secondsSinceEpoch() - lastPollAt, tostring(remoteConnected),
    math.max(0, manualHoldUntil - hs.timer.secondsSinceEpoch()), LOG_FILE)
end

-- Restore saved brightness on reload, even if the module is being disabled.
if dimmed then restore('Hammerspoon reload/restart') end

if hs.fs.attributes(DISABLE_FILE) then
  writeLog('INFO', 'Auto dimming disabled by user marker: ' .. DISABLE_FILE)
  return
end

if not hs.fs.attributes(BETTERDISPLAY) or not hs.fs.attributes(HID_QUERY) then
  writeLog('ERROR', 'BetterDisplay or HID helper missing: automatic dimmer not started')
else
  hs.caffeinate.set('displayIdle', true)
  hs.hotkey.bind({'ctrl', 'alt', 'cmd'}, 15, manualRestore)
  -- Explicitly retain timer and power watcher objects for the life of the Lua VM.
  _G.BDIdleDimTimer = hs.timer.new(POLL_SECONDS, safePoll, true):start()
  _G.BDIdleWatchdogTimer = hs.timer.new(WATCHDOG_SECONDS, watchdog, true):start()
  _G.BDIdleWakeWatcher = hs.caffeinate.watcher.new(onPowerEvent):start()
  writeLog('INFO', string.format('v2.3 SOFTWARE ONLY started; idle=%ds dim=%.1f%% poll=%ds watchdog=%ds VNC=%s',
    IDLE_SECONDS, DIM_LEVEL * 100, POLL_SECONDS, WATCHDOG_SECONDS,
    tostring(ENABLE_SCREEN_SHARING_DETECTION)))
end
