-- TNS|FPV Hub|TNE
-- FPV Hub for the Pocket (128x64): header bar, four raised icon tiles and a row of
-- oval tabs. NEXT/PREV moves, ENTER opens a tile or changes a tab, EXIT goes back.
-- The layout tab is a picker: ENTER, then NEXT/PREV, then ENTER saves (EXIT cancels). Tiles only show when their script is on the SD card; LED needs RGB LEDs.

local LED_CFG = "/SCRIPTS/RGBLED/hubcfg.txt"        -- last LED color picked (RGB radios only)
local LAYOUT_CFG = "/SCRIPTS/TELEMETRY/sticks.cfg"  -- read by /SCRIPTS/TELEMETRY/sticks.lua
local LAYOUTS = { "BOXES", "TRAIL", "MINI", "CHRONO" }
local COLORS = {
  { "OFF", 0, 0, 0 }, { "RED", 255, 0, 0 }, { "GRN", 0, 255, 0 },
  { "BLU", 0, 0, 255 }, { "PUR", 160, 0, 255 }, { "ORG", 255, 90, 0 },
  { "WHT", 255, 255, 255 },
}

-- 12x10 icons, '#' = pixel on
local ICONS = {
  display = {
    "############", "#..........#", "#.##.......#", "#..........#", "#.......##.#",
    "#..........#", "############", ".....##.....", "...######...", "............" },
  gauge = {
    "...######...", "..#......#..", ".#........#.", "#..........#", "#....#.....#",
    "#.....#....#", "#.....##...#", "#..........#", "############", "............" },
  rates = {
    "#...........", "#..........#", "#.........#.", "#........#..", "#......##...",
    "#....##.....", "#.###.......", "##..........", "############", "............" },
  antenna = {
    ".#...##...#.", "#..#.##.#..#", "#.#..##..#.#", "#.#..##..#.#", "#..#.##.#..#",
    ".#...##...#.", ".....##.....", ".....##.....", "....####....", "...######..." },
}

local function exists(path)
  if fstat then return fstat(path) ~= nil end
  return true -- firmware without fstat: a missing file is reported when opened
end

local function readFile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = io.read(f, 32)
  io.close(f)
  return s
end

local function writeFile(path, s)
  local f = io.open(path, "w")
  if not f then return false end
  io.write(f, s)
  io.close(f)
  return true
end

