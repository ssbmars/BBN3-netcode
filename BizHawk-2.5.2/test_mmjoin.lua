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

gui.drawText(120,50,"JOIN",nil,nil,nil,nil, "center")

-- Client
-- #!/usr/bin/env lua5.1

local wait_count = 10 -- in seconds

local dummy_hash = "YZ0123"
local mm = require("matchmaker.matchmaker")

mm:init(dummy_hash, '158.101.96.179', 5738, 1)

if mm:check_config() == false then return end

-- will join a private session by its secret
--mm:join_session("nssiaA1")

-- will join any public session
mm:join_session()

-- NOTE: will abort the loop if we fail or succeed (instant notification) 
while(wait_count > 0 and mm:is_join_pending()) do
    wait_count = wait_count - 1
    print("wait_count: "..wait_count)
    mm:poll()
    mm:sleep(1.0)
    emu.frameadvance()
    gui.drawText(120,50,"JOIN",nil,nil,nil,nil, "center")
end

print("Join request status="..mm:get_join_status())

local remote_addr = mm:get_remote_addr()

if remote_addr ~= '' then
    print("joined session with remote "..remote_addr)
    
    -- use the socket when connection is available!
    -- mm.socket 
else 
    print("I could not find a session")
end

-- Cleanup
mm:close()

print('Done')


	emu.frameadvance()
end

return