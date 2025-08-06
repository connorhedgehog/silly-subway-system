local modem = peripheral.find("modem")
local thisTurtle = modem.getNameLocal()
local storage = peripheral.find("minecraft:barrel") or peripheral.find("minecraft:chest")

while true do
    turtle.suck()
    storage.pullItems(thisTurtle, 1)
    sleep(0.5)
end