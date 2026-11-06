-- dash.lua: flight dashboard for 128x64 EdgeTX radios (RadioMaster Pocket).
-- Shows timer 1, flight mode, arm state and ELRS/Betaflight telemetry.
-- Missing sensors (e.g. in the simulator model) show "--".

local function sensor(name)
  local f = getFieldInfo(name)
  if not f then return nil end
  return getValue(f.id)
end

local function fmt(v, pattern)
  if v == nil or type(v) ~= "number" then return "--" end
  return string.format(pattern, v)
end

local function run(event)
  lcd.clear()

  -- header: model name + radio battery
  lcd.drawScreenTitle(model.getInfo().name, 0, 0)
  lcd.drawText(LCD_W - 1, 1, fmt(getValue("tx-voltage"), "%.1fV"), SMLSIZE + RIGHT + INVERS)

  -- timer 1, large
  local t = model.getTimer(0)
  local s = math.abs(t.value)
  lcd.drawText(2, 13, string.format("%d:%02d", math.floor(s / 60), s % 60), DBLSIZE)

  -- flight mode from Betaflight (CRSF "FM" sensor) and arm state from CH5
  local fm = sensor("FM")
  lcd.drawText(LCD_W - 2, 12, type(fm) == "string" and fm or "--", MIDSIZE + RIGHT)
  local armed = getValue("ch5") > 0
  lcd.drawText(LCD_W - 2, 24, armed and " ARMED " or " SAFE ", SMLSIZE + RIGHT + (armed and INVERS or 0))

  lcd.drawLine(0, 33, LCD_W - 1, 33, SOLID, FORCE)

  -- telemetry grid
  local lq = sensor("RQly")
  local lowLink = lq ~= nil and lq > 0 and lq < 50
  lcd.drawText(2, 36, "Bat " .. fmt(sensor("RxBt"), "%.1fV"), SMLSIZE)
  lcd.drawText(66, 36, "Bat% " .. fmt(sensor("Bat%"), "%d"), SMLSIZE)
  lcd.drawText(2, 46, "LQ " .. fmt(lq, "%d%%"), SMLSIZE + (lowLink and (INVERS + BLINK) or 0))
  lcd.drawText(66, 46, "RSSI " .. fmt(sensor("1RSS"), "%d"), SMLSIZE)
  lcd.drawText(2, 56, "Cur " .. fmt(sensor("Curr"), "%.1fA"), SMLSIZE)
  lcd.drawText(66, 56, "Used " .. fmt(sensor("Capa"), "%d"), SMLSIZE)

  return 0
end

return { run = run }
