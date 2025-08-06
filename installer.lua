print("Welcome to the Silly Subway System installer!")
print()
print("Please choose a program to install on this computer:")
print("[1] ATM")
print("[2] ATM Turtle")
print("[3] Turnstile")
print("[4] Destination Picker")

term.write("> ")
local input = read()

-- libraries
if input == "1" or input == "3" then
    print("Installing ccryptolib")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/internal/curve25519.lua ccryptolib/internal/curve25519.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/internal/edwards25519.lua ccryptolib/internal/edwards25519.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/internal/fp.lua ccryptolib/internal/fp.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/internal/fq.lua ccryptolib/internal/fq.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/internal/mp.lua ccryptolib/internal/mp.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/internal/packing.lua ccryptolib/internal/packing.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/internal/sha512.lua ccryptolib/internal/sha512.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/internal/util.lua ccryptolib/internal/util.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/aead.lua ccryptolib/aead.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/blake3.lua ccryptolib/blake3.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/chacha20.lua ccryptolib/chacha20.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/ed25519.lua ccryptolib/ed25519.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/poly1305.lua ccryptolib/poly1305.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/random.lua ccryptolib/random.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/sha256.lua ccryptolib/sha256.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/util.lua ccryptolib/util.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/x25519.lua ccryptolib/x25519.lua")
    shell.run("wget https://raw.githubusercontent.com/migeyel/ccryptolib/refs/heads/main/ccryptolib/x25519c.lua ccryptolib/x25519c.lua")
elseif input == "4" then
    print("Installing hopper and maculib")
    shell.run("wget https://raw.githubusercontent.com/umnikos/hopper.lua/main/hopper.lua")
    shell.run("wget https://raw.githubusercontent.com/connorhedgehog/silly-subway-system/refs/heads/main/maculib.lua")
end

-- programs
if input == "1" then
    shell.run("wget https://raw.githubusercontent.com/connorhedgehog/silly-subway-system/refs/heads/main/atm.lua startup.lua")
elseif input == "2" then
    shell.run("wget https://raw.githubusercontent.com/connorhedgehog/silly-subway-system/refs/heads/main/atm_turtle.lua startup.lua")
elseif input == "3" then
    shell.run("wget https://raw.githubusercontent.com/connorhedgehog/silly-subway-system/refs/heads/main/turnstile.lua startup.lua")
elseif input == "4" then
    shell.run("wget https://raw.githubusercontent.com/connorhedgehog/silly-subway-system/refs/heads/main/railway.lua startup.lua")
    shell.run("wget https://raw.githubusercontent.com/connorhedgehog/silly-subway-system/refs/heads/main/config.macl")
end

-- extra info
print()
if input == "1" or input == "3" then
    print("You'll need a private key for that specific program.")
    print("If you already have one, you'll want to use the 'copy' command in CraftOS to copy it to a disk, and then to here.")
    print("The private key has to be the same in the ATM and turnstile for them to work together.")
    print()
    print("Would you like to generate a private key now? (yes/no)")
    
    term.write("> ")
    local input = read()

    if input == "yes" or input == "YES" or input == "y" or input == "Y" then
        local random = require("ccryptolib.random")
        random.initWithTiming()

        local privateKeyFile = fs.open("privateKey", "w")
        privateKeyFile.write(random.random(32))

        print()
        print("Generated at /privateKey")
        print("Don't share that file with anyone, or they could write their own balances!")
        sleep(3)
    end
    print()
end

os.reboot()