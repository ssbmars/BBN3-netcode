
--	TO DO: verify specific ROM hash, both for vanilla files and patch files. This should be very helpful for smooth operation
function file_exists(name)
	if not name then 
		print("received nil argument for file_exists func")
		return false
	end
	--print("file_exists("..name..")")
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
end

function configdefaults()
		username = "username"
		language = "language"
		use_translation_patches = "use_translation_patches"
		animate_menu = "animate_menu"
		remember_position = "remember_position"
		remember_version = "remember_version"
		last_pos_x = "last_pos_x"
		read_clipboard = "read_clipboard"
		delay_buffer = "delay_buffer"


		altjpfix = nil

		config_keys = {
			{username, "NetBattler"},
			{language, "ENG"},
			{use_translation_patches, "true"},
			{animate_menu, "true"},
			{remember_position, "true"},
			{remember_version, "true"},
			{last_pos_x, 1},
			{read_clipboard, "false"},
			{delay_buffer, 3}}
end

function initdatabase()
	if not file_exists("tango.db") then
		SQL.createdatabase("tango.db")
	end

	if file_exists("tango.db") then
		tangotime = true
		SQL.opendatabase("tango.db")

		SQL.writecommand("CREATE TABLE IF NOT EXISTS config_table (ID INTEGER PRIMARY KEY, setting_name TEXT UNIQUE, val);")
		SQL.writecommand("CREATE TABLE IF NOT EXISTS pos (ID INTEGER PRIMARY KEY, pos_x INTEGER UNIQUE, pos_y INTEGER);")


		--read the existing config data and populate the config file with defaults if data is missing

		config_raw = {}
		config_raw = SQL.readcommand("SELECT * FROM config_table;")
		--print(config_raw)
		config = {}

		--first, read the existing data and check whether there's any missing data
		for i=0, #config_keys do
			if config_raw["setting_name "..i] and config_raw["val "..i] then
				config[config_raw["setting_name "..i]] = config_raw["val "..i]
			end
		end

		--if there is any missing data, populate the database with default values for the missing data
		for i=1, #config_keys do
			if not config[config_keys[i][1]] then
				--print(config_keys[i][1])
				SQL.writecommand("REPLACE INTO config_table (setting_name, val) VALUES(".."'".. config_keys[i][1] .."'"..",".."'".. config_keys[i][2] .."'"..");")
			end
		end

		--load the updated database into the table
		config = {}
		config_raw = SQL.readcommand("SELECT * FROM config_table;")
		for i=0, #config_keys do
			if config_raw["setting_name "..i] and config_raw["val "..i] then
				config[config_raw["setting_name "..i]] = config_raw["val "..i]
			end
		end

	else
		print("unable to create config file")
		tangotime = false
		config = {}
		for i=1, #config_keys do
			config[config_keys[i][1]] = config_keys[i][2]
		end
	end


	playername = config[username]

	if startmenu_open then
		y_hist = {}
		local pos_tbl = {}
		pos_tbl = SQL.readcommand("SELECT pos_x, pos_y FROM pos;")
		for i=0, #item do
			if pos_tbl["pos_x "..i] then
				y_hist[tonumber(pos_tbl["pos_x "..i])] = tonumber(pos_tbl["pos_y "..i])
			end
		end
		--	print(y_hist)
		if config[last_pos_x] then
			pos_x = tonumber(config[last_pos_x])
		else
			pos_x = 1
		end
		if y_hist[pos_x] then
			pos_y = tonumber(y_hist[pos_x])
		else
			pos_y = 1
		end
	end
end

function saveconfig(name, val)
	if val then
		config[name] = val
	end
	if not tangotime then return end
	SQL.writecommand("REPLACE INTO config_table (setting_name, val) VALUES(".."'".. name .."'"..",".."'".. config[name] .."'"..");")
	--update config table in memory
	config = {}
	config_raw = SQL.readcommand("SELECT * FROM config_table;")
	for i=0, #config_keys do
		if config_raw["setting_name "..i] and config_raw["val "..i] then
			config[config_raw["setting_name "..i]] = config_raw["val "..i]
		end
	end
end

