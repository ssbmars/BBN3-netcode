PLAYERNUM = 0
HOST_IP = "127.0.0.1"
HOST_PORT = 5738

socket = require("socket.core")

tcp = nil
connected = nil
client = nil
t = {}
c = {}
l = {}
s = {}
data = nil
err = nil
part = nil
waitingforpvp = 0
thisispvp = 0
opponent = nil

menu = nil
menu = forms.newform(300,140,"BBN3 Netplay",function()
	return nil
end)
label_ip = forms.label(menu,"IP:",8,0,32,24)
port_ip = forms.label(menu,"Port:",8,30,32,24)
textbox_ip = forms.textbox(menu,"127.0.0.1",240,24,nil,40,0)
textbox_port = forms.textbox(menu,"5738",240,24,nil,40,30)
button_host = forms.button(menu,"Host",function()
	PLAYERNUM = 1
	HOST_IP = forms.gettext(textbox_ip)
	HOST_PORT = tonumber(forms.gettext(textbox_port))
end,80,60,48,24)
button_join = forms.button(menu,"Join",function()
	PLAYERNUM = 2
	HOST_IP = forms.gettext(textbox_ip)
	HOST_PORT = tonumber(forms.gettext(textbox_port))
end,160,60,48,24)

while PLAYERNUM < 1 do
	emu.frameadvance()
end

forms.destroyall()

