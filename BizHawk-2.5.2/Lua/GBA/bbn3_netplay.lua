local PLAYERNUM = 2 -- CHANGE THIS TO BE YOUR PLAYER NUMBER
local HOST_IP = "10.0.0.180" -- CHANGE TO HOST IP
local HOST_PORT = 7777 -- CHANGE BOTH PORTS TO SAME VALUE

socket = require("socket.core")

-- Check if either Host or Client
local tcp = nil
local connected = nil
local client = nil
tcp = assert(socket.tcp())
-- Host
if PLAYERNUM == 1 then
	tcp:bind(HOST_IP, HOST_PORT)
	tcp:settimeout(5,'b')
	local server = tcp:listen(1)
	client = tcp:accept()
-- Client
else
	client = tcp:connect(HOST_IP, HOST_PORT)
end
-- Finalize Connection
if client then
	connected = true
end

t = {}
data = nil
err = nil
part = nil

-- Main Loop
while true do

	-- Write Data to Variables
	local opponent = nil

	-- Set who your Opponent is
	if PLAYERNUM == 1 then
		opponent = client
	else
		opponent = tcp
	end
	
	-- Send Data to Opponent
	if opponent and connected then
		opponent:send(tostring(PLAYERNUM).."\n") -- Player Number
		opponent:send(tostring(memory.read_u8(0x0203B36E)).."\n") -- Lockstep Check
		opponent:send(tostring(memory.read_u8(0x0203B410)).."\n") -- Player Control Input Buffer Timer
		opponent:send(tostring(memory.read_u16_le(0x0203B412)).."\n") -- Player Control Bitflag
		opponent:send(tostring(memory.read_u16_le(0x0200F888)).."\n") -- Player Current HP
		opponent:send(tostring(memory.read_u16_le(0x2006CCC)).."\n") -- Custom Meter Value
		opponent:send(tostring(memory.read_u8(0x2006CA1)).."\n") -- Custom Meter Is Open Value
		opponent:send(tostring(memory.read_u8(0x2006CAC)).."\n") -- Custom Meter Active Value
		opponent:send(tostring(memory.read_u32_le(0x2009730)).."\n") -- RNG #1
		opponent:send(tostring(memory.read_u32_le(0x2009800)).."\n") -- RNG #2
		opponent:send(tostring(memory.read_u8(0x020097F8)).."\n") -- Battle Check
		local i = 0
		for i=0,0x10 do
			opponent:send(tostring(memory.read_u32_le(0x02036840 + i*0x4)).."\n") -- Player Stats
		end
		opponent:send("end\n") -- Ends the Data Stream
	end
	
	-- Receive Client Data
	if opponent and connected then
		-- Loop for Received data
		t = {}		
		while true do
			data = nil
			err = nil
			part = nil
			data,err,part = opponent:receive('*l')
			if data ~= "end" then
				t[#t+1] = data
			else
				break
			end
		end
		
		-- Turn it all into numbers
		for i=1, #t do
			t[i] = tonumber(t[i])
		end
	else
		break
	end

	-- Weird Netcode Stuff
	if opponent and connected and #t > 0 then
		-- In Battle Check
		if memory.read_u8(0x020097F8) == 0x08 and t[11] == 0x08 then
			-- Stream Inputs Forward
			local i = memory.read_u8(0x0203b402)
			local baseoffset = 0x0203b400 + memory.read_u8(0x0203b402)*0x10 + 0x20
			while i > 0 do
				local reinsert = baseoffset + i*0x10
				memory.write_u32_le(reinsert, memory.read_u32_le(reinsert - 0x10))
				i = i - 1
			end
			
			-- Clear Input Slot 0
			local p2offset = 0x0203b400 + memory.read_u8(0x0203b402)*0x10 + 0x20
			memory.write_u8(p2offset, memory.read_u8(0x0203b380))
			memory.write_u16_le(p2offset + 2, 0x00) -- Clear Input Buffer
			
			-- Sync Frame Timer
			local f = 0
			f = (memory.read_u32_le(0x0203B380) - t[12]) % 256
			print(f)
			
			-- Sync Various Player Information
			memory.write_u16_le(0x0200F8B2, t[5]) -- Player Current HP
			memory.write_u8(p2offset, t[3] - f) -- Player Control Input Buffer Timer
			memory.write_u16_le(p2offset + 0x2, t[4]) -- Player Control Bitflag
			if memory.read_u32_le(0x2009730) ~= t[9] then
				memory.write_u32_le(0x2009730,t[9]) -- RNG #1
			end
			if memory.read_u32_le(0x2009800) ~= t[10] then
				memory.write_u32_le(0x2009800,t[10]) -- RNG #2
			end
			i = 0
			for i=0,0x10 do
				memory.write_u32_le(0x02036950 + i*0x4,t[#t-0x10+i]) -- Player Stats
			end
			
			-- Sync Custom Meter
			if memory.read_u16_le(0x02006CCC) > t[6] then
				memory.write_u16_le(0x02006CCC, t[6])
			end
			
			-- Sync Custom Screen
			if t[7] == 0x08 then
				if memory.read_u8(0x0203B36E) == 0x00 and memory.read_u8(0x2006CA1) >= 0x08 and memory.read_u8(0x2006CA1) ~= t[7] and memory.read_u8(0x2006CAC) == 0x01 then
					memory.write_u8(0x0203B36E, 0x01)
				end
			end
			if t[7] ~= 0x08 and t[4]/0x100 >= 0x01 and memory.read_u8(0x2006CA1) == 0x0C and memory.read_u8(0x2006CAC) == 0x01 then
				memory.write_u16_le(0x0203b412, 0x100)
				memory.write_u8(0x0203b410, memory.read_u8(0x0203b380))
				memory.write_u8(0x0203B36E, 0x00)
			elseif t[7] ~= 0x08 and (t[4]/0x1000 == 0x4) and memory.read_u8(0x2006CA1) == 0x08 then
				memory.write_u8(0x2006CAC, 0x01)
				memory.write_u8(0x0203B36E, 0x01)
			end
			if memory.read_u8(0x2006CA1) == t[7] and t[7] == 0x0C then
				if t[8] == 0x00 then
					memory.write_u8(0x0203B36E, 0x00)
				end
			end
			if memory.read_u8(0x2006CA1) == t[7] and t[7] == 0x08 then
				if memory.read_u8(0x2006CAC) == 0x00 then
					memory.write_u8(0x2006CAC, 0x01)
				end
			end
		end
	end
	emu.frameadvance()
end

tcp:close()