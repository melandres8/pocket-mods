-- TNS|FPV Radar|TNE
-- FPV Radar: find a crashed quad by its ELRS signal (Pocket/128x64).
-- The radar sweep is decoration: the receiver gives signal strength, not direction.
-- The target ring shrinks and the bar fills as the signal gets stronger.
-- ENTER: sound on/off   NEXT/PREV: reset peak   EXIT: close

local CX, CY = 25, 33          -- radar center
local RINGS = { 7, 14, 21 }
local DBM_FAR, DBM_NEAR = -115, -45 -- signal range mapped to 0..100 %
local SEGMENTS = 24

local ring = {}                -- precomputed dotted circle points
local smooth, peak = nil, 0
local history, histAt = {}, 0  -- smoothed dBm sampled every 0.5 s, for the trend arrow
local muted, nextBeep = false, 0

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

local function radar(p, linked, now)
  for _, pt in ipairs(ring) do lcd.drawPoint(pt[1], pt[2]) end
  lcd.drawLine(CX - 2, CY, CX + 2, CY, SOLID, FORCE)
  lcd.drawLine(CX, CY - 2, CX, CY + 2, SOLID, FORCE)

  -- sweep: one solid arm and two fading dotted arms behind it
  local a = (now % 300) / 300 * 2 * math.pi
  for i = 0, 2 do
    local ang = a - i * 0.22
    local x = math.floor(CX + math.cos(ang) * 21 + 0.5)
    local y = math.floor(CY + math.sin(ang) * 21 + 0.5)
    lcd.drawLine(CX, CY, x, y, i == 0 and SOLID or DOTTED, FORCE)
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

local function panel(p, dbm, lq, linked, now)
  local x = 52
  lcd.drawText(x, 12, "SIGNAL", SMLSIZE)
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
  if event == EVT_VIRTUAL_ENTER then muted = not muted end
  if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_PREV then peak = 0 end

  local now = getTime()
  local dbm, lq = signal()
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
    beep(p, now)
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