--	load different things based on the rom that's currently open

	local function tango_loadstartmenu()
		require "startmenu"
		isstartmenu = true
	end
	
	local function tango_loadBBN3()
		require "bbn3_netplay"
		init_bbn3_netplay()
		isbbn3 = true
	end
	
	local function tango_checkstate()
		local isrom = emu.getsystemid()
		if isrom == "NULL" then 
			tango_loadstartmenu()
			init_voidrom()
		else
			winapi = require("winapi")
			configdefaults()
			initdatabase()
	
			local thisgame = gameinfo.getromname()
			if thisgame == "voidrom" then
				tango_loadstartmenu()
				init_startmenu()
			elseif thisgame == "BBN3 Online" or thisgame == "BBN3 Online Spanish" then
				--print(thisgame)
				tango_loadBBN3()
			end
		end
	end
	tango_checkstate()
-- end of state check functions


--	menu functions

	function inputs(ii,count)
		local press = nil
		local hold = nil
		local release = nil
		if not count then count = 0 end
		-- begin
		if preproc_ctrl[ii] then
			if count >= 12 then -- this number is how many frames to hold down a button before it counts as held
				hold = true
			else
				if count == 0 then
					press = true
				end
				count = count + 1
			end
		else
			if count > 0 then
				release = true
			end
			count = 0
		end
		return press, hold, release, count
	end
	
	function proc_ctrl()
		preproc_ctrl = joypad.get()
		--c_p means press, c_h means hold, c_r means release
		--cont_ means contiguous, for # of contiguous frames that a button is being pressed
	
		c_p_A, c_h_A, c_r_A, cont_A = inputs('A', cont_A)
		c_p_B, c_h_B, c_r_B, cont_B = inputs('B', cont_B)
		c_p_L, c_h_L, c_r_L, cont_L = inputs('L', cont_L)
		c_p_R, c_h_R, c_r_R, cont_R = inputs('R', cont_R)
		c_p_Start, c_h_Start, c_r_Start, cont_Start = inputs('Start', cont_Start)
		c_p_Select, c_h_Select, c_r_Select, cont_Select = inputs('Select', cont_Select)
		c_p_Up, c_h_Up, c_r_Up, cont_Up = inputs('Up', cont_Up)
		c_p_Down, c_h_Down, c_r_Down, cont_Down = inputs('Down', cont_Down)
		c_p_Left, c_h_Left, c_r_Left, cont_Left = inputs('Left', cont_Left)
		c_p_Right, c_h_Right, c_r_Right, cont_Right = inputs('Right', cont_Right)
	end
	
	
	--	universal online comm menu

	function do_nothing()
		-- wow it's nothing
	end

	function vistest()
		gui.drawText(60, 50, "searching for players",nil,nil,12, "Arial")
	end

	function ocm_vis_copycode()
		if new_code then
			local field_len = string.len(new_code) 
			field_len = (field_len * 8) + 8
			gui.drawImage("gui_Sprites\\temp\\clipboard.png", 9, 75)
			gui.drawRectangle(27, 75, field_len, 16, 0xFF111111, 0xFF212121)
			gui.drawText(30, 75, new_code,nil,nil,12)
			if c_p_A then
				if not vis_cc_apress then
					vis_cc_apress = true
					vis_cc_a_timer = 50
					winapi.set_clipboard(new_code)
				end
			end
		end
		if vis_cc_apress then
			if vis_cc_a_timer > 43 then
				gui.drawImage("gui_Sprites\\temp\\pressed_A.png", 9, 100)
			else
				gui.drawImage("gui_Sprites\\temp\\button_A.png", 9, 100)
			end
			gui.drawText(28, 100, "copied",nil,nil,12, "Arial")
			if vis_cc_a_timer > 0 then
				vis_cc_a_timer = vis_cc_a_timer - 1
			else
				vis_cc_apress = nil
			end
		else
			gui.drawImage("gui_Sprites\\temp\\button_A.png", 9, 100)
			gui.drawText(28, 100, "copy to clipboard",nil,nil,12, "Arial")
		end
	end

	function ocm_server_reset()
		debug("ocm_server_reset()")
		--mm:close_session()
		mm:close()
		--mm:clear_session()

		mm_printedhostcode = nil
		mm_requested_new_session = nil
		mm_requested_join = nil
		ocm_om_firstjoin = nil
		ocm_om_waiting = nil
		ocm_om_hosted = nil
		new_code = nil
		debug_in_openmatch = nil

		resetnet()
		StartSearch()
	end

	function ocm_server_host(isprivate)
		if SESSION_CODE ~= "" then return end

		if not mm_requested_new_session then
			mm_requested_new_session = true
			new_code = nil
			mm:create_session(isprivate)
			debug("requested new session")
		end
		if not mm_polltime then mm_polltime = 1 end

		local h_new_sesh = ""

		if mm_polltime == 1 then
			mm_polltime = 2
			mm:poll()
		else
			mm_polltime = 1
		end
		
		h_new_sesh = mm:get_session()

		if string.len(h_new_sesh) ~= 0 then
			new_code = h_new_sesh
			if isprivate and not mm_printedhostcode then
				print(new_code)
				mm_printedhostcode = true
			end
		end


		if not new_code then
			debugdraw(10,90, "getting session")
		elseif debug_in_openmatch then
			debugdraw(10,90, new_code)
		end

		if new_code and connectedclient == "" then
			local new_addr = ""
			new_addr = mm:get_remote_addr()
			mm:poll()
			if new_addr ~= "" then
				debug("host: new_addr = "..new_addr)
				debug("host: new_code = "..new_code)
				PLAYERNUM = 1
				--connectedclient = new_addr	-- maybe don't do this, it breaks things
				mm_requested_new_session = nil
				SESSION_CODE = new_code
			elseif debug_in_openmatch then
				debugdraw(10,100, "no joins yet")
			end
		else
			debugdraw(10,100, "hmmm")
		end

	end

	function ocm_server_join(private)
		if SESSION_CODE ~= "" then return end

		if not mm_requested_join then 
			local password
			if private then
				local input = winapi.get_clipboard()
				if type(input) == "string" then
					password = string.gsub(input, "%s+", "")
				end
			end
			mm:join_session(password)
			mm_requested_join = true
			if password then
				debug("join request ("..password..")")
			else
				debug("join request")
			end
			mm:poll()
		end
		local j_new_sesh = ""
		j_new_sesh = mm:get_remote_addr()
		mm:poll()
		if j_new_sesh ~= "" then
			SESSION_CODE = j_new_sesh
			mm_requested_join = nil
			PLAYERNUM = 2
		end
	end

	function ocm_openmatch()
		if SESSION_CODE ~= "" then return end
		if not ocm_om_firstjoin then
			ocm_om_waiting = 90
			ocm_om_firstjoin = true
			debug_in_openmatch = true
		end
		if ocm_om_hosted then
			ocm_server_host()
			debugdraw(5, 130, "hosting")
		else
			if ocm_om_waiting > 0 then
				ocm_server_join()
				ocm_om_waiting = ocm_om_waiting -1
				debugdraw(5, 130, "join attempt")
			else
				ocm_om_hosted = true
				resetnet()
			end
		end
		if SESSION_CODE ~= "" then
			preconnect()
			ocm_om_firstjoin = nil
			ocm_om_waiting = nil
			ocm_om_hosted = nil
			debug("playernum: ".. PLAYERNUM)
		end
	end

	function exit_stophost()
		--mm:close_session()
		--resetnet()
		ocm_server_reset()
	end

	--exit_ocm() has game-specific memory writes, so it's currently defined by the game-specific script


	-- It's safe to call this function without supplying any arguments.
	-- But if any arg is defined, then they need to all be defined.
	-- Render = true or nil ; ii & optioncount should be taken from ocm_showmenu()
	function ocm_get_clipboard(render, ii, optioncount)
		-- Reads the clipboard and displays it on the screen. (Can only read and display text).
		--	On first run it immediately reads the clipboard. From then on, it counts down 
		--	the frames and reads the clipboard again every X frames.
		-- (This function is intended purely for fetching info to display to the user.)
		local function getstring()
			local clippy = winapi.get_clipboard()
			if type(clippy) == "string" then
				clippy = string.gsub(clippy, "%s+", "")
			else
				clippy = ""
			end
			return clippy
		end

		if not getclip_contents then
			getclip_contents = getstring()
		end
		if not getclip_updater then getclip_updater = 90 end

		if getclip_updater > 0 then
			getclip_updater = getclip_updater - 1
		else
			getclip_updater = 120
			getclip_contents = getstring()
		end

		if render then
			--gui.drawImage("gui_Sprites\\menu\\settings_footer.png",0, 16 - ocm_itempos(optioncount))
			local field_len = string.len(getclip_contents) 
			field_len = (field_len * 8) + 8
			gui.drawImage("gui_Sprites\\temp\\clipboard.png", 9, ocm_itempos(optioncount+1) + 3)
			gui.drawRectangle(27, ocm_itempos(optioncount+1)+3, field_len, 16, 0xFF111111, 0xFF212121)
			gui.drawText(30, ocm_itempos(optioncount+1) + 3, getclip_contents,nil,nil,12)
		end

		return getclip_contents
	end


	function ocm_hover_desc(ii, optioncount)
		-- debug option to show where the best places to insert newlines are
			local middle = 1
				local descdraw_x
				local descdraw_origin
			if middle == 1 then
				descdraw_x = 120
				descdraw_origin = "middle"
			else
				descdraw_x = 10
				descdraw_origin = "left"
			end
		--end of debug stuff
		local desc_text = ocm_menu_opt[comm_menu_scene][ii].tabledesc
		gui.drawText(descdraw_x, ocm_itempos(optioncount+2), desc_text,nil,nil,12, "Arial",nil, descdraw_origin)
	end

	function ocm_showclipboard(ii, optioncount)
		ocm_get_clipboard(true, ii, optioncount)
		ocm_hover_desc(ii, optioncount)
	end


	function init_ocm()

		ocm_ready = true
		ocm_pos_y = 1

		local l = config[language]

		-- menu option names
			opt_matchmaking_name = {
					["ENG"] = "Open Matchmaking",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
	
				opt_password_name = {
					["ENG"] = "Private NetBattle",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
	
				opt_host_code_name = {
					["ENG"] = "Host Session",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
	
				opt_join_code_name = {
					["ENG"] = "Join Session",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
	
				opt_direct_name = {
					["ENG"] = "Direct IP",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
	
				opt_host_name = {
					["ENG"] = "Host match",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
	
				opt_client_name = {
					["ENG"] = "Join as Client",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
	
			ocm_menu_name = {
				["ENG"] = "Online Comm Menu",
				["ESP"] = "",
				["JP"] = "",
				["GER"] = "",
			}
		-- close

		-- descriptive text
			opt_host_code_hover = {
					["ENG"] = "Creates a private session code.\nSend the code to the other player.",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
				opt_host_code_hover = opt_host_code_hover[l]

			opt_join_code_hover = {
					["ENG"] = "Join a private session. Uses code\ncopied from clipboard.",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
				opt_join_code_hover = opt_join_code_hover[l]

			opt_host_hover = {
					["ENG"] = "Does not use the matchmaking server.\nHost using direct IP connection.\nRequires LAN or portforwarding.",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
				opt_host_hover = opt_host_hover[l]

			opt_client_hover = {
					["ENG"] = "Does not use the matchmaking server.\nConnect to the IP address of the host.\nUses IP copied from clipboard.",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
				opt_client_hover = opt_client_hover[l]

			_hover = {
					["ENG"] = "",
					["ESP"] = "",
					["JP"] = "",
					["GER"] = "",
				}
				_hover = _hover[l]


		-- close


		-- explanation of variable definitions within these tables that are used for the comm menu
			--[[
			FUNCTION TYPES AND WHAT THEY DO:
				each of these functions is optional! If they're undefined, it will simply not attempt to run them.

			hoverfunc runs every frame when the cursor is placed over an option. 
				These functions need to be pretty lightweight, and are primarily for displaying extra info specific to the option.
				(define this in a menu option, not in a menu scene!)

			clickfunc runs once at the moment that an option in the menu is chosen.
				this can be handy for resetting or initializing data right before entering a menu scene that makes use of said data.
				(define this in the menu scene)

			scenefunc runs every frame while in the respective scene. This function is meant for code that does "backend" things.
				(define this in the menu scene)

			visfunc is the same idea as scenefunc, but it's meant for code that just does visual stuff, rather than "backend" logic.
				(define this in the menu scene)


			TABLE VARIABLES
				FOR MENU OPTIONS:

			]]
		-- end of variable definition explanations

		-- these are the "menu options" mentioned above
		-- root menu
		opt_matchmaking = {
			tablename = opt_matchmaking_name[l], 
			tabledest = 2,
		}
		opt_password = {
			tablename = opt_password_name[l], 
			tabledest = 3,
		}
		opt_direct = {
			tablename = opt_direct_name[l], 
			tabledest = 4,
		}
		-- private menu
		opt_join_code = {
			tablename = opt_join_code_name[l], 
			tabledest = 5,
			hoverfunc = ocm_showclipboard,
			tabledesc = opt_join_code_hover,
		}
		opt_host_code = {
			tablename = opt_host_code_name[l], 
			tabledest = 6,
			hoverfunc = ocm_hover_desc,
			tabledesc = opt_host_code_hover,
		}
		-- direct ip menu
		opt_host = {
			tablename = opt_host_name[l], 
			tabledest = 7,
			hoverfunc = ocm_hover_desc,
			tabledesc = opt_host_hover,
		}
		opt_client = {
			tablename = opt_client_name[l], 
			tabledest = 8,
			hoverfunc = ocm_showclipboard,
			tabledesc = opt_client_hover,
		}

		-- these are the "menu scenes" mentioned in the above explanation
		-- comm_menu_scene is the key for the first index, which gets defined by tabledest
		ocm_menu_opt = {
			[1] = {	-- root of menu
				opt_matchmaking, 
				opt_password, 
				opt_direct, 
				scenename = ocm_menu_name[l],
				exitfunc = exit_ocm
				}, 
			-- open matchmaking function
			[2] = { 
				--clickfunc = ocm_server_reset,
				scenefunc = ocm_openmatch, 
				visfunc = vistest, 
				scenename = opt_matchmaking_name[l],
				exitfunc = exit_stophost,
				exitdest = 1,
				exitcursor = 1
				},
			-- private match menu list
			[3] = {
				opt_host_code,
				opt_join_code,
				scenename = opt_password_name[l],
				exitdest = 1,
				exitcursor = 2
				},
			-- direct ip connection menu list
			[4] = { 
				opt_host, 
				opt_client, 
				scenename = opt_direct_name[l],
				exitdest = 1,
				exitcursor = 3
				},
			-- private match join with code function
			[5] = {
				--clickfunc = ocm_server_reset,
				scenefunc = ocm_server_join, 
				scenefunc_arg = true,
				scenename = opt_join_code_name[l],
				exitfunc = exit_stophost,
				exitdest = 3,
				exitcursor = 2
				},
			-- private match host & generate new code function
			[6] = { 
				--clickfunc = ocm_server_reset,
				scenefunc_arg = true,
				scenefunc = ocm_server_host, 
				visfunc = ocm_vis_copycode,
				scenename = opt_host_code_name[l],
				exitfunc = exit_stophost,
				exitdest = 3,
				exitcursor = 1
				},
			-- direct ip host match function
			[7] = {
				clickfunc_arg = true, 
				clickfunc = ocm_directip
				},
			-- direct ip connect as client function
			[8] = {
				clickfunc_arg = false, 
				clickfunc = ocm_directip
				}
		}
	end

	function ocm_acceptbutton()
		if ocm_choice_anim then return end
		if not ocm_pos_y then ocm_pos_y = 1 end
		p_ocm_pos_y = ocm_pos_y

		if c_r_A then
			if ocm_menu_opt[comm_menu_scene][ocm_pos_y] then
				if ocm_menu_opt[comm_menu_scene][ocm_pos_y].tabledest then
						ocm_choice_anim = true
						comm_menu_scene = ocm_menu_opt[comm_menu_scene][ocm_pos_y].tabledest
						ocm_pos_y = 1
					if ocm_menu_opt[comm_menu_scene].clickfunc then
						local arg = ocm_menu_opt[comm_menu_scene].clickfunc_arg
						local dofunc = ocm_menu_opt[comm_menu_scene].clickfunc(arg)
					end
				end
			end

		elseif c_r_B then
			if not ocm_B_lockout then
				if ocm_menu_opt[comm_menu_scene].exitfunc then
					local dofunc = ocm_menu_opt[comm_menu_scene].exitfunc()
				end
				if ocm_menu_opt[comm_menu_scene].exitdest then
					if ocm_menu_opt[comm_menu_scene].exitcursor then
						ocm_pos_y = ocm_menu_opt[comm_menu_scene].exitcursor
					else
						ocm_pos_y = 1
					end
					comm_menu_scene = ocm_menu_opt[comm_menu_scene].exitdest
					ocm_choice_anim = true
				end
			else
				-- stop searching for matches?
			end

		elseif c_p_Up or c_h_Up then
			if ocm_menu_opt[comm_menu_scene][ocm_pos_y - 1] then
				ocm_pos_y = ocm_pos_y - 1
			else
				ocm_pos_y = #ocm_menu_opt[comm_menu_scene]
			end

		elseif c_p_Down or c_h_Down then
			if ocm_menu_opt[comm_menu_scene][ocm_pos_y + 1] then
				ocm_pos_y = ocm_pos_y + 1
			else
				ocm_pos_y = 1
			end

		end
	
	end
	
	function ocm_make_choice()
		if not ocm_choice_anim then return end
		
		ocm_choice_anim = nil
	end

	function ocm_itempos(arg)
		local value = (arg*22)+10

		return value
	end

	function ocm_showmenu()

		--gui.drawImage("gui_Sprites/temp/test_bg.png",0,0)
		gui.drawImage("gui_Sprites/temp/testmenu.png",0,0)
		gui.drawText(20, -1, ocm_menu_opt[comm_menu_scene].scenename)

		-- menu options are the only table entries that aren't named variables, so they're the only
		-- items in the table that will cause the table to return a nonzero value if you read #table
		local optioncount = #ocm_menu_opt[comm_menu_scene]
		if optioncount > 0 then
			for ii=1, optioncount do
				if ii == ocm_pos_y then
					-- put stuff in here to draw the highlighted option differently
					gui.drawImageRegion("gui_Sprites/cobber.png", 0,0,26,26, 15, ocm_itempos(ii) - 7)
					-- perform a hover function if defined
					sm_hoverfunc = ocm_menu_opt[comm_menu_scene][ii].hoverfunc
					if sm_hoverfunc then
						local dofunc = sm_hoverfunc(ii, optioncount)
						-- ii gets passed along as an arg so that the function can know the relative position
						-- of the highlighted option. And optioncount is context for if the func
						-- needs to display something below the list of options
					end
				end
				-- render the name of the table option
				local sm_tablename = ocm_menu_opt[comm_menu_scene][ii].tablename
				if sm_tablename then
					gui.drawText(43, ocm_itempos(ii), sm_tablename, nil,nil,12, "Arial")
				end
			end
		end

		if ocm_menu_opt[comm_menu_scene].visfunc then
			--local arg = ocm_menu_opt[comm_menu_scene].visfunc_arg
			local dofunc = ocm_menu_opt[comm_menu_scene].visfunc()
		end

	end

	function ocm_run_scenefunc()
		if ocm_menu_opt[comm_menu_scene].scenefunc then
			local arg = ocm_menu_opt[comm_menu_scene].scenefunc_arg
			local dofunc = ocm_menu_opt[comm_menu_scene].scenefunc(arg)
		end
	end

	function online_comm_menu()
		if not comm_menu_scene then comm_menu_scene = 1 end
		if not ocm_ready then init_ocm() end
		proc_ctrl()
	
		ocm_acceptbutton()
		ocm_make_choice()
		ocm_run_scenefunc()
		ocm_showmenu()
	end
--	end of menu functions

while true do

	if isstartmenu then
		startmenu_mainloop()
	elseif isbbn3 then
		bbn3_netplay_mainloop()
	end

	emu.frameadvance()
end

return