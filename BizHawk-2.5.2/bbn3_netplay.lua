socket = require("socket.core")

local function isIP(ip) 
	local function GetIPType(ip)
		local IPType = {
			[0] = "Error",
			[1] = "IPv4",
			[2] = "IPv6",
			[3] = "string",
		}
	
		-- must pass in a string value
		if ip == nil or type(ip) ~= "string" then
			return IPType[0]
		end
	
		-- check for format 1.11.111.111 for ipv4
		local chunks = {ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
		if (#chunks == 4) then
			for _,v in pairs(chunks) do
				if (tonumber(v) < 0 or tonumber(v) > 255) then
					return IPType[0]
				end
			end
			return IPType[1]
		else
			return IPType[0]
		end
	
		-- check for ipv6 format, should be 8 'chunks' of numbers/letters
		local _, chunks = ip:gsub("[%a%d]+%:?", "")
		if chunks == 8 then
			return IPType[2]
		end
	
		-- if we get here, assume we've been given a random string
		return IPType[3]
	end

	local type = GetIPType(ip)
	return ip == "localhost" or type == "IPv4" or type == "IPv6"
end

local function preconnect()
	-- Check if either Host or Client
	tcp = socket.tcp()
	local ip, dnsdata = socket.dns.toip(HOST_IP)
	HOST_IP = ip

	--tcp:settimeout(1/30,'b')
	tcp:settimeout(1 / (16777216 / 280896),'b')


	--define controller ports and offsets for individual players
	PORTNUM = PLAYERNUM - 1
	InputBufferLocal = InputData + PLAYERNUM
	InputStackLocal = InputData + 0x10 + (PORTNUM*0x4)
	PlayerHPLocal = BDA_HP + (BDA_s * PORTNUM)
	PlayerDataLocal = PlayerData + (PD_s * PORTNUM)
	
	--this math only works for 1v1s
	InputStackRemote =  InputData + 0x10 + (0x4*bit.bxor(1, PORTNUM))
	InputBufferRemote = InputData + 0x1 + bit.bxor(1, PORTNUM)
	PlayerHPRemote = BDA_HP + (BDA_s * bit.bxor(1, PORTNUM))
	PlayerDataRemote = PlayerData + (PD_s * bit.bxor(1, PORTNUM))
	--this is fine for now. To support more than 2 players it will need to define these after everyone has connected, 
	--and up to 3 sets of "Remote" addresses will need to exist. But this won't matter any time soon.
end

local function defineopponent()
	-- Set who your Opponent is
	opponent = socket.udp()
	opponent:settimeout(0)--(1 / (16777216 / 280896))
end


local function gui_src()
	VSimgo = "gui_Sprites\\vs_text.png"
	VSimgt = "gui_Sprites\\vs_text_t.png"
	bigpet = "gui_Sprites\\PET_big.png"
	smallpet = "gui_Sprites\\PET_small_blue.png"
	smallpet_bright = "gui_Sprites\\PET_small_bright.png"

	signal_anim = "gui_Sprites\\search_signal_blue.png"
		dur_max_signal = 4
		cnt_max_signal = 6
		dur_signal = 0
		cnt_signal = 0
		xreg_signal = 24
		yreg_signal = 16


	style_h = 40
	style_w = 130
	motion_b = "gui_Sprites\\motion_bg_blue.png"
	motion_p = "gui_Sprites\\motion_bg_pink.png"
		motion_bg_w = 256
	f1_motion_b = "gui_Sprites\\f1_motion_bg_blue.png"
	f1_motion_p = "gui_Sprites\\f1_motion_bg_pink.png"

	f2_motion_b = "gui_Sprites\\f2_motion_bg_blue.png"
	f2_motion_p = "gui_Sprites\\f2_motion_bg_pink.png"

	f3_motion_b = "gui_Sprites\\f3_motion_bg_blue.png"
	f3_motion_p = "gui_Sprites\\f3_motion_bg_pink.png"

end


local function cleanstate()
	--define variables that we might adjust sometimes
	
	BufferVal = 5		--input lag value in frames
	debugmessages = 1	--toggle whether to print debug messages
	rollbackmode = 1	--toggle this between 1 and nil
	saferollback = 6
	delaybattletimer = 20
	savcount = 30	--amount of savestate frames to keep
	client.displaymessages(false)
	emu.minimizeframeskip(true)
	client.frameskip(0)
	HideResim = 1
	TargetFrame = 167.427063 --166.67
	TargetSpeed = 100
	client.speedmode(TargetSpeed)
	
	--set variables at script start
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
	h = {}
	s = {}
	wt = {}
	wt2 = {}
	data = nil
	err = nil
	part = nil
	opponent = nil
	acked = nil
	CanWriteRemoteStats = nil
	CanWriteRemoteChips = nil
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
	EndBattleEarly = 0x0203B365

	PreloadStats = 0x0200F330
	PLS_Style = PreloadStats + 0x4
	PLS_HP = PreloadStats + 0x8
	
	PlayerData = 0x02036840
	PD_s = 0x110 --PlayerData size
	
	BattleData_A = 0x02037274
	BDA_s = 0xD4 --BattleData_A size
	BDA_HP = 0x20 + BattleData_A --address for active HP value
	BDA_HandSize = 0x16 + BattleData_A 

	--the rest of these pointers aren't meant for anything currently
	BDA_Act_State = 0x1 + BattleData_A 

	-- 7 = idle, 4 = movement, 3 & 1 = buster endlag, 0 = chip/attack
	BDA_Act_Main = 0x2 + BattleData_A 
	
	-- holds the value of the type of attack being used (ie almost all swords have the val of 0x8)
	BDA_Act_Sub = 0x5D + BattleData_A 

	-- defines the specific sub attack (if main = 0x8, then sub = 0x3 would be firesword, or 0x9 for Muramasa)
	BattleData_B = 0x020384D0
	BDB_s = 0x88 --BattleData_B size
	
	--define variables for gui.draw
	x_center = 120 
	y_center = 80
	scene_anim = nil
	gui_src()

	--things get drawn at the base GBA resolution and then scaled up, so calculations are based on 1x GBA res
	menu = nil
end

cleanstate()


--gui_animate(120, 80, signal_anim, xreg_signal, yreg_signal, dur_max_signal, cnt_max_signal, dur_signal, cnt_signal)
local function gui_animate(xpos, ypos, img, xreg, yreg, dur_max, cnt_max, dur, cnt)
	--dur = duration of the frame, max defines how long to hold each frame for
	--cnt = the frame that's currently being shown, max defines how many total frames exist
	--region = the size in pixels of each frame

	gui.drawImageRegion(img, xreg * cnt, 0, xreg, yreg, xpos, ypos)

	if dur == dur_max then
		dur = 0
		if cnt == cnt_max then
			cnt = 0
		else
			cnt = cnt + 1
		end
	else
		dur = dur + 1
	end
	return dur, cnt
end

local delaymenu = 20
while delaymenu > 0 do
	delaymenu = delaymenu - 1
	emu.frameadvance()
end

local function connectionform()
	menu = forms.newform(300,140,"BBN3 Netplay",function() return nil end)
	local windowsize = client.getwindowsize()
	local form_xpos = (client.xpos() + 120*windowsize - 142)
	local form_ypos = (client.ypos() + 80*windowsize + 10)
	forms.setlocation(menu, form_xpos, form_ypos)
	label_ip = forms.label(menu,"IP:",8,0,32,24)
	port_ip = forms.label(menu,"Port:",8,30,32,24)
	textbox_ip = forms.textbox(menu,"127.0.0.1",240,24,nil,40,0)
	textbox_port = forms.textbox(menu,"5738",240,24,nil,40,30)

	local function makeCallback(playernum, is_host)
		return function()
			PLAYERNUM = playernum
			local input = forms.gettext(textbox_ip)

			if isIP(input) then
				if is_host and (input == "127.0.0.1" or input == "localhost") then
					HOST_IP = "0.0.0.0"
				else
					HOST_IP = input
				end
				HOST_PORT = tonumber(forms.gettext(textbox_port))
				forms.destroyall()
				preconnect()
			else 
				forms.settext(textbox_ip, "Bad IP")
			end
		end
	end

	button_host = forms.button(menu,"Host", makeCallback(1, true), 80,60,48,24)
	button_join = forms.button(menu,"Join", makeCallback(2, false), 160,60,48,24)
end

connectionform()

while PLAYERNUM < 1 do
	emu.frameadvance()
end



local function receivepackets()
	-- Loop for Received data
	--t = {}
	--ctrl = {}
	--data = nil
	--err = nil
	--part = nil
	while true do
		data,err,part = opponent:receive()
		-- Data will not be nil if a full data packet has been received.
		-- Otherwise an error and partial data is thrown.
		-- We're checking specifically for full packets, dropped or partial packets aren't good enough.
		if data ~= nil then

	--[[
			--messy debug check
			if not(thisco) then
				thisco = memory.read_u16_le(0x0203b380)
				cyclecount = 0
				x_shift = 0
			end
			if memory.read_u16_le(0x0203b380) ~= thisco then
				thisco = memory.read_u16_le(0x0203b380)
				cyclecount = 0
				x_shift = 0
			end
			if thisco > 100 then
				if not(cyclecount) then
					cyclecount = 0
				end
				gui.drawText(80+ 90*x_shift, 12*cyclecount, bizstring.hex(thisco) .." "..data,nil,"black")
				cyclecount = cyclecount + 1
				if cyclecount > 11 then
					x_shift = x_shift + 1
					cyclecount = 0
				end
			--print(this .."  "..data)
			end
			--end messy debug check
	]]

			-- A "Get" is received when you send an ack to your opponent(s) and they acknowledge that they received it.
			-- Once this has been received, clear out the correct slot in the local frame table so that we can free up some space.
			if string.match(data, "get") == "get" then
				local frame = string.match(data, "(%d+)")
				frametable[frame][1] = nil
				frametable[frame][2] = nil
				frametable[frame][3] = nil
				frametable[frame] = nil
				timedout = 0
			-- An incoming ack, sent before incoming data.
			-- Used to make sure each player's frame tables are in-sync.
			elseif string.match(data, "ack") == "ack" then
				acked = string.match(data, "(%d+)")
				opponent:send("get,"..string.match(data, "(%d+)"))
				timedout = 0
			end
			-- The End of the incoming data buffer.
			-- Just used to clear some variables and tell the user they're no longer being acked.
			if data == "end" then
				data = nil
				err = nil
				part = nil
				acked = nil
			-- If a player sends a disconnect packet, make sure to self-disconnect.
			-- Looks like you guys made it close the battle as well.
			elseif data == "disconnect" then
				connected = nil
				acked = nil
				closebattle()
				break
			else
				-- Save the buffered data to the Player Control Information.
				-- The Control Information includes things like gamestate and player inputs.
				-- Clears out the buffered control table afterward.
				if data == "c" and #ctrl == 3 then --"controls"
					c[#c+1] = ctrl
					ctrl = {}
				end
				if data == "w" and #t == 2 then --"wait for pvp"
					wt = t 
					t = {}
				end
				if data == "w2" and #t == 1 then --"wait for pvp"
					wt2 = t 
					t = {}
				end
				-- Save the buffered data to the Player Stats table.
				-- The Stats include things like the Player's NCP Setup, their HP, etc.
				-- Clears out the buffered data table afterward.
				if data == "s" and #t == 19 then --"stats"
					s = t
					t = {}
				end
				-- Save the buffered data to the Player's "Load Round" table.
				-- This table loads things like Custom Screen state, RNG values, The Pre-round Timer, Input Delay, etc.
				-- Again, clears out the buffered data table afterward.
				if data == "cs" and #t == 4 then --"custom screen"
					l = t
					t = {}
				end
				if data == "h" and #t == 4 then
					h = t
					t = {}
				end
				
				-- This for loop grabs numerical values from the received packet.
				local str = {}
				local w = ""
				for w in string.gmatch(data, "(%d+)") do
					str[#str+1] = w
				end
				
				-- This if statement block turns the numerical values grabbed from the above for loop
				-- and turns them into actual numbers. The packet requires strings, so we have to preconvert both ways.
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

		-- This is the only exit condition for yielding this routine. It will continue to run until a check returns no data.
		-- Counts the amount of contiguous checks that resulted in no received data, this is to detect unhandled disconnects.
		-- (Since this runs thrice per frame, the threshold for ending the match is 3x the amount of frames to wait.)
		-- Currently this timeout detection is only used for ending the match. We aren't set up to safely implement lockstep here (yet?)
		else --if err == "timeout" then -- Timed Out
			data = nil
			err = nil
			part = nil
			acked = nil
			timedout = timedout + 1
		--	gui.drawText(80, 120, "timeout")
			if timedout >= 3*(memory.read_u8(InputBufferRemote) + saferollback) then
				--	emu.yield()
				if timedout >= 60*7 then
					connected = nil
					acked = nil
					break
				end
			end
			coroutine.yield()
	--	else
	--		gui.drawText(100, 120, "nothin", "white")
	--		coroutine.yield()

		end
	end
end

co = coroutine.create(function() receivepackets() end)



local function debug(message)
	if debugmessages == 1 then
		print(message)
	end
end


local function Init_Battle_Vis()


	local style = 
		{[1] = "Normal", [2] = "Guts", [3] = "Custom", [4] = "Team", 
		 [5] = "Shield", [6] = "Ground", [7] = "Shadow", [8] = "Bug"}

	local elem = {[1] = "Nullelem", [2] = 0, [3] = 1, [4] = 2, [5] = 3}
	-- style order: Null, Elec, Heat, Aqua, Wood


	--define for local player
	local stylebyte = memory.read_u8(PLS_Style)
	vis_style_L = style[1+(bit.band(stylebyte, 0x38)/8)]
	vis_elem_L = elem[1+bit.band(stylebyte, 0x7)]

	--define for remote player
	local stylebyte = math.floor(s[4] % 256)
	vis_style_R1 = style[1+(bit.band(stylebyte, 0x38)/8)]
	vis_elem_R1 = elem[1+bit.band(stylebyte, 0x7)]

	--define the file string for each player's megaman style 
	p1_char = "gui_Sprites\\style_"..vis_style_L..".png"
	p2_char = "gui_Sprites\\style_"..vis_style_R1..".png"

	local function checkelem(style, elem)
		if elem == "Nullelem" then
			if style == "Normal" then
				elem = 0
				--NCP easter eggs here, but not yet cuz press is always installed
			else
				--the player is cheating if this returns true
			end
		elseif style == "Normal" then
			--this also means the player is cheating by having an elemental NormalStyle
			elem = 0
		end
		return elem 
	end

	vis_elem_L = checkelem(vis_style_L, vis_elem_L)
	vis_elem_R1 = checkelem(vis_style_R1, vis_elem_R1)


	vis_looptimes = 60
	vis_vs_zoom = {}
	local function def_vs_frame_zooms(...)
		for pos, val in pairs({...}) do
			vis_vs_zoom[pos] = val
		end
	end
	def_vs_frame_zooms(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 6, 5, 4, 3, 2, 1.3, 0.9, 0.8, 0.7, 0.7, 0.7, 0.8, 0.8, 0.9, 1, 0.9)
end


local function Battle_Vis()

	if not(scene_anim) then scene_anim = 1 end

	local movetext = 0

	local function bg_animation(scroll)
		--top backgrounds
		gui.drawImage(motion_b, -scroll, 30)
		gui.drawImage(motion_b, motion_bg_w -scroll, 30)

		--bottom backgrounds
		gui.drawImage(motion_p, scroll, 140 -style_h)
		gui.drawImage(motion_p, -motion_bg_w +scroll, 140 -style_h)
	end

	--start of time syncing code
		if not(SB_sent_packet) then
			SB_sent_packet = true

			local frametime = math.floor((socket.gettime()*10000) % 0x100000)
			frametable[tostring(frametime)] = {{},{},{}}
			frametable[tostring(frametime)][3][1] = tostring(PLAYERNUM)
			--send
			opponent:send("ack,"..tostring(frametime)) -- Ack Time
			opponent:send("2,1,"..frametable[tostring(frametime)][3][1])
			opponent:send("w2")
		end

		if not(SB_Received) and #wt2 == 1 then
			SB_Received = true
			wt2 = {}
			if PLAYERNUM == 1 then
				local waittime = 60		--in frames
				local frametime = math.floor((socket.gettime()*10000) % 0x100000)
				frametable[tostring(frametime)] = {{},{},{}}
				frametable[tostring(frametime)][3][1] = tostring(frametime)
				frametable[tostring(frametime)][3][2] = tostring(waittime)
				--send
				opponent:send("ack,"..tostring(frametime)) -- Ack Time
				opponent:send("2,1,"..frametable[tostring(frametime)][3][1])
				opponent:send("2,2,"..frametable[tostring(frametime)][3][2])
				opponent:send("w") --"wait for pvp"
				vis_looptimes = vis_looptimes + waittime
				SB_Received_2 = true
			end
		end

		if SB_Received and not(SB_Received_2) and #wt == 2 then
			SB_Received_2 = true
			--accommodate latency between the time packet was sent and received
			local currentFrameTime = math.floor((socket.gettime()*10000) % 0x100000)
			local FrameTimeDif = math.floor((currentFrameTime - wt[1]) % 0x100000)
			local WholeFrames = math.floor(FrameTimeDif/TargetFrame)
			local remainder = FrameTimeDif - (WholeFrames*TargetFrame)
			local adj_CntDn = wt[2] - WholeFrames
			--timerift = timerift + remainder

			--set the amount of frames to wait before beginning turn
			vis_looptimes = vis_looptimes + adj_CntDn
			--clean the table
			wt = {}
		end

		if not(SB_Received_2) then
			vis_looptimes = vis_looptimes + 1
		end
	--end of time syncing code


	if scene_anim > 9 then

		local scroll = scene_anim*5
		while scroll > motion_bg_w do
			scroll = scroll - motion_bg_w
		end

		local swooshin = (scene_anim - 10)*6
		if swooshin > style_w then
			swooshin = style_w
		end

		--exit animation
		local exit_time = 35
		if vis_looptimes < exit_time then
			swooshin = 240 + style_w
			if vis_looptimes > 8 then
				swooshin = style_w + (exit_time-vis_looptimes)*8
				bg_animation(scroll)
			elseif vis_looptimes > 5 then 

				gui.drawImage(f3_motion_b, 0, 30)
				gui.drawImage(f3_motion_p, 0, 140 -style_h)
			elseif vis_looptimes > 3 then
				gui.drawImage(f2_motion_b, 0, 30)
				gui.drawImage(f2_motion_p, 0, 140 -style_h)
			elseif vis_looptimes > 1 then
				gui.drawImage(f1_motion_b, 0, 30)
				gui.drawImage(f1_motion_p, 0, 140 -style_h)
			end
		else --normal loop
			bg_animation(scroll)
		end
	
		--both megamans
		gui.drawImageRegion(p1_char, 0, vis_elem_L*style_h, style_w, style_h, swooshin -style_w, 30)
		gui.drawImageRegion(p2_char, 0, vis_elem_R1*style_h, style_w, style_h, 240 + style_w -swooshin, 140 -style_h, -style_w)

	--intro animation
	elseif scene_anim < 3 then
		gui.drawImage(f1_motion_b, 0, 30)
		gui.drawImage(f1_motion_p, 0, 140 -style_h)
	elseif scene_anim < 6 then
		gui.drawImage(f2_motion_b, 0, 30)
		gui.drawImage(f2_motion_p, 0, 140 -style_h)
	else
		gui.drawImage(f3_motion_b, 0, 30)
		gui.drawImage(f3_motion_p, 0, 140 -style_h)
	end

	--if vis_looptimes < 8 then
	--	movetext = 8 - vis_looptimes
	--end

	--left megaman
	gui.drawText(5, 29 +style_h +movetext, "NetBattler1", "white", nil, nil, nil, "left","top")

	--right megaman
	gui.drawText(235, 140 -style_h -movetext, "NetBattler2", "white", nil, nil, nil, "right","bottom")


	--left megaman
	--gui.drawText(100, 60, vis_elem_L..vis_style_L, "white", nil, nil, nil, "right","middle")
	--right megaman
	--gui.drawText(140, 60, vis_elem_R1..vis_style_R1, "white", nil, nil, nil, "left","middle")


	--animate the VS image flying in
	local multiplier = 1
	if vis_vs_zoom[scene_anim] then 
		multiplier = vis_vs_zoom[scene_anim]
	end
	if vis_looptimes < 8 then
		multiplier = vis_looptimes /10
	end
	vs_xsize = 48 * multiplier
	vs_ysize = 24 * multiplier
	if multiplier < 4 then
		VSimg = VSimgo
	else
		VSimg = VSimgt
	end
	gui.drawImage(VSimg, 120 -vs_xsize/2, 85 -vs_ysize/2, vs_xsize, vs_ysize)


	scene_anim = scene_anim + 1
	return scene_anim
end



local function FrameStart()
	if thisispvp == 0 then return end 
	if connected then 
		if coroutine.status(co) == "suspended" then coroutine.resume(co) end
	end
	TimeToSlowDown = nil
	if resimulating then return end

	--compensate for local frame stuttering by temporarily speeding up
	--make sure this also can compensate for the time spent on rollbacks

	sockettime = math.floor((socket.gettime()*10000) % 0x100000)
	if not(prevsockettime) then
		 prevsockettime = sockettime
		return 
	end

	timepast = math.floor((sockettime - prevsockettime) % 0x100000)
	timerift = timerift + timepast - TargetFrame
	prevsockettime = sockettime
	local placeholderspot = " "
	if timerift < 0 then placeholderspot = "" end
	gui.drawText(1, 14, placeholderspot.. math.floor(timerift),nil,"black")

	if timerift > TargetFrame then 
		--speed up if the timerift has surpassed 1 frame worth of ms
		if framethrottle == true then 
			emu.limitframerate(false) 
			framethrottle = false
		end
	elseif timerift < -50 then
		TimeToSlowDown = true
		client.speedmode(75)
	else
		if framethrottle == false then
			emu.limitframerate(true)
			framethrottle = true
		end
		client.speedmode(TargetSpeed)
	end
end
event.onframestart(FrameStart,"FrameStart")

-- Sync Custom Screen
local function custsynchro()
	if thisispvp == 0 then return end

	reg3 = emu.getregister("R3")

	if reg3 == 0x2 then
		if CanBeginTurn then 
			CanBeginTurn = nil
			return
		end
		if waitingforround == 0 then
			waitingforround = 1
			local frametime = math.floor((socket.gettime()*10000) % 0x100000)
			frametable[tostring(frametime)] = {{},{},{}}
			--data to send regardless of whether host or client
			frametable[tostring(frametime)][3][1] = tostring(PLAYERNUM)
			frametable[tostring(frametime)][3][2] = tostring(waitingforround)
			frametable[tostring(frametime)][3][3] = tostring(memory.read_u8(InputBufferLocal))
			frametable[tostring(frametime)][3][4] = tostring(memory.read_u16_le(PlayerHPLocal))
			--send
			opponent:send("ack,"..tostring(frametime)) -- Ack Time
			opponent:send("2,1,"..frametable[tostring(frametime)][3][1])
			opponent:send("2,2,"..frametable[tostring(frametime)][3][2])
			opponent:send("2,3,"..frametable[tostring(frametime)][3][3])
			opponent:send("2,4,"..frametable[tostring(frametime)][3][4])
			opponent:send("cs") --"custom screen"
			print("part 1")
		end

		if not(WroteCSPlayerState) and #l == 4 then
			print("part 2")
			--apply the correct data for the remote player, just in case
				--PLAYERNUM will let us know which player this data is for. For now we're allowed to assume.
			--remote input buffer
			memory.write_u8(InputBufferRemote, l[3])
			--remote HP
			memory.write_u16_le(PlayerHPRemote, l[4])
			--now we can proceed with the rest of the code
			WroteCSPlayerState = true
		end

		--run this when we know that everyone has closed their cust
		--(this only runs once)
		if not(AllCustomizingFinished) and WroteCSPlayerState and l[2] == 1 then 
			print("part 3a")
			AllCustomizingFinished = true
			--clean the table
			l = {}
			--the host dictates parts of the gamestate in this conditional
			if PLAYERNUM == 1 then
				print("part 3b")
				local waittime = 60		--in frames
				local frametime = math.floor((socket.gettime()*10000) % 0x100000)
				frametable[tostring(frametime)] = {{},{},{}}
				--data for only the host to send
				frametable[tostring(frametime)][3][1] = tostring(frametime)
				frametable[tostring(frametime)][3][2] = tostring(waittime)
				frametable[tostring(frametime)][3][3] = tostring(memory.read_u32_le(0x02009800)) -- Battle RNG
				frametable[tostring(frametime)][3][4] = tostring(memory.read_u16_le(0x0203b380)) -- Battle Timestamp
				--send
				opponent:send("ack,"..tostring(frametime)) -- Ack Time
				opponent:send("2,1,"..frametable[tostring(frametime)][3][1])
				opponent:send("2,2,"..frametable[tostring(frametime)][3][2])
				opponent:send("2,3,"..frametable[tostring(frametime)][3][3])
				opponent:send("2,4,"..frametable[tostring(frametime)][3][4])
				opponent:send("h")
				TurnCountDown = waittime
			end
		end

		if AllCustomizingFinished and not(TurnCountDown) and #h == 4 then
			print("part 4")
			--accommodate latency between the time packet was sent and received
			local currentFrameTime = math.floor((socket.gettime()*10000) % 0x100000)
			local FrameTimeDif = math.floor((currentFrameTime - h[1]) % 0x100000)
			local WholeFrames = math.floor(FrameTimeDif/TargetFrame)
			local remainder = FrameTimeDif - (WholeFrames*TargetFrame)

			local adj_CntDn = h[2] - WholeFrames
			local adj_TS = math.floor((h[4] + WholeFrames)%0x10000)

			--timerift = timerift + remainder
			--set the amount of frames to wait before beginning turn
			TurnCountDown = adj_CntDn
			--overwrite Battle RNG value
			memory.write_u16_le(0x02009800, h[3])
			--overwrite Battle Timestamp
			memory.write_u16_le(0x0203b380, adj_TS)
			--clean the table
			h = {}
		end

		if TurnCountDown then
			TurnCountDown = TurnCountDown - 1
			if TurnCountDown == 0 then
				CanBeginTurn = true
			end
		end

		if CanBeginTurn then
			print("can begin turn")
			waitingforround = 0
			AllCustomizingFinished = nil
			WroteCSPlayerState = nil
			TurnCountDown = nil
		else 
			emu.setregister("R3",0)
		end
	end
end
event.onmemoryexecute(custsynchro,0x08008B96,"CustSync")

-- Sync Player Hands
local function SendHand()
	if thisispvp == 0 or opponent == nil then return end

	--when this runs, it means you can safely send your chip hand and write over the remote player's hand
	local WriteType = memory.read_u8(0x02036830)
	if emu.getregister("R1") == 0x02036940 and emu.getregister("R3") == 0x34 and WriteType == 0x2 then
		debug("sent hand")
		
		-- Get Frame Time.
		local frametime = math.floor((socket.gettime()*10000) % 0x100000)
		
		-- Write new entry to the frame table.
		frametable[tostring(frametime)] = {{},{},{}}
		
		-- Write Player Stats to the Frame Table.
		frametable[tostring(frametime)][2][1] = tostring(PLAYERNUM)
		frametable[tostring(frametime)][2][2] = tostring(TimeStatsWereSent)
		
		-- This for loop grabs most if not all of the Player's Stats.
		local i = 0
		for i=0,0x10 do
			frametable[tostring(frametime)][2][i+3] = tostring(memory.read_u32_le(PreloadStats + i*0x4))
		end
		
		-- Send an Ack to the opponent.
		opponent:send("ack,"..tostring(frametime))
		
		-- Send the frame table to the opponent.
		opponent:send("1,1,"..frametable[tostring(frametime)][2][1])
		opponent:send("1,2,"..frametable[tostring(frametime)][2][2])
		for i=0,0x10 do
			opponent:send("1,"..tostring(i+3)..","..frametable[tostring(frametime)][2][i+3])
		end
		opponent:send("s") -- This tells the opponent that the packets are for stats.
			
		CanWriteRemoteChips = true
		return
	end

	--this is the signal that it's safe to write the received player stats to ram
	--it only triggers once, at the start of the match before players have loaded in
	--this is not the same as actually writing the stats; that's done later
	if emu.getregister("R1") == 0x02036940 and emu.getregister("R3") == 0x4C and WriteType == 0x1 then
		CanWriteRemoteStats = true
	end
end
event.onmemoryexecute(SendHand,0x08008B56,"SendHand")

-- Sync Data on Match Load
local function SendStats()
	if thisispvp == 0 then 
		memory.write_u8(0x0200F31F, 0x0)
		return
	end
	if opponent == nil then debug("nopponent") return end
	debug("entering SendStats()")

	-- Get Frame Timer.
	local frametime = math.floor((socket.gettime()*10000) % 0x100000)
	
	TimeStatsWereSent = frametime --we're saving this for later
	
	-- Write new entry to frame table.
	frametable[tostring(frametime)] = {{},{},{}}
	
	-- Write Player Stats to Frame Table.
	frametable[tostring(frametime)][2][1] = tostring(PLAYERNUM)
	frametable[tostring(frametime)][2][2] = tostring(TimeStatsWereSent)
	
	-- This for loop grabs most if not all of the Player's Stats.
	local i = 0
	for i=0,0x10 do
		frametable[tostring(frametime)][2][i+3] = tostring(memory.read_u32_le(PreloadStats + i*0x4)) -- Player Stats
	end
	-- Send an ack to the opponent.
	opponent:send("ack,"..tostring(frametime)) -- Ack Time
	
	-- Send the frame table to the opponent.
	opponent:send("1,1,"..frametable[tostring(frametime)][2][1])
	opponent:send("1,2,"..frametable[tostring(frametime)][2][2])
	for i=0,0x10 do
		opponent:send("1,"..tostring(i+3)..","..frametable[tostring(frametime)][2][i+3])
	end
	opponent:send("s") -- This tells the opponent that the packets are for stats.
	
	debug("sending stats")
	StallingBattle = true
	memory.write_u8(0x0200F31F, 0x1) -- 0x1
end
event.onmemoryexecute(SendStats,0x0800761A,"SendStats")

local function WaitForPvP()
	if memory.readbyte(0x0200188F) == 0x0B then
		if thisispvp == 0 then
			waitingforpvp = 1
			delaybattletimer = 30
			ypos_bigpet = 45
			yoffset_bigpet = 120
		end
		thisispvp = 1
		prevsockettime = nil
		timerift = 0

		if opponent ~= nil and connected then
			local frametime = math.floor((socket.gettime()*10000) % 0x100000)
			frametable[tostring(frametime)] = {{},{},{}}
			frametable[tostring(frametime)][3][1] = tostring(BufferVal)
			frametable[tostring(frametime)][3][2] = tostring(waitingforpvp)
			--send
			opponent:send("ack,"..tostring(frametime)) -- Ack Time
			opponent:send("2,1,"..frametable[tostring(frametime)][3][1])
			opponent:send("2,2,"..frametable[tostring(frametime)][3][2])
			opponent:send("w") --"wait for pvp"
		end

		if #wt == 0 then
			memory.writebyte(SceneIndicator,0x4)
			gui.drawImage(bigpet, 120 -56, ypos_bigpet +yoffset_bigpet)
			gui.drawImage(smallpet, 124 -8, ypos_bigpet +43 +yoffset_bigpet)
			dur_signal, cnt_signal = gui_animate(124 - 12, ypos_bigpet +25 +yoffset_bigpet, signal_anim, xreg_signal, yreg_signal, dur_max_signal, cnt_max_signal, dur_signal, cnt_signal)
			if yoffset_bigpet > 0 then
				yoffset_bigpet = yoffset_bigpet - 10
				if yoffset_bigpet > 40 then
					yoffset_bigpet = yoffset_bigpet - 10
				end
			end
		else
			if waitingforpvp == 1 then
				waitingforpvp = 0
			end
			if delaybattletimer > 0 then
				memory.writebyte(SceneIndicator,0x4)
			end
			if waitingforpvp == 0 and wt[2] == 0 then
				delaybattletimer = delaybattletimer - 1
			end
			gui.drawImage(bigpet, 120 -56, ypos_bigpet +yoffset_bigpet)
			gui.drawImage(smallpet_bright, 124 -8, ypos_bigpet +43 +yoffset_bigpet)
			gui.drawText(1, 120, wt[2], "white")
		end
	else
		thisispvp = 0
    end
end
event.onmemoryexecute(WaitForPvP,0x080048CC,"WaitForPvP")

local function SetPlayerPorts()
	if thisispvp == 0 then return end

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
	if thisispvp == 0 then return end
	if resimulating then return end
	if coroutine.status(co) == "suspended" then coroutine.resume(co) end

	--write the last received input to the latest entry, This will be undone when the corresponding input is received
	memory.write_u16_le(InputStackRemote+0x2, lastinput)
	--mark the latest input in the stack as unreceived. This will be undone when the corresponding input is received
	memory.write_u8(InputStackRemote+1,0x1)

	--the iteration of the timestamp is now handled by the ROM

	localtimestamp = memory.read_u8(0x0203b380)
	--[[
	--iterate the latest input's timestamp by 1 frame (it's necessary to do this first for this new routine)
	previoustimestamp = memory.read_u8(InputStackRemote)
	newtimestamp = math.floor((previoustimestamp + 0x1)%256)

	--avoid iterating the remote timestamp if it would make it greater than the local timestamp
	local tsdif = newtimestamp - localtimestamp
	if tsdif > 0 and (newtimestamp + BufferVal) < 0xFF and localtimestamp > BufferVal then 
	else
		memory.write_u8(InputStackRemote, newtimestamp) --update timestamp on remote stack for this latest frame
	end
	]]


	--if type(c) == "table" and #c > 0 and type(c[1]) == "table" and #c[1] == 3 then

		--debug: find out how many times this loops, to see if it's writing the full input backlog
		local NumberTimesLooped = 0
		local NumberSkipped = 0

		while true do --continue writing inputs until the backlog of received inputs is empty

			if #c == 0 or NumberSkipped >= #c then break end	--the simplest exit scenario 



			NumberTimesLooped = NumberTimesLooped + 1
			local pointer = 0
			local tsmatch = false
			local stacksize = memory.read_u8(InputStackSize)
			local currentpacket = 1 + NumberSkipped
			local nogoodpackets = nil

			--remove corrupt packets
			while c[currentpacket][2] == nil do
				table.remove(c,currentpacket)
				if #c == 0 then break end
			end

			if #c == 0 or NumberSkipped >= #c or NumberSkipped > 6 then break end

			--skip packets that have arrived for future frames, do not delete them
		--	while (c[currentpacket][2] % 256) > localtimestamp or ((c[currentpacket][2] % 256) - localtimestamp) < (-10) do
		--		currentpacket = currentpacket + 1
		--		if currentpacket > #c then
		--			nogoodpackets = true
		--			break
		--		end
		--	end

			currentpacketprinter = currentpacket
			if nogoodpackets then break end



			while tsmatch == false do
				if (c[currentpacket][2] % 256) == memory.read_u8(InputStackRemote + pointer*0x10) then
					tsmatch = true
				else
					pointer = pointer + 1
					if pointer > stacksize then pointer = 0 break end
				end
			end


			

			if tsmatch == true then
				--rollback logic
				--returns true if it's about to write to an input slot that was already executed
				local iStatus = bit.check(memory.read_u8(InputStackRemote + 0x1 + pointer*0x10),1)
				if iStatus == true then
				--check whether the guessed input was correct
					--record the guessed input before overwriting
					local iGuess = memory.read_u16_le(InputStackRemote + 0x2 + pointer*0x10)
					--write the received input
					memory.write_u32_le(InputStackRemote + pointer*0x10, c[currentpacket][2])
					--load the received input (halfword) into a variable for comparison
					iCorrected = memory.read_u16_le(InputStackRemote + 0x2 + pointer*0x10)
					--compare both inputs, set the rollback flag if they don't match
					if iGuess ~= iCorrected then
						rbAmount =  math.floor(localtimestamp - (c[currentpacket][2] % 256) %256)
						--this will use the pointer to decide how many frames back to jump
						--it can rewrite the flag many times in a frame, but it will keep the largest value for that frame
						if memory.read_u8(rollbackflag) < rbAmount then
							memory.write_u8(rollbackflag, rbAmount)
						end
					end
					gui.drawText(-8, 82, bizstring.hex(0xC00000000 + c[currentpacket][2]),nil,"black")
					table.remove(c,currentpacket)
				else
				--runs when the input was received on time
					memory.write_u32_le(InputStackRemote + pointer*0x10, c[currentpacket][2])
					gui.drawText(-8, 82, bizstring.hex(0xC00000000 + c[currentpacket][2]),nil,"black")
					table.remove(c,currentpacket)
				end
			else
				NumberSkipped = NumberSkipped + 1
				--local i = 0
				--for i=0,(stacksize - 1) do
				--	table.insert(CycleInputStack, 1, memory.read_u32_le(InputStackRemote + i*0x10))
				--end
				--local i = 0
				--for i=0,(stacksize - 1) do
				--	memory.write_u32_le(InputStackRemote + (i+1)*0x10 ,CycleInputStack[#CycleInputStack])
				--	table.remove(CycleInputStack,#CycleInputStack)
				--end
				--gui.drawText(18, 94, "append",nil,"black")
				--memory.write_u32_le(InputStackRemote, c[currentpacket][2])
				--table.remove(c,currentpacket)
			end
		end
			
		--gui.drawText(-1, 108, NumberTimesLooped,nil,"black")
		--gui.drawText(-1, 120, currentpacketprinter,nil,"black")
	--else
		--if no input was received this frame
	--end

	local pointer = 0
	local stacksize = memory.read_u8(InputStackSize)
	while true do
		if memory.read_u8(InputStackRemote + 0x1 + pointer*0x10) == 0 then
			lastinput = memory.read_u16_le(InputStackRemote + 0x2 + pointer*0x10)
			break
		else
			pointer = pointer + 1
			if pointer > stacksize then 
				lastinput = 0
				break 
			end
		end
	end

	--[NEW EXPERIMENTAL CONDITIONAL] exit battle with the game's 'comm error' feature if players disconnect early
	if connected == nil then
		memory.write_u8(EndBattleEarly, 0x1)
	end
end
event.onmemoryexecute(ApplyRemoteInputs,0x08008800,"ApplyRemoteInputs")

local function closebattle()
	while #sav > 0 do
		memorysavestate.removestate(sav[#sav])
		table.remove(sav,#sav)
	end

	for k,v in pairs(frametable) do
		frametable[k][1] = nil
		frametable[k][2] = nil
		frametable[k][3] = nil
		frametable[k] = nil
	end

	opponent:send("disconnect")
	opponent:close()
	
	cleanstate()
	connectionform()

end
event.onmemoryexecute(closebattle,0x08006958,"CloseBattle")



local function Init_p2p_Connection()

	if PLAYERNUM == 1 then

		if not(Init_p2p_Connection_looped) then
			Init_p2p_Connection_looped = true
			tcp:bind(HOST_IP, HOST_PORT)
		end

		if not(connection_attempt_delay) then connection_attempt_delay = 1 end
		if connection_attempt_delay < 35 then
			connection_attempt_delay = connection_attempt_delay + 1
		else
			if connectedclient == nil then

				while host_server == nil do
					host_server, host_err = tcp:listen(1)
					emu.frameadvance()
				end
				if host_server ~= nil then
					connectedclient = tcp:accept()
				end

			end
		end

	-- Client
	else
	--	local previousSound = client.GetSoundOn() -- query what settings the user had for sound...
		local err
		if connectedclient == nil then
	--		client.SetSoundOn(false) -- the stutter is horrible
			
			if not(connection_attempt_delay) then connection_attempt_delay = 1 end
			if connection_attempt_delay < 35 then
				connection_attempt_delay = connection_attempt_delay + 1
			else

				connectedclient, err = tcp:connect(HOST_IP, HOST_PORT)
				while err == nil and connectedclient == nil do
					emu.frameadvance()
				end
				if err == "already connected" then
					connectedclient = 1
				end
			end
		end
	end
	
	
	if connectedclient then

		debug(connectedclient)
		connection_attempt_delay = nil
		Init_p2p_Connection_looped = nil
		host_server, host_err = nil

		defineopponent()

		if PLAYERNUM == 1 then
			debug("Connected as Server.")
			ip, port = connectedclient:getpeername()
			connectedclient:close()
			tcp:close()
			opponent:setsockname(HOST_IP, HOST_PORT)
			opponent:setpeername(ip, port)
		else
	--		client.SetSoundOn(previousSound) -- retoggle back to the user's settings...
			debug("Connected as Client.")
			--give host priority to the server side
		    memory.writebyte(0x0801A11C,0x1)
		    memory.writebyte(0x0801A11D,0x5)
		    memory.writebyte(0x0801A120,0x0)
		    memory.writebyte(0x0801A121,0x2)
			ip, port = tcp:getsockname()
			tcp:close()
			opponent:setsockname(ip, port)
			opponent:setpeername(HOST_IP, HOST_PORT)
			debug(HOST_IP..", "..HOST_PORT)
		end
		-- Finalize Connection
		connected = true
	end
 --coroutine.yield()
end

coco = coroutine.create(function() Init_p2p_Connection() end)



-- Main Loop
while true do
	

	--Reusable code for initializing the socket connection between players
	if connected ~= true and waitingforpvp == 1 and PLAYERNUM > 0 then
		if coroutine.status(coco) == "dead" then
			coco = coroutine.create(function() Init_p2p_Connection() end)
		end
		if coroutine.status(coco) == "suspended" then
			coroutine.resume(coco)
		end
	elseif connected == true then
	--	gui.drawText(220, 1, "p"..PLAYERNUM, "white")
	end


	--[[
	Controls the operation of the battle intro animation and syncs battle start times:
		1) stalls until verifying that the remote player's stats have been received
		2) runs Init_Battle_Vis() and then loops Battle_Vis() until the animation is completed
		3) pauses emulation for a variable time with the intention of both players resuming at the exact same time
	]]
	if StallingBattle then
		if connected then 
			if coroutine.status(co) == "suspended" then coroutine.resume(co) end
		end
		if received_stats == true then
			if vis_looptimes > 0 then
				vis_looptimes = vis_looptimes - 1
				scene_anim = Battle_Vis()
			else
				--exit condition
				c = {}
				StallingBattle = nil
				received_stats = nil
				memory.write_u8(0x0200F31F, 0x0) --this makes the game start the battle

				--clear the vars for syncing start time in Battle_Vis()
				SB_sent_packet = nil
				SB_Received = nil
				SB_Received_2 = nil
			end
		else
			if type(s) == "table" and #s == 19 then
				Init_Battle_Vis()
				received_stats = true
				memory.write_u8(InputBufferRemote, wt[1])
				wt = {}
			end
		end
	end


	--[[Once the local operation has written over the relevant addresses with the incorrect data, it will flag that 
		it's now safe to write the remote player's data to those addresses. Once it's safe to write, this code will 
		run as soon as the remote player's data has been received. ]]
	if CanWriteRemoteStats then
		if type(s) == "table" and #s == 19 then
			debug("wrote remote stats")
			local i = 0
			for i=0x0,0x10 do
				memory.write_u32_le(PlayerDataRemote + i*0x4,s[#s-0x10+i]) -- Player Stats
				table.remove(s,#s-0x10+i)
			end
			CanWriteRemoteStats = nil
		else
			debug("not enough data to write stats")
		end
	end

	if CanWriteRemoteChips then
		if type(s) == "table" and #s == 19 then
			local i = 0
			for i=0x0,0x10 do
				memory.write_u32_le(PlayerDataRemote + i*0x4,s[#s-0x10+i]) -- Player Hand
				table.remove(s,#s-0x10+i)
			end
			CanWriteRemoteChips = nil
			debug("wrote remote chips")
		end
	end



	-- Main routine for sending data to other players
	if opponent ~= nil and connected and not(resimulating) then
		
		-- Sort and clean Frame Table's earliest frames

		local frametableSize = 0
		for k,v in pairs(frametable) do
		    frametableSize = frametableSize + 1
		end
		--debugging stuff
		gui.drawText(1, 34, frametableSize,nil,"black")
		local debuggingtimestamp = bizstring.hex(memory.read_u16_be(0x0203b380))
		gui.drawText(1, 46, debuggingtimestamp,nil,"black")

		gui.drawText(-8, 58, bizstring.hex(0xC00000000+ memory.read_u32_be(InputStackLocal + (memory.read_u8(InputBufferLocal)*0x10))).." "..bizstring.hex(memory.read_u8(InputBufferLocal)),nil,"black")
		gui.drawText(-8, 70, bizstring.hex(0xC00000000+ memory.read_u32_be(InputStackRemote + (memory.read_u8(InputBufferRemote)*0x10))).." "..bizstring.hex(memory.read_u8(InputBufferRemote)),nil,"black")

		--gui.drawText(1, 94, bizstring.hex(),nil,"black")
		-- e


	--for now we'll avoid destroying these since we don't know which ones get destroyed yet
	--[[	while frametableSize >= 120 do
			for k,v in pairs(frametable) do
				frametable[k][1] = nil
				frametable[k][2] = nil
				frametable[k][3] = nil
				frametable[k] = nil
				frametableSize = frametableSize - 1
			--	debug("Removing #"..k.." from frametable.")
				break
			end
		end]]

		
		-- Get Frame Time
		local frametime = math.floor((socket.gettime()*10000) % 0x100000)
		
		-- Write new entry to Frame Table
		frametable[tostring(frametime)] = {{},{},{}}
			-- The Frame Table is a 3-dimensional dictionary that uses frametimes as the main indices.
			-- For each Frame Time listed in the frame table, there are 3 subtables which each hold further subtables full of packet data.
			-- Subtable 1 is the Player Control Information subtable, used to sync inputs and gamestate info.
			-- Subtable 2 is the Player Stats subtable, used to obviously sync player stats.
			-- Subtable 3 is the "Load Round" subtable, used to sync pre-round information.
			-- If you guys have to add more subtables, don't increase or decrease this dictionary from being 3-dimensional.
			
			-- If you notice below, the frame table's subtables start at 1 while the packet table indices start at 0.
			-- While not necessary, I did this in the receivepackets() function to turn the values we're converting to strings here back into numbers.
			-- You can either fix it or keep the trend going, up to you. It only really matters if you decide to add more subtables.
		

		-- Writing the Player Control Information subtable values.
		frametable[tostring(frametime)][1][1] = tostring(PLAYERNUM)
		frametable[tostring(frametime)][1][2] = tostring(memory.read_u32_le(InputStackLocal))
		frametable[tostring(frametime)][1][3] = tostring(frametime)
		
		-- Send Ack to Opponent
		opponent:send("ack,"..tostring(frametime)) -- Ack Time
		-- Send Frame Table to Opponent
		
		-- Control Information table
		opponent:send("0,1,"..frametable[tostring(frametime)][1][1])
		opponent:send("0,2,"..frametable[tostring(frametime)][1][2])
		opponent:send("0,3,"..frametable[tostring(frametime)][1][3])
		opponent:send("c") -- This tells the opponent what the packets are for (it's controls).
		
		-- End the data stream
		--opponent:send("end")
		
		
		-- Receive Data from Opponent
		if coroutine.status(co) == "suspended" then
			coroutine.resume(co)
		elseif coroutine.status(co) == "dead" then
		--	debug("coroutine dead, recreating")
			co = coroutine.create(function() receivepackets() end)
		end
	
		-- Reset to Disconnect
		-- Will also disconnect the other player
		local buttons = joypad.get()
		if (buttons["A"] and buttons["B"] and buttons["Start"] and buttons["Select"]) then
			closebattle()
		end
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
				if HideResim then
					client.invisibleemulation(true)
				end
			end

			--count down remaining rollback frames by 1
			rollbackframes = rollbackframes - 1
			memory.write_u8(rollbackflag,rollbackframes)
			gui.drawText(1, 23, "     ".. rollbackframes,nil,"black")

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



	emu.frameadvance()
end

event.unregisterbyname("FrameStart")
event.unregisterbyname("SetPlayerPorts")
event.unregisterbyname("WaitForPvP")
event.unregisterbyname("SendStats")
event.unregisterbyname("SendHand")
event.unregisterbyname("CustSync")
event.unregisterbyname("ApplyRemoteInputs")
event.unregisterbyname("CloseBattle")
return