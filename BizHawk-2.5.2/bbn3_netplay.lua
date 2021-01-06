rollbackmode = 1	--toggle this between 1 and nil
saferollback = 6
resimulating = nil
HideResim = 1
savcount = 30	--amount of savestate frames to keep
client.displaymessages(false)

InputData = 0x0203B400
InputStackSize = InputData + 0x5
rollbackflag = InputData + 0x6
SceneIndicator = 0x020097F8
StartBattleFlipped = 0x0203B362
PreloadStats = 0x0200F330

PlayerData = 0x02036840
	PD_s = 0x110	--PlayerData size

BattleData_A = 0x02037274
	BDA_s = 0xD4	--BattleData_A size
		BDA_HP = 0x20 + BattleData_A --pointer for active HP value
		BDA_HandSize = 0x16 + BattleData_A 

			--the rest of these pointers aren't meant for anything currently
			BDA_Act_State = 0x1 + BattleData_A 
			-- 7 = idle, 4 = movement, 3 & 1 = buster endlag, 0 = chip/attack
			BDA_Act_Main = 0x2 + BattleData_A 
			-- holds the value of the type of attack being used (ie almost all swords have the val of 0x8)
			BDA_Act_Sub = 0x5D + BattleData_A 
			-- defines the specific sub attack (if main = 0x8, then sub = 0x3 would be firesword, or 0x9 for Muramasa)

BattleData_B = 0x020384D0
	BDB_s = 0x88	--BattleData_B size



FullInputStack = {}  --input stack for rollback frames
sav = {}  --savestate ID table
CycleInputStack = {}

--define variables for gui.draw
	--things get drawn at the base GBA resolution and then scaled up, so calculations are based on 1x GBA res
x_center = 120 
y_center = 80



PLAYERNUM = 0
PORTNUM = nil
HOST_IP = "127.0.0.1"
HOST_PORT = 5738

socket = require("socket.core")

tcp = nil
connected = nil
connectedclient = nil
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
delaybattletimer = 10
opponent = nil
acked = false
timedout = 0
CanWriteRemoteChips = false
droppedcount = 0
RiBacklog = 0
lastinput = 0

menu = nil
local delaymenu = 20

while delaymenu > 0 do
	delaymenu = delaymenu - 1
	emu.frameadvance()
end

local windowsize = client.getwindowsize()
local form_xpos = (client.xpos() + 120*windowsize - 142)
local form_ypos = (client.ypos() + 80*windowsize + 10)

menu = forms.newform(300,140,"BBN3 Netplay",function()
	return nil
end)
forms.setlocation(menu, form_xpos , form_ypos)
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

BufferVal = 4

PORTNUM = PLAYERNUM - 1
InputBufferLocal = InputData + PLAYERNUM
InputStackLocal = InputData + 0x10 + (PORTNUM*0x4)
PlayerHPLocal = BattleData_A + BDA_HP + (BDA_s * PORTNUM)
PlayerDataLocal = PlayerData + (PD_s * PORTNUM)

--this math only works for 1v1s
InputStackRemote =  InputData + 0x10 + (0x4*bit.bxor(1, PORTNUM))
InputBufferRemote = InputData + 0x1 + bit.bxor(1, PORTNUM)
PlayerHPRemote = BattleData_A + BDA_HP + (BDA_s * bit.bxor(1, PORTNUM))
PlayerDataRemote = PlayerData + (PD_s * bit.bxor(1, PORTNUM))
--this is fine for now. To support more than 2 players it will need to define these after everyone has connected, 
--and up to 3 sets of "Remote" addresses will need to exist. But this won't matter any time soon.

CanWriteRemoteStats = false


local function ReceiveAtStart()
	if thisispvp == 1 and connected then
		if coroutine.status(co) == "suspended" then coroutine.resume(co) end
	end
end
event.onframestart(ReceiveAtStart)



