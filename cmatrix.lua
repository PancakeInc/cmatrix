-- cmatrix.lua
-- Copyright (c) 2026 Pancakse
-- SPDX-License-Identifier: BSD-3-Clause
-- "Matrix" digital rain for the terminal, in the spirit of cmatrix.
-- usage: cmatrix [-C color] [-u speed] [-s]
--   -C color   green (default), red, blue, cyan, yellow, magenta, white
--   -u speed   0 (slow) to 10 (fast), default 5
--   -s         screensaver mode: any key exits (otherwise q or Ctrl+T)

local args = { ... }
local opts = { color = "green", speed = 5, saver = false }

local PALETTES = {
    -- { trail near head, trail middle, trail tail }
    green   = { colors.lime,      colors.green,   colors.gray },
    red     = { colors.pink,      colors.red,     colors.brown },
    blue    = { colors.lightBlue, colors.blue,    colors.gray },
    cyan    = { colors.lightBlue, colors.cyan,    colors.gray },
    yellow  = { colors.yellow,    colors.orange,  colors.brown },
    magenta = { colors.pink,      colors.magenta, colors.purple },
    white   = { colors.white,     colors.lightGray, colors.gray },
}

local function usage()
    print("usage: cmatrix [-C color] [-u speed] [-s]")
    print("  -C color   green, red, blue, cyan, yellow, magenta, white")
    print("  -u speed   0 (slow) to 10 (fast), default 5")
    print("  -s         screensaver mode: any key exits")
    print("Press q (or Ctrl+T) to quit.")
end

local i = 1
while i <= #args do
    local a = args[i]
    if a == "-C" and args[i + 1] then
        opts.color = args[i + 1]:lower(); i = i + 2
    elseif a == "-u" and tonumber(args[i + 1]) then
        opts.speed = math.max(0, math.min(10, tonumber(args[i + 1]))); i = i + 2
    elseif a == "-s" then
        opts.saver = true; i = i + 1
    else
        usage()
        return
    end
end

local palette = PALETTES[opts.color]
if not palette then
    printError("cmatrix: unknown color '" .. opts.color .. "'")
    return
end

local HEAD = colors.white
if not term.isColor() then
    -- basic computers can only show grays
    palette = { colors.white, colors.lightGray, colors.gray }
end
local delay = 0.05 * (1 + math.max(0, 5 - opts.speed)) -- CC timers tick every 0.05s

local CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@#$%^&*()-=+<>?/:;"
local function randomChar()
    local n = math.random(#CHARS)
    return CHARS:sub(n, n)
end

local w, h = term.getSize()
local drops

local function newDrop()
    return {
        head = -math.random(0, h),               -- starts above the screen, staggered
        len = math.random(4, math.max(5, h - 2)),
        every = math.random(1, 3),               -- falls once every N ticks
        tick = 0,
        chars = {},
    }
end

local function reset()
    w, h = term.getSize()
    drops = {}
    for x = 1, w do drops[x] = newDrop() end
    term.setBackgroundColor(colors.black)
    term.clear()
end

local function put(x, y, ch, color)
    if y < 1 or y > h then return end
    term.setCursorPos(x, y)
    term.setTextColor(color)
    term.write(ch)
end

local function recolor(x, d, y, color)
    local ch = d.chars[y]
    if ch then put(x, y, ch, color) end
end

local function step()
    for x = 1, w do
        local d = drops[x]
        d.tick = d.tick + 1
        if d.tick >= d.every then
            d.tick = 0
            d.head = d.head + 1
            local y = d.head
            if y >= 1 and y <= h then
                d.chars[y] = randomChar()
                put(x, y, d.chars[y], HEAD)
            end
            -- fade the trail from tail to head
            recolor(x, d, y - math.floor(d.len * 2 / 3), palette[3])
            recolor(x, d, y - math.floor(d.len / 3), palette[2])
            recolor(x, d, y - 1, palette[1])
            -- erase the end of the trail
            local tail = y - d.len
            if d.chars[tail] then
                put(x, tail, " ", colors.black)
                d.chars[tail] = nil
            end
            if tail > h then drops[x] = newDrop() end
        end
    end
end

math.randomseed(os.epoch("utc"))
reset()

local timer = os.startTimer(delay)
while true do
    local event, p1 = os.pullEventRaw()
    if event == "terminate" then
        break
    elseif event == "timer" and p1 == timer then
        step()
        timer = os.startTimer(delay)
    elseif event == "term_resize" then
        reset()
    elseif event == "key" and (opts.saver or p1 == keys.q) then
        break
    elseif event == "mouse_click" and opts.saver then
        break
    end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
