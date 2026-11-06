-- TNS|FPV Radar|TNE
-- FPV Radar: find a crashed quad by its ELRS signal (Pocket/128x64).
-- The radar sweep is decoration: the receiver gives signal strength, not direction.
-- The target ring shrinks and the bar fills as the signal gets stronger.
-- Direction comes from a guided spin: hold the radio against your chest and turn
-- right 45 deg on each beep. Your body blocks the signal from behind, so the step
-- with the strongest average signal is the one where you faced the quad.
-- ENTER: start/cancel spin   ENTER long: sound on/off
-- NEXT/PREV: reset peak and direction   EXIT: close

local CX, CY = 25, 33          -- radar center
local RINGS = { 7, 14, 21 }
local DBM_FAR, DBM_NEAR = -115, -45 -- signal range mapped to 0..100 %
local SEGMENTS = 24

local ring = {}                -- precomputed dotted circle points
local smooth, peak = nil, 0
local history, histAt = {}, 0  -- smoothed dBm sampled every 0.5 s, for the trend arrow
local muted, nextBeep = false, 0

local STEPS = 8                -- 8 x 45 deg = one full turn
local STEP_T, SETTLE_T = 200, 70 -- 2 s per step, first 0.7 s ignored while you turn
-- shortcut: fixed 3 dB threshold, untested in the field; tune after real spins.
local MIN_SPREAD = 3           -- best minus worst step below this: direction unreliable
local spin = nil               -- { k = step, at = step start, sum = {}, n = {}, pwr, pwrMoved }
local result = nil             -- { lvl = {}, best = k, spread = dB, weak = bool } or { fail = text }