-- Sync Custom Screen
local function custsynchro()
	if thisispvp == 1 then
		reg3 = emu.getregister("R3")
		

		
		-- Sync Player HP and Input Buffer
		if type(l) == "table" and #l > 0 then
			memory.write_u8(InputBufferRemote, l[3])
			if PLAYERNUM == 1 and #l >= 6 then
			--	memory.write_u16_le(PlayerHPRemote, l[6])
			elseif PLAYERNUM == 2 and #l >= 6 then
			--	memory.write_u16_le(PlayerHPLocal, l[6])
			--	memory.write_u32_le(0x02009730, l[7])
			--	memory.write_u32_le(0x02009800, l[8])
			end
		end
		
		-- Rewrite Client's Timestamp
		if PLAYERNUM > 1 then
			if type(c) == "table" and #c > 0 then
				if type(c[1]) == "table" and #c[1] > 0 then
					if c[1][3] == 0x4 or memory.read_u8(SceneIndicator) == 0x4 then
						memory.write_u16_le(0x0203b380, l[9])
					end
				end
			end
		end
		
		if reg3 == 0x2 then
			waitingforround = 1
			if type(l) == "table" and #l > 0 then
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
		--when this runs, it means you can safely send your chip hand and write over the remote player's hand
		local WriteType = memory.read_u8(0x02036830)
		if emu.getregister("R1") == 0x02036940 and emu.getregister("R3") == 0x34 and WriteType == 0x2 then
			print("sent hand")
			opponent:send("ack")
			opponent:send("1,1,"..tostring(PLAYERNUM))
			local i = 0
			for i=0,0x10 do
				opponent:send("1,"..tostring(i+2)..","..tostring(memory.read_u32_le(PlayerDataLocal + i*0x4))) -- Player Stats
			end
			opponent:send("stats")
			CanWriteRemoteChips = true
			return
		end

		--this is the signal that you can write the received player stats to ram
		--it only triggers once, at the start of the match before players have loaded in
		if emu.getregister("R1") == 0x02036940 and emu.getregister("R3") == 0x4C and WriteType == 0x1 then

			CanWriteRemoteStats = true

	--		local looptimes = 5
	--		while looptimes > 0 do
	--			socket.sleep(0.5)
	--			looptimes = looptimes - 1
	--		end

		end
	end
end
event.onmemoryexecute(sendhand,0x08008B56,"SendHand")

-- Sync Data on Match Load
local function loadmatch()
	if thisispvp == 1 then
		if opponent == nil then print("nopponent") return end
		opponent:send("ack")
		opponent:send("1,1,"..tostring(PLAYERNUM))
		local i = 0
		for i=0,0x10 do
			opponent:send("1,"..tostring(i+2)..","..tostring(memory.read_u32_le(PreloadStats + i*0x4))) -- Player Stats
		end
		opponent:send("stats")
		--print("sending stats at the proper time")
	end
end
event.onmemoryexecute(loadmatch,0x0800761A,"LoadBattle")

local function delaybattlestart()
	if memory.readbyte(0x0200188F) == 0x0B then
		thisispvp = 1
		if #c == 0 then
			memory.writebyte(SceneIndicator,0x4)
			waitingforpvp = 1
			gui.drawText(20, y_center - 20, "search routine", "white", nil, nil, nil, nil,"middle")
			gui.drawText(20, y_center + 0, "find: [ Netbattler ]", "white", nil, nil, nil, nil,"middle")
		else
			if waitingforpvp == 1 then
				waitingforpvp = 0
				if PLAYERNUM == 1 then
					delaybattletimer = 10
				else
					local ping = 0
					if type(c[1]) == "table" then
						ping = math.min(30, math.abs(math.floor(((socket.gettime()*1000/60) % 100)) - c[1][5]))
					end
					delaybattletimer = 10 - ping
				end
				if type(l) == "table" and #l > 0 then
					if PLAYERNUM == 2 then
						memory.write_u32_le(0x02009730, l[7])
						memory.write_u32_le(0x02009800, l[8])
					end
				end
			end
			if waitingforpvp == 0 and c[1][4] == 0 and delaybattletimer > 0 then
				delaybattletimer = delaybattletimer - 1
				memory.writebyte(SceneIndicator,0x4)
				gui.drawText(x_center, y_center - 10, "Battle routine, set", "white", nil, nil, nil, "center","middle")
				gui.drawText(x_center, y_center + 10, "Execute!", "white", nil, nil, nil, "center","middle")
			elseif delaybattletimer > 0 then
				memory.writebyte(SceneIndicator,0x4)
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