-- big tiles: "screen" = telemetry script (EXIT returns here), "tool" = handles its own keys
local TILES = {}
local function tile(label, icon, kind, path)
  if exists(path) then TILES[#TILES + 1] = { label = label, icon = icon, kind = kind, path = path } end
end
-- labels fit the tile: SMLSIZE is ~5 px per character on the Pocket, 8 chars max
tile("STICKS", "display", "screen", "/SCRIPTS/TELEMETRY/sticks.lua")
tile("TELEM", "gauge", "screen", "/SCRIPTS/TELEMETRY/dash.lua")
tile("BTFL", "rates", "tool", "/SCRIPTS/TOOLS/bf.lua")
tile("ELRS", "antenna", "tool", "/SCRIPTS/TOOLS/elrs.lua")

-- tabs: "locate" opens the radar, "layout" picks the TELE layout, "light" cycles the LED color
local RADAR = "/SCRIPTS/TOOLS/FPVRadar.lua"
local TABS = {}
if exists(RADAR) then TABS[#TABS + 1] = "locate" end
if exists("/SCRIPTS/TELEMETRY/sticks.lua") then TABS[#TABS + 1] = "layout" end
if setRGBLedColor then TABS[#TABS + 1] = "light" end

-- restore saved choices
local layout = 1
local savedLayout = readFile(LAYOUT_CFG)
for i, n in ipairs(LAYOUTS) do if savedLayout and string.find(savedLayout, n, 1, true) == 1 then layout = i end end
local color = 3 -- green, the stock look
local savedColor = readFile(LED_CFG)
for i, c in ipairs(COLORS) do if savedColor == c[2] .. "," .. c[3] .. "," .. c[4] then color = i end end

-- icon strings become horizontal runs once, so drawing is a few lines per row
local runs = {}
for key, rows in pairs(ICONS) do
  local list = {}
  for y, row in ipairs(rows) do
    local x = 1
    while x <= #row do
      local s, e = string.find(row, "#+", x)
      if not s then break end
      list[#list + 1] = { s - 1, e - 1, y - 1 }
      x = e + 1
    end
  end
  runs[key] = list
end

local sel, open = 1, nil -- sel: 1..#TILES are tiles, then tabs
local picking = nil -- layout index shown while the layout picker is open
local child, err
local WHITE = ERASE or 0 -- drawing white on black needs ERASE

local function isNext(e) return e == EVT_VIRTUAL_NEXT or e == EVT_VIRTUAL_INC end
local function isPrev(e) return e == EVT_VIRTUAL_PREV or e == EVT_VIRTUAL_DEC end

local function back()
  open, child, err = nil, nil, nil
  collectgarbage()
end

local function load(path)
  local chunk, msg = loadScript(path)
  if not chunk then return nil, msg end
  local ok, res = pcall(chunk)
  if not ok then return nil, res end
  if type(res) ~= "table" or type(res.run) ~= "function" then return nil, "not a script" end
  if res.init then
    local okInit, initErr = pcall(res.init)
    if not okInit then return nil, initErr end
  end
  return res
end

-- LED_STRIP_LENGTH is not always defined as a global; general settings carry the count
local function ledCount()
  local gs = getGeneralSettings()
  return LED_STRIP_LENGTH or (gs and gs.leds) or 6
end

local function nextColor()
  color = color % #COLORS + 1
  local c = COLORS[color]
  for i = 0, ledCount() - 1 do setRGBLedColor(i, c[2], c[3], c[4]) end
  applyRGBLedColors()
  writeFile(LED_CFG, c[2] .. "," .. c[3] .. "," .. c[4])
end

-- drawing helpers -----------------------------------------------------------

local function hline(x1, x2, y, f) lcd.drawLine(x1, y, x2, y, SOLID, f or FORCE) end
local function vline(x, y1, y2, f) lcd.drawLine(x, y1, x, y2, SOLID, f or FORCE) end

-- rectangle with the four corner pixels cut off
local function roundRect(x, y, w, h)
  hline(x + 1, x + w - 2, y); hline(x + 1, x + w - 2, y + h - 1)
  vline(x, y + 1, y + h - 2); vline(x + w - 1, y + 1, y + h - 2)
end

local function roundFill(x, y, w, h)
  lcd.drawFilledRectangle(x + 1, y, w - 2, h)
  vline(x, y + 1, y + h - 2); vline(x + w - 1, y + 1, y + h - 2)
end

-- oval: the first three rows from each end are cut in by 4, 2 and 1 px
local INSET = { 4, 2, 1 }
local function oval(x, y, w, h, filled)
  for j = 0, h - 1 do
    local k = math.min(j, h - 1 - j)
    local c = INSET[k + 1] or 0
    if filled or k == 0 then hline(x + c, x + w - 1 - c, y + j)
    else
      local e = math.max(c, (INSET[k] or 0) - 1) -- reach back to the row above so the edge is unbroken
      hline(x + c, x + e, y + j); hline(x + w - 1 - e, x + w - 1 - c, y + j)
    end
  end
end

local function drawIcon(key, x, y, f)
  for _, r in ipairs(runs[key]) do hline(x + r[1], x + r[2], y + r[3], f) end
end

-- header: title, clock and a radio battery gauge, white on black
local function header()
  lcd.drawFilledRectangle(0, 0, LCD_W, 9)
  lcd.drawText(3, 1, "FPV HUB", SMLSIZE + INVERS)
  local dt = getDateTime()
  lcd.drawText(105, 1, string.format("%02d:%02d", dt.hour, dt.min), SMLSIZE + INVERS + RIGHT)
  if not ERASE then return end
  local g = getGeneralSettings()
  local p = (getValue("tx-voltage") - g.battMin) / (g.battMax - g.battMin)
  p = math.max(0, math.min(1, p))
  hline(109, 121, 2, ERASE); hline(109, 121, 6, ERASE)
  vline(109, 2, 6, ERASE); vline(121, 2, 6, ERASE); vline(122, 3, 5, ERASE); vline(123, 3, 5, ERASE)
  local fill = math.floor(p * 9 + 0.5)
  if fill > 0 then lcd.drawFilledRectangle(111, 4, fill, 1, ERASE) end
end

-- a raised tile; the selected one is "pressed": shifted 1 px and filled
local CHAR = 5 -- SMLSIZE width per character on the Pocket

local function drawTile(t, x, y, selected)
  local w, h = 61, 18
  if selected then x, y = x + 1, y + 1 end
  -- label centered in the space right of the icon
  local tx = x + 18 + math.floor((w - 20 - #t.label * CHAR) / 2)
  if selected then
    roundFill(x, y, w, h)
    drawIcon(t.icon, x + 4, y + 4, WHITE)
    lcd.drawText(tx, y + 6, t.label, SMLSIZE + INVERS)
  else
    roundRect(x, y, w, h)
    hline(x + 2, x + w - 1, y + h); vline(x + w, y + 2, y + h - 1) -- drop shadow
    drawIcon(t.icon, x + 4, y + 4)
    lcd.drawText(tx, y + 6, t.label, SMLSIZE)
  end
end

local function tabLabel(kind)
  if kind == "light" then return "LED " .. COLORS[color][1] end
  if kind == "layout" then return LAYOUTS[picking or layout] end
  return "LOCATE"
end

local function menu(event)
  local count = #TILES + #TABS
  if picking then
    if isNext(event) then picking = picking % #LAYOUTS + 1
    elseif isPrev(event) then picking = (picking - 2) % #LAYOUTS + 1
    elseif event == EVT_VIRTUAL_ENTER then
      layout, picking = picking, nil
      writeFile(LAYOUT_CFG, LAYOUTS[layout])
    elseif event == EVT_VIRTUAL_EXIT then picking = nil end
  elseif isNext(event) then sel = sel % count + 1
  elseif isPrev(event) then sel = (sel - 2) % count + 1
  elseif event == EVT_VIRTUAL_ENTER then
    if sel <= #TILES then
      open = TILES[sel]
      child, err = load(open.path)
      return
    end
    local kind = TABS[sel - #TILES]
    if kind == "light" then nextColor()
    elseif kind == "layout" then picking = layout
    else
      open = { label = "RADAR", kind = "tool", path = RADAR }
      child, err = load(RADAR)
      return
    end
  end

  header()
  for i, t in ipairs(TILES) do
    drawTile(t, 2 + ((i - 1) % 2) * 63, 11 + math.floor((i - 1) / 2) * 20, i == sel)
  end

  -- oval tabs along the bottom
  local w = math.floor((124 - (#TABS - 1) * 3) / #TABS)
  for i, kind in ipairs(TABS) do
    local x, y = 2 + (i - 1) * (w + 3), 51
    local label = tabLabel(kind)
    local selected = sel == #TILES + i
    local f = selected and ERASE or FORCE
    oval(x, y, w, 12, selected)
    local editing = kind == "layout" and picking
    -- while picking, the name blinks every half second and small arrows sit at the ends
    if not (editing and math.floor(getTime() / 50) % 2 == 1) then
      lcd.drawText(x + math.floor((w - #label * CHAR) / 2) + 1, y + 3, label, SMLSIZE + (selected and INVERS or 0))
    end
    if editing then
      lcd.drawPoint(x + 2, y + 6, f); vline(x + 3, y + 5, y + 7, f)
      lcd.drawPoint(x + w - 3, y + 6, f); vline(x + w - 4, y + 5, y + 7, f)
    end
  end
end

local function run(event)
  lcd.clear()
  if open == nil then
    if event == EVT_VIRTUAL_EXIT and not picking then return 1 end
    menu(event)
    return 0
  end

  if not child then
    -- script failed to load or crashed: show why instead of closing the hub
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_ENTER then back(); return 0 end
    lcd.drawScreenTitle(open.label, 0, 0)
    lcd.drawText(2, 12, "Could not run:", SMLSIZE)
    lcd.drawText(2, 22, tostring(err), SMLSIZE)
    lcd.drawText(2, 56, "EXIT: back", SMLSIZE)
    return 0
  end

  if open.kind == "tool" then
    local ok, res = pcall(child.run, event)
    if not ok then child, err = nil, res
    elseif res ~= 0 then back() end -- the tool closed itself
    return 0
  end

  if event == EVT_VIRTUAL_EXIT then back(); return 0 end
  local ok, res = pcall(child.run, event)
  if not ok then child, err = nil, res end
  return 0
end

return { run = run }
