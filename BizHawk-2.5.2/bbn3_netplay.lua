InputData = 0x0203B400
InputBufferLocal = InputData
InputBufferRemote = InputData + 0x1
InputStackSize = InputData + 0x3
InputStackLocal = InputData + 0x10
InputStackRemote = InputData + 0x18

PLAYERNUM = 0
HOST_IP = "127.0.0.1"
HOST_PORT = 5738

socket = require("socket.core")

tcp = nil
connected = nil
client = nil
t = {}
c = {}
ctrl = {}
l = {}
s = {}
data = nil
err = nil
part = nil
waitingforpvp = 0
waitingforround = 0
thisispvp = 0
delaybattletimer = 30
opponent = nil
acked = false
timedout = 0

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
		
		if type(s) == "table" and #s == 18 then
			local i = 0
			for i=0x0,0x10 do
				memory.write_u32_le(0x02036950 + i*0x4,s[#s-0x10+i]) -- Player Stats
			end
		end
		
		if reg3 == 0x2 then
			waitingforround = 1
			if type(l) == "table" and #l > 0 then
				memory.write_u8(InputBufferRemote, l[3])
				if l[4] <= 0 and waitingforround and l[5] then
					waitingforround = 0
					return
				else
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
			opponent:send("ack")
			opponent:send("1,1,"..tostring(PLAYERNUM))
			local i = 0
			for i=0,0x10 do
				opponent:send("1,"..tostring(i+2)..","..tostring(memory.read_u32_le(0x02036840 + i*0x4))) -- Player Stats
			end
			opponent:send("stats")
			return
		end
		if emu.getregister("R1") == 0x02036940 and emu.getregister("R3") == 0x4C then
			opponent:send("ack")
			opponent:send("1,1,"..tostring(PLAYERNUM))
			local i = 0
			for i=0,0x10 do
				opponent:send("1,"..tostring(i+2)..","..tostring(memory.read_u32_le(0x02036840 + i*0x4))) -- Player Stats
			end
			opponent:send("stats")
			opponent:send("2,1,"..tostring(PLAYERNUM))
			opponent:send("2,2,"..tostring(memory.read_u8(0x2036830))) -- Custom Screen Value
			opponent:send("2,3,"..tostring(memory.read_u8(InputBufferLocal))) -- Player Input Delay
			opponent:send("2,4,"..tostring(0x3C))
			opponent:send("2,5,"..tostring(waitingforround))
			opponent:send("loadround")
			return
		end
	end
end
event.onmemoryexecute(sendhand,0x08008B56,"SendHand")

-- Sync Data on Match Load
local function loadmatch()
	if thisispvp == 1 then
		if opponent == nil then return end
		opponent:send("ack")
		opponent:send("1,1,"..tostring(PLAYERNUM))
		local i = 0
		for i=0,0x10 do
			opponent:send("1,"..tostring(i+2)..","..tostring(memory.read_u32_le(0x02036840 + i*0x4))) -- Player Stats
		end
		opponent:send("stats")
	end
end
event.onmemoryexecute(loadmatch,0x0800761A,"LoadBattle")

local function delaybattlestart()
	if memory.readbyte(0x0200188F) == 0x0B then
		thisispvp = 1
		if #c == 0 then
			memory.writebyte(0x020097F8,0x4)
			waitingforpvp = 1
		else
			if waitingforpvp == 1 then
				waitingforpvp = 0
				if PLAYERNUM == 1 then
					delaybattletimer = 30
				else
					local ping = 0
					if type(c[1]) == "table" then
						ping = math.min(30, math.abs(math.floor(((socket.gettime()*1000/60) % 100)) - c[1][5]))
					end
					delaybattletimer = 30 - ping
				end
			end
			if waitingforpvp == 0 and c[1][4] == 0 and delaybattletimer > 0 then
				delaybattletimer = delaybattletimer - 1
				memory.writebyte(0x020097F8,0x4)
			elseif delaybattletimer > 0 then
				memory.writebyte(0x020097F8,0x4)
			end
			if #c > 1 then
				table.remove(c,1)
			end
		end
	else
		thisispvp = 0
    end
end
event.onmemoryexecute(delaybattlestart,0x080048CC,"DelayBattle")

local function applyp2inputs()
	if thisispvp == 1 then
		-- Sync Player Information
		if type(c) == "table" and #c > 0 and type(c[1]) == "table" and #c[1] == 5 then
			iBacklog = 1
            while true do
                local iCheck = memory.read_u8(InputStackRemote + 0x1 + (iBacklog*0x10) )
                if iCheck == 0 then
                    break
                end
                iBacklog = iBacklog + 1
            end
            if iBacklog > #c then
                iWriteCount = #c
            else
                iWriteCount = iBacklog
            end 
            while iWriteCount > 0 do
                iWriteCount = iWriteCount - 1
                if type(c[#c - iWriteCount][2]) == "number" then
                    memory.write_u32_le(InputStackRemote + iWriteCount*0x10, c[#c - iWriteCount][2]) --Player Button Inputs
                    table.remove(c,#c - iWriteCount)
                end
            end
        else
            memory.write_u8(InputStackRemote+1,0x1)
            local rollbackmode = nil
            if rollbackmode then
                local previoustimestamp = memory.read_u8(InputStackRemote)
                memory.write_u8(InputStackRemote, math.floor((previoustimestamp + 0x1)%256))
            end    
        end
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
tcp = socket.tcp()
local ip, dnsdata = socket.dns.toip(HOST_IP)
HOST_IP = ip
-- Host
tcp:settimeout(1 / (16777216 / 280896),'b')
if PLAYERNUM == 1 then
	tcp:bind(HOST_IP, HOST_PORT)
	local server, err = nil, nil
	while client == nil do
		if thisispvp == 1 then
			while server == nil do
				server, err = tcp:listen(1)
			end
			if server ~= nil then
				client = tcp:accept()
			end
		end
		emu.frameadvance()
	end
	print("You are the Server.")
-- Client
else
	local err = nil
	while client == nil do
		if thisispvp == 1 then
			client, err = tcp:connect(HOST_IP, HOST_PORT)
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

-- Set who your Opponent is
opponent = socket.udp()
opponent:settimeout(1 / (16777216 / 280896))
if PLAYERNUM == 1 then
	ip, port = client:getpeername()
	client:close()
	tcp:close()
	opponent:setsockname(HOST_IP, HOST_PORT)
	opponent:setpeername(ip, port)
else
	ip, port = tcp:getsockname()
	tcp:close()
	opponent:setsockname(ip, port)
	opponent:setpeername(HOST_IP, HOST_PORT)
end

-- Finalize Connection
if client then
	connected = true
	print("Connected!")
end

co = coroutine.create(function()
	-- Loop for Received data
	--t = {}
	ctrl = {}
	data = nil
	err = nil
	part = nil
	while true do
		data,err,part = opponent:receive()
		if data ~= nil then -- Receive Data
			if data == "ack" then
				acked = true
				timedout = 0
			end
			if data == "end" and acked then -- End of Data Stream
				data = nil
				err = nil
				part = nil
				acked = false
				coroutine.yield()
			elseif data == "disconnect" and acked then
				connected = nil
				acked = false
				break
			elseif acked then
				if data == "control" and #ctrl == 5 then -- Player Control Information
					c[#c+1] = ctrl
					ctrl = {}
				end
				if data == "stats" and #t == 18 then -- Player Stats
					s = t
					t = {}
				end
				if data == "loadround" and #t == 5 then -- Player Load Round Timer
					l = t
					t = {}
				end
				local str = {}
				local w = ""
				for w in data:gmatch("(%d+)") do
					str[#str+1] = w
				end
				if #str > 0 then
					if tonumber(str[1]) == 0 then
						ctrl[tonumber(str[2])] = tonumber(str[3])
					elseif tonumber(str[1]) == 1 then
						t[tonumber(str[2])] = tonumber(str[3])
					elseif tonumber(str[1]) == 2 then
						t[tonumber(str[2])] = tonumber(str[3])
					end
				end
			end
		elseif err == "timeout" then
			data = nil
			err = nil
			part = nil
			acked = false
			timedout = timedout + 1
			if timedout >= memory.read_u8(InputBufferRemote) then
				emu.yield()
				if timedout >= 60*3 then
					connected = nil
					acked = false
					break
				end
			end
		end
	end
end)

-- Main Loop
while true do
	
	-- Weird Netcode Stuff
	if opponent ~= nil and connected then
	
		-- Send Data to Opponent
		opponent:send("ack")
		opponent:send("0,1,"..tostring(PLAYERNUM)) -- Player Number
		opponent:send("0,2,"..tostring(memory.read_u32_le(InputStackLocal))) -- Player Control Inputs
		opponent:send("0,3,"..tostring(memory.read_u8(0x020097F8))) -- Battle Check
		opponent:send("0,4,"..tostring(waitingforpvp)) -- Waiting for PVP Value
		opponent:send("0,5,"..tostring(math.floor((socket.gettime()*1000/60) % 100))) -- Socket Time
		opponent:send("control")
		opponent:send("2,1,"..tostring(PLAYERNUM))
		opponent:send("2,2,"..tostring(memory.read_u8(0x2036830))) -- Custom Screen Value
		opponent:send("2,3,"..tostring(memory.read_u8(InputBufferLocal))) -- Player Input Delay
		if type(l) == "table" and type(l[4]) == "number" and waitingforround == 1 and l[5] == 1 then
			l[4] = l[4]-1
			opponent:send("2,4,"..tostring(l[4]))
		elseif type(l) == "table" and type(l[4]) == "number" and (waitingforround == 1 or l[5] == 1) then
			opponent:send("2,4,"..tostring(l[4]))
		else
			opponent:send("2,4,"..tostring(0x3C))
		end
		opponent:send("2,5,"..tostring(waitingforround))
		opponent:send("loadround")
		opponent:send("end")
		
		-- Receive Data from Opponent
		if coroutine.status(co) == "suspended" then
			coroutine.resume(co)
		end
	
		-- Reset to Disconnect
		-- Will also disconnect the other player
		local buttons = joypad.get()
		if (buttons["A"] and buttons["B"] and buttons["Start"] and buttons["Select"]) then
			opponent:send("disconnect")
			opponent:close()
			opponent = nil
			connected = nil
		end
	end
	
	if connected == nil then
		if opponent ~= nil then
			opponent:send("disconnect")
			opponent:close()
			opponent = nil
		end
		break
	end
	
	emu.frameadvance()
end

thisispvp = 0
if opponent ~= nil then
	opponent:send("disconnect")
	opponent:close()
	opponent = nil
end
event.unregisterbyname("CustSync")
event.unregisterbyname("DelayBattle")
event.unregisterbyname("LoadBattle")
event.unregisterbyname("SendHand")
event.unregisterbyname("ApplyP2Inputs")
event.unregisterbyname("CloseBattle")
return