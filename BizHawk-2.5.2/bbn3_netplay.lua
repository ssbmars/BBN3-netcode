socket = require("socket.core")

--define variables that we might adjust sometimes
	
	BufferVal = 1		--input lag value in frames
	debugmessages = 0	--toggle whether to print debug messages
	rollbackmode = 1	--toggle this between 1 and nil
	saferollback = 6
	delaybattletimer = 10
	savcount = 30	--amount of savestate frames to keep
	client.displaymessages(false)
	emu.minimizeframeskip(true)
	client.frameskip(9)
	HideResim = 0
	TargetFrame = 167.427063 --166.67


--set empty variables at script start
	
	rollbackframes = 0
	resimulating = nil
	emu.limitframerate(true)
	framethrottle = true
	
	PLAYERNUM = 0
	PORTNUM = nil
	HOST_IP = "127.0.0.1"
	HOST_PORT = 5738
	tcp = nil
	connected = nil
	connectedclient = nil
	frametable = {}
	t = {}
	c = {}
	ctrl = {}
	l = {}
	s = {}
	data = nil
	err = nil
	part = nil
	opponent = nil
	acked = nil
	CanWriteRemoteStats = false
	CanWriteRemoteChips = false
	thisispvp = 0
	waitingforpvp = 0
	waitingforround = 0
	timedout = 0
	lastinput = 0
	sav = {}  --savestate ID table
	FullInputStack = {}  --input stack for rollback frames
	CycleInputStack = {} --input stack when the input handler cycles it down to make more room


--define RAM offset variables
	
	InputData = 0x0203B400
	InputStackSize = InputData + 0x5
	rollbackflag = InputData + 0x6
	SceneIndicator = 0x020097F8
	StartBattleFlipped = 0x0203B362

	PreloadStats = 0x0200F330
		PLS_Style = PreloadStats + 0x4
		PLS_HP = PreloadStats + 0x8
	
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


--define variables for gui.draw
	
	x_center = 120 
	y_center = 80
	--things get drawn at the base GBA resolution and then scaled up, so calculations are based on 1x GBA res




menu = nil
local delaymenu = 20
while delaymenu > 0 do
	delaymenu = delaymenu - 1
	emu.frameadvance()
end


menu = forms.newform(300,140,"BBN3 Netplay",function()
	return nil end)
