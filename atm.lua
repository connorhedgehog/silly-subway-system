local ed = require("ccryptolib.ed25519")
local random = require("ccryptolib.random")
local expect = require "cc.expect".expect

local monitor = peripheral.find("monitor")
monitor.setTextScale(0.5)

local drive = peripheral.find("drive")

local storage = peripheral.find("minecraft:barrel") or peripheral.find("minecraft:chest")
local total_items = 0
for slot, item in pairs(storage.list()) do
    if item.name == "minecraft:iron_ingot" then
        total_items = total_items + item.count
    end
end

local monitor_x,monitor_y = monitor.getSize()

random.initWithTiming()

-- primeui elements
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

--- Draws a line of text at a position.
---@param win window The window to draw on
---@param x number The X position of the left side of the text
---@param y number The Y position of the text
---@param text string The text to draw
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.label(win, x, y, text, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, text, "string")
    fgColor = expect(5, fgColor, "number", "nil") or colors.white
    bgColor = expect(6, bgColor, "number", "nil") or colors.black
    win.setCursorPos(x, y)
    win.setTextColor(fgColor)
    win.setBackgroundColor(bgColor)
    win.write(text)
end

local privateKey
if fs.exists("privateKey") then
    privateKey = fs.open("privateKey", "r").readAll()
else
    error('The private key, file "privateKey", is not present!')
end
local publicKey = ed.publicKey(privateKey)



-- set up windows
local insertCardScreen = window.create(monitor, 1, 1, monitor_x, monitor_y)
local mainScreen = window.create(monitor, 1, 1, monitor_x, monitor_y, false)
local depositScreen = window.create(monitor, 1, 1, monitor_x, monitor_y, false)
local thanksScreen = window.create(monitor, 1, 1, monitor_x, monitor_y, false)
local balanceScreen = window.create(monitor, 1, 1, monitor_x, monitor_y, false)

local windows = {insertCardScreen, mainScreen, depositScreen, thanksScreen, balanceScreen}
local function changeWindow(window)
    for i,v in pairs(windows) do
        if v.isVisible() then
            v.setVisible(false)
        end
    end

    window.setVisible(true)
end

local computerTerm = term.current()

-- insert card screen
term.redirect(insertCardScreen)

insertCardScreen.setBackgroundColor(colors.blue)
insertCardScreen.setTextColor(colors.white)
insertCardScreen.clear()

paintutils.drawBox(1, 1, monitor_x, 1, colors.white)
insertCardScreen.setCursorPos(1,1)
insertCardScreen.setTextColor(colors.black)
insertCardScreen.write("SillyCard Kiosk")
insertCardScreen.setTextColor(colors.white)

PrimeUI.centerLabel(insertCardScreen, 1, 5, monitor_x, "Insert a disk", colors.white, colors.blue)
PrimeUI.centerLabel(insertCardScreen, 1, 6, monitor_x, "to get started!", colors.white, colors.blue)

-- main screen
term.redirect(mainScreen)

mainScreen.setBackgroundColor(colors.blue)
mainScreen.setTextColor(colors.white)
mainScreen.clear()

paintutils.drawBox(1, 1, monitor_x, 1, colors.white)
mainScreen.setCursorPos(1,1)
mainScreen.setTextColor(colors.black)
mainScreen.write("SillyCard Kiosk")
mainScreen.setTextColor(colors.white)

paintutils.drawFilledBox(2, 3, 14, 5, colors.lightBlue)
mainScreen.setCursorPos(5, 4)
mainScreen.write("Deposit")
--PrimeUI.clickRegion(mainScreen, 2, 3, 13, 3, function() changeWindow(depositScreen) end, peripheral.getName(monitor))

paintutils.drawFilledBox(2, 7, 14, 9, colors.lightBlue)
mainScreen.setCursorPos(5, 8)
mainScreen.write("Balance")
--PrimeUI.clickRegion(mainScreen, 2, 7, 13, 3, function() changeWindow(balanceScreen) end, peripheral.getName(monitor))


