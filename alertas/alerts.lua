-- alerts.lua: voice + haptic warnings for battery per cell and link quality.
-- Runs from a Special Function: ON > Lua Script > alerts (repeat On).
-- Only speaks while the receiver is linked, so the simulator model stays quiet.

local WARN_CELL, CRIT_CELL = 3.5, 3.3 -- volts per cell
local WARN_LQ, CRIT_LQ = 50, 25       -- link quality %
local HOLD = 300                      -- 3 s below a limit before warning (ignores punch-out sag)

local cells                           -- detected once per connection
local since = {}                      -- when each condition started (10 ms ticks)
local nextSay = {}                    -- when each warning may repeat

local function sensor(name)
  local f = getFieldInfo(name)
  if not f then return nil end
  return getValue(f.id)
end

-- true once `active` has held for HOLD ticks; false resets the timer
local function held(key, active, now)
  if not active then since[key] = nil return false end
  since[key] = since[key] or now
  return now - since[key] >= HOLD
end

local function due(key, every, now)
  if now < (nextSay[key] or 0) then return false end
  nextSay[key] = now + every
  return true
end

local function run()
  local now = getTime()
  local lq = sensor("RQly")
  if type(lq) ~= "number" or lq <= 0 then
    -- link lost or not powered: start over next time (reset once, not every frame)
    if cells or next(since) or next(nextSay) then cells, since, nextSay = nil, {}, {} end
    return
  end

  local v = sensor("RxBt")
  if type(v) == "number" and v > 2 then
    cells = cells or math.ceil(v / 4.35) -- 4.35 V = fullest HV cell, so a full pack never undercounts
    local cell = v / cells
    if held("crit", cell < CRIT_CELL, now) then
      if due("crit", 800, now) then
        playFile("/SOUNDS/en/clobat.wav")
        playHaptic(30, 10, PLAY_NOW)
      end
    elseif held("warn", cell < WARN_CELL, now) then
      if due("warn", 2000, now) then
        playFile("/SOUNDS/en/lowbat.wav")
        playNumber(math.floor(cell * 10 + 0.5), 1, PREC1) -- e.g. "3.4 volts"
      end
    end
  end

  if held("lqcrit", lq < CRIT_LQ, now) then
    if due("lqcrit", 500, now) then
      playFile("/SOUNDS/en/sigcrt.wav")
      playHaptic(20, 10, PLAY_NOW)
    end
  elseif held("lqwarn", lq < WARN_LQ, now) then
    if due("lqwarn", 1000, now) then playFile("/SOUNDS/en/siglow.wav") end
  end
end

return { run = run }