local windowsize = client.getwindowsize()
local form_xpos = (client.xpos() + 120*windowsize - 142)
local form_ypos = (client.ypos() + 80*windowsize + 10)
forms.setlocation(menu, form_xpos , form_ypos)
label_ip = forms.label(menu,"IP:",8,0,32,24)
port_ip = forms.label(menu,"Port:",8,30,32,24)
textbox_ip = forms.textbox(menu,"127.0.0.1",240,24,nil,40,0)
textbox_port = forms.textbox(menu,"5738",240,24,nil,40,30)
button_host = forms.button(menu,"Host",function()
	PLAYERNUM = 1
	if forms.gettext(textbox_ip) == "127.0.0.1" or forms.gettext(textbox_ip) == "localhost" then
		HOST_IP = "0.0.0.0"
	else
		HOST_IP = forms.gettext(textbox_ip)
	end
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


--define controller ports and offsets for individual players
	
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
			if string.match(data, "get") == "get" then -- Received Ack
				local frame = string.match(data, "(%d+)")
				frametable[frame][1] = nil
				frametable[frame][2] = nil
				frametable[frame][3] = nil
				frametable[frame] = nil
				timedout = 0
			elseif string.match(data, "ack") == "ack" then -- Getting Ack
				acked = string.match(data, "(%d+)")
				opponent:send("get,"..string.match(data, "(%d+)")) -- Acked Frame
				timedout = 0
			end
			if data == "end" then -- End of Data Stream
				data = nil
				err = nil
				part = nil
				acked = nil
				--coroutine.yield()	
			elseif data == "disconnect" then -- Disconnecting
				connected = nil
				acked = nil
				break
			else
				if data == "control" and #ctrl == 5 then -- Player Control Information
					c[#c+1] = ctrl
					ctrl = {}
				end
				if data == "stats" and #t == 19 then -- Player Stats
					s = t
					t = {}
				end
				if data == "loadround" and #t == 9 then -- Player Load Round Timer
					l = t
					t = {}
				end
				local str = {}
				local w = ""
				for w in string.gmatch(data, "(%d+)") do
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
		elseif err == "timeout" then -- Timed Out
			data = nil
			err = nil
			part = nil
			acked = nil
			timedout = timedout + 1
			if timedout >= memory.read_u8(InputBufferRemote) + saferollback then
			--	emu.yield()
				if timedout >= 60*5 then
				--	connected = nil
				--	acked = nil
				--	break
				end
			end
			coroutine.yield()
		else
			coroutine.yield()
		end
	end
end)



local function debug(message)
	if debugmessages == 1 then
		print(message)
	end
end


local function Init_Battle_Vis()


	local style = {}
	local function def_styles(...)
		for pos, val in pairs({...}) do
			style[pos] = val
		end
	end
	def_styles("Normal","Guts","Custom","Team","Shield","Ground","Shadow","Bug")

	local elem = {}
	local function def_elems(...)
		for pos, val in pairs({...}) do
			elem[pos] = val
		end
	end
	def_elems("Null","Elec","Heat","Aqua","Wood")

	--define for local player
	local stylebyte = memory.read_u8(PLS_Style)
	vis_style_L = style[1+(bit.band(stylebyte, 0x38)/8)]
	vis_elem_L = elem[1+bit.band(stylebyte, 0x7)]

	--define for remote player
	local stylebyte = math.floor(s[4] % 256)
	vis_style_R1 = style[1+(bit.band(stylebyte, 0x38)/8)]
	vis_elem_R1 = elem[1+bit.band(stylebyte, 0x7)]


	--decide how much to offset the wait time, to sync up battle start times
	--print(s[2] .." .. "..(math.floor((socket.gettime()*10000) % 0x10000)))

	local localsent = TimeStatsWereSent
	local remotesent = s[2] 
	local receivedremote = math.floor((socket.gettime()*10000) % 0x10000)
	
	--math.floor( / 167.427063)

	debug(localsent .." - ".. remotesent .." .. ".. receivedremote)

	
	if localsent < remotesent then
		--if you sent it first
		sleeptimeoffset = (receivedremote - localsent) / 10
	else
		--if you sent it second
		sleeptimeoffset = (receivedremote - remotesent) / 10
	end
	sleeptime = 1500 - sleeptimeoffset --measured in milliseconds

	vis_looptimes = 60


end


local function Battle_Vis()

	--left megaman
	gui.drawText(100, 60, vis_elem_L..vis_style_L, "white", nil, nil, nil, "right","middle")

	--right megaman
	gui.drawText(140, 60, vis_elem_R1..vis_style_R1, "white", nil, nil, nil, "left","middle")

	gui.drawText(120, 80, "VS", "white", nil, nil, nil, "center","middle")
end


local function FrameStart()
	if thisispvp == 1 then
		if connected then 
			if coroutine.status(co) == "suspended" then coroutine.resume(co) end
		end

		--compensate for local frame stuttering by temporarily speeding up
		--make sure this also can compensate for the time spent on rollbacks
		if resimulating then return end

		sockettime = math.floor((socket.gettime()*10000) % 0x10000)
		if prevsockettime then 
			timepast = math.floor((sockettime - prevsockettime) % 0x10000)
			timerift = timerift + timepast - TargetFrame
			gui.drawText(1, 14, math.floor(timerift), "white")
			if timerift > TargetFrame then 
				--speed up if the timerift has surpassed 1 frame worth of ms
				if framethrottle == true then 
					emu.limitframerate(false) 
					framethrottle = false
					gui.drawText(1, 23, "FAST", "white")
				end
			elseif timerift < -20 then
					client.sleep(math.abs(timerift)/5)
			else
				if framethrottle == false then
					emu.limitframerate(true)
					framethrottle = true
				end
			end
		end
		prevsockettime = sockettime
	end
end
event.onframestart(FrameStart,"FrameStart")

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
						debug("wrote the thing")
					end
				else
					debug("nada")
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
			debug("sent hand")
			
			local frametime = math.floor((socket.gettime()*10000) % 0x10000) -- Ack Time
			if type(frametable[tostring(frametime)]) == "nil" then
				frametable[tostring(frametime)] = {{},{},{}}
			end
			frametable[tostring(frametime)][2][1] = tostring(PLAYERNUM)
			frametable[tostring(frametime)][2][2] = tostring(TimeStatsWereSent)
			local i = 0
			for i=0,0x10 do
				frametable[tostring(frametime)][2][i+3] = tostring(memory.read_u32_le(PreloadStats + i*0x4)) -- Player Stats
			end
			opponent:send("ack,"..tostring(frametime)) -- Ack Time
			
			opponent:send("1,1,"..frametable[tostring(frametime)][2][1])
			opponent:send("1,2,"..frametable[tostring(frametime)][2][2])
			for i=0,0x10 do
				opponent:send("1,"..tostring(i+3)..","..frametable[tostring(frametime)][2][i+3])
			end
			opponent:send("stats")
			
			--[[
			if acked and type(frametable[acked]) == "table" then
				opponent:send("1,1,"..frametable[acked][2][1])
				opponent:send("1,2,"..frametable[acked][2][2]) -- Socket Time
				for i=0,0x10 do
					opponent:send("1,"..tostring(i+3)..","..frametable[acked][2][i+3]) -- Player Stats
				end
				opponent:send("stats")
				acked = nil
			end
			]]
			CanWriteRemoteChips = true
			return
		end

		--this is the signal that it's safe to write the received player stats to ram
		--it only triggers once, at the start of the match before players have loaded in
		if emu.getregister("R1") == 0x02036940 and emu.getregister("R3") == 0x4C and WriteType == 0x1 then

			CanWriteRemoteStats = true


		end
	end
end
event.onmemoryexecute(sendhand,0x08008B56,"SendHand")


-- Sync Data on Match Load
local function SendStats()
	if thisispvp == 1 then
		if opponent == nil then debug("nopponent") return end
		
		local frametime = math.floor((socket.gettime()*10000) % 0x10000)
		TimeStatsWereSent = frametime --we're saving this for later
		if type(frametable[tostring(frametime)]) == "nil" then
			frametable[tostring(frametime)] = {{},{},{}}
		end
		frametable[tostring(frametime)][2][1] = tostring(PLAYERNUM)
		frametable[tostring(frametime)][2][2] = tostring(TimeStatsWereSent)
		local i = 0
		for i=0,0x10 do
			frametable[tostring(frametime)][2][i+3] = tostring(memory.read_u32_le(PreloadStats + i*0x4)) -- Player Stats
		end
		opponent:send("ack,"..tostring(frametime)) -- Ack Time
		
		opponent:send("1,1,"..frametable[tostring(frametime)][2][1])
		opponent:send("1,2,"..frametable[tostring(frametime)][2][2])
		for i=0,0x10 do
			opponent:send("1,"..tostring(i+3)..","..frametable[tostring(frametime)][2][i+3])
		end
		opponent:send("stats")
		
		--[[
		if acked ~= nil and type(frametable[acked]) == "table" then
			opponent:send("1,1,"..frametable[acked][2][1])
			opponent:send("1,2,"..frametable[acked][2][2]) -- Socket Time
			for i=0,0x10 do
				opponent:send("1,"..tostring(i+3)..","..frametable[acked][2][i+3]) -- Player Stats
			end
			opponent:send("stats")
			acked = nil
		end
		]]
		debug("sending stats before initializing battle")
		StallingBattle = true
		received_stats = false
		memory.write_u8(0x0200F320, 0x1) -- 0x1
	else
		memory.write_u8(0x0200F320, 0x0)
	end
end
event.onmemoryexecute(SendStats,0x0800761A,"SendStats")

local function delaybattlestart()
	if memory.readbyte(0x0200188F) == 0x0B then
		thisispvp = 1
		prevsockettime = nil
		timerift = 0

		if #c == 0 then
			memory.writebyte(SceneIndicator,0x4)
			waitingforpvp = 1
			gui.drawText(20, y_center - 20, "search routine", "white", nil, nil, nil, nil,"middle")
			gui.drawText(20, y_center + 0, "find: [ Netbattler ]", "white", nil, nil, nil, nil,"middle")
		else
			if waitingforpvp == 1 then
				waitingforpvp = 0
				delaybattletimer = 10
				if type(l) == "table" and #l > 0 then
					if PLAYERNUM == 2 then
					--	memory.write_u32_le(0x02009730, l[7])
						memory.write_u32_le(0x02009800, l[8])
					end
				end
			end
			if waitingforpvp == 0 and c[1][4] == 0 and delaybattletimer > 0 then
				delaybattletimer = delaybattletimer - 1
				memory.writebyte(SceneIndicator,0x4)
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
	if thisispvp == 1 then
		if coroutine.status(co) == "suspended" then coroutine.resume(co) end
	if not(resimulating) then


		--write the last received input to the latest entry, This will be undone when the corresponding input is received
		memory.write_u8(InputStackRemote+0x2, lastinput)
		--mark the latest input in the stack as unreceived. This will be undone when the corresponding input is received
		memory.write_u8(InputStackRemote+1,0x1)

		--iterate the latest input's timestamp by 1 frame (it's necessary to do this first for this new routine)
		previoustimestamp = memory.read_u8(InputStackRemote)
		newtimestamp = math.floor((previoustimestamp + 0x1)%256)
		localtimestamp = memory.read_u8(0x0203b380)

		--avoid iterating the remote timestamp if it would make it greater than the local timestamp
		local tsdif = newtimestamp - localtimestamp
		if tsdif > 0 then
		else
			memory.write_u8(InputStackRemote, newtimestamp) --update timestamp on remote stack for this latest frame
		end


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
					--rollback logic
					--returns true if it's about to write to an input slot that was already executed
					local iStatus = bit.check(memory.read_u8(InputStackRemote + 0x1 + pointer*0x10),1)
					if iStatus == true then
					--check whether the guessed input was correct
						--record the guessed input before overwriting
						local iGuess = memory.read_u16_le(InputStackRemote + 0x2 + pointer*0x10)
						--write the received input (halfword)
						memory.write_u32_le(InputStackRemote + pointer*0x10, c[1][2])
						--load the received input (halfword) into a variable for comparison
						iCorrected = memory.read_u16_le(InputStackRemote + 0x2 + pointer*0x10)
						--compare both inputs, set the rollback flag if they don't match
						if iGuess ~= iCorrected then
							rbAmount =  math.floor(localtimestamp - (c[1][2] % 256) %256)
							--this will use the pointer to decide how many frames back to jump
							--it can rewrite the flag many times in a frame, but it will keep the largest value for that frame
							if memory.read_u8(rollbackflag) < rbAmount then
								memory.write_u8(rollbackflag, rbAmount)
							end
						end
						table.remove(c,1)
					else
					--runs when the input was received on time
						memory.write_u32_le(InputStackRemote + pointer*0x10, c[1][2])
						table.remove(c,1)
					end
				else
					local i = 0
					for i=0,(stacksize - 1) do
						table.insert(CycleInputStack, 1, memory.read_u32_le(InputStackRemote + i*0x10))
					end
					local i = 0
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
end
event.onmemoryexecute(ApplyRemoteInputs,0x08008800,"ApplyRemoteInputs")