-- deposit screen
term.redirect(depositScreen)

depositScreen.setBackgroundColor(colors.blue)
depositScreen.setTextColor(colors.white)
depositScreen.clear()

paintutils.drawBox(1, 1, monitor_x, 1, colors.white)
depositScreen.setCursorPos(1,1)
depositScreen.setTextColor(colors.black)
depositScreen.write("SillyCard Kiosk")
depositScreen.setTextColor(colors.white)

PrimeUI.centerLabel(depositScreen, 1, 3, monitor_x, "Drop iron", colors.white, colors.blue)
PrimeUI.centerLabel(depositScreen, 1, 4, monitor_x, "to deposit", colors.white, colors.blue)

PrimeUI.centerLabel(depositScreen, 2, 6, monitor_x, "Deposited:", colors.white, colors.blue)
PrimeUI.centerLabel(depositScreen, 1, 7, monitor_x, "0", colors.white, colors.blue)

paintutils.drawFilledBox(4, 9, 12, 9, colors.lightBlue)
PrimeUI.centerLabel(depositScreen, 1, 9, monitor_x, "Done ->", colors.white, colors.lightBlue)


-- thanks screen
term.redirect(thanksScreen)

thanksScreen.setBackgroundColor(colors.blue)
thanksScreen.setTextColor(colors.white)
thanksScreen.clear()

paintutils.drawBox(1, 1, monitor_x, 1, colors.white)
thanksScreen.setCursorPos(1,1)
thanksScreen.setTextColor(colors.black)
thanksScreen.write("SillyCard Kiosk")
thanksScreen.setTextColor(colors.white)

PrimeUI.centerLabel(thanksScreen, 1, 4, monitor_x, "Thanks for", colors.white, colors.blue)
PrimeUI.centerLabel(thanksScreen, 1, 5, monitor_x, "using SillyCard", colors.white, colors.blue)

PrimeUI.centerLabel(thanksScreen, 1, 7, monitor_x, "Please eject", colors.white, colors.blue)
PrimeUI.centerLabel(thanksScreen, 1, 8, monitor_x, "your disk now", colors.white, colors.blue)

 
-- balance screen
term.redirect(balanceScreen)

balanceScreen.setBackgroundColor(colors.blue)
balanceScreen.setTextColor(colors.white)
balanceScreen.clear()

paintutils.drawBox(1, 1, monitor_x, 1, colors.white)
balanceScreen.setCursorPos(1,1)
balanceScreen.setTextColor(colors.black)
balanceScreen.write("SillyCard Kiosk")
balanceScreen.setTextColor(colors.white)

PrimeUI.centerLabel(balanceScreen, 2, 5, monitor_x, "Balance:", colors.white, colors.blue)
PrimeUI.centerLabel(balanceScreen, 1, 6, monitor_x, "0", colors.white, colors.blue)

paintutils.drawFilledBox(4, 9, 12, 9, colors.lightBlue)
PrimeUI.centerLabel(balanceScreen, 1, 9, monitor_x, "<- Back", colors.white, colors.lightBlue)
--PrimeUI.clickRegion(balanceScreen, 4, 9, 8, 1, function () changeWindow(mainScreen) end, peripheral.getName(monitor))


local balance
local signature

local function resetCard()
    -- in case they have a signature file for some reason, erase it
        if fs.exists("disk/signature") then
            fs.delete("disk/signature")
        end

        local balanceFile = fs.open("disk/balance", "w")

        balanceFile.write("0")
        balanceFile.close()

        balance = fs.open("disk/balance", "r").readAll()

        signature = ed.sign(privateKey, publicKey, balance)
        local signatureFile = fs.open("disk/signature", "w")

        signatureFile.write(signature)
        signatureFile.close()
end

local deposited = 0

