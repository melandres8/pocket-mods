-- sticks.lua: FPV telemetry screen for 128x64 EdgeTX radios (Pocket, Mode 2).
-- Four layouts, ENTER cycles them: BOXES (big stick squares with trails),
-- TRAIL (stick trails + throttle bar), MINI (four cards), CHRONO (big timer + trails).

-- First flight date for the "FPV day" counter: { year, month, day }, or nil to hide it.
local FPV_SINCE = { 2025, 9, 20 } -- approximate: when the radio was set up (SD card dates)

local LAYOUTS = { "BOXES", "TRAIL", "MINI", "CHRONO" }
local layout = 1
do -- start on the layout chosen in FPV Hub (tab "TELE LAYOUT")
  local f = io.open("/SCRIPTS/TELEMETRY/sticks.cfg", "r")
  if f then
    local saved = io.read(f, 16) or ""
    io.close(f)
    for i, n in ipairs(LAYOUTS) do if string.find(saved, n, 1, true) == 1 then layout = i end end
  end
end
local TRAIL = 12 -- stick positions kept per stick
local trails = { {}, {} }
local lastVal, lastTick = nil, 0

-- data -------------------------------------------------------------------

local function sensor(name)
  local f = getFieldInfo(name)
  if not f then return nil end
  return getValue(f.id)
end

local function num(v, pattern)
  if type(v) ~= "number" then return "--" end
  return string.format(pattern, v)
end

local function armed() return getValue("ch5") > 0 end

local function timer(withTenths)
  local t = model.getTimer(0)
  local now = getTime() -- 10 ms ticks
  if t.value ~= lastVal then lastVal, lastTick = t.value, now end
  local s = math.abs(t.value)
  local txt = string.format("%02d:%02d", math.floor(s / 60), s % 60)
  if not withTenths then return txt end
  -- the timer only reports whole seconds; tenths come from the time since it last ticked
  local tenths = armed() and math.min(9, math.floor((now - lastTick) / 10)) or 0
  return txt .. "." .. tenths
end

local function txPercent()
  local g = getGeneralSettings()
  local pct = (getValue("tx-voltage") - g.battMin) / (g.battMax - g.battMin) * 100
  return math.max(0, math.min(100, math.floor(pct + 0.5)))
end

-- returns volts per cell and pack volts, or nil without telemetry
local function battery()
  local v = sensor("RxBt")
  if type(v) ~= "number" or v <= 0 then return nil end
  local cells = math.ceil(v / 4.35) -- 4.35 V = highest HV cell, so this never undercounts
  return v / cells, v
end

local function dayNumber(y, m, d)
  if m <= 2 then y, m = y - 1, m + 12 end
  return 365 * y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400)
    + math.floor((153 * (m - 3) + 2) / 5) + d
end

local function fpvDay()
  if not FPV_SINCE then return nil end
  local now = getDateTime()
  return dayNumber(now.year, now.mon, now.day) - dayNumber(FPV_SINCE[1], FPV_SINCE[2], FPV_SINCE[3]) + 1
end

-- drawing ----------------------------------------------------------------

local function topBar()
  lcd.drawText(1, 0, timer(false), SMLSIZE)
  if armed() then lcd.drawFilledRectangle(62, 1, 4, 4) else lcd.drawRectangle(62, 1, 4, 4) end
  lcd.drawText(LCD_W - 1, 0, txPercent() .. "%", SMLSIZE + RIGHT)
end