-- Sync Custom Screen
local function custsynchro()
	if thisispvp == 1 then
		reg3 = emu.getregister("R3")
		
		if #s > 0 then
			local i = 0
			for i=0x0,0x10 do
				memory.write_u32_le(0x02036950 + i*0x4,s[#s-0x10+i]) -- Player Stats
			end
		end
		
		if reg3 == 0x2 then
			if #c < 1 then
				emu.setregister("R3",0)
				return
			end
			if #l > 0 then
				if l[2] <= 0 then
					emu.setregister("R3",2)
					s = {}
					local i = 0
				else
					if c[#c][4] == 0x2 then
						l[2] = l[2] - 1
					end
					emu.setregister("R3",0)
				end
			else
				emu.setregister("R3",0)
			end
		end
	end
end
event.onmemoryexecute(custsynchro,0x08008B96,"CustSync")

-- Sync Player Hands
local function sendhand()
	if thisispvp == 1 then
		if opponent == nil then return end
		if emu.getregister("R1") == 0x02036830 and emu.getregister("R3") == 0x34 then
			opponent:send(tostring(PLAYERNUM).."\n")
			local i = 0
			for i=0,0x10 do
				opponent:send(tostring(memory.read_u32_le(0x02036840 + i*0x4)).."\n") -- Player Stats
			end
			opponent:send("stats".."\n")
			return
		end
		if emu.getregister("R1") == 0x02036940 and emu.getregister("R3") == 0x4C then
			opponent:send(tostring(PLAYERNUM).."\n")
			local i = 0
			for i=0,0x10 do
				opponent:send(tostring(memory.read_u32_le(0x02036840 + i*0x4)).."\n") -- Player Stats
			end
			opponent:send("stats".."\n")
			opponent:send(tostring(PLAYERNUM).."\n")
			opponent:send(tostring(0x3C).."\n")
			opponent:send("loadround".."\n")
			return
		end
	end
end
event.onmemoryexecute(sendhand,0x08008B56,"SendHand")

-- Sync Data on Match Load
local function loadmatch()
	if thisispvp == 1 then
		if opponent == nil then return end
		opponent:send(tostring(PLAYERNUM).."\n")
		local i = 0
		for i=0,0x10 do
			opponent:send(tostring(memory.read_u32_le(0x02036840 + i*0x4)).."\n") -- Player Stats
		end
		opponent:send("stats".."\n")
	end
end
event.onmemoryexecute(loadmatch,0x0800761A,"LoadBattle")

local function delaybattlestart()
	if memory.readbyte(0x0200188F) == 0x0B then
		thisispvp = 1
		if #c > 0 then
			if c[1][5] ~= 0x08 then --if this returns true, delay battle start until players connect
				memory.writebyte(0x020097F8,0x4)
				waitingforpvp = 1
			end
		end
    end
end
event.onmemoryexecute(delaybattlestart,0x080048CC,"DelayBattle")

local function applyp2inputs()
	if thisispvp == 1 and #c > 0 then
		-- Sync Player Information
		local offset = 0
		if c[1][3] % 256 <= memory.read_u8(0x203b410) then
			offset = (math.abs((c[1][3] % 256) - memory.read_u8(0x203b410)) % 256)
			offset = offset*0x10
		end
		memory.write_u8(0x203b401, c[1][2]) -- Player Input Delay
		memory.write_u32_le(0x0203b418 + offset, c[1][3]) -- Player Control Inputs
		table.remove(c, 1)
	end
end
event.onmemoryexecute(applyp2inputs,0x080085A2,"ApplyP2Inputs")

local function closebattle()
	if opponent ~= nil then
		opponent:close()
		opponent = nil
		connected = nil
	end
end
event.onmemoryexecute(closebattle,0x08006958,"CloseBattle")

-- Check if either Host or Client
tcp = assert(socket.tcp())
local ip, dnsdata = socket.dns.toip(HOST_IP)
HOST_IP = ip
-- Host
tcp:settimeout(0.032,'b')
if PLAYERNUM == 1 then
	tcp:bind(HOST_IP, HOST_PORT)
	local server, err = tcp:listen(1)
	while not client do
		if thisispvp == 1 then
			memory.writebyte(0x020097F8,0x4)
			client = tcp:accept()
		end
		emu.frameadvance()
	end
	print("You are the Server.")
-- Client
else
	while not client do
		if thisispvp == 1 then
			memory.writebyte(0x020097F8,0x4)
			client = tcp:connect(HOST_IP, HOST_PORT)
		end
		emu.frameadvance()
	end
	print("You are the Client.")
	--give host priority to the server side
    memory.writebyte(0x0801A11C,0x1)
    memory.writebyte(0x0801A11D,0x5)
    memory.writebyte(0x0801A120,0x0)
    memory.writebyte(0x0801A121,0x2)
end
tcp:settimeout(0.016,'b')

-- Set who your Opponent is
--opponent = socket.udp()
if PLAYERNUM == 1 then
	opponent = client
else
	opponent = tcp
end

-- Finalize Connection
if client then
	connected = true
	print("Connected!")
end

co = coroutine.create(function()
	-- Loop for Received data
	t = {}
	data = nil
	err = nil
	part = nil
	while true do
		data,err,part = opponent:receive()
		if err == "timeout" then
			print(tostring(data)..","..tostring(err))
			data = nil
			err = nil
			part = nil
			coroutine.yield()
		end
		if err == "closed" then
			connected = nil
			break
		end
		if data == "control" then -- Player Control Information
			c[#c+1] = t
			t = {}
		elseif data == "stats" then -- Player Stats
			s = t
			t = {}
		elseif data == "loadround" then -- Player Load Round Timer
			l = t
			t = {}
		elseif data == "end" then -- End of Data Stream
			t = {}
			data = nil
			err = nil
			part = nil
			coroutine.yield()
		elseif data ~= nil then
			t[#t+1] = data
			t[#t] = tonumber(t[#t])
		end
	end
end)

-- Main Loop
while true do
	
	-- Weird Netcode Stuff
	if opponent ~= nil and connected then
	
		-- Send Data to Opponent
		opponent:send(tostring(PLAYERNUM).."\n") -- Player Number
		opponent:send(tostring(memory.read_u8(0x0203b400)).."\n") -- Player Input Delay
		opponent:send(tostring(memory.read_u32_le(0x0203B410)).."\n") -- Player Control Inputs
		opponent:send(tostring(memory.read_u8(0x2036830)).."\n") -- Custom Screen Closed Value
		opponent:send(tostring(memory.read_u8(0x020097F8)).."\n") -- Battle Check
		opponent:send(tostring(waitingforpvp).."\n") -- Waiting for PVP Value
		opponent:send(tostring(socket.gettime()).."\n") -- Socket Time
		opponent:send("control".."\n")
		if #l > 0 and #c > 0 and c[#c][4] == 0x0 and memory.read_u8(0x2036830) == 0x0 then
			opponent:send(tostring(PLAYERNUM).."\n")
			opponent:send(tostring(0x3C).."\n")
			opponent:send("loadround".."\n")
		elseif #l > 0 and #c > 0 and c[#c][4] == 0x2 and memory.read_u8(0x2036830) == 0x2 then
			if l[2] <= 0 then
				opponent:send(tostring(PLAYERNUM).."\n")
				opponent:send(tostring(0).."\n")
				opponent:send("loadround".."\n")
			end
		end
		opponent:send("end".."\n")
		
		-- Receive Data from Opponent
		if coroutine.status(co) == "suspended" then
			coroutine.resume(co)
		end
	
		-- Reset to Disconnect
		-- Will also disconnect the other player
		local buttons = joypad.get()
		if (buttons["A"] and buttons["B"] and buttons["Start"] and buttons["Select"]) then
			opponent:close()
			opponent = nil
			connected = nil
		end
		
		if #c > 0 and waitingforpvp == 1 and c[1][6] == 1 and c[1][7] > socket.gettime() then
			-- No longer waiting for PVP
			waitingforpvp = 0
		end
	end
	
	if connected == nil then
		if opponent ~= nil then
			opponent:close()
			opponent = nil
		end
		break
	end
	
	emu.frameadvance()
end

thisispvp = 0
if opponent ~= nil then
	opponent:close()
	opponent = nil
end
tcp:close()
event.unregisterbyname("CustSync")
event.unregisterbyname("DelayBattle")
event.unregisterbyname("LoadBattle")
event.unregisterbyname("SendHand")
event.unregisterbyname("ApplyP2Inputs")
event.unregisterbyname("CloseBattle")
return