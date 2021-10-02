client.displaymessages(true)
emu.limitframerate(true)

local sotrue = 10
while sotrue > 0 do
    emu.frameadvance()
    sotrue = sotrue - 1
end
sotrue = nil


-- Main Loop
while true do

gui.drawText(120,50,"HOST",nil,nil,nil,nil, "center")

-- Client
-- #!/usr/bin/env lua5.1

local wait_count = 10 -- in seconds

local dummy_hash = "YZ0123"
local mm = require("matchmaker.matchmaker")

mm:init(dummy_hash, '158.101.96.179', 5738, 1)

if mm:check_config() == false then return end

-- create_session() creates a new session on the server
-- create_session(true) creates a private session
mm:create_session()

-- wait until we get our unique session key (secret)
while(mm:get_session():len() == 0) do
    mm:poll()
    emu.frameadvance()
    gui.drawText(120,50,"HOST",nil,nil,nil,nil, "center")
end

print("Server returned session code: "..mm:get_session())

while(wait_count > 0) do
    wait_count = wait_count - 1
    print("wait_count: "..wait_count)
    mm:poll()
    mm:sleep(1.0)
    emu.frameadvance()
    gui.drawText(120,50,"HOST",nil,nil,nil,nil, "center")
end

local remote_addr = mm:get_remote_addr()

if remote_addr ~= '' then
    print("joined session with remote "..remote_addr)
    
    -- use the socket when connection is available!
    -- mm.socket 
else 
    print("No one joined the session")
end

-- cleanup
-- will also close session on server for us
mm:close()

print('Done')

	emu.frameadvance()
end

return