local function SetPlayerPorts()
	--write port number (0-3)
	memory.write_u8(InputData, PORTNUM)
	--write input lag value
	memory.write_u8(InputBufferLocal, BufferVal)

	--if port # is odd then spawn on right side, if even then left side
	if bit.check(PORTNUM,0) == true then
		memory.write_u8(StartBattleFlipped, 0x1)
	end
end
event.onmemoryexecute(SetPlayerPorts,0x08008804,"SetPlayerPorts")

local function ApplyRemoteInputs()
	if thisispvp == 1 and not(resimulating) then

		if coroutine.status(co) == "suspended" then coroutine.resume(co) end


		--iterate the latest input's timestamp by 1 frame (it's necessary to do this first for this new routine)
		local previoustimestamp = memory.read_u8(InputStackRemote)
		memory.write_u8(InputStackRemote, math.floor((previoustimestamp + 0x1)%256))
		memory.write_u8(InputStackRemote+0x2, lastinput)
		--mark the latest input in the stack as unreceived. This will be undone when the corresponding input is received
		memory.write_u8(InputStackRemote+1,0x1)
		--	if an instance is behind, it will write timestamps for future frames. Then the entries with those timestamps
		--will remain intact even after it catches back up. So when the instance's timing is synced, it will also
		--need to clear out the future timestamps. I'm still looking for the best way to sync timing

		if type(c) == "table" and #c > 0 and type(c[1]) == "table" and #c[1] == 5 then


			while #c > 0 do --continue writing inputs until the backlog of received inputs is empty

				local pointer = 0
				local match = false
				local stacksize = memory.read_u8(InputStackSize)
	
				while match == false do
					if (c[1][2] % 256) == memory.read_u8(InputStackRemote + pointer*0x10) then
						match = true
					else
						pointer = pointer + 1
						if pointer > stacksize then pointer = 0 break end
					end
				end

				if match == true then
					--put logic here to check for a rollback guess
					memory.write_u32_le(InputStackRemote + pointer*0x10, c[1][2])
					table.remove(c,1)
				else
					local i = 0
					for i=0,(stacksize - 1) do
						table.insert(CycleInputStack, 1, memory.read_u32_le(InputStackRemote + i*0x10))
					end
					for i=0,(stacksize - 1) do
						memory.write_u32_le(InputStackRemote + (i+1)*0x10 ,CycleInputStack[#CycleInputStack])
						table.remove(CycleInputStack,#CycleInputStack)
					end
					memory.write_u32_le(InputStackRemote, c[1][2])
					table.remove(c,1)		
				end
			end
			
			local pointer = 0
			local stacksize = memory.read_u8(InputStackSize)

			while true do
				if memory.read_u8(InputStackRemote + 0x1 + pointer*0x10) == 0 then
					lastinput = memory.read_u8(InputStackRemote + 0x2 + pointer*0x10)
					break
				else
					pointer = pointer + 1
					if pointer > stacksize then 
						lastinput = 0
						break 
					end
				end
			end

		else
		--if no input was received this frame

		end
	end
end
event.onmemoryexecute(ApplyRemoteInputs,0x08008800,"ApplyRemoteInputs")

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
	while connectedclient == nil do
		if thisispvp == 1 then
			while server == nil do
				server, err = tcp:listen(1)
			end
			if server ~= nil then
				connectedclient = tcp:accept()
			end
		end
		emu.frameadvance()
	end
	print("You are the Server.")
-- Client
else
	local err = nil
	while connectedclient == nil do
		if thisispvp == 1 then
			connectedclient, err = tcp:connect(HOST_IP, HOST_PORT)
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
opponent:settimeout(0)--(1 / (16777216 / 280896))
if PLAYERNUM == 1 then
	ip, port = connectedclient:getpeername()
	connectedclient:close()
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
if connectedclient then
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
				
				--	coroutine.yield()
				
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
				if data == "loadround" and #t == 9 then -- Player Load Round Timer
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
			if timedout >= memory.read_u8(InputBufferRemote) + saferollback then
			--	emu.yield()
				if timedout >= 60*5 then
				--	connected = nil
				--	acked = false
				--	break
				end
			end
			coroutine.yield()
		else
			coroutine.yield()
		end
	end
end)



-- Main Loop
while true do
	

	if CanWriteRemoteStats == true then
		if type(s) == "table" and #s == 18 then
			print("wrote stats")
			local i = 0
			for i=0x0,0x10 do
				memory.write_u32_le(PlayerDataRemote + i*0x4,s[#s-0x10+i]) -- Player Stats
				table.remove(s,#s-0x10+i)
			end
			CanWriteRemoteStats = false
		else
			print("not enough data to write stats")
		end
	end

	if CanWriteRemoteChips == true then
		if type(s) == "table" and #s == 18 then
			local i = 0
			for i=0x0,0x10 do
				memory.write_u32_le(PlayerDataRemote + i*0x4,s[#s-0x10+i]) -- Player Stats
				table.remove(s,#s-0x10+i)
			end
			CanWriteRemoteChips = false
			print("wrote chips")
		end
	end



	-- Weird Netcode Stuff
	if opponent ~= nil and connected and not(resimulating) then
	
		-- Send Data to Opponent
		opponent:send("ack")
		opponent:send("0,1,"..tostring(PLAYERNUM)) -- Player Number
		opponent:send("0,2,"..tostring(memory.read_u32_le(InputStackLocal))) -- Player Control Inputs
		opponent:send("0,3,"..tostring(memory.read_u8(SceneIndicator))) -- Battle Check
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

		opponent:send("2,6,"..tostring(memory.read_u16_le(PlayerHPLocal))) -- Player HP
		opponent:send("2,7,"..tostring(memory.read_u32_le(0x02009730))) -- RNG #1
		opponent:send("2,8,"..tostring(memory.read_u32_le(0x02009800))) -- RNG #2
		opponent:send("2,9,"..tostring(memory.read_u16_le(0x0203b380))) -- Battle Timestamp Value
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
		
	--rollback rountine
	if thisispvp == 1 then 
		if rollbackmode then
		
			--create savestates
			if not(resimulating) then
				table.insert(sav, 1, memorysavestate.savecorestate())
				--delete the oldest savestate after 20 frames
				if #sav > savcount then
					memorysavestate.removestate(sav[#sav])
					table.remove(sav,#sav)
				end
			end

			--check if we need to roll back
			local rollbackframes = memory.read_u8(rollbackflag)
				if rollbackframes > savcount-1 then
					rollbackframes = savcount-1
				end

			if rollbackframes > 0 then

				--runs once when rollback begins, but not on subsequent rollback frames
				if not(resimulating) then
					resimulating = 1
					--save the corrected input stack
					local stacksize = memory.read_u8(InputStackSize)
					local i = 0
					for i=0,(stacksize*2) do
						table.insert(FullInputStack, 1, memory.read_u32_le(InputStackLocal + i*0x8))
					end

					memorysavestate.loadcorestate(sav[rollbackframes])

					for i=0,(stacksize*2) do
						memory.write_u32_le(InputStackLocal + i*0x8,FullInputStack[#FullInputStack])
						table.remove(FullInputStack,#FullInputStack)
					end


					if HideResim then
						client.invisibleemulation(true)
						emu.limitframerate(false)
					end
				end

				--count down remaining rollback frames by 1
				rollbackframes = rollbackframes - 1
				memory.write_u8(rollbackflag,rollbackframes)

				--if it's the final rollback frame, queue it up to display the next frame
				if rollbackframes == 0 then
					client.invisibleemulation(false)
				end

			else
				--default branch when not in a rollback frame
				if resimulating then
					--restore normal speed if just now exiting out of rollback
					resimulating = nil
					emu.limitframerate(true)
				end
			end
		end
	end

	emu.frameadvance()
end

thisispvp = 0
if opponent ~= nil then
	opponent:send("disconnect")
	opponent:close()
	opponent = nil
end
while #sav > 0 do
	memorysavestate.removestate(sav[#sav])
	table.remove(sav,#sav)
end
event.unregisterbyname("CustSync")
event.unregisterbyname("DelayBattle")
event.unregisterbyname("LoadBattle")
event.unregisterbyname("SendHand")
event.unregisterbyname("ApplyRemoteInputs")
event.unregisterbyname("CloseBattle")
event.unregisterbyname("SetPlayerPorts")
return