-- newest position goes to trail[1]; shifted by hand because EdgeTX has no `table` library
local function push(trail, cx, cy, half, hSrc, vSrc)
  for j = math.min(#trail, TRAIL - 1), 1, -1 do trail[j + 1] = trail[j] end
  trail[1] = {
    math.floor(cx + getValue(hSrc) / 1024 * half + 0.5),
    math.floor(cy - getValue(vSrc) / 1024 * half + 0.5),
  }
end

-- one stick: dotted crosshair, dotted trail, solid 3x3 dot at the current position
local function stick(i, cx, cy, half, hSrc, vSrc)
  lcd.drawLine(cx - half, cy, cx + half, cy, DOTTED, FORCE)
  lcd.drawLine(cx, cy - half, cx, cy + half, DOTTED, FORCE)
  local trail = trails[i]
  push(trail, cx, cy, half, hSrc, vSrc)
  for j = 2, #trail do lcd.drawPoint(trail[j][1], trail[j][2]) end
  lcd.drawFilledRectangle(trail[1][1] - 1, trail[1][2] - 1, 3, 3)
end

local function sticks(cy, half)
  stick(1, 32, cy, half, "rud", "thr")
  stick(2, 96, cy, half, "ail", "ele")
end

-- BOXES layout: minimal. Corner marks frame each stick area, a small hollow
-- square marks the stick, older positions fade out as single dots.
local HW, HH, ARM_LEN = 18, 15, 4 -- area half width/height (Pocket pixels are a bit tall), corner arm length

local function corners(cx, cy)
  local l, r, t, b = cx - HW - 3, cx + HW + 3, cy - HH - 3, cy + HH + 3
  lcd.drawLine(l, t, l + ARM_LEN, t, SOLID, FORCE); lcd.drawLine(l, t, l, t + ARM_LEN, SOLID, FORCE)
  lcd.drawLine(r - ARM_LEN, t, r, t, SOLID, FORCE); lcd.drawLine(r, t, r, t + ARM_LEN, SOLID, FORCE)
  lcd.drawLine(l, b, l + ARM_LEN, b, SOLID, FORCE); lcd.drawLine(l, b - ARM_LEN, l, b, SOLID, FORCE)
  lcd.drawLine(r - ARM_LEN, b, r, b, SOLID, FORCE); lcd.drawLine(r, b - ARM_LEN, r, b, SOLID, FORCE)
end

local function boxStick(i, cx, cy, hSrc, vSrc)
  corners(cx, cy)
  local trail = trails[i]
  for j = math.min(#trail, TRAIL - 1), 1, -1 do trail[j + 1] = trail[j] end
  trail[1] = {
    math.floor(cx + getValue(hSrc) / 1024 * HW + 0.5),
    math.floor(cy - getValue(vSrc) / 1024 * HH + 0.5),
  }
  -- trail: 2 px thick line for the newer half, 1 px line for the older half (fades out)
  for j = 2, #trail do
    local a, b = trail[j - 1], trail[j]
    lcd.drawLine(a[1], a[2], b[1], b[2], SOLID, FORCE)
    if j <= TRAIL / 2 then
      lcd.drawLine(a[1] + 1, a[2], b[1] + 1, b[2], SOLID, FORCE)
      lcd.drawLine(a[1], a[2] + 1, b[1], b[2] + 1, SOLID, FORCE)
    end
  end
  lcd.drawRectangle(trail[1][1] - 2, trail[1][2] - 2, 5, 5)
end

local function boxes()
  local txt = timer(true)
  lcd.drawText(64 - #txt * 4, 2, txt, MIDSIZE)
  boxStick(1, 30, 33, "rud", "thr")
  boxStick(2, 98, 33, "ail", "ele")
  local lq = sensor("RQly")
  local day = fpvDay()
  -- LQ 0 means the receiver is not linked
  lcd.drawText(1, 57, "LINK " .. ((type(lq) == "number" and lq > 0) and (lq .. "%") or "----"), SMLSIZE)
  if armed() then lcd.drawText(57, 57, "ARM", SMLSIZE + INVERS) end
  lcd.drawText(LCD_W - 1, 57, "DAY " .. (day and tostring(day) or "--"), SMLSIZE + RIGHT)
end

local function throttleBar(y)
  local filled = math.floor((getValue("thr") + 1024) / 2048 * 25 + 0.5)
  for s = 0, 24 do
    local x = 14 + s * 4
    if s < filled then lcd.drawFilledRectangle(x, y, 3, 3) else lcd.drawPoint(x + 1, y + 1) end
  end
end

local function bottomRow()
  local cell = battery()
  local day = fpvDay()
  lcd.drawText(1, 46, "LQ " .. num(sensor("1RSS"), "%ddBm"), SMLSIZE)
  lcd.drawText(1, 52, num(sensor("RQly"), "%d"), MIDSIZE)
  lcd.drawText(64, 46, "DAY", SMLSIZE + RIGHT)
  lcd.drawText(68, 52, day and tostring(day) or "--", MIDSIZE + RIGHT)
  lcd.drawText(LCD_W - 1, 46, "QUAD", SMLSIZE + RIGHT)
  lcd.drawText(LCD_W - 1, 52, cell and string.format("%.2fv", cell) or "--", MIDSIZE + RIGHT)
end

local function card(x, y, label, value, sub)
  lcd.drawRectangle(x, y, 63, 27)
  lcd.drawText(x + 3, y + 2, label, SMLSIZE)
  lcd.drawText(x + 3, y + 8, value, MIDSIZE)
  lcd.drawText(x + 3, y + 21, sub, SMLSIZE)
end

local function mini()
  local cell, pack = battery()
  local day = fpvDay()
  card(0, 9, "battery/cell", cell and string.format("%.2fv", cell) or "--", pack and string.format("%.1fv pack", pack) or "no telemetry")
  card(65, 9, "timer", timer(false), armed() and "armed" or "safe")
  card(0, 37, "link", num(sensor("RQly"), "%d lq"), num(sensor("1RSS"), "%d dBm"))
  card(65, 37, "fpv day", day and tostring(day) or "--",
    FPV_SINCE and string.format("since %d.%d.%d", FPV_SINCE[2], FPV_SINCE[3], FPV_SINCE[1] % 100) or "set FPV_SINCE")
end

local function run(event)
  if event == EVT_VIRTUAL_ENTER then layout = layout % #LAYOUTS + 1 end
  lcd.clear()
  local name = LAYOUTS[layout]
  if name == "BOXES" then
    boxes()
  elseif name == "TRAIL" then
    topBar()
    sticks(24, 14)
    throttleBar(41)
    bottomRow()
  elseif name == "MINI" then
    topBar()
    mini()
  else
    local txt = timer(true)
    lcd.drawText(64 - #txt * 6, 8, txt, DBLSIZE)
    sticks(35, 9)
    bottomRow()
  end
  return 0
end

return { run = run }
