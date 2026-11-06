-- Simulates EdgeTX on a 128x64 Pocket and runs FPVRadar.lua through guided spins.
-- usage: lua test_radar.lua path/to/FPVRadar.lua
local path = arg[1]

LCD_W, LCD_H = 128, 64
SMLSIZE, MIDSIZE, DBLSIZE, INVERS, RIGHT, BLINK = 0x1, 0x2, 0x4, 0x8, 0x10, 0x20
SOLID, DOTTED, FORCE = 0, 1, 0
EVT_VIRTUAL_EXIT, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_ENTER_LONG = 1, 2, 3
EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV = 4, 5

local fb, oob = {}, 0
local function px(x, y)
  if x < 0 or x >= LCD_W or y < 0 or y >= LCD_H then oob = oob + 1 return end
  fb[y * LCD_W + x] = true
end
local texts = {}
lcd = {
  clear = function() fb = {}; texts = {} end,
  drawPoint = px,
  drawFilledRectangle = function(x, y, w, h) for i = x, x + w - 1 do for j = y, y + h - 1 do px(i, j) end end end,
  drawLine = function(x1, y1, x2, y2, pat)
    local n = math.max(math.abs(x2 - x1), math.abs(y2 - y1), 1)
    for i = 0, n do if pat ~= DOTTED or i % 2 == 0 then px(math.floor(x1 + (x2 - x1) * i / n + 0.5), math.floor(y1 + (y2 - y1) * i / n + 0.5)) end end
  end,
  drawText = function(x, y, s, f)
    s = tostring(s)
    local cw = (f & DBLSIZE ~= 0) and 11 or (f & MIDSIZE ~= 0) and 8 or 5
    local w = #s * cw
    if f & RIGHT ~= 0 then x = x - w end
    if x < 0 or x + w > LCD_W + 1 then oob = oob + 1; print("TEXT OUT OF SCREEN: " .. s) end
    texts[#texts + 1] = s
  end,
}

local now, tones, killed = 0, 0, 0
local sim = { linked = true, heading = 0, bearing = 90, base = -80, gain = 6, pwr = 25, noise = 1.5 }
function getTime() return now end
function playTone() tones = tones + 1 end
function killEvents() killed = killed + 1 end
function getFieldInfo(n) return { id = n } end
function getValue(id)
  if id == "TPWR" then return sim.pwr end
  if not sim.linked then return 0 end
  if id == "RQly" then return 100 end
  -- body shield: strongest facing the quad, weakest with your back to it
  local d = math.rad(sim.heading - sim.bearing)
  return math.floor(sim.base + sim.gain * math.cos(d) + (math.random() * 2 - 1) * sim.noise)
end

local function load()
  local s = dofile(path)
  s.init()
  return s
end

local function screenHas(word)
  for _, t in ipairs(texts) do if t:find(word, 1, true) then return true end end
  return false
end

-- run one spin; the simulated pilot turns right 45 deg 0.3 s after each step cue
local function doSpin(s, opts)
  opts = opts or {}
  s.run(EVT_VIRTUAL_ENTER)
  local start = now
  for _ = 1, 600 do
    now = now + 3
    local step = math.floor((now - start) / 200)
    if (now - start) % 200 >= 30 then sim.heading = (step * 45) % 360 end
    if opts.pwrAt and now - start > opts.pwrAt then sim.pwr = 100 end
    s.run(0)
    if not screenHas("SPIN ") or screenHas("SPIN FAILED") then break end
  end
  sim.heading = 0
end

local fails = 0
local function check(name, ok)
  print((ok and "PASS " or "FAIL ") .. name)
  if not ok then fails = fails + 1 end
end

local function dump()
  for y = 0, LCD_H - 1 do
    local row = {}
    for x = 0, LCD_W - 1 do row[#row + 1] = fb[y * LCD_W + x] and "#" or "." end
    print(table.concat(row))
  end
  print("texts: " .. table.concat(texts, " | "))
end

math.randomseed(7)
local expect = { [0] = "DIR AHEAD", [45] = "DIR 45R", [90] = "DIR 90R", [135] = "DIR 135R",
                 [180] = "DIR BEHIND", [225] = "DIR 135L", [270] = "DIR 90L", [315] = "DIR 45L" }
for b = 0, 315, 45 do
  local s = load(); sim.bearing = b; sim.pwr = 25; sim.linked = true; sim.gain = 6
  doSpin(s)
  s.run(0)
  check("bearing " .. b .. " -> " .. expect[b], screenHas(expect[b]) and not screenHas("UNSURE"))
end

-- an off-grid bearing should land on a neighbouring step
do
  local s = load(); sim.bearing = 100
  doSpin(s); s.run(0)
  check("bearing 100 -> 90R or 135R", screenHas("DIR 90R") or screenHas("DIR 135R"))
end

do
  local s = load(); sim.gain = 0.5; sim.bearing = 90
  doSpin(s); s.run(0)
  check("flat signal -> UNSURE", screenHas("UNSURE"))
  sim.gain = 6
end

do
  local s = load(); sim.bearing = 90
  doSpin(s, { pwrAt = 600 }); s.run(0)
  check("power changes mid-spin -> flagged", screenHas("25mW, no dyn") or screenHas("UNSURE"))
  sim.pwr = 25
end

do
  local s = load(); sim.linked = false
  doSpin(s); s.run(0)
  check("no link -> SPIN FAILED", screenHas("SPIN FAILED"))
  sim.linked = true
end

do
  local s = load()
  s.run(EVT_VIRTUAL_ENTER); now = now + 3; s.run(0)
  check("ENTER starts spin", screenHas("SPIN 1/8"))
  s.run(EVT_VIRTUAL_ENTER); now = now + 3; s.run(0)
  check("ENTER again cancels", not screenHas("SPIN 1/8") and screenHas("SIGNAL"))
  local k0 = killed
  s.run(EVT_VIRTUAL_ENTER_LONG)
  check("long ENTER mutes, kills event, no spin", screenHas("RADAR MUTE") and killed == k0 + 1 and not screenHas("SPIN"))
  check("EXIT returns 2", s.run(EVT_VIRTUAL_EXIT) == 2)
end

do
  local s = load(); sim.bearing = 90
  doSpin(s); s.run(0)
  s.run(EVT_VIRTUAL_NEXT)
  check("NEXT clears direction", screenHas("SIGNAL") and not screenHas("DIR "))
end

check("nothing drawn off screen", oob == 0)

-- picture of a result screen and a mid-spin screen, for eyeballing the layout
local s = load(); sim.bearing = 135
doSpin(s); now = now + 3; s.run(0)
print("\n-- result screen (quad at 135R) --"); dump()
s = load()
s.run(EVT_VIRTUAL_ENTER)
for _ = 1, 300 do now = now + 3; local st = math.floor(_ * 3 / 200); sim.heading = st * 45; s.run(0) end
print("\n-- mid spin --"); dump()

print(fails == 0 and "\nALL PASS" or ("\n" .. fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
