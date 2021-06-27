
--[[
	
	This lua file and the related BBN3 romhack are provided under an MIT license.
	This means you're allowed to copy our code and use it for your own purposes.
	You don't need to ask us for permission to do this, because we've already given you permission!
	
	The only condition is that if you copy our code for your own project, other people who see the
	copied code need to be told that they're also allowed to copy the code. This is open for anyone
	to use and share, and anyone you share it with is also allowed to use and share it!

	This is as easy as saying "Hey, we copied code from this project and it has an MIT license."

	We highly recommend that you share ALL of the code that you make with this, but proprietary derivative works ARE allowed.
	It's ok to just provide a link to our original repository if that's what you're comfortable with.
	
	--------
	
	MIT License
	
	Copyright (c) 2021 Joey C. and C.S. Hoppins
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
	
	--------
  ]]


bbn3_netplay_open = true
socket = require("socket.core")
lanes = require "lanes"
lanes.configure{with_timers = false}

--Lua-Stats by Robin Gertenbach, licensed under MIT
	--https://github.com/rgertenbach/Lua-Stats
	function assertTables(...)
	  for _, t in pairs({...}) do
	    assert(type(t) == "table", "Argument must be a table")
	  end
	end
	
	-- checks if a value is in a table as a value or key
	function in_table(value, t, key)
	  assert(type(t) == 'table', "The second argument must be a table")
	  key = key or false
	  for i, e in pairs(t) do
	    if value == (key and i or e) then
	      return true
	    end
	  end
	  return false
	end

	-- Simple reduce function
	function reduce(t, f)
	  assert(t ~= nil, "No table provided to reduce")
	  assert(f ~= nil, "No function provided to reduce")
	  local result
	
	  for i, value in ipairs(t) do
	    if i == 1 then
	      result = value
	    else
	      result = f(result, value)
	    end 
	  end
	  return result
	end 
	
	-- Concatenates tables and scalars into one list
	function unify(...)
	  local output = {}
	  for i, element in ipairs({...}) do
	    if type(element) == 'number' then
	      table.insert(output, element)
	    elseif type(element) == 'table' then
	      for j, row in ipairs(element) do
	        table.insert(output, row)
	      end
	    end 
	  end 
	  return output
	end 
	
	function sum(...) 
	  return reduce(unify(...), function(a, b) return a + b end)
	end 
	
	function count(...) 
	  return #unify(...) 
	end 
	
	function mean(...) 
	  return sum(...) / count(...) 
	end 

	-- Calculates the quantile
	-- Currently uses the weighted mean of the two values the position is inbetween
	function quantile(t, q)
	  assert(t ~= nil, "No table provided to quantile")
	  assert(q >= 0 and q <= 1, "Quantile must be between 0 and 1")
	  table.sort(t)
	  local position = #t * q + 0.5
	  local mod = position % 1
	
	  if position < 1 then 
	    return t[1]
	  elseif position > #t then
	    return t[#t]
	  elseif mod == 0 then
	    return t[position]
	  else
	    return mod * t[math.ceil(position)] +
	           (1 - mod) * t[math.floor(position)] 
	  end 
	end 

	-- Simple map function
	function map(t, f, ...)
	  assert(t ~= nil, "No table provided to map")
	  assert(f ~= nil, "No function provided to map")
	  local output = {}
	
	  for i, e in pairs(t) do
	    output[i] = f(e, ...)
	  end
	  return output
	end 
	
	function sumSquares(...)
	  local data = unify(...)
	  local mu = mean(data)
	
	  return sum(map(data, function(x) return (x - mu)^2 end))  
	end 
	
	function varPop(...)
	  return sumSquares(...) / count(...)
	end 
	
	function frequency(t)
	  assertTables(t)
	  local counts = {}
	  for _, value in ipairs(t) do
	    if in_table(value, counts, true) then
	      counts[value] = counts[value] + 1
	    else 
	      counts[value] = 1
	    end
	  end 
	  return counts
	end
	
	function mode(t)
	  local frequencies = frequency(t)
	  local last
	  local most
	
	  for value, repeats in pairs(frequencies) do
	    if not last or (value > last) then
	      last = repeats
	      most = value
	    end
	  end
	
	  return most
	end

	function median(t)
	  assert(t ~= nil, "No table provided to median")
	  return quantile(t, 0.5)
	end

	function sdPop(...)
	  return math.sqrt(varPop(...))
	end
--end of imported Lua-Stats code


--Define constants and various functions

	--define constant RAM offset variables
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
	--end of RAM offset variables



	-- Took this from some Lua Tutorial
	function string:split(sep)
		local sep, fields = sep or ":", {}
		local pattern = string.format("([^%s]+)", sep)
		self:gsub(pattern, function(c) fields[#fields+1] = c end)
		return fields
	end
	
	function isIP(ip) 
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
			local chunks = {ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
			if (#chunks == 4) then
				for _,v in pairs(chunks) do
					if (tonumber(v) < 0 or tonumber(v) > 255) then
						return IPType[0]
					end
				end
				return IPType[1]
			--else
			--	return IPType[0]
			end
		
			-- check for ipv6 format, should be 8 'chunks' of numbers/letters
			local _, chunks = ip:gsub("[%a%d]+%:?", "")
			if chunks == 8 then
				return IPType[2]
			end
		
			-- if we get here, assume we've been given a random string

			return IPType[3]
		end
	
		local thisiptype = GetIPType(ip)
		sessioniptype = thisiptype
		if thisiptype == "string" then
			local maybedomain, err = socket.dns.toip(ip)
			thisiptype = GetIPType(maybedomain)
			if thisiptype ~= "Error" then
				sessioniptype = "string"
			end
		end
		return ip == "localhost" or thisiptype == "IPv4" or thisiptype == "IPv6"
	end
	
	
	function preconnect()
		-- Check if either Host or Client
		tcp = socket.tcp()
		if sessioniptype == "string" then
			local ip, dnsdata = socket.dns.toip(HOST_IP)
			HOST_IP = ip
		end
	
		tcp:settimeout(6,'b')
		--tcp:settimeout(1 / (16777216 / 280896),'b')
	
	
		--define controller ports and offsets for individual players
		PORTNUM = PLAYERNUM - 1
		InputBufferLocal = InputData + PLAYERNUM
		InputStackLocal = InputData + 0x10 + (PORTNUM*0x4)
		PlayerHPLocal = BDA_HP + (BDA_s * PORTNUM)
		PlayerDataLocal = PlayerData + (PD_s * PORTNUM)
		BattleData_A_Local = BattleData_A + (BDA_s * PORTNUM)
		
		--this math only works for 1v1s
		InputStackRemote =  InputData + 0x10 + (0x4*bit.bxor(1, PORTNUM))
		InputBufferRemote = InputData + 0x1 + bit.bxor(1, PORTNUM)
		PlayerHPRemote = BDA_HP + (BDA_s * bit.bxor(1, PORTNUM))
		PlayerDataRemote = PlayerData + (PD_s * bit.bxor(1, PORTNUM))
		BattleData_A_Remote = BattleData_A + (BDA_s * bit.bxor(1, PORTNUM))
		--this is fine for now. To support more than 2 players it will need to define these after everyone has connected, 
		--and up to 3 sets of "Remote" addresses will need to exist. But this won't matter any time soon.
	end
	
	
	function defineopponent()
		-- Set who your Opponent is
		opponent = socket.udp()
		opponent:settimeout(0)--(1 / (16777216 / 280896))
	end
	
	
	function gui_animate(xpos, ypos, img, xreg, yreg, dur_max, cnt_max, dur, cnt)
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
	
	
	function gui_src()
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

		x_center = 120 
		y_center = 80
	end
	--things get drawn at the base GBA resolution and then scaled up, so calculations are based on 1x GBA res


	--IMPORTANT: coroutines apparently cannot use these debug functions for displaying data
	function debug(message)
		if debugmessages == 1 then
			print(message)
		end
	end
	function debugdraw(x,y,message)
		if debugmessages == 1 then
			gui.drawText(x,y,message,nil,"black")
		end
	end
	-- other debug stuff
	d_pos1 = 18--70
	d_pos2 = d_pos1 + 12
	d_pos3 = d_pos2 + 12
	d_pos4 = d_pos3 + 12
	d_pos5 = d_pos4 + 12
	d_pos6 = d_pos5 + 12
	
	--end of debug stuff

	function readbyterange(addr, length) --length must be multiples of 0x4
		local x = math.floor(length /4)
		local temptable = {}
		for i=0, x do
			table.insert(temptable, 1, memory.read_u32_le(addr + i*0x4))
		end
		return temptable
	end
	
	function writebyterange(addr, usetable)
		local tmptable = {}
		tmptable = usetable
		for i=0, #tmptable - 1 do
			memory.write_u32_le(addr + i*0x4, tmptable[#tmptable])
			table.remove(tmptable,#tmptable)
		end
	end


	timecutoff = 0x100000

	function getframetime()
		local xyz = math.floor((socket.gettime()*10000) % timecutoff)
		return xyz
	end
	function tinywait()
		while tostring(math.floor((socket.gettime()*10000) % timecutoff)) == ftt[1] do
			client.sleep(1) --1 millisecond
		end
	end
--End of "Define constants and various functions"


function resetnet()
	--reset variables that control the p2p connection
	PLAYERNUM = 0
	PORTNUM = nil
	HOST_IP = "127.0.0.1"
	HOST_PORT = 5738
	tcp = nil
	connected = nil
	connectedclient = nil
	clock_dif = nil

	opponent = nil
	servermsg = "nattlebetwork"
end



function resetstate()
	--define variables that we might adjust sometimes

	BufferVal = 3		--input lag value in frames
	debugmessages = 1	--toggle whether to print debug messages
	saferollback = 15
	delaybattletimer = 30
	clocksync_looptimes = 15
	savecount = 60	--amount of savestate frames to keep
	client.displaymessages(false)
	emu.minimizeframeskip(false)
	client.enablerewind(false)
	client.frameskip(0)
	HideResim = true
	TargetFrame = 167.4270629882813 --gonna give this more specific value a shot
	--167.427063 --166.666666666667
	TargetSpeed = 100
	client.speedmode(TargetSpeed)
	TempTargetSpeed = 100
	SoundBool = client.GetSoundOn()
	
	--set variables at script start
	rollbackframes = 0
	resimulating = nil
	emu.limitframerate(true)
	framethrottle = true
	wfp_val = {}
	wfp_ping = {}
	pl = {} --payload
	ft = {}
	ftt = {}
	table.insert(ftt, 1, 0)		--easy way to prevent a nil error at the start
	rft = {}
	rftt = {}
	t = {}
	c = {}
	ctrl = {}
	l = {}
	h = {}
	s = {}
	wt = {}
	wt2 = {}
	wt3 = {}
	wt4 = {}
	data = nil
	err = nil
	part = nil
	acked = nil
	CanWriteRemoteStats = nil
	CanWriteRemoteChips = nil
	lane_time = nil
	scene_anim = nil
	cs_sentcount = 0
	thisispvp = 0
	waitingforpvp = 0
	sync_waitingforround = 0
	timedout = 0
	ari_lastinput = 0
	ari_droppedcount = 0
	ari_contig_non_rb = 0
	save = {}  --savestate ID table
	FullInputStack = {}  --input stack for rollback frames
	CycleInputStack = {} --input stack when the input handler cycles it down to make more room
	wfp_client_got = {}
	wfp_local_got = {}
	wfp_local_req = nil
	wfp_remote_got = nil
	wfp_remote_sent = nil
	
	menu = nil
	serialize = true
end



function connectionform()
	menu = forms.newform(300,175,"BBN3 Netplay",function() return nil end)
	local windowsize = client.getwindowsize()
	local form_xpos = (client.xpos() + 120*windowsize - 142)
	local form_ypos = (client.ypos() + 80*windowsize + 10)
	forms.setlocation(menu, form_xpos, form_ypos)
	label_ip = forms.label(menu,"IP:",8,0,32,24)
	port_ip = forms.label(menu,"Port:",8,30,32,24)
	textbox_default_ip = "127.0.0.1"
	textbox_ip = forms.textbox(menu,textbox_default_ip,240,24,nil,40,0)
	textbox_port = forms.textbox(menu,"5738",240,24,nil,40,30)
	local badip = "Bad IP"
	local clippy_opt
	local clippy_desc
	local clippy_descs = {
						["false"] = "Will not read IP from Clipboard",
						["true"] = "Will read IP from Clipboard if IP field is left default"
						}
	if tangotime then
		clippy_opt = config[read_clipboard]
		clippy_desc = clippy_descs[clippy_opt]
	else
		clippy_opt = "false"
		clippy_desc = clippy_descs[clippy_opt]
	end

	local function togglereadclip()
		return function()
			if clippy_opt == "true" then
				clippy_opt = "false"
			else
				clippy_opt = "true"
			end
			if tangotime then
				saveconfig(read_clipboard, clippy_opt)
			end	
			clippy_desc = clippy_descs[clippy_opt]
			forms.settext(menu_readclip_desc, clippy_desc)
		end
	end


	menu_readclip = forms.button(menu,"Toggle", togglereadclip(), 8,100,50,24)
	menu_readclip_desc = forms.label(menu, clippy_desc, 60,105,232,64)


	local function makeCallback(playernum, is_host)
		return function()
			PLAYERNUM = playernum
			local input = forms.gettext(textbox_ip)

			if not(is_host) and clippy_opt == "true" and (input == textbox_default_ip or input == badip) then
				input = winapi.get_clipboard()
			end
			--remove spaces in the ip field (before processing)
			input = string.gsub(input, "%s+", "")
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
				forms.settext(textbox_ip, badip)
			end
		end
	end

	button_host = forms.button(menu,"Host", makeCallback(1, true), 80,60,48,24)
	button_join = forms.button(menu,"Join", makeCallback(2, false), 160,60,48,24)

end




function receivepackets()
	-- Loop for Received data
	while true do
		data,err,part = opponent:receive()
		-- Data will not be nil if a full data packet has been received.
		-- Otherwise an error and partial data is thrown.
		-- We're checking specifically for full packets, dropped or partial packets aren't good enough.
		if data ~= nil then

	--[[	--messy debug check
			--this prints (to the screen) the raw packet data as it's coming in
			if not(thisco) then
				thisco = memory.read_u16_le(0x0203b380)
				cyclecount = 0
				x_shift = 0 end
			if memory.read_u16_le(0x0203b380) ~= thisco then
				thisco = memory.read_u16_le(0x0203b380)
				cyclecount = 0
				x_shift = 0 end
			if thisco > 1 then
				if not(cyclecount) then cyclecount = 0 end
				gui.drawText(-30+ 90*x_shift, 12*cyclecount, data,nil,"black")
				cyclecount = cyclecount + 1
					if cyclecount > 11 then
					x_shift = x_shift + 1
					cyclecount = 0 end
			end
		]]	--end messy debug check

			local subpackets = data:split("|")
			local p = 0
			for p = 1,#subpackets do
				local str = subpackets[p]:split(",")
				-- An "ack" is received when you send a packet to your opponent(s) and they acknowledge that they received it.
				-- Once this has been received, clear out the correct slot in the local frame table so that we can free up some space.
				if str[1] == "ack" then
					local frame = str[3]
					--record that the ack has been received by putting the ID into this table
					--it will be possible to receive the same ack packet more than once, so this conditional avoids an error
					if ft[frame] ~= nil then
						ft[frame][1] = nil
						ft[frame][2] = nil
						ft[frame][3] = nil
						ft[frame] = nil
						pl[frame] = nil
					end
					timedout = 0
				-- An incoming ack, sent before incoming data.
				-- Used to make sure each player's frame tables are in-sync.
				elseif str[1] == "send" then
					acked = str[3]
					local player = str[2]
					opponent:send("ack,"..player..","..acked)
					timedout = 0
					--populate the remote frametable, which keeps track of the packets that have already gone through
					if rft[acked] == nil then
						rft[acked] = 1
						table.insert(rftt, 1, acked)
						not_a_dupe = true
					else
						--find some way to make it ignore whatever packets are bundled with this timestamp
						not_a_dupe = nil
					end

				end
				-- The End of the incoming data buffer.
				-- Just used to clear some variables and tell the user they're no longer being acked.
				if subpackets[p] == "end" then
					data = nil
					err = nil
					part = nil
					acked = nil
				-- If a player sends a disconnect packet, make sure to self-disconnect.
				-- Looks like you guys made it close the battle as well.
				elseif subpackets[p] == "disconnect" then
					connected = nil
					acked = nil
					closebattle()
					break
				elseif not_a_dupe then
					-- Save the buffered data to the Player Control Information.
					-- The Control Information includes things like gamestate and player inputs.
					-- Clears out the buffered control table afterward.
					if str[1] == "c" then --"controls"
						c[#c+1] = ctrl
						ctrl = {}
					end
					if str[1] == "wt" then --"wait for pvp"
						wt = t 
						t = {}
					end
					if str[1] == "wt2" then --"clock sync wait"
						wt2 = t 
						t = {}
						local timeval = socket.gettime()*10000
						if #wt2 == 1 then
							table.insert(wfp_client_got, #wfp_client_got+1, timeval)
						elseif #wt2 == 2 then
							table.insert(wfp_local_got, #wfp_local_got+1, timeval)
						end
					end
					if str[1] == "wt3" then --"battle_vis"
						wt3 = t 
						t = {}
					end
					if str[1] == "wt4" then --"battle_vis"
						wt4 = t 
						t = {}
					end
					-- Save the buffered data to the Player Stats table.
					-- The Stats include things like the Player's NCP Setup, their HP, etc.
					-- Clears out the buffered data table afterward.
					if str[1] == "s" then --"stats"
						s = t
						t = {}
					end
					-- Save the buffered data to the Player's "Load Round" table.
					-- This table loads things like Custom Screen state, RNG values, The Pre-round Timer, Input Delay, etc.
					-- Again, clears out the buffered data table afterward.
					if str[1] == "cs" then --"custom screen"
						l = t
						t = {}
					end
					if str[1] == "h" then
						h = t
						t = {}
					end
					
					-- This if statement block turns the numerical values grabbed from the subpacket
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
			if timedout >= 3*(memory.read_u8(InputBufferRemote) + saferollback) then
				--	emu.yield()
				if timedout >= 60*7 and waitingforpvp == 0 then
					connected = nil
					acked = nil
					break
				end
			end
			coroutine.yield()
		end
	end
end



function Init_Battle_Vis()
	--screen position constants
	vis_x_max_w = 240
	vis_y_p1_bg = 30
	vis_y_p2_bg = 140
	vis_x_vs_size = 48
	vis_y_vs_size = 24
	vis_x_vs_pos = 120
	vis_y_vs_pos = 85


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
	local stylebyte = math.floor(s[3] % 256)
	vis_style_R1 = style[1+(bit.band(stylebyte, 0x38)/8)]
	vis_elem_R1 = elem[1+bit.band(stylebyte, 0x7)]

	--define the file string for each player's megaman style 
	p1_char = "gui_Sprites\\style_"..vis_style_L..".png"
	p2_char = "gui_Sprites\\style_"..vis_style_R1..".png"

	local function checkelem(style, elem)
		if elem == "Nullelem" then
			if style == "Normal" then
				elem = 0
				--NCP easter eggs go here
			else
				--the player is cheating if this returns true
				--accomplished by having a style with no element
			end
		elseif style == "Normal" then
			--this also means the player is cheating by having an element with no Style
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


function Battle_Vis()
	if not(scene_anim) then scene_anim = 1 end

	if clock_dif then
		gui.drawText(3,140, clock_dif)
	end

	local movetext = 0
	local function bg_animation(scroll)
		--top backgrounds
		gui.drawImage(motion_b, (-scroll), vis_y_p1_bg)
		gui.drawImage(motion_b, (motion_bg_w - scroll), vis_y_p1_bg)

		--bottom backgrounds
		gui.drawImage(motion_p, scroll, (vis_y_p2_bg - style_h))
		gui.drawImage(motion_p, (scroll - motion_bg_w), (vis_y_p2_bg - style_h))
	end

	--start of time syncing code
	if coroutine.status(co) == "suspended" then coroutine.resume(co) end
		if clock_dif and not(SB_sent_packet) then
			SB_sent_packet = true
			tinywait()
			local frametime = getframetime()
			local FID = tostring(frametime)
			table.insert(ftt, 1, FID)
			ft[FID] = {{},{},{}}
			ft[FID][3][1] = tostring(PLAYERNUM)
			
			local send_payload = ("send,"..PLAYERNUM..","..FID.."|2,1,"..ft[FID][3][1].."|wt3")
			opponent:send(send_payload)
			pl[FID] = send_payload
		end

		if clock_dif and not(SB_Received) and #wt3 ~= 0 then
			SB_Received = true
			wt3 = {}
			if PLAYERNUM == 1 then
				--this stalls until the frametimes are different enough to not be interpreted as a dupe
				tinywait()
				local waittime = 60		--in frames
				local frametime = getframetime()
				local FID = tostring(frametime)
				table.insert(ftt, 1, FID)
				ft[FID] = {{},{},{}}
				ft[FID][3][1] = socket.gettime()*10000
				ft[FID][3][2] = tostring(waittime)
				
				-- Waiting for PVP Packet
				local send_payload = ("send,"..PLAYERNUM..","..FID.."|2,1,"..ft[FID][3][1].."|2,2,"..ft[FID][3][2].."|wt4")
				opponent:send(send_payload)
				pl[FID] = send_payload

				vis_looptimes = vis_looptimes + waittime
				SB_Received_2 = true
				wt4 = {}
			end
		end

		if clock_dif and SB_Received and not(SB_Received_2) and #wt4 ~= 0 then
			SB_Received_2 = true
			--accommodate latency between the time packet was sent and received
			local currentFrameTime = socket.gettime()*10000
			local FrameTimeDif = math.abs(currentFrameTime + clock_dif - wt4[1])
			local WholeFrames = math.floor(FrameTimeDif/TargetFrame)
			local remainder = FrameTimeDif - (WholeFrames*TargetFrame)
			local adj_CntDn = wt4[2] - WholeFrames
			debug(currentFrameTime.. " + " .. clock_dif .. " - "..wt4[1].." = "..FrameTimeDif)
			debug("adj wait = "..wt4[2] .. " - " .. WholeFrames)

			--set the amount of frames to wait before beginning turn
			vis_looptimes = vis_looptimes + adj_CntDn
			--clean the table
			wt4 = {}
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
			swooshin = vis_x_max_w + style_w
			if vis_looptimes > 8 then
				swooshin = style_w + (exit_time-vis_looptimes)*8
				bg_animation(scroll)
			elseif vis_looptimes > 5 then 

				gui.drawImage(f3_motion_b, 0, vis_y_p1_bg)
				gui.drawImage(f3_motion_p, 0, (vis_y_p2_bg -style_h))
			elseif vis_looptimes > 3 then
				gui.drawImage(f2_motion_b, 0, vis_y_p1_bg)
				gui.drawImage(f2_motion_p, 0, (vis_y_p2_bg -style_h))
			elseif vis_looptimes > 1 then
				gui.drawImage(f1_motion_b, 0, vis_y_p1_bg)
				gui.drawImage(f1_motion_p, 0, (vis_y_p2_bg -style_h))
			end
		else --normal loop
			bg_animation(scroll)
		end
	
		--both megamans
		gui.drawImageRegion(p1_char, 0, vis_elem_L*style_h, style_w, style_h, swooshin -style_w, vis_y_p1_bg)
		gui.drawImageRegion(p2_char, 0, vis_elem_R1*style_h, style_w, style_h, vis_x_max_w + style_w -swooshin, vis_y_p2_bg -style_h, -style_w)

	--intro animation
	elseif scene_anim < 3 then
		gui.drawImage(f1_motion_b, 0, vis_y_p1_bg)
		gui.drawImage(f1_motion_p, 0, (vis_y_p2_bg -style_h))
	elseif scene_anim < 6 then
		gui.drawImage(f2_motion_b, 0, vis_y_p1_bg)
		gui.drawImage(f2_motion_p, 0, (vis_y_p2_bg -style_h))
	else
		gui.drawImage(f3_motion_b, 0, vis_y_p1_bg)
		gui.drawImage(f3_motion_p, 0, (vis_y_p2_bg -style_h))
	end

	--if vis_looptimes < 8 then
	--	movetext = 8 - vis_looptimes
	--end

	--left megaman
	gui.drawText(5, (vis_y_p1_bg -1 +style_h +movetext), "NetBattler1", "white", nil, nil, nil, "left","top")

	--right megaman
	gui.drawText(vis_x_max_w - 5, (vis_y_p2_bg -style_h -movetext), "NetBattler2", "white", nil, nil, nil, "right","bottom")


	--animate the VS image flying in
	local multiplier = 1
	if vis_vs_zoom[scene_anim] then 
		multiplier = vis_vs_zoom[scene_anim]
	end
	if vis_looptimes < 8 then
		multiplier = vis_looptimes /10
	end
	vs_xsize = vis_x_vs_size * multiplier
	vs_ysize = vis_y_vs_size * multiplier
	if multiplier < 4 then
		VSimg = VSimgo
	else
		VSimg = VSimgt
	end
	gui.drawImage(VSimg, (vis_x_vs_pos -vs_xsize/2), (vis_y_vs_pos -vs_ysize/2), vs_xsize, vs_ysize)


	scene_anim = scene_anim + 1
	return scene_anim
end


function FrameStart()
	if thisispvp == 0 then return end 
	--[[this routine only has a niche use. It does not run from an opcode execution, but rather is tied to what 
		the emulator believes to be the beginning of the frame. So it is unreliable for anything involving
		time-sensitive code due to how rollbacks work.
		However, this routine can run even when the game is running a loop where it's essentially doing nothing.
		This makes it very helpful for ensuring that we can always receive packets from the other players.
	  ]]

	if connected then 
		if coroutine.status(co) == "suspended" then coroutine.resume(co) end
	end
end



--runs right before the gamestate update, is included in the loop during rollback
function PreBattleLoop()
	if thisispvp == 0 then return end

	--for whatever reason, pressing a lot of buttons can cause this function to run multiple times
	--in a single frame, which is really bad. This is a quick fix at least until I can find the 
	--exact reason why this is happening
	pbl_currenttimestamp = memory.read_u8(0x0203b380)
	if pbl_prevtimestamp and memory.read_u8(0x02006CA1) == 0x0C and pbl_currenttimestamp == pbl_prevtimestamp then
		return
	end
	pbl_prevtimestamp = pbl_currenttimestamp

	fs_TimeToSlowDown = nil

	--define this value as early as possible in the function
	sockettime = getframetime()
	--debugdraw(50, 14, sockettime)


	--create savestates for rollback
	table.insert(save, 1, memorysavestate.savecorestate())
	--delete the oldest savestate after x frames
	if #save > savecount then
		memorysavestate.removestate(save[#save])
		table.remove(save,#save)
	end


	if resimulating then 
		if memory.read_u8(rollbackflag+1) == 0 then
			resimulating = nil
			client.invisibleemulation(false)
			emu.limitframerate(true)
			framethrottle = true
		else
			return
		end 
	end


	--compensate for local frame stuttering by temporarily speeding up
	--make sure this also can compensate for the time spent on rollbacks
	if not(prevsockettime) then
		 prevsockettime = sockettime
		return 
	end

	--when sockettime rolls over, the absolute value of this calculation will be greater than 0x100000
	--which will result in it discarding everything except the difference in time between the frames
	local fs_timepast = (sockettime - prevsockettime) % timecutoff
	fs_timerift = fs_timerift + fs_timepast - TargetFrame
	prevsockettime = sockettime
	local placeholderspot = " "
	if fs_timerift < 0 then placeholderspot = "" end
	debugdraw(1, 14, placeholderspot.. math.floor(fs_timerift))

	if math.abs(fs_timerift) > 9 then
		local msdif = TargetFrame - fs_timerift
		--if it's too far behind, the resulting value could be negative
		TempTargetSpeed = math.floor((TargetFrame / msdif * 100) + 0.5 ) --the +0.5 rounds it up
		if TempTargetSpeed > 0 and TempTargetSpeed < 1000 then
			client.speedmode(TempTargetSpeed)
		else
			TempTargetSpeed = 1000
			client.speedmode(TempTargetSpeed)
		end
	else
		client.speedmode(TargetSpeed)
		TempTargetSpeed = 100
	end
end



--runs soon after the gamestate update
function BattleLoop()
	if thisispvp == 0 then return end
	--nothing yet
end
--event.onmemoryexecute(BattleLoop,0x08014944)


function StartResim()
	if thisispvp == 0 then return end
	--rollback routine
	--runs once when rollback begins, but not on subsequent rollback frames
	local rollbackframes = memory.read_u8(rollbackflag)

	if rollbackframes == 0 then return end	--just in case, this shouldn't ever be true but the rest would break if it somehow was
	
	resimulating = true

	--update inputs that are still guesses with the more recent data
	local pointer = rollbackframes + memory.read_u8(InputBufferRemote)
	local isguess = nil
	local newguess = nil
	local writecount = 0
	while pointer > -1 do
		isguess = memory.read_u8(InputStackRemote+1 +pointer*0x10)
		if isguess == 0 then
			newguess = memory.read_u16_le(InputStackRemote+2 +pointer*0x10)
			writecount = 0
		elseif newguess then
			--idea for how to use writecount:
			--when the val gets above a certain amount, screen for specific types of inputs, ie high write limit for B presses
			--but lower limit for Dpad presses. Modify the guess to remove specific inputs from the guess accordingly.
			--this doesn't work yet. It can cause desyncs
				--if writecount > 5 then
				--	writeguess = (newguess % 0x10)
				--else
				--	writeguess = newguess
				--end
			memory.write_u16_le(InputStackRemote + 0x2 + pointer*0x10, newguess)
			writecount = writecount + 1
		end
		pointer = pointer - 1
	end

	--save the corrected input stack
	local stacksize = memory.read_u8(InputStackSize)
	for i=0,(stacksize*4)+0x10 do
		table.insert(FullInputStack, 1, memory.read_u32_le(InputData + i*0x4))
	end


	if HideResim then
		client.invisibleemulation(true)
	end

	--try copying some visual data
	--local visdata = readbyterange(0x0200C0C0,0x140)


	--load savestate
	memorysavestate.loadcorestate(save[rollbackframes])


	--write the corrected input stack to RAM
	for i=0,(stacksize*4)+0x10 do
		memory.write_u32_le(InputData + i*0x4,FullInputStack[#FullInputStack])
		table.remove(FullInputStack,#FullInputStack)
	end


	--writebyterange(0x0200C0C0, visdata)


	--enable the SPEED
	client.speedmode(TargetSpeed)
	emu.limitframerate(false)
	framethrottle = false
	pbl_prevtimestamp = nil

	--decrease the rb frame counter by 1 (this step is necessary)
	rollbackframes = rollbackframes - 1
	memory.write_u8(rollbackflag, rollbackframes)

	--delete the savestates for the frames that will be resimulated
	--(they will be recreated upon resimulation)
	--this is very important
	for i=0, rollbackframes-1 do
		memorysavestate.removestate(save[1])
		table.remove(save,1)
	end
end



function StopResim()
	if thisispvp == 0 then return end
	--probably going to depreciate this routine
end
--event.onmemoryexecute(StopResim,0x0800880C)


-- Sync Custom Screen
function custsynchro()
	if thisispvp == 0 then return end

	local reg3 = emu.getregister("R3")

	if reg3 == 0x2 then
		if CanBeginTurn then 
			CanBeginTurn = nil
			return
		end
		if sync_waitingforround == 0 then
			sync_waitingforround = 1
			tinywait()
			local frametime = getframetime()
			local FID = tostring(frametime)
			table.insert(ftt, 1, FID)
			ft[FID] = {{},{},{}}
			--data to send regardless of whether host or client
			ft[FID][3][1] = tostring(PLAYERNUM)
			ft[FID][3][2] = tostring(sync_waitingforround)
			ft[FID][3][3] = tostring(memory.read_u8(InputBufferLocal))
			ft[FID][3][4] = tostring(memory.read_u16_le(PlayerHPLocal))
			
			-- Custom Screen Packet
			local send_payload = ("send,"..PLAYERNUM..","..FID.."|2,1,"..ft[FID][3][1].."|2,2,"..ft[FID][3][2].."|2,3,"..ft[FID][3][3].."|2,4,"..ft[FID][3][4].."|cs")
			opponent:send(send_payload)
			pl[FID] = send_payload

		end

		if not(sync_WroteCSPlayerState) and #l == 4 then
			--debug("got handshake")
			--apply the correct data for the remote player, just in case
				--PLAYERNUM will let us know which player this data is for. For now we're allowed to assume.
			--remote input buffer
			memory.write_u8(InputBufferRemote, l[3])
			--remote HP
			memory.write_u16_le(PlayerHPRemote, l[4])
			--now we can proceed with the rest of the code
			sync_WroteCSPlayerState = true
		end

		--run this when we know that everyone has closed their cust
		--(this only runs once)
		if not(sync_AllCustomizingFinished) and sync_WroteCSPlayerState and l[2] == 1 then 
			sync_AllCustomizingFinished = true
			--clean the table
			l = {}
			--the host dictates parts of the gamestate in this conditional
			if PLAYERNUM == 1 then
				--this stalls until the frametimes are different enough to not be interpreted as a dupe
				tinywait()
				local waittime = 120		--in frames
				local frametime = getframetime()
				local FID = tostring(frametime)
				table.insert(ftt, 1, FID)
				ft[FID] = {{},{},{}}
				--data for only the host to send
				ft[FID][3][1] = socket.gettime()*10000
				ft[FID][3][2] = tostring(waittime)
				ft[FID][3][3] = tostring(memory.read_u32_le(0x02009800)) -- Battle RNG
				ft[FID][3][4] = tostring(memory.read_u16_le(0x0203b380)) -- Battle Timestamp
				
				-- Host Packet
				local send_payload = ("send,"..PLAYERNUM..","..FID.."|2,1,"..ft[FID][3][1].."|2,2,"..ft[FID][3][2].."|2,3,"..ft[FID][3][3].."|2,4,"..ft[FID][3][4].."|h")
				opponent:send(send_payload)
				pl[FID] = send_payload

				sync_TurnCountDown = waittime
			end
		end

		if sync_AllCustomizingFinished and not(sync_TurnCountDown) and #h == 4 then
			--debug("got host data")
			--accommodate latency between the time packet was sent and received
			local currentFrameTime = socket.gettime()*10000
			local FrameTimeDif = math.abs(currentFrameTime - h[1] + clock_dif)
			local WholeFrames = math.floor(FrameTimeDif/TargetFrame)
			local remainder = FrameTimeDif - (WholeFrames*TargetFrame)

			local adj_CntDn = h[2] - WholeFrames
			local adj_TS = math.floor((h[4] + WholeFrames)%0x10000)

			--fs_timerift = fs_timerift + remainder
			--set the amount of frames to wait before beginning turn
			sync_TurnCountDown = adj_CntDn
			--overwrite Battle RNG value
			memory.write_u32_le(0x02009800, h[3])
			--overwrite Battle Timestamp
			memory.write_u16_le(0x0203b380, adj_TS)

			print(currentFrameTime.." - "..h[1].." = "..FrameTimeDif)
			print("int      = "..WholeFrames)
			--print("waittime = "..h[2])
			print("adjusted = "..adj_CntDn)
			--clean the table
			h = {}
		end

		if sync_TurnCountDown then
			sync_TurnCountDown = sync_TurnCountDown - 1
			if sync_TurnCountDown == 0 then
				CanBeginTurn = true
			end
		end

		if CanBeginTurn then
			debug("can begin turn")
			sync_waitingforround = 0
			sync_AllCustomizingFinished = nil
			sync_WroteCSPlayerState = nil
			sync_TurnCountDown = nil
		--	debug(memory.read_u16_le(PlayerHPLocal))
		else
			emu.setregister("R3",0)
		end
	end
end



function WaitForPvP()
	if memory.readbyte(0x0200188F) == 0x0B then
		if thisispvp == 0 then
			waitingforpvp = 1
			delaybattletimer = 30
			ypos_bigpet = 45
			yoffset_bigpet = 120
			connect_delay = 30
		end
		thisispvp = 1
		prevsockettime = nil
		fs_timerift = 0

		if connect_delay > 0 then
			connect_delay = connect_delay - 1
		end

		if opponent ~= nil and connected and connect_delay == 0 then
			tinywait()
			local frametime = getframetime()
			local FID = tostring(frametime)
			table.insert(ftt, 1, FID)
			ft[FID] = {{},{},{}}
			ft[FID][3][1] = tostring(BufferVal)
			ft[FID][3][2] = tostring(waitingforpvp)
			
			-- Waiting For PVP Packet
			local send_payload = ("send,"..PLAYERNUM..","..FID.."|2,1,"..ft[FID][3][1].."|2,2,"..ft[FID][3][2].."|wt")
			opponent:send(send_payload)
			pl[FID] = send_payload

			if coroutine.status(co) == "suspended" then coroutine.resume(co) end
		end


		if #wt == 0 or connect_delay > 0 then
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
			debugdraw(1, 120, wt[2])
		end
	else
		thisispvp = 0
    end
end


function ClockSync()
	--new code for synchronizing clocks
	--run a number of pings in order to determine the median difference between system clock values
	--stay in a loop while waiting for the round-trip packet 
	if PLAYERNUM == 1 and not(clock_dif) then
		if #wfp_val < clocksync_looptimes then
			if not(wfp_local_req) then
				--this stalls until the frametimes are different enough to not be interpreted as a dupe
				tinywait()
				--generate and send the packet
				local frametime = getframetime()
				local FID = tostring(frametime)
				table.insert(ftt, 1, FID)
				ft[FID] = {{},{},{}}
				ft[FID][3][1] = 1

				local send_payload = ("send,"..PLAYERNUM..","..FID.."|2,1,"..ft[FID][3][1].."|wt2")
				opponent:send(send_payload)
				pl[FID] = send_payload

				wfp_local_req = socket.gettime()*10000
			end

			--loop while waiting to receive the packet from the other player
			if not(wfp_remote_got) then
				if coroutine.status(co) == "suspended" then coroutine.resume(co) end
				if #wt2 == 2 then
					wfp_remote_got = wt2[1]
					wfp_remote_sent = wt2[2]
				end

				if not(wfp_remote_got) then
					--make sure sent packet doesn't get lost
					if ft[ftt[1]] ~= nil then
						local FID = ftt[1]
						local send_payload = pl[FID]
						opponent:send(send_payload)
					end
				else
					wt2 = {}
				end
			end

			if not(wfp_remote_got) then return end

			--https://en.wikipedia.org/wiki/Network_Time_Protocol
			--clock synchronization algorithm

			local t0 = wfp_local_req
			local t1 = wfp_remote_got
			local t2 = wfp_remote_sent
			local t3 = wfp_local_got[#wfp_val+1]

			-- [(t1 - t0) + (t2 - t3)] /2
			-- t0 = wfp_local_req , t1 = wfp_remote_got , t2 = wfp_remote_sent , t3 = wfp_local_got
			-- [(wfp_remote_got - wfp_local_req) + (wfp_remote_sent - wfp_local_got)] /2
			--local abs_offset = (((wfp_remote_got - wfp_local_req) % timecutoff) - ((wfp_local_got - wfp_remote_sent) % timecutoff)) / 2 --attempted fix for when values reset, didn't work
			local abs_offset = ( (t1 - t0) + (t2 - t3) ) / 2

			abs_offset = math.floor(abs_offset)		--abs_offset = math.floor(abs_offset/10) *10
			--print("loop: " .. #wfp_val .. "  #got = " .. #wfp_local_got .. "  clock = " .. abs_offset)
			--print( "( ("..t1.." - "..t0..") + ("..t2.." - "..t3..") ) / 2 \n= "..abs_offset)

			--roundtrip value currently isn't used, but I'll keep it around just in case. This measures ping
			local rndtrip = (t3 - t0) - (t2 - t1)

			--table.insert(wfp_val, 1, {abs_offset, rndtrip})
			table.insert(wfp_val, abs_offset)
			table.insert(wfp_ping, rndtrip)
			wfp_local_req = nil
			--wfp_local_got = nil
			wfp_remote_got = nil
			wfp_remote_sent = nil
		end

		if #wfp_val < clocksync_looptimes then return end

		--parse the results and then send them
		local wfp_sd = sdPop(wfp_val)	--frequency(wfp_val)
		debug("sd = "..wfp_sd)
		local wfp_mean = mean(wfp_val)
		debug("mean = "..wfp_mean)
		local i= #wfp_val
		while i > 0 do
			if math.abs(wfp_val[i]) - wfp_sd > math.abs(wfp_mean) then
				table.remove(wfp_val, i)
				table.remove(wfp_ping, i)
			end
			i = i - 1
		end

		--local wfpss = wfp_val[1]
		--for i=2, #wfp_val do
		--	local x = wfp_val[i]
		--	wfpss = wfpss .. ", " .. x
		--end
		--debug(wfpss)
		local medianping = median(wfp_ping)/2
		local medianclock = median(wfp_val)
		print("ping = "..medianping .. "  clock = " .. medianclock)
		clock_dif = math.floor(medianclock)

		print("clock_dif: "..clock_dif .. "  (median)")

		--this stalls until the frametimes are different enough to not be interpreted as a dupe
		tinywait()
		--generate and send the packet
		local frametime = getframetime()
		local FID = tostring(frametime)
		table.insert(ftt, 1, FID)
		ft[FID] = {{},{},{}}
		ft[FID][3][1] = medianclock
		ft[FID][3][2] = medianping
		ft[FID][3][3] = 0
		local send_payload = ("send,"..PLAYERNUM..","..FID.."|2,1,"..ft[FID][3][1].."|2,2,"..ft[FID][3][2].."|2,3,"..ft[FID][3][3].."|wt2")
		opponent:send(send_payload)
		pl[FID] = send_payload
		wfp_SyncFinished = true

	elseif not(clock_dif) then
		--version for the client
		if coroutine.status(co) == "suspended" then coroutine.resume(co) end

		if #wt2 == 3 and wt2[3] == 0  then
			clock_dif = math.floor(wt2[1] *(-1))
			wt2 = {}
			wfp_SyncFinished = true
		end

		if #wt2 == 1 then
			cs_sentcount = cs_sentcount +1
			--step 1: record when the packet was received
					--trying to put this in a different spot so it's defined sooner
					--wfp_client_got = math.floor((socket.gettime()*10000) % 0x100000)
			--step 2: send a new packet as a response
			--this stalls until the frametimes are different enough to not be interpreted as a dupe
			tinywait()
			local frametime = getframetime()
			local FID = tostring(frametime)
			table.insert(ftt, 1, FID)
			ft[FID] = {{},{},{}}
			ft[FID][3][1] = wfp_client_got[cs_sentcount]
			ft[FID][3][2] = socket.gettime()*10000
			local send_payload = ("send,"..PLAYERNUM..","..FID.."|2,1,"..ft[FID][3][1].."|2,2,"..ft[FID][3][2].."|wt2")
			opponent:send(send_payload)
			pl[FID] = send_payload
			if #wt2 == 1 then	--apparently this doesn't always return true, and that would break things
				wt2 = {}
			end
		end

		if ft[ftt[1]] ~= nil then
			local FID = ftt[1]
			local send_payload = pl[FID]
			opponent:send(send_payload)
		end

		if clock_dif then
			print("clock_dif: "..clock_dif)
			wfp_local_req = nil
			--wfp_local_got = nil
			wfp_remote_got = nil
			wfp_remote_sent = nil
		end
	end
	--end of new code
end



-- Sync Player Hands
function SendHand()
	if thisispvp == 0 or opponent == nil then return end

	--when this runs, it means you can safely send your chip hand and write over the remote player's hand
	local WriteType = memory.read_u8(0x02036830)
	if emu.getregister("R1") == 0x02036940 and emu.getregister("R3") == 0x34 and WriteType == 0x2 then
		debug("sent hand")
		
		-- Get Frame Time.
		tinywait()
		local frametime = getframetime()
		local FID = tostring(frametime)
		table.insert(ftt, 1, FID)
		
		-- Write new entry to the frame table.
		ft[FID] = {{},{},{}}
		
		-- Write Player Stats to the Frame Table.
		ft[FID][2][1] = tostring(PLAYERNUM)
		
		-- This for loop grabs most if not all of the Player's Stats.
		for i=0,0x10 do
			ft[FID][2][i+2] = tostring(memory.read_u32_le(PreloadStats + i*0x4))
		end
		
		-- Stats Packet
		local str = "send,"..PLAYERNUM..","..FID.."|"
		str = str.."1,1,"..ft[FID][2][1].."|"
		for i=0,0x10 do
			str = str.."1,"..tostring(i+2)..","..ft[FID][2][i+2].."|"
		end
		local send_payload = (str.."s") -- This tells the opponent that the packets are for stats.
		opponent:send(send_payload)
		pl[FID] = send_payload

			
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



-- Sync Data on Match Load
function SendStats()
	if thisispvp == 0 then 
		memory.write_u8(0x0200F31F, 0x0)
		return
	end

	-- Get Frame Timer.
	tinywait()
	local frametime = getframetime()
	local FID = tostring(frametime)
	table.insert(ftt, 1, FID)
	
	-- Write new entry to frame table.
	ft[FID] = {{},{},{}}
	
	-- Write Player Stats to Frame Table.
	ft[FID][2][1] = tostring(PLAYERNUM)
	
	-- This for loop grabs most if not all of the Player's Stats.
	for i=0,0x10 do
		ft[FID][2][i+2] = tostring(memory.read_u32_le(PreloadStats + i*0x4)) -- Player Stats
	end
	
	-- Stats Packet
	local str = "send,"..PLAYERNUM..","..FID.."|"
	str = str.."1,1,"..ft[FID][2][1].."|"
	for i=0,0x10 do
		str = str.."1,"..tostring(i+2)..","..ft[FID][2][i+2].."|"
	end
	local send_payload = (str.."s") -- This tells the opponent that the packets are for stats.
	opponent:send(send_payload)
	pl[FID] = send_payload

	
	debug("sending stats")
	StallingBattle = true
	memory.write_u8(0x0200F31F, 0x1) -- 0x1
end



function SendInputs()
	-- Main routine for sending data to other players
	if opponent and connected then

		-- Get Frame Time
		tinywait()
		local frametime = getframetime()
		local FID = tostring(frametime)

		--this will help track how long ago a frametable entry was created
		--https://cdn.discordapp.com/attachments/791359988546273330/825892778713546802/the_cooler_frametable.jpg
		table.insert(ftt, 1, FID)

		-- Write new entry to Frame Table
		ft[FID] = {{},{},{}}
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
		ft[FID][1][1] = tostring(PLAYERNUM)
		ft[FID][1][2] = tostring(memory.read_u32_le(InputStackLocal))
		ft[FID][1][3] = FID
		
		-- Control Information Packet
		local send_payload = ("send,"..PLAYERNUM..","..ft[FID][1][3].."|0,1,"..ft[FID][1][1].."|0,2,"..ft[FID][1][2].."|0,3,"..ft[FID][1][3].."|c")
		opponent:send(send_payload)
		pl[FID] = send_payload


		-- Sort and clean Frame Table's earliest frames
		frametableSize = 0
		for k,v in pairs(ft) do
		    frametableSize = frametableSize + 1
		end


		--this might be enough to keep our frametables clean
		--[[ftt has an index in which the largest number denotes the oldest frame, so we can clear 
			the frametable IDs contained in the oldest entries. It will throw an error if we try to clear a
			a frametable ID that's already been cleared, so that part is surrounded in a conditional.
			Also the amount of table entries to keep before being cleared should allow enough time for 
			multiple attempts at resending the packets, but should not keep entries for long enough that 
			it's possible for the frametime value to overlap itself. ]]
		while #ftt > 240 do
			if ft[ftt[#ftt]] ~= nil then
				for i=1,3 do
					ft[ftt[#ftt]][i] = nil
				end
				ft[ftt[#ftt]] = nil
			end
			table.remove(ftt,#ftt)
		end

		--same thing as above but for the remote table that keeps track of received packets
		while #rftt > 240 do
			if rft[rftt[#rftt]] ~= nil then
				rft[rftt[#rftt]] = nil
			end
			table.remove(rftt,#rftt)
		end



		--re send packets that might have been dropped
		local i = 1
		local i2 = frametableSize -1	--this will track how many unACK'd packets exist, excluding the packet already sent this frame
		local i3 = #ftt
		while i2 > 0 and i3 > 0 do
			i = i + 1
			--only send the packet if it has NOT been ACK'd (ACK'd data no longer exists in the table)
			if ft[ftt[i]] ~= nil then			--(i % 2 == 1) and --only send every other packet
				if (i % 2 == 0) then
					local FID = ftt[i]
					local send_payload = pl[FID]
					opponent:send(send_payload)
				end
				i2 = i2 - 1
			end
			i3 = i3 - 1
		end


		-- Reset to Disconnect
		-- Will also disconnect the other player
		--local buttons = joypad.get()
		--if (buttons["A"] and buttons["B"] and buttons["Start"] and buttons["Select"]) then
		--	closebattle()
		--end
	end
end


function SetPlayerPorts()
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



function ApplyRemoteInputs()
	if thisispvp == 0 then return end
	if resimulating then return end 

	-- Send input data to the opponent
	SendInputs()

	-- Receive Data from Opponent
	if coroutine.status(co) == "suspended" then coroutine.resume(co) 
	elseif coroutine.status(co) == "dead" then co = coroutine.create(function() receivepackets() end)
	end

	--check the current gamestate to resolve whether a rollback to this frame should be allowed
	--battle state is 0x0C
		--there are no other states I currently know of where rollback should be allowed
	if memory.read_u8(0x02006CA1) == 0x0C then
		--mark the latest input in the stack as unreceived. This will be undone when the corresponding input is received
		memory.write_u8(InputStackRemote+1,0x1)
	else
		--by default it copies the data from the previous frame, so we must intentionally clear the "unreceived" flag to prevent rollbacks
		memory.write_u8(InputStackRemote+1,0)
	end

	--write the last received input to the latest entry, This will be undone when the corresponding input is received
	memory.write_u16_le(InputStackRemote+0x2, ari_lastinput)
	

	--the iteration of the timestamp is now handled by the ROM

	local ari_localtimestamp = memory.read_u8(0x0203b380)
	local stacksize = memory.read_u8(InputStackSize)

	local debugaroony = 0

	--debug: find out how many times this loops, to see if it's writing the full input backlog
	local NumberTimesLooped = 0
	local NumberSkipped = 0
	while true do --continue writing inputs until the backlog of received inputs is empty
		--if #c == 0 or NumberSkipped >= #c then break end	--the simplest exit scenario 

		NumberTimesLooped = NumberTimesLooped + 1
		local pointer = 1
		local tsmatch = false
		local currentpacket = 1 + NumberSkipped
		local nogoodpackets = nil


		--it's possible for connection issues or serious stuttering to cause a larger amount of backlogged inputs. 
		--There can be so many that it causes performance issues when attempting to write all of them in one frame.
		--Which can become a bigger problem if so much time has passed that the target input is no longer in the stack.
		--So for now, it will limit the amount of attempted writes while trying to go fast.
		if TempTargetSpeed - TargetSpeed > 50 then	--framethrottle == true then
			if #c == 0 or NumberSkipped >= #c or NumberSkipped > 20 then break end
		else
			if #c == 0 or NumberSkipped >= #c then break end
		end

		currentpacketprinter = currentpacket
		if nogoodpackets then break end


		--find the location of the timestamp that will be overwritten
		--when tsmatch returns true, pointer will tell us how far down the stack it is
		while tsmatch == false do
			if (c[currentpacket][2] % 256) == memory.read_u8(InputStackRemote + pointer*0x10) then
				tsmatch = true
			else
				pointer = pointer + 1
				if pointer > stacksize then pointer = 0 break end
			end
		end


		if tsmatch == true then

			debugdraw(-8, d_pos5 +(12*debugaroony), bizstring.hex(0xC00000000 + c[currentpacket][2]))
			debugaroony = debugaroony + 1

			if NumberSkipped > 0 then
				NumberSkipped = NumberSkipped - 1
			end
			local isrollbackframe = nil
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
				local iCorrected = memory.read_u16_le(InputStackRemote + 0x2 + pointer*0x10)
				--compare both inputs, set the rollback flag if they don't match
				if iGuess ~= iCorrected then
					isrollbackframe = true
					ari_rbAmount =  math.floor((ari_localtimestamp -   ((memory.read_u8(InputBufferRemote) + c[currentpacket][2] - 1) % 256)) %256)
					--this will use the pointer to decide how many frames back to jump
					--it can rewrite the flag many times in a frame, but it will keep the largest value for that frame
					--it jumps to the frame that the input will be executed, rather than when the input was created
					if memory.read_u8(rollbackflag) < ari_rbAmount then
						memory.write_u8(rollbackflag, ari_rbAmount)
						rbtrigger = (c[currentpacket][2] % 256)
						tsbeforerb = ari_localtimestamp
					end
					emu.limitframerate(false)
					framethrottle = false
				end
				table.remove(c,currentpacket)
			else
			--runs when the input was received on time
				memory.write_u32_le(InputStackRemote + pointer*0x10, c[currentpacket][2])
				table.remove(c,currentpacket)
			end

			if not isrollbackframe then
				--update the guess for unreceived inputs on slightly later frames
				local iCorrected = memory.read_u16_le(InputStackRemote + 0x2 + pointer*0x10)
				local iStatus = nil
				pointer = pointer - 1
				while pointer > 0 do 
					local thisbyte = memory.read_u8(InputStackRemote + 0x1 + pointer*0x10)
					iStatus = bit.check(thisbyte,1)
					if iStatus == true then
						--input is a guess, we should update the guess
						memory.write_u16_le(InputStackRemote + 0x2 + pointer*0x10, iCorrected)
					else
						--if reaching an input that is NOT a guess, that means all guesses above it will already be copying
						--from the newer input, which is good. We do not want to replace those guesses with older inputs.
						break 
					end
					pointer = pointer - 1 --point to the input immediately above
				end
				--end of guess update code
			end

		else
			NumberSkipped = NumberSkipped + 1
			--for i=0,(stacksize - 1) do
			--	table.insert(CycleInputStack, 1, memory.read_u32_le(InputStackRemote + i*0x10))
			--end
			--for i=0,(stacksize - 1) do
			--	memory.write_u32_le(InputStackRemote + (i+1)*0x10 ,CycleInputStack[#CycleInputStack])
			--	table.remove(CycleInputStack,#CycleInputStack)
			--end
			--debugdraw(18, 94, "append")
			--memory.write_u32_le(InputStackRemote, c[currentpacket][2])
			--table.remove(c,currentpacket)
		end
	end
			
		--debugdraw(-1, 108, NumberTimesLooped)
		--debugdraw(-1, 120, currentpacketprinter)
	--else
		--if no input was received this frame
	--end

	local pointer = 0
	local stacksize = memory.read_u8(InputStackSize)
	while true do
		if memory.read_u8(InputStackRemote + 0x1 + pointer*0x10) == 0 then
			ari_lastinput = memory.read_u16_le(InputStackRemote + 0x2 + pointer*0x10)
			break
		else
			pointer = pointer + 1
			if pointer > stacksize then 
				ari_lastinput = 0
				break 
			end
		end
	end

	--[NEW EXPERIMENTAL CONDITIONAL] exit battle with the game's 'comm error' feature if players disconnect early
	if connected == nil then
		memory.write_u8(EndBattleEarly, 0x1)
	end

	--detect when a guess input is about to be pushed out of the input stack

	--local isdropped = memory.read_u8(InputStackRemote  + 0x1 + 0x100)
	local isdropped = memory.read_u8(InputStackRemote + 0x1 + stacksize*0x10)
	if isdropped ~= 0 then
		ari_droppedcount = ari_droppedcount + 1
		--local read_addr = memory.read_u8(InputStackRemote + 0x100)
		local read_addr = memory.read_u8(InputStackRemote + stacksize*0x10)
		--print(bizstring.hex(read_addr))
	end
	debugdraw(240 - 30, 160 - 12, ari_droppedcount)

		--debugging stuff
	debugdraw(37, d_pos2, frametableSize)
	local debuggingtimestamp = bizstring.hex(memory.read_u16_be(0x0203b380))
	debugdraw(0, d_pos2, debuggingtimestamp)

	debugdraw(-8, d_pos3, bizstring.hex(0xC00000000+ memory.read_u32_be(InputStackLocal + (memory.read_u8(InputBufferLocal)*0x10))))
	debugdraw(-8, d_pos4, bizstring.hex(0xC00000000+ memory.read_u32_be(InputStackRemote + (memory.read_u8(InputBufferRemote)*0x10))).." "..bizstring.hex(memory.read_u8(InputBufferRemote)))
	-- e

end



function closebattle()
	while #save > 0 do
		memorysavestate.removestate(save[#save])
		table.remove(save,#save)
	end

	for k,v in pairs(ft) do
		ft[k][1] = nil
		ft[k][2] = nil
		ft[k][3] = nil
		ft[k] = nil
	end

	if opponent then 
	--	opponent:send("disconnect")
	--	opponent:close()
	end
	
	resetstate()
	--connectionform()
end



function Init_p2p_Connection()

	while not connectedclient do
		if PLAYERNUM == 1 then
			if not(Init_p2p_Connection_looped) then
				Init_p2p_Connection_looped = true
				tcp:bind(HOST_IP, HOST_PORT)
			end
			if connectedclient == nil then
				while host_server == nil do
					host_server, host_err = tcp:listen(1)
					--emu.frameadvance()
				end
				if host_server == 1 then
					connectedclient = tcp:accept()
				end
			end
		else
		-- Client
			local err
			if connectedclient == nil then
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
		--debug(connectedclient)
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
			--debug(ip)
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
			--debug(HOST_IP..", "..HOST_PORT)
		end
		-- Finalize Connection
		connected = true
	end
end
--coco = coroutine.create(function() Init_p2p_Connection() end)


function p2p_sniffer(PLAYERNUM, HOST_IP, HOST_PORT,servermsg)

	local socket = require("socket.core")

	--
	--theoretical feature: receive connection info from matchmaking server and return it to the main script
	local ret_IP = nil
	local ret_PORT = nil
	local ret_PLAYERNUM = nil
	--
	
	local tcp
	local s_shake
	local s_err
	local r_shake
	local r_err
	local loopxs = 0
	local loopmax = 10
	local host_server, host_err


	local function tcpinit()
		tcp = socket.tcp()
		tcp:settimeout(5,'b')
	end

	local function resetvars()
		s_shake = nil
		s_err = nil
		r_shake = nil
		r_err = nil
		loopxs = 0
		connectedclient = nil
		p2p_sniffer_looped = nil
		host_server = nil
	end

	tcpinit()
	resetvars()

	while true do
		if PLAYERNUM == 1 then
			if not(p2p_sniffer_looped) then
				p2p_sniffer_looped = true
				tcp:bind(HOST_IP, HOST_PORT)
			end
			if connectedclient == nil then
				while not(connectedclient) and host_server == nil do
					socket.sleep(0.5)
					host_server, host_err = tcp:listen(1)
				end
				if host_server == 1 and not connectedclient then
					connectedclient, err = tcp:accept()
				end
			end
			if connectedclient then 
				connectedclient:settimeout(5)
				if not r_shake then
					r_shake, r_err = connectedclient:receive()
				end
				if r_shake and r_shake == servermsg then
					s_shake, s_err = connectedclient:send(r_shake.."accepted".."\n")
				end
				if s_shake then
					connectedclient:close()
					tcp:close()
					return ret_IP,ret_PORT,ret_PLAYERNUM
				end
				socket.sleep(0.3)
				loopxs = loopxs + 1
				if loopxs > loopmax then
					connectedclient:close()
					tcp:close()
					resetvars()
					tcpinit()
				end
			end
		else
		-- Client
			local err
			if connectedclient == nil then
				while err == nil and connectedclient == nil do
					socket.sleep(0.5)
					connectedclient, err = tcp:connect(HOST_IP, HOST_PORT)
				end
				if err == "already connected" then
					--connectedclient = 1
					--tcp:close()
					--tcp = socket.tcp()
					--tcp:settimeout(5,'b')
				end
			end
			if connectedclient then
				if not s_shake then
					--returns nil if error, so the definition check tells us whether we need to send again
					s_shake, s_err = tcp:send(servermsg.."\n")
				end
				if s_shake then
					r_shake, r_err = tcp:receive()
				end
				if s_shake and r_shake == (servermsg.."accepted") then --and r_shake == "nattlebetwork" then
					tcp:close()
					return ret_IP,ret_PORT,ret_PLAYERNUM
				end

				loopxs = loopxs + 1
				if loopxs > loopmax then
					tcp:close()
					resetvars()
					tcpinit()
				end
				socket.sleep(0.3)
			end
		end
	end
end


--debugging tool, disables held inputs so that the stack only every registers an input on a single frame
sp_read = 0
function SinglePress()
	sp_prev = sp_read
	sp_read = memory.read_u8(0x02009760)
	--clearing this memory will cause inputs to not work during battle
	sp_mem = bit.bor(sp_read, sp_prev)
	sp_mem = sp_mem - sp_prev
	memory.write_u8(0x02009760, sp_mem)
end
--event.onmemoryexecute(SinglePress,0x08000398)


function MainLoop()

	--[[Once the local operation has written over the relevant addresses with the incorrect data, it will flag that 
		it's now safe to write the remote player's data to those addresses. Once it's safe to write, this code will 
		run as soon as the remote player's data has been received. ]]
	if CanWriteRemoteStats then
		if type(s) == "table" and #s == 18 then
			debug("wrote remote stats")
			for i=0x0,0x10 do
				memory.write_u32_le(PlayerDataRemote + i*0x4,s[#s-0x10+i]) -- Player Stats
				table.remove(s,#s-0x10+i)
			end
			CanWriteRemoteStats = nil
		end
	end

	if CanWriteRemoteChips then
		if type(s) == "table" and #s == 18 then
			for i=0x0,0x10 do
				memory.write_u32_le(PlayerDataRemote + i*0x4,s[#s-0x10+i]) -- Player Hand
				table.remove(s,#s-0x10+i)
			end
			CanWriteRemoteChips = nil
			debug("wrote remote chips")
		end
	end

	if resimulating then
		client.invisibleemulation(false)
	end

end



--debugging function that's used to manually browse and load serialized frames
function loadsavestate()
	statemenu = forms.newform(250,120,"Savestate",function() return nil end)
	local windowsize = client.getwindowsize()
	local form_xpos = (client.xpos() + 120*windowsize - 90)
	local form_ypos = (client.ypos() - 100)
	forms.setlocation(statemenu, form_xpos, form_ypos)
	textbox_frame = forms.textbox(statemenu,"1",40,24,nil,14,5)

	textbox_rb = forms.textbox(statemenu,"1",40,24,nil,169,5)

	checkbox_serial = forms.checkbox(statemenu,"Serialize",10,60)

	local function loadthatstate(incr)
		return function()
			local i = forms.gettext(textbox_frame)
			i = tonumber(i)
			if not(incr) then
				if i > 0 and i < (1 + #save) then
					memorysavestate.loadcorestate(save[i])
				end
			else
				i = i + incr
				if i > 0 and i < (1 + #save) then
					forms.settext(textbox_frame, tostring(i))
					memorysavestate.loadcorestate(save[i])
					print(bizstring.hex(memory.read_u8(0x0203B380)) .. "  loaded")
				end
			end
		end
	end
	button_load = forms.button(statemenu,"Load", loadthatstate(nil), 10,28,48,24)
	button_load = forms.button(statemenu,"fwrd", loadthatstate(-1), 62,5,48,20)
	button_load = forms.button(statemenu,"back", loadthatstate(1), 62,28,48,24)

	local function rollbackthatstate()
		return function()
			serialize = forms.ischecked(checkbox_serial)

			local i = forms.gettext(textbox_rb)
			i = tonumber(i)
			memory.write_u8(rollbackflag,i)
			print("rollback by " .. i )
			StartResim()
		end
	end
	button_load = forms.button(statemenu,"RollBack",rollbackthatstate(), 155,28,70,24)
end
enablestatedebug = nil


-- End of Frame loop (runs purely based on time instead of opcodes ran)
function bbn3_netplay_mainloop()

	--debugdraw(160, 5, getframetime())

	--Reusable code for initializing the socket connection between players
	if connected ~= true and waitingforpvp == 1 and PLAYERNUM > 0 then

		if not lane_time then
			lane_time = lanes.gen( "math,package,string,table", {package={}},p2p_sniffer )
			lain = lane_time(PLAYERNUM,HOST_IP,HOST_PORT,servermsg)
		end

		if lain.status == "done" then
			debug("Detected viable connection. ")
			emu.frameadvance()
			--if not connected then print("not connected") end
			--[[
			--theoretical feature: receive connection info from a server, returned by the p2p_sniffer function
			ret_IP = lain[1]
			ret_PORT = lain[2]
			ret_PLAYERNUM = lain[3]
			]]
			Init_p2p_Connection() 

		elseif lain.status == "error" then
			print("lain error")
			print(lain[1] .." ".. lain[2].." ".. lain[3])
		end
	end

	if connected and memory.read_u8(0x0200F31F) == 1 then
		SendInputs()
	end

	--[[
	Controls the operation of the battle intro animation and syncs battle start times:
		1) stalls until verifying that the remote player's stats have been received
		2) runs Init_Battle_Vis() and then loops Battle_Vis() until the animation is completed
		3) for the client, Battle_Vis() lasts for a variable time with the goal of both players resuming on the same frame
	]]
	if StallingBattle then
		if connected then 
			if coroutine.status(co) == "suspended" then coroutine.resume(co) end
		end
		if received_stats == true then
			if vis_looptimes > 0 then
				vis_looptimes = vis_looptimes - 1
				PreBattleLoop()
				scene_anim = Battle_Vis()
			else
				--exit condition
				c = {}
				StallingBattle = nil
				received_stats = nil
				memory.write_u8(0x0200F31F, 0x0) --this makes the game start the battle
				prevsockettime = nil

				--clear the vars for syncing start time in Battle_Vis()
				SB_sent_packet = nil
				SB_Received = nil
				SB_Received_2 = nil
			end
		else
			if type(s) == "table" and #s == 18 then
				Init_Battle_Vis()
				received_stats = true
				memory.write_u8(InputBufferRemote, wt[1])
				wt = {} 
				--wt table is also defined with Battle_Vis(), but the host should only ever be able to send the packet after all
				--the clients have already started running the function, so it should be safe to clear it at this point in the code
				--(this line runs once, before Battle_vis() begins)
				prevsockettime = nil
			end
		end
	end


	--debug code for selecting and loading previous serialized frames when Select is pressed
	if enablestatedebug and bit.band(memory.read_u8(0x02009760), 0x4) == 0x4 and not(amloadingstates) then
		loadsavestate()
		client.pause()
		amloadingstates = true
	end 
end


function init_bbn3_netplay()

	--define variables for gui.draw
	gui_src()

	resetnet()
	resetstate()
	connectionform()

	while PLAYERNUM < 1 do
		emu.frameadvance()
	end

	co = coroutine.create(function() receivepackets() end)
	event.onframestart(FrameStart)
	event.onmemoryexecute(PreBattleLoop,0x08006434)
	event.onmemoryexecute(StartResim,0x08008808)
	event.onmemoryexecute(custsynchro,0x08008B96)
	event.onmemoryexecute(WaitForPvP,0x080048CC)
	event.onmemoryexecute(ClockSync,0x08008810)
	event.onmemoryexecute(SendHand,0x08008B56)
	event.onmemoryexecute(SendStats,0x0800761A)
	event.onmemoryexecute(SetPlayerPorts,0x08008804)
	event.onmemoryexecute(ApplyRemoteInputs,0x08008800)
	event.onmemoryexecute(closebattle,0x08006958)
	event.onmemoryexecute(MainLoop,0x080002B4)

end



return