local function init()
  for _, r in ipairs(RINGS) do
    local n = r * 3
    for k = 0, n - 1 do
      local a = k / n * 2 * math.pi
      ring[#ring + 1] = { math.floor(CX + math.cos(a) * r + 0.5), math.floor(CY + math.sin(a) * r + 0.5) }
    end
  end
end

local function sensor(name)
  local f = getFieldInfo(name)
  if not f then return nil end
  return getValue(f.id)
end

-- best antenna in dBm, or nil when the receiver is not linked
local function signal()
  local lq = sensor("RQly")
  if type(lq) ~= "number" or lq <= 0 then return nil end
  local a, b = sensor("1RSS"), sensor("2RSS")
  local best
  for _, v in ipairs({ a or 0, b or 0 }) do
    if type(v) == "number" and v < 0 and (best == nil or v > best) then best = v end
  end
  return best, lq
end

local function stateWord(p)
  if p >= 0.85 then return "HERE!" end
  if p >= 0.6 then return "CLOSE" end
  if p >= 0.3 then return "WARM" end
  return "FAR"
end

-- With ELRS dynamic power the radio lowers power as you get close, which flattens
-- the signal. A fixed 25 mW gives a reading that keeps rising: warn when it differs.
local SEARCH_MW = 25

local function header(now)
  lcd.drawFilledRectangle(0, 0, LCD_W, 9)
  lcd.drawText(3, 1, muted and "RADAR MUTE" or "FPV RADAR", SMLSIZE + INVERS)
  local pwr = sensor("TPWR")
  if type(pwr) == "number" and pwr > 0 then
    local off = pwr ~= SEARCH_MW
    lcd.drawText(LCD_W - 3, 1, pwr .. "mW" .. (off and "!" or ""), SMLSIZE + INVERS + RIGHT + (off and BLINK or 0))
  end
end

-- screen angle of spin step k: step 1 points up (where you faced at the start), clockwise
local function stepAngle(k) return (k - 1) * math.pi / 4 - math.pi / 2 end

local function tip(ang, r)
  return math.floor(CX + math.cos(ang) * r + 0.5), math.floor(CY + math.sin(ang) * r + 0.5)
end

-- average dBm per step so far (nil where no sample), with min and max
local function spinLevels()
  local lvl, lo, hi = {}, nil, nil
  for k = 1, STEPS do
    if (spin.n[k] or 0) > 0 then
      local v = spin.sum[k] / spin.n[k]
      lvl[k] = v
      if not lo or v < lo then lo = v end
      if not hi or v > hi then hi = v end
    end
  end
  return lvl, lo, hi
end

local function spinStart(now)
  local pwr = sensor("TPWR")
  spin = { k = 1, at = now, sum = {}, n = {}, pwr = pwr }
  result = nil
  playTone(1500, 80, 0)
end

local function spinFinish()
  local lvl, lo, hi = spinLevels()
  local best, valid = nil, 0
  for k = 1, STEPS do
    if lvl[k] then
      valid = valid + 1
      if not best or lvl[k] > lvl[best] then best = k end
    end
  end
  if valid < STEPS - 2 then
    result = { fail = "NO LINK" }
  else
    local spread = hi - lo
    result = { lvl = lvl, lo = lo, hi = hi, best = best, spread = spread,
               weak = spread < MIN_SPREAD or spin.pwrMoved }
  end
  spin = nil
  playTone(2000, 250, 0)
end

local function spinUpdate(dbm, now)
  local k = spin.k
  if dbm and now - spin.at >= SETTLE_T then
    spin.sum[k] = (spin.sum[k] or 0) + dbm
    spin.n[k] = (spin.n[k] or 0) + 1
    local pwr = sensor("TPWR")
    if pwr ~= spin.pwr then spin.pwrMoved = true end -- dynamic power skews the comparison
  end
  if now - spin.at >= STEP_T then
    if k >= STEPS then spinFinish() return end
    spin.k, spin.at = k + 1, now
    playTone(1500, 80, 0)
  end
end

-- "AHEAD", "BEHIND", or degrees to turn right (R) or left (L) from where you started
local function dirText(k)
  local deg = (k - 1) * 45
  if deg == 0 then return "AHEAD" end
  if deg == 180 then return "BEHIND" end
  if deg < 180 then return deg .. "R" end
  return (360 - deg) .. "L"
end

-- polar plot: one dotted spoke per step, longer = stronger
local function spokes(lvl, lo, hi)
  for k = 1, STEPS do
    if lvl[k] then
      local rel = hi > lo and (lvl[k] - lo) / (hi - lo) or 1
      local x, y = tip(stepAngle(k), 4 + rel * 15)
      lcd.drawLine(CX, CY, x, y, DOTTED, FORCE)
    end
  end
end

local function arrow(k)
  local ang = stepAngle(k)
  local x, y = tip(ang, 21)
  lcd.drawLine(CX, CY, x, y, SOLID, FORCE)
  for _, side in ipairs({ 2.6, -2.6 }) do
    local hx = math.floor(x + math.cos(ang + side) * 5 + 0.5)
    local hy = math.floor(y + math.sin(ang + side) * 5 + 0.5)
    lcd.drawLine(x, y, hx, hy, SOLID, FORCE)
  end
end

local function radar(p, linked, now)
  for _, pt in ipairs(ring) do lcd.drawPoint(pt[1], pt[2]) end
  lcd.drawLine(CX - 2, CY, CX + 2, CY, SOLID, FORCE)
  lcd.drawLine(CX, CY - 2, CX, CY + 2, SOLID, FORCE)

  if spin then
    local lvl, lo, hi = spinLevels()
    if lo then spokes(lvl, lo, hi) end
    local x, y = tip(stepAngle(spin.k), 21) -- where you should be facing now
    lcd.drawLine(CX, CY, x, y, SOLID, FORCE)
    return
  end

  if result and result.best then
    spokes(result.lvl, result.lo, result.hi)
    if not result.weak or (now // 50) % 2 == 0 then arrow(result.best) end -- blinks when unsure
    return -- no target ring over the arrow; %, bar and beeps still say hot or cold
  else
    -- sweep: one solid arm and two fading dotted arms behind it
    local a = (now % 300) / 300 * 2 * math.pi
    for i = 0, 2 do
      local x, y = tip(a - i * 0.22, 21)
      lcd.drawLine(CX, CY, x, y, i == 0 and SOLID or DOTTED, FORCE)
    end
  end

  if linked then
    -- target ring: radius shrinks as the quad gets closer, pulses twice a second
    local r = 3 + math.floor((1 - p) * 18 + 0.5)
    if (now // 25) % 2 == 0 then r = r + 1 end
    local n = 10 + r
    for k = 0, n - 1 do
      local ang = k / n * 2 * math.pi
      local x = math.floor(CX + math.cos(ang) * r + 0.5)
      local y = math.floor(CY + math.sin(ang) * r + 0.5)
      lcd.drawFilledRectangle(x, y, 2, 2)
    end
  end
end

local function spinPanel(now)
  local x = 52
  lcd.drawText(x, 12, "SPIN " .. spin.k .. "/" .. STEPS, SMLSIZE)
  if now - spin.at < SETTLE_T then
    lcd.drawText(x, 22, spin.k == 1 and "FACE" or "TURN R", MIDSIZE + INVERS)
  else
    lcd.drawText(x, 22, "HOLD", MIDSIZE)
  end
  lcd.drawText(x, 38, "Radio on chest", SMLSIZE)
  lcd.drawText(x, 45, "ENTER: cancel", SMLSIZE)
end

local function panel(p, dbm, lq, linked, now)
  local x = 52
  if spin then return spinPanel(now) end
  if result and result.fail then
    lcd.drawText(x, 12, "SPIN FAILED", SMLSIZE)
  elseif result then
    lcd.drawText(x, 12, "DIR " .. dirText(result.best), SMLSIZE + (result.weak and BLINK or 0))
  else
    lcd.drawText(x, 12, "SIGNAL", SMLSIZE)
  end
  if not linked then
    lcd.drawText(x, 22, "NO LINK", MIDSIZE + ((now // 50) % 2 == 0 and INVERS or 0))
    lcd.drawText(x, 38, "Power the", SMLSIZE)
    lcd.drawText(x, 45, "quad, walk", SMLSIZE)
    return
  end
  local pct = math.floor(p * 100 + 0.5)
  lcd.drawText(LCD_W - 12, 18, pct .. "%", DBLSIZE + RIGHT)

  -- trend arrow: signal now vs 1.5 s ago
  local old = history[1]
  if old and smooth then
    local ax, ay = LCD_W - 6, 26
    if smooth - old > 1.5 then
      lcd.drawLine(ax, ay - 5, ax - 3, ay - 2, SOLID, FORCE); lcd.drawLine(ax, ay - 5, ax + 3, ay - 2, SOLID, FORCE)
      lcd.drawLine(ax, ay - 5, ax, ay + 3, SOLID, FORCE)
    elseif old - smooth > 1.5 then
      lcd.drawLine(ax, ay + 3, ax - 3, ay, SOLID, FORCE); lcd.drawLine(ax, ay + 3, ax + 3, ay, SOLID, FORCE)
      lcd.drawLine(ax, ay - 5, ax, ay + 3, SOLID, FORCE)
    end
  end

  -- state pill
  local word = stateWord(p)
  local w = #word * 5 + 5 -- SMLSIZE is ~5 px per character on the Pocket
  lcd.drawFilledRectangle(x, 36, w, 9)
  lcd.drawText(x + 3, 38, word, SMLSIZE + INVERS + (p >= 0.85 and BLINK or 0))
  local pwr = sensor("TPWR")
  if type(pwr) == "number" and pwr > 0 and pwr ~= SEARCH_MW then
    lcd.drawText(x, 47, "25mW, no dyn", SMLSIZE) -- tip replaces dBm until power is fixed
  elseif result and result.weak then
    lcd.drawText(x, 47, "UNSURE, spin", SMLSIZE)
  elseif result and result.best then
    lcd.drawText(x, 47, string.format("spread %ddB", math.floor(result.spread + 0.5)), SMLSIZE)
  else
    lcd.drawText(x, 47, string.format("%ddBm LQ%d", math.floor(dbm + 0.5), lq), SMLSIZE)
  end
end

local function bar(p)
  local x0, y = 4, 57
  local filled = math.floor(p * SEGMENTS + 0.5)
  for s = 0, SEGMENTS - 1 do
    local x = x0 + s * 5
    if s < filled then
      -- segments grow taller toward the end, like a signal meter
      local h = 3 + math.floor(s / SEGMENTS * 4)
      lcd.drawFilledRectangle(x, y + 7 - h, 4, h)
    else
      lcd.drawLine(x, y + 6, x + 3, y + 6, SOLID, FORCE)
    end
  end
  if peak > 0 then
    local px = x0 + math.floor(peak * SEGMENTS + 0.5) * 5 - 1
    lcd.drawLine(px, y - 1, px, y + 6, DOTTED, FORCE) -- best signal so far
  end
end

local function beep(p, now)
  if muted or now < nextBeep then return end
  playTone(500 + math.floor(p * 1500), 40, 0)
  nextBeep = now + 120 - math.floor(p * 108) -- 1.2 s far, 0.12 s on top of it
end

local function run(event)
  if event == EVT_VIRTUAL_EXIT then return 2 end
  local now = getTime()
  if event == EVT_VIRTUAL_ENTER_LONG then
    killEvents(event) -- no ENTER on release, so a long press does not also start a spin
    muted = not muted
  elseif event == EVT_VIRTUAL_ENTER then
    if spin then spin = nil else spinStart(now) end
  end
  if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_PREV then peak = 0; result = nil end

  local dbm, lq = signal()
  if spin then spinUpdate(dbm, now) end
  local linked = dbm ~= nil
  local p = 0
  if linked then
    smooth = smooth and (smooth * 0.7 + dbm * 0.3) or dbm
    p = math.max(0, math.min(1, (smooth - DBM_FAR) / (DBM_NEAR - DBM_FAR)))
    if p > peak then peak = p end
    if now - histAt >= 50 then
      histAt = now
      history[#history + 1] = smooth
      if #history > 3 then for i = 1, #history - 1 do history[i] = history[i + 1] end history[#history] = nil end
    end
    if not spin then beep(p, now) end -- step cues only while spinning
  else
    smooth = nil
  end

  lcd.clear()
  header(now)
  radar(p, linked, now)
  panel(p, smooth or 0, lq or 0, linked, now)
  bar(p)
  return 0
end

return { init = init, run = run }
