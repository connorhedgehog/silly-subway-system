local expect = require "cc.expect".expect

local maculib = require("maculib")
local config = maculib.loadconfig("config.macl")

local hopper = require("hopper")

local monitor = peripheral.find("monitor")
monitor.setTextScale(0.5)

local minecart_storage = peripheral.find("minecraft:barrel") or peripheral.find("minecraft:chest")
local dispenser = peripheral.find("minecraft:dispenser")

local monitor_x,monitor_y = monitor.getSize()

local PrimeUI = {}
do
    local coros = {}
    local restoreCursor

    --- Adds a task to run in the main loop.
    ---@param func function The function to run, usually an `os.pullEvent` loop
    function PrimeUI.addTask(func)
        expect(1, func, "function")
        local t = {coro = coroutine.create(func)}
        coros[#coros+1] = t
        _, t.filter = coroutine.resume(t.coro)
    end

    --- Sends the provided arguments to the run loop, where they will be returned.
    ---@param ... any The parameters to send
    function PrimeUI.resolve(...)
        coroutine.yield(coros, ...)
    end

    --- Clears the screen and resets all components. Do not use any previously
    --- created components after calling this function.
    function PrimeUI.clear()
        -- Reset the screen.
        term.setCursorPos(1, 1)
        term.setCursorBlink(false)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        -- Reset the task list and cursor restore function.
        coros = {}
        restoreCursor = nil
    end

    --- Sets or clears the window that holds where the cursor should be.
    ---@param win window|nil The window to set as the active window
    function PrimeUI.setCursorWindow(win)
        expect(1, win, "table", "nil")
        restoreCursor = win and win.restoreCursor
    end

    --- Gets the absolute position of a coordinate relative to a window.
    ---@param win window The window to check
    ---@param x number The relative X position of the point
    ---@param y number The relative Y position of the point
    ---@return number x The absolute X position of the window
    ---@return number y The absolute Y position of the window
    function PrimeUI.getWindowPos(win, x, y)
        if win == term then return x, y end
        while win ~= term.native() and win ~= term.current() do
            if not win.getPosition then return x, y end
            local wx, wy = win.getPosition()
            x, y = x + wx - 1, y + wy - 1
            _, win = debug.getupvalue(select(2, debug.getupvalue(win.isColor, 1)), 1) -- gets the parent window through an upvalue
        end
        return x, y
    end

    --- Runs the main loop, returning information on an action.
    ---@return any ... The result of the coroutine that exited
    function PrimeUI.run()
        while true do
            -- Restore the cursor and wait for the next event.
            if restoreCursor then restoreCursor() end
            local ev = table.pack(os.pullEvent())
            -- Run all coroutines.
            for _, v in ipairs(coros) do
                if v.filter == nil or v.filter == ev[1] then
                    -- Resume the coroutine, passing the current event.
                    local res = table.pack(coroutine.resume(v.coro, table.unpack(ev, 1, ev.n)))
                    -- If the call failed, bail out. Coroutines should never exit.
                    if not res[1] then error(res[2], 2) end
                    -- If the coroutine resolved, return its values.
                    if res[2] == coros then return table.unpack(res, 3, res.n) end
                    -- Set the next event filter.
                    v.filter = res[2]
                end
            end
        end
    end
end

--- Draws a line of text, centering it inside a box horizontally.
---@param win window The window to draw on
---@param x number The X position of the left side of the box
---@param y number The Y position of the box
---@param width number The width of the box to draw in
---@param text string The text to draw
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.centerLabel(win, x, y, width, text, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, text, "string")
    fgColor = expect(6, fgColor, "number", "nil") or colors.white
    bgColor = expect(7, bgColor, "number", "nil") or colors.black
    assert(#text <= width, "string is too long")
    win.setCursorPos(x + math.floor((width - #text) / 2), y)
    win.setTextColor(fgColor)
    win.setBackgroundColor(bgColor)
    win.write(text)
end

-- set up windows
local minecartScreen = window.create(monitor, 1, 1, monitor_x, monitor_y)
local destinationScreen = window.create(monitor, 1, 1, monitor_x, monitor_y, false)

local windows = {minecartScreen, destinationScreen}
local function changeWindow(window)
    for i,v in pairs(windows) do
        if v.isVisible() then
            v.setVisible(false)
        end
    end

    window.setVisible(true)
end

local computerTerm = term.current()

-- minecart screen
term.redirect(minecartScreen)

minecartScreen.setBackgroundColor(colors.blue)
minecartScreen.setTextColor(colors.white)
minecartScreen.clear()

paintutils.drawBox(1, 1, monitor_x, 1, colors.white)
PrimeUI.centerLabel(minecartScreen, 1, 1, monitor_x, "Silly Subway System", colors.black, colors.white)

paintutils.drawFilledBox(2, 3, 35, 12, colors.lightBlue)
PrimeUI.centerLabel(minecartScreen, 2, 7, 33, "Spawn a minecart", colors.white, colors.lightBlue)

paintutils.drawFilledBox(2, 14, 35, 23, colors.lightBlue)
PrimeUI.centerLabel(minecartScreen, 2, 18, 33, "Use an existing minecart", colors.white, colors.lightBlue)


-- destination picking screen
term.redirect(destinationScreen)

destinationScreen.setBackgroundColor(colors.blue)
destinationScreen.setTextColor(colors.white)
destinationScreen.clear()

paintutils.drawBox(1, 1, monitor_x, 1, colors.white)
PrimeUI.centerLabel(destinationScreen, 1, 1, monitor_x, "Silly Subway System", colors.black, colors.white)

-- is there a better way to do this? who knows!
if config.destinations.amount == 1 then
    paintutils.drawFilledBox(2, 3, 35, 23, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 13, 33, config.destinations.firstLabel, colors.white, colors.lightBlue)
elseif config.destinations.amount == 2 then
    paintutils.drawFilledBox(2, 3, 35, 12, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 7, 33, config.destinations.firstLabel, colors.white, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 8, 33, config.destinations.firstLabelSecondLine, colors.white, colors.lightBlue)

    paintutils.drawFilledBox(2, 14, 35, 23, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 18, 33, config.destinations.secondLabel, colors.white, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 19, 33, config.destinations.secondLabelSecondLine, colors.white, colors.lightBlue)
elseif config.destinations.amount == 3 then
    paintutils.drawFilledBox(2, 3, 17, 12, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 7, 15, config.destinations.firstLabel, colors.white, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 8, 15, config.destinations.firstLabelSecondLine, colors.white, colors.lightBlue)

    paintutils.drawFilledBox(20, 3, 35, 12, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 20, 7, 15, config.destinations.secondLabel, colors.white, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 20, 8, 15, config.destinations.secondLabelSecondLine, colors.white, colors.lightBlue)
    
    paintutils.drawFilledBox(2, 14, 35, 23, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 18, 33, config.destinations.thirdLabel, colors.white, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 19, 33, config.destinations.thirdLabelSecondLine, colors.white, colors.lightBlue)
elseif config.destinations.amount == 4 then
    paintutils.drawFilledBox(2, 3, 17, 12, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 7, 15, config.destinations.firstLabel, colors.white, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 8, 15, config.destinations.firstLabelSecondLine, colors.white, colors.lightBlue)

    paintutils.drawFilledBox(20, 3, 35, 12, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 20, 7, 15, config.destinations.secondLabel, colors.white, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 20, 8, 15, config.destinations.secondLabelSecondLine, colors.white, colors.lightBlue)

    paintutils.drawFilledBox(2, 14, 17, 23, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 18, 15, config.destinations.thirdLabel, colors.white, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 2, 19, 15, config.destinations.thirdLabelSecondLine, colors.white, colors.lightBlue)

    paintutils.drawFilledBox(20, 14, 35, 23, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 20, 18, 15, config.destinations.fourthLabel, colors.white, colors.lightBlue)
    PrimeUI.centerLabel(destinationScreen, 20, 19, 15, config.destinations.fourthLabelSecondLine, colors.white, colors.lightBlue)
end

-- all clickable areas have to be in one task or they can't overlap
PrimeUI.addTask(function ()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")

        local dispenser_relay = peripheral.wrap(config.dispenserRelay)

        local rail_relay = peripheral.wrap(config.railRelay)
        
        local first_relay
        local second_relay
        local third_relay
        if config.destinations.amount >= 2 then
            first_relay = peripheral.wrap(config.destinations.firstRelay)
            if config.destinations.amount >= 3 then
                second_relay = peripheral.wrap(config.destinations.secondRelay)
                if config.destinations.amount == 4 then
                    third_relay = peripheral.wrap(config.destinations.thirdRelay)
                end
            end
        end

        -- minecart screen, spawn a minecart
        if x >= 2 and x < 2 + 33 and y >= 3 and y < 3 + 9 and minecartScreen.isVisible() then
            dispenser_relay.setOutput("top", true)
            sleep(0.1)
            dispenser_relay.setOutput("top", false)

            changeWindow(destinationScreen)
        -- minecart screen, use existing minecart
        elseif x >= 2 and x < 2 + 33 and y >= 14 and y < 14 + 9 and minecartScreen.isVisible() then
            changeWindow(destinationScreen)
        -- destination screen
        -- 1 out of 1
        elseif x >= 2 and x < 35 and y >= 3 and y < 23 and destinationScreen.isVisible() and config.destinations.amount == 1 then
            rail_relay.setOutput("top", true)

            sleep(5)

            rail_relay.setOutput("top", false)
            changeWindow(minecartScreen)
        -- 1 out of 2
        elseif x >= 2 and x < 35 and y >= 3 and y < 12 and destinationScreen.isVisible() and config.destinations.amount == 2 then
            first_relay.setOutput("top", not config.invertSignals)
            rail_relay.setOutput("top", true)

            sleep(5)

            rail_relay.setOutput("top", false)
            first_relay.setOutput("top", config.invertSignals)
            changeWindow(minecartScreen)
        -- 2 out of 2
        elseif x >= 2 and x < 35 and y >= 14 and y < 23 and destinationScreen.isVisible() and config.destinations.amount == 2 then
            first_relay.setOutput("top", config.invertSignals)
            rail_relay.setOutput("top", true)

            sleep(5)

            rail_relay.setOutput("top", false)
            changeWindow(minecartScreen)
        -- 1 out of 3
        elseif x >= 2 and x < 17 and y >= 3 and y < 12 and destinationScreen.isVisible() and config.destinations.amount == 3 then
            first_relay.setOutput("top", not config.invertSignals)
            second_relay.setOutput("top", config.invertSignals)
            rail_relay.setOutput("top", true)

            sleep(5)

            rail_relay.setOutput("top", false)
            first_relay.setOutput("top", config.invertSignals)
            changeWindow(minecartScreen)
        -- 2 out of 3
        elseif x >= 20 and x < 35 and y >= 3 and y < 12 and destinationScreen.isVisible() and config.destinations.amount == 3 then
            first_relay.setOutput("top", config.invertSignals)
            second_relay.setOutput("top", not config.invertSignals)
            rail_relay.setOutput("top", true)

            sleep(5)

            rail_relay.setOutput("top", false)
            second_relay.setOutput("top", config.invertSignals)
            changeWindow(minecartScreen)
        -- 3 out of 3
        elseif x >= 2 and x < 35  and y >= 14 and y < 23 and destinationScreen.isVisible() and config.destinations.amount == 3 then
            first_relay.setOutput("top", config.invertSignals)
            second_relay.setOutput("top", config.invertSignals)
            rail_relay.setOutput("top", true)

            sleep(5)

            rail_relay.setOutput("top", false)
            changeWindow(minecartScreen)
        -- 1 out of 4
        elseif x >= 2 and x < 17 and y >= 3 and y < 12 and destinationScreen.isVisible() and config.destinations.amount == 4 then
            first_relay.setOutput("top", not config.invertSignals)
            second_relay.setOutput("top", config.invertSignals)
            third_relay.setOutput("top", config.invertSignals)
            rail_relay.setOutput("top", true)

            sleep(5)

            rail_relay.setOutput("top", false)
            first_relay.setOutput("top", config.invertSignals)
            changeWindow(minecartScreen)
        -- 2 out of 4
        elseif x >= 20 and x < 35 and y >= 3 and y < 12 and destinationScreen.isVisible() and config.destinations.amount == 4 then
            first_relay.setOutput("top", config.invertSignals)
            second_relay.setOutput("top", not config.invertSignals)
            third_relay.setOutput("top", config.invertSignals)
            rail_relay.setOutput("top", true)

            sleep(5)

            rail_relay.setOutput("top", false)
            second_relay.setOutput("top", config.invertSignals)
            changeWindow(minecartScreen)
        -- 3 out of 4
        elseif x >= 2 and x < 18 and y >= 14 and y < 23 and destinationScreen.isVisible() and config.destinations.amount == 4 then
            first_relay.setOutput("top", config.invertSignals)
            second_relay.setOutput("top", config.invertSignals)
            third_relay.setOutput("top", not config.invertSignals)
            rail_relay.setOutput("top", true)

            sleep(5)

            rail_relay.setOutput("top", false)
            third_relay.setOutput("top", config.invertSignals)
            changeWindow(minecartScreen)
        -- 4 out of 4
        elseif x >= 20 and x < 35 and y >= 14 and y < 23 and destinationScreen.isVisible() and config.destinations.amount == 4 then
            first_relay.setOutput("top", config.invertSignals)
            second_relay.setOutput("top", config.invertSignals)
            third_relay.setOutput("top", config.invertSignals)
            rail_relay.setOutput("top", true)

            sleep(5)

            rail_relay.setOutput("top", false)
            changeWindow(minecartScreen)
        end
    end
end)

PrimeUI.addTask(function ()
    while true do
        hopper(peripheral.getName(minecart_storage).." *dispenser* *minecart*")
        sleep(5)
    end
end)

term.redirect(computerTerm)
local ok, err = pcall(PrimeUI.run)

if not ok then -- if error
    printError(err)
end