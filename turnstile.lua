local price = 1

local ed = require("ccryptolib.ed25519")
local random = require("ccryptolib.random")

local drive = peripheral.find("drive")

random.initWithTiming()

local privateKey
if fs.exists("privateKey") then
    privateKey = fs.open("privateKey", "r").readAll()
    privateKey = privateKey:sub(1, 32)
    print(privateKey)
else
    error('The private key, file "privateKey", is not present!')
end
local publicKey = ed.publicKey(privateKey)

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

while true do
    local event, _ = os.pullEvent("disk")

    if disk.hasData(peripheral.getName(drive)) then
        -- checks for broken / non-transit disks and fix / recruit them
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
        


        if tonumber(balance) >= price then
            -- take one currency
            local balanceFile = fs.open("disk/balance", "w")

            balanceFile.write(tonumber(balance) - price)
            balanceFile.close()

            balance = fs.open("disk/balance", "r").readAll()
            signature = ed.sign(privateKey, publicKey, balance)

            local signatureFile = fs.open("disk/signature", "w")

            signatureFile.write(signature)
            signatureFile.close()

            -- open the turnstile
            redstone.setOutput("top", true)
            sleep(2)
            redstone.setOutput("top", false)
        else
            print("Not enough money!")
        end
    else
        print("Non-disk inserted")
    end

    -- if a disk is inserted, wait until it's ejected to continue
    local event, _ = os.pullEvent("disk_eject")

    sleep()
end