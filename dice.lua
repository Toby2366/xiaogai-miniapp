-- 小白掷骰子小应用 v2（含统计）
-- 单击功能键 = 掷骰子；双击 = 切换「掷骰 / 统计」视图；长按 3 秒 = 退出小应用。
-- 统计：本次进入小应用以来，点数 1~6 各自出现的次数（柱状图展示）。
-- 纯矩形 + 文字绘制，无图片接口；接口见 docs/miniapp.md。

local W, H = 240, 240

local WHITE    = 0xF7F8FA
local PIP      = 0x151A22
local BORDER   = 0x5A6478
local SHADOW   = 0x05070C
local TITLE    = 0xF4C64A
local TEXT     = 0xE8ECF3
local TEXT_DIM = 0x9AA6B8
local BAR      = 0x4A6FA5
local BAR_HI   = 0xF4C64A
local BASELINE = 0x3A4A66

local SIZE   = 122
local BASE_X = 59
local BASE_Y = 63

local PIPS = {
  { {2,2} },
  { {1,1},{3,3} },
  { {1,1},{2,2},{3,3} },
  { {1,1},{1,3},{3,1},{3,3} },
  { {1,1},{1,3},{2,2},{3,1},{3,3} },
  { {1,1},{2,1},{3,1},{1,3},{2,3},{3,3} },
}

local view  = "roll"  -- "roll" | "stats"
local state = "idle"  -- "idle" | "rolling"
local value  = 1
local target = 1
local elapsed = 0
local roll_duration = 0
local total_ms = 0
local clicks = 0
local dx, dy = 0, 0

local counts = { 0, 0, 0, 0, 0, 0 }
local total  = 0

-- 双击判定
local click_pending = false
local click_ms = 0
local DOUBLE_MS = 320

local rng = 1
local function rnd()
  rng = (rng * 16807) % 2147483647
  if rng <= 0 then rng = 1 end
  return rng / 2147483647
end
local function rnd_int(n)
  return math.floor(rnd() * n) + 1
end

local function beep(hz, ms)
  if buzzer ~= nil then buzzer.play(hz, ms) end
end

local function draw_roll()
  local bgs = { 0x23324F, 0x1F2C46, 0x1B263D, 0x172134, 0x131C2B, 0x0F1722 }
  for i = 1, 6 do
    screen.rect(0, (i - 1) * 40, W, 40, bgs[i])
  end
  screen.text("掷骰子", 96, 14, TITLE)

  local sx = BASE_X + dx
  local sy = BASE_Y + dy
  screen.rect(sx + 4, sy + 4, SIZE + 4, SIZE + 4, SHADOW)
  screen.rect(sx - 3, sy - 3, SIZE + 6, SIZE + 6, BORDER)
  screen.rect(sx, sy, SIZE, SIZE, WHITE)

  local p = 20
  local layout = PIPS[value]
  for i, rc in ipairs(layout) do
    local cx = sx + math.floor((rc[2] * 2 - 1) * SIZE / 6)
    local cy = sy + math.floor((rc[1] * 2 - 1) * SIZE / 6)
    local hx = math.floor(cx - p / 2)
    local hy = math.floor(cy - p / 2)
    screen.rect(hx, hy, p, p, PIP)
    screen.rect(hx, hy, 4, 4, WHITE)
    screen.rect(hx + p - 4, hy, 4, 4, WHITE)
    screen.rect(hx, hy + p - 4, 4, 4, WHITE)
    screen.rect(hx + p - 4, hy + p - 4, 4, 4, WHITE)
  end

  screen.text("点数 " .. value, 96, 202, TEXT)
  screen.text("单击掷骰 双击统计", 56, 222, TEXT_DIM)
end

local function draw_stats()
  local bgs = { 0x23324F, 0x1F2C46, 0x1B263D, 0x172134, 0x131C2B, 0x0F1722 }
  for i = 1, 6 do
    screen.rect(0, (i - 1) * 40, W, 40, bgs[i])
  end
  screen.text("本次统计", 88, 10, TITLE)
  screen.text("共掷 " .. total .. " 次", 88, 30, TEXT)

  local max_f = 1
  for i = 1, 6 do
    if counts[i] > max_f then max_f = counts[i] end
  end

  local bar_w   = 26
  local bar_gap = 34
  local bar_x0  = 22
  local base_y  = 180
  local max_h   = 120

  screen.rect(bar_x0 - 2, base_y, 196, 2, BASELINE)

  for i = 1, 6 do
    local x = bar_x0 + (i - 1) * bar_gap
    local cx = x + math.floor(bar_w / 2)
    local f = counts[i]
    if f > 0 then
      local h = math.floor(f * max_h / max_f)
      local y = base_y - h
      local color = (f == max_f) and BAR_HI or BAR
      screen.rect(x, y, bar_w, h, color)
      screen.text(tostring(f), cx - 4, y - 18, TEXT)
    else
      screen.text("0", cx - 4, base_y - 16, TEXT_DIM)
    end
    screen.text(tostring(i), cx - 4, base_y + 6, TEXT_DIM)
  end

  screen.text("双击回掷骰", 80, 222, TEXT_DIM)
end

local function draw()
  screen.begin(0x172134)
  if view == "roll" then
    draw_roll()
  else
    draw_stats()
  end
  screen.present()
end

local function do_roll()
  view = "roll"
  rng = (total_ms * 2654435761 + clicks * 97 + 1) % 2147483646 + 1
  target = rnd_int(6)
  roll_duration = 700 + rnd_int(500)
  elapsed = 0
  state = "rolling"
  clicks = clicks + 1
  beep(880, 40)
end

local function toggle_view()
  if view == "roll" then
    view = "stats"
  else
    view = "roll"
  end
  draw()
end

function on_start()
  value = 1
  draw()
end

function on_tick(dt_ms)
  total_ms = total_ms + dt_ms

  if click_pending then
    click_ms = click_ms + dt_ms
    if click_ms >= DOUBLE_MS then
      click_pending = false
      do_roll()
    end
  end

  if state == "rolling" then
    elapsed = elapsed + dt_ms
    dx = rnd_int(5) - 3
    dy = rnd_int(5) - 3
    if math.floor(elapsed / 60) ~= math.floor((elapsed - dt_ms) / 60) then
      value = rnd_int(6)
      beep(600 + value * 60, 25)
    end
    if elapsed >= roll_duration then
      state = "idle"
      value = target
      dx, dy = 0, 0
      counts[target] = counts[target] + 1
      total = total + 1
      beep(1320, 120)
    end
    draw()
  end
end

function on_button_click(button_id)
  if button_id ~= "function" then return end
  if state == "rolling" then return end

  if click_pending then
    click_pending = false
    toggle_view()
  else
    click_pending = true
    click_ms = 0
  end
end

function on_exit()
end
