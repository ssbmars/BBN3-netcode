
--TO DO: verify specific ROM hash, both for vanilla files and patch files. This should be very helpful for smooth operation
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

		altjpfix = nil

		config_keys = {
			{username, "NetBattler"},
			{language, "ENG"},
			{use_translation_patches, "true"},
			{animate_menu, "true"},
			{remember_position, "true"},
			{remember_version, "true"},
			{last_pos_x, 1},
			{read_clipboard, "false"}}
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






while true do

	if isstartmenu then
		startmenu_mainloop()
	elseif isbbn3 then
		bbn3_netplay_mainloop()
	end

	emu.frameadvance()
end

return