local function deposit()
    local balanceFile = fs.open("disk/balance", "w+")

    balanceFile.write(tostring(balance + deposited))
    balanceFile.close()

    signature = ed.sign(privateKey, publicKey, tostring(balance + deposited))

    local signatureFile = fs.open("disk/signature", "w")

    signatureFile.write(signature)
    signatureFile.close()
end


-- all clickable areas have to be in one task or they can't overlap
PrimeUI.addTask(function ()
    while true do 
        local event, side, x, y = os.pullEvent("monitor_touch")

        -- main screen, deposit button
        if x >= 2 and x < 2 + 13 and y >= 3 and y < 3 + 3 and mainScreen.isVisible() then
            changeWindow(depositScreen)
        -- main screen, balance button
        elseif x >= 2 and x < 2 + 13 and y >= 7 and y < 7 + 3 and mainScreen.isVisible() then
            changeWindow(balanceScreen)
        -- deposit screen, done button
        elseif x >= 4 and x < 4 + 8 and y >= 9 and y < 9 + 1 and depositScreen.isVisible() then
            deposit()
            changeWindow(thanksScreen)
        -- balance screen, back button 
        elseif x >= 4 and x < 4 + 8 and y >= 9 and y < 9 + 1 and balanceScreen.isVisible() then
            changeWindow(mainScreen)
        end
    end
end)

-- since we drew on the windows while setting them up they're all visible, so make them not (except insertCardScreen, the default)
changeWindow(insertCardScreen)

-- since we drew on the windows while setting them up they're all visible, so make them not (except insertCardScreen, the default)
changeWindow(insertCardScreen)

-- disk events (inserts and ejects)
PrimeUI.addTask(function ()
    while true do
        local event, side = os.pullEvent("disk")

        -- make sure an actual disk was inserted! without this, the checking code makes a fake disk/ on the computer and bricks the atm until that's manually deleted
        if disk.hasData(peripheral.getName(drive)) then

            -- checks for broken / non-transit disks and fix / recruit them
            -- should really be a screen that asks if you want to fix / recruit it instead of turning random disks into transit cards
            if not fs.exists("disk/signature") then
                -- balance with no signature isn't verifiable, so erase it
                if fs.exists("disk/balance") then
                    fs.delete("disk/balance")
                end
            end

            if not fs.exists("disk/balance") then
                print("Disk isn't a card, resetting")
                resetCard()
            end

            -- get the balance and signature from the card
            balance = fs.open("disk/balance", "r").readAll()
            signature = fs.open("disk/signature", "r").readAll()

            if not ed.verify(publicKey, balance, signature) then
                print("Could not verify card balance, resetting card")
                resetCard()
            end

            PrimeUI.centerLabel(balanceScreen, 1, 6, monitor_x, balance, colors.white, colors.blue)
            balanceScreen.setVisible(false)

            changeWindow(mainScreen)
        else
            print("Non-disk inserted")
        end
    end
end)

-- should check if it's ejected during the deposit screen and hold onto the data for a few seconds
-- with an on screen timer or something, so if they deposited anything so they don't just lose it
PrimeUI.addTask(function ()
    while true do
        local event, side = os.pullEvent("disk_eject")

        -- clean up deposit stuff
        deposited = 0

        changeWindow(insertCardScreen)
    end
end)


PrimeUI.addTask(function ()
    while true do
        if depositScreen.isVisible() then
            local old_total_items = total_items

            total_items = 0
            for _, item in pairs(storage.list()) do
                if item.name == "minecraft:iron_ingot" then
                    total_items = total_items + item.count
                end
            end

            deposited = total_items - old_total_items + deposited

            PrimeUI.centerLabel(depositScreen, 1, 7, monitor_x, tostring(deposited), colors.white, colors.blue)
        end
        sleep(0.5)
    end
end)

term.redirect(computerTerm)
local ok, err = pcall(PrimeUI.run)

if not ok then -- if error
    printError(err)
end