local function closebattle()
	if opponent ~= nil then
		opponent:close()
		opponent = nil
		connected = nil
	end
	while #sav > 0 do
		memorysavestate.removestate(sav[#sav])
		table.remove(sav,#sav)
	end
end
event.onmemoryexecute(closebattle,0x08006958,"CloseBattle")

-- Check if either Host or Client
tcp = socket.tcp()
local ip, dnsdata = socket.dns.toip(HOST_IP)
HOST_IP = ip
-- Host
tcp:settimeout(0.5 / (16777216 / 280896),'b')
if PLAYERNUM == 1 then
	tcp:bind(HOST_IP, HOST_PORT)
	local server, err = nil, nil
	while connectedclient == nil do
		while server == nil do
			server, err = tcp:listen(1)
		end
		if server ~= nil then
			connectedclient = tcp:accept()
		end
		emu.frameadvance()
	end
	debug("You are the Server.")
-- Client
else
	local err
	while connectedclient == nil do
		err = nil	
		connectedclient, err = tcp:connect(HOST_IP, HOST_PORT)
		if connectedclient and not err then
			emu.frameadvance()
		end
	end
	debug("You are the Client.")
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
	debug("Connected!")
end




-- Main Loop
while true do
	

	if StallingBattle == true then

		if connected then 
			if coroutine.status(co) == "suspended" then coroutine.resume(co) end
		end

		if received_stats == true then
			if vis_looptimes > 0 then
				vis_looptimes = vis_looptimes - 1
				Battle_Vis()
			else
				StallingBattle = false
				memory.write_u8(0x0200F320, 0x0)
				client.exactsleep(sleeptime)
				prevsockettime = nil
			end
		else
			if type(s) == "table" and #s == 19 then
				Init_Battle_Vis()
				received_stats = true
			end
		end
	end


	if CanWriteRemoteStats == true then
		if type(s) == "table" and #s == 19 then
			debug("wrote remote stats")
			local i = 0
			for i=0x0,0x10 do
				memory.write_u32_le(PlayerDataRemote + i*0x4,s[#s-0x10+i]) -- Player Stats
				table.remove(s,#s-0x10+i)
			end
			CanWriteRemoteStats = false
		else
			debug("not enough data to write stats")
		end
	end

	if CanWriteRemoteChips == true then
		if type(s) == "table" and #s == 19 then
			local i = 0
			for i=0x0,0x10 do
				memory.write_u32_le(PlayerDataRemote + i*0x4,s[#s-0x10+i]) -- Player Stats
				table.remove(s,#s-0x10+i)
			end
			CanWriteRemoteChips = false
			debug("wrote remote chips")
		end
	end



	-- Weird Netcode Stuff
	if opponent ~= nil and connected and not(resimulating) then
		
		-- Sort and clean Frame Table's earliest frames
		while #frametable >= savcount do
			for k,v in pairs(frametable) do
				frametable[k][1] = nil
				frametable[k][2] = nil
				frametable[k][3] = nil
				frametable[k] = nil
				debug("Removing #"..k.." from frametable.")
				break
			end
		end
		
		-- Write new data to Frame Table
		local frametime = math.floor((socket.gettime()*10000) % 0x10000)
		if type(frametable[tostring(frametime)]) == "nil" then
			frametable[tostring(frametime)] = {{},{},{}}
		end
		frametable[tostring(frametime)][1][1] = tostring(PLAYERNUM)
		frametable[tostring(frametime)][1][2] = tostring(memory.read_u32_le(InputStackLocal))
		frametable[tostring(frametime)][1][3] = tostring(memory.read_u8(SceneIndicator))
		frametable[tostring(frametime)][1][4] = tostring(waitingforpvp)
		frametable[tostring(frametime)][1][5] = tostring(frametime)
		
		frametable[tostring(frametime)][3][1] = tostring(PLAYERNUM)
		frametable[tostring(frametime)][3][2] = tostring(memory.read_u8(0x2036830))
		frametable[tostring(frametime)][3][3] = tostring(memory.read_u8(InputBufferLocal))
		if type(l) == "table" and type(l[4]) == "number" and waitingforround == 1 and l[5] == 1 then
			l[4] = l[4]-1
			frametable[tostring(frametime)][3][4] = tostring(l[4])
		elseif type(l) == "table" and type(l[4]) == "number" and (waitingforround == 1 or l[5] == 1) then
			frametable[tostring(frametime)][3][4] = tostring(l[4])
		else
			frametable[tostring(frametime)][3][4] = tostring(0x3C)
		end
		frametable[tostring(frametime)][3][5] = tostring(waitingforround)
		frametable[tostring(frametime)][3][6] = tostring(memory.read_u16_le(PlayerHPLocal))
		frametable[tostring(frametime)][3][7] = tostring(memory.read_u32_le(0x02009730))
		frametable[tostring(frametime)][3][8] = tostring(memory.read_u32_le(0x02009800))
		frametable[tostring(frametime)][3][9] = tostring(memory.read_u16_le(0x0203b380))
	
		-- Send Ack to Opponent
		opponent:send("ack,"..tostring(frametime)) -- Ack Time
		-- Send Frame Table to Opponent
		opponent:send("0,1,"..frametable[tostring(frametime)][1][1])
		opponent:send("0,2,"..frametable[tostring(frametime)][1][2])
		opponent:send("0,3,"..frametable[tostring(frametime)][1][3])
		opponent:send("0,4,"..frametable[tostring(frametime)][1][4])
		opponent:send("0,5,"..frametable[tostring(frametime)][1][5])
		opponent:send("control")
		opponent:send("2,1,"..frametable[tostring(frametime)][3][1])
		opponent:send("2,2,"..frametable[tostring(frametime)][3][2])
		opponent:send("2,3,"..frametable[tostring(frametime)][3][3])
		opponent:send("2,4,"..frametable[tostring(frametime)][3][4])
		opponent:send("2,5,"..frametable[tostring(frametime)][3][5])
		opponent:send("2,6,"..frametable[tostring(frametime)][3][6])
		opponent:send("2,7,"..frametable[tostring(frametime)][3][7])
		opponent:send("2,8,"..frametable[tostring(frametime)][3][8])
		opponent:send("2,9,"..frametable[tostring(frametime)][3][9])
		opponent:send("loadround")
		opponent:send("end")
		
		--[[
		opponent:send("0,1,"..tostring(PLAYERNUM)) -- Player Number
		opponent:send("0,2,"..tostring(memory.read_u32_le(InputStackLocal))) -- Player Control Inputs
		opponent:send("0,3,"..tostring(memory.read_u8(SceneIndicator))) -- Battle Check
		opponent:send("0,4,"..tostring(waitingforpvp)) -- Waiting for PVP Value
		opponent:send("0,5,"..tostring(math.floor((socket.gettime()*10000) % 0x10000))) -- Socket Time
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
		--]]
		
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
		

			--check if we need to roll back
		local rollbackframes = memory.read_u8(rollbackflag)
		if rollbackframes > #sav then
			rollbackframes = #sav
		end

		if rollbackframes > 0 then

			--runs once when rollback begins, but not on subsequent rollback frames
			if not(resimulating) then
				resimulating = true
				--save the corrected input stack
				local stacksize = memory.read_u8(InputStackSize)
				local i = 0
				for i=0,(stacksize*4) do
					table.insert(FullInputStack, 1, memory.read_u32_le(InputStackLocal + i*0x4))
				end

				memorysavestate.loadcorestate(sav[rollbackframes])

				local i = 0
				for i=0,(stacksize*4) do
					memory.write_u32_le(InputStackLocal + i*0x4,FullInputStack[#FullInputStack])
					table.remove(FullInputStack,#FullInputStack)
				end

				emu.limitframerate(false)
				framethrottle = false
			--	prevsockettime = math.floor((socket.gettime()*10000) % 0x10000) --make sure it can compensate for the time spent resimulating
				if HideResim then
					client.invisibleemulation(true)
				end
			end

			--count down remaining rollback frames by 1
			rollbackframes = rollbackframes - 1
			memory.write_u8(rollbackflag,rollbackframes)
			gui.drawText(1, 23, "     ".. rollbackframes, "white")

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
				framethrottle = true
			end
		end

		--create savestates
		if not(resimulating) then
			table.insert(sav, 1, memorysavestate.savecorestate())
			--delete the oldest savestate after 20 frames
			if #sav > savcount then
				memorysavestate.removestate(sav[#sav])
				table.remove(sav,#sav)
			end
		end
	end

--	if thisispvp == 1 and timerift < -60 and not(resimulating) and framethrottle == true then
	--	local endingtime = math.floor((socket.gettime()*10000) % 0x10000)
	--	local timedif = math.floor((endingtime - sockettime) % 0x10000)
	--	local adjtimerift = math.abs(timerift) - timedif

	--	if adjtimerift > 0 then
	--		local slpamount = math.floor(adjtimerift / 10)
	--		gui.drawText(1, 34, slpamount, "white")
	--		client.sleep(slpamount)
	--		local eeee = math.abs(timerift) - adjtimerift
	--		gui.drawText(50, 13, eeee, "white")
	--	end
--	end

	emu.frameadvance()
end

thisispvp = 0
if opponent ~= nil then
	opponent:send("disconnect")
	opponent:close()
	opponent = nil
end
event.unregisterbyname("FrameStart")
event.unregisterbyname("CustSync")
event.unregisterbyname("DelayBattle")
event.unregisterbyname("SendStats")
event.unregisterbyname("SendHand")
event.unregisterbyname("ApplyRemoteInputs")
event.unregisterbyname("CloseBattle")
event.unregisterbyname("SetPlayerPorts")
return