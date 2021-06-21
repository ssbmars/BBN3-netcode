socket = require("socket.core")
client.displaymessages(false)


--JP text converter code
	--UTF8 -> Shift-JIS library sourced from AoiSaya, licensed under MIT
	--https://github.com/AoiSaya/FlashAir_UTF8toSJIS
	local UTF8toSJIS = require("UTF8toSjis/UTF8toSJIS")
	local UTF8SJIS_table = "UTF8toSjis/Utf8Sjis.tbl"

	local function init_tojp()
		fht = io.open(UTF8SJIS_table, "r")
	end
	local function close_tojp()
		fht:close()
	end
	local function tojp(str)
		if not altjpfix then return str end
		local strSJIS = UTF8toSJIS:UTF8_to_SJIS_str_cnv(fht, str)
		return strSJIS
	end
--end of JP text converter code


--TO DO: verify specific ROM hash, both for vanilla files and patch files. This should be very helpful for smooth operation
local function file_exists(name)
	if not name then 
		print("received nil argument for file_exists func")
		return false
	end
	--print("file_exists("..name..")")
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
end

local function write_file(filename, path)
	if not filename or not path then
		print("missing arg for write_file func")
		return
	end
	local file = io.open(filename, "w")
	file:write(path)
	file:close()
end

local function read_file(filename)
	if not filename then
		print("missing arg for read_file func")
		return
	end
	local f = assert(io.open(filename, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

local function opengame(path)
	if not path then 
		print("missing arg for opengame func")
		return
	end
	if userdata.get("last_openrom_path") == path then
		userdata.remove("last_openrom_path")
	else
		userdata.set("last_openrom_path", path)
		client.openrom(path)
	end
	client.openrom(path)
end


local function applypatch()

	if src_rom and bat_path then
		os.execute('cd /d %~dp0 & start "" ' .. bat_path .." ".. src_rom)
	else
		if not src_rom then
			print("src_rom arg is missing for applypatch func")
		end
		if not bat_path then
			print("bat_path arg is missing for applypatch func")
		end
	end
end


local function choosegame(game, patch)
	if file_exists(game) then --can be replaced with something that checks if the ROM md5 is valid (or check both)
		rom_path = game
		--forms.destroyall()
		--formopen = nil
	else
		bat_path = patch
		file_prompt = true
	end
end


void_path = "Netplay\\voidrom.gba"

BBN3_path = "Netplay\\BBN3 Online.gba"
BBN3_bat = '".\\patches\\patch BBN3.bat"'

BN6f_path = "Netplay\\BN6 Falzar Online.gba"
BN6f_bat = '".\\patches\\patch BN6f.bat"'

BN6g_path = "Netplay\\BN6 Gregar Online.gba"
BN6g_bat = '".\\patches\\patch BN6g.bat"'

EXE6g_path = "Netplay\\EXE6 Gregar Online.gba"
EXE6g_bat = '".\\patches\\patch EXE6g.bat"'

EXE6f_path = "Netplay\\EXE6 Falzar Online.gba"
EXE6f_bat = '".\\patches\\patch EXE6f.bat"'


GoldenSun = "BBN3\\notbbn3.gba"


local function startmenu()
	thisgame = emu.getsystemid()
	if thisgame ~= "NULL" then 
		menuopen = nil
		return 
	end
	menuopen = true
	rom_path = nil
	bat_path = nil
	src_rom = nil
end

local function bootvoidrom()
	local isrom = emu.getsystemid()
	if isrom == "NULL" then 
		choosegame(void_path, nil)
		if rom_path then
			if file_exists(rom_path) == true then
				opengame(rom_path)
			end
		end
	end
end
bootvoidrom()


-- cd /d %~dp0
-- flips -a "../patches/BBN3.bps" %1 "../BBN3/BBN3.gba"

function newform()
	local thisgame = emu.getsystemid()
	if thisgame ~= "NULL" then 
		thisgame = gameinfo.getromname()
		if thisgame ~= "voidrom" then
			formopen = nil
			return
		end
	end
	formopen = true
	rom_path = nil
	bat_path = nil
	src_rom = nil

	menu = forms.newform(300,80,"BBN3 Netplay",function()
		return nil end)
	local windowsize = client.getwindowsize()
	local form_xpos = (client.xpos() + 120*windowsize - 142)
	local form_ypos = (client.ypos() + 80*windowsize + 10)
	forms.setlocation(menu, form_xpos , form_ypos)

	button_one = forms.button(menu,"BBN3",function()
		choosegame(BBN3_path, BBN3_bat)
	end,70,10,58,24)

	button_two = forms.button(menu,"Isaac",function()
		choosegame(GoldenSun, nil)
	end,150,10,58,24)
end

local delaymenu = 20
while delaymenu > 0 do
	delaymenu = delaymenu - 1
	emu.frameadvance()
end
--newform()


local function configdefaults()
		username = "username"
		language = "language"
		use_translation_patches = "use_translation_patches"
		reduce_movement = "reduce_movement"
		remember_position = "remember_position"
		remember_version = "remember_version"
		last_pos_x = "last_pos_x"

		altjpfix = nil

		config_keys = {
			{username, "NetBattler"}, 
			{language, "ENG"}, 
			{use_translation_patches, "true"}, 
			{reduce_movement, "false"},
			{remember_position, "true"},
			{remember_version, "true"},
			{last_pos_x, 1}}
end
configdefaults()


local function initdatabase()
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
end
initdatabase()


local function saveconfig(name, val)
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

local function savepos(x, y)
	if not tangotime then return end
	SQL.writecommand("REPLACE INTO pos (pos_x, pos_y) VALUES("..x..","..y..");")
end

local function input(i,count)
	local press = nil
	local hold = nil
	local release = nil
	if not count then count = 0 end
	-- begin
	if ctrl[i] then
		if count >= 16 then
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

local function proc_ctrl()
	ctrl = joypad.get()
	--c_p means press, c_h means hold, c_r means release
	--cont_ means contiguous, for # of contiguous frames that a button is being pressed

	c_p_A, c_h_A, c_r_A, cont_A = input('A', cont_A)
	c_p_B, c_h_B, c_r_B, cont_B = input('B', cont_B)
	c_p_L, c_h_L, c_r_L, cont_L = input('L', cont_L)
	c_p_R, c_h_R, c_r_R, cont_R = input('R', cont_R)
	c_p_Start, c_h_Start, c_r_Start, cont_Start = input('Start', cont_Start)
	c_p_Select, c_h_Select, c_r_Select, cont_Select = input('Select', cont_Select)
	c_p_Up, c_h_Up, c_r_Up, cont_Up = input('Up', cont_Up)
	c_p_Down, c_h_Down, c_r_Down, cont_Down = input('Down', cont_Down)
	c_p_Left, c_h_Left, c_r_Left, cont_Left = input('Left', cont_Left)
	c_p_Right, c_h_Right, c_r_Right, cont_Right = input('Right', cont_Right)
end



	x_max = 240
	y_max = 160
	x_center = x_max/2 
	y_center = y_max/2
	-- "gui_Sprites\\menu\\.png"
	BBN3_img = "gui_Sprites\\menu\\title_BBN3.png"
	BN6_img = "gui_Sprites\\menu\\title_BN6.png"
	BN6f_img = "gui_Sprites\\menu\\title_BN6f.png"
	BN6g_img = "gui_Sprites\\menu\\title_BN6g.png"
	EXE6f_img = "gui_Sprites\\menu\\title_EXE6f.png"
	EXE6g_img = "gui_Sprites\\menu\\title_EXE6g.png"

	nameplate = "gui_Sprites\\menu\\nameplate.png"
	tooltips = "gui_Sprites\\menu\\tooltips.png"
	footer = "gui_Sprites\\menu\\footer.png"
	settings_footer = "gui_Sprites\\menu\\settings_footer.png"
	checkmark = "gui_Sprites\\menu\\checkmark.png"
	flags = "gui_Sprites\\menu\\flags.png"
	arrows = "gui_Sprites\\menu\\arrows.png"
	arrow_size = 9


	playername = config[username]


	--define the granular values in a different table for each game, then place those tables into a main table
	BBN3 = {{[1] = BBN3_img, [2] = BBN3_path, [3] = BBN3_bat, [4] = "BBN3", [5] = "BN3 Blue (English)"}}

	BN6 = { {[1] = BN6g_img, [2] = BN6g_path, [3] = BN6g_bat, [4] = "BN6 Gregar", [5] = "BN6 Gregar (US)"},
			{[1] = BN6f_img, [2] = BN6f_path, [3] = BN6f_bat, [4] = "BN6 Gregar", [5] = "BN6 Gregar (US)"}}

	EXE6 = { {[1] = EXE6g_img, [2] = EXE6g_path, [3] = EXE6g_bat, [4] = "EXE6 Gregar", [5] = "EXE6 Gregar (Japanese)"},
			 {[1] = EXE6f_img, [2] = EXE6f_path, [3] = EXE6f_bat, [4] = "EXE6 Falzar", [5] = "EXE6 Falzar (Japanese)"}}

	--define the order of the main table
	--item = {[1] = BBN3, [2] = BN6, [3] = EXE6 }
	item = {[1] = BBN3}


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


local function drawArrow(direction, arrow_timer, arrow_offset, arr_x, arr_y)
	local frame = arrow_timer
	local offset = arrow_offset

	local iserror = nil
	if type(direction) ~= 'number' then
		iserror = true
	elseif direction < 0 or direction > 3 then
		iserror = true
	end
	if iserror then
		if not drawArrowPrintedError then
			drawArrowPrintedError = true
			print('"direction" argument for drawArrow() must be an int value between 0-3')
		end
		return
	end

	local direc = math.floor(direction)
	
	if not frame then 
		frame = 0 
	end
	if not offset then
		if direc == 1 or direc == 3 then
			offset = -1
		else
			offset = 1
		end
	end

	frame = frame + 1
	if frame > 10 then
		frame = 0
		offset = -1 * offset
	end
	local arrow = nil
	local xoff = 0
	local yoff = 0


	if direc < 2 then
		yoff = offset
	else
		xoff = offset
	end

	local size = arrow_size
	gui.drawImageRegion(arrows, size * direc, 0, size, size, arr_x - size/2 + xoff, arr_y + yoff + size/2)
	return frame, offset
end

--mainmenu functions defined here
	local function mm_acceptbutton()
		if choice_anim or launch_anim or file_prompt then return end
		p_pos_x = pos_x
		p_pos_y = pos_y
	
		if c_r_A then
			launch_anim = true
	
		elseif c_r_Start then
			scene = scene + 1
	
		elseif c_p_Left or c_h_Left then
			if pos_x == 1 then
				pos_x = #item
			else
				pos_x = pos_x - 1
			end
	
		elseif c_p_Right or c_h_Right then
			if pos_x == #item then
				pos_x = 1
			else
				pos_x = pos_x + 1
			end
	
		elseif c_p_Up and item[pos_x][2] then
			if item[pos_x][pos_y+1] then
				pos_y = pos_y + 1
			else
				pos_y = 1
			end
	
		elseif c_p_Down and item[pos_x][2] then
			if item[pos_x][pos_y-1] then
				pos_y = pos_y - 1
			else
				pos_y = #item[pos_x]
			end
		end
	
	
		if (pos_x ~= p_pos_x) then
			choice_anim = true
			--populate a table entry with a record of the y position before switching x positions
			y_hist[p_pos_x] = pos_y
			if y_hist[pos_x] then 
				pos_y = y_hist[pos_x]
			else
				pos_y = 1
			end
		elseif (pos_y ~= p_pos_y) then
			choice_anim = true
		else
			choice_anim = nil
			gui.drawImage(item[pos_x][pos_y][1],0,0)
			--gui.drawText(x_max/2, 159, item[pos_x][pos_y][3], "white", nil, nil, nil, "middle","bottom")
			if item[pos_x][2] then
				--animate the arrow that prompts for vertical dpad presses when applicable
				mm_ab_arrow1, mm_ab_arroff1 = drawArrow(1, mm_ab_arrow1, mm_ab_arroff1, x_max/2, 129)
			end
		end
	end
	
	local function mm_change_title()
		if not choice_anim then return end
		if not ct_f then ct_f = 0 end
	
		local v,vx,vy,x,y
		local dur = 8
		local int = x_max / dur
	
		ct_f = ct_f + 1
	
		local function anim(cur,prev)
			if prev > cur then
				v = 1
			else
				v = -1
			end
			if math.abs(cur - prev) ~= 1 then
				v = -1*v
			end
			local xyz = (int * ct_f) * v
			return xyz, v
		end
	
		if pos_x ~= p_pos_x then
			x,vx = anim(pos_x,p_pos_x)
			y,vy = 0,0
		else
			x,vx = 0,0
			y = (int * ct_f) * (-1)
			vy = -1
		end
	
		if config[reduce_movement] == "false" then
			gui.drawImage(item[p_pos_x][p_pos_y][1],0 + x, 0 - y)
			gui.drawImage(item[pos_x][pos_y][1],(-vx * x_max) + x, (-vy * x_max) + y)
		else
			dur = 15
			gui.drawImage(item[pos_x][pos_y][1], 0, 0)
		end
	
		if ct_f >= dur then
			ct_f = nil
			choice_anim = nil
		end
	
		return ct_f
	end
	
	local function mm_launch_title()
		if not launch_anim then return end
		if not lt_f then lt_f = 0 end
		lt_f = lt_f + 1
	
		local int
		local dur = 8
		local x_int = x_max * 0.5 / dur
		local y_int = y_max * 0.5 / dur
	
		if lt_f > dur/2 then
			int = (dur - lt_f)/2
		else
			int = lt_f
		end
	
		x_int = x_int * int
		y_int = y_int * int
		local x = x_max - x_int
		local y = y_max - y_int
	
	
		if lt_f >= dur then
			lt_f = nil
			launch_anim = nil
	
			--save the menu position to the config
			if config[remember_version] == "true" then
				savepos(pos_x, pos_y)
			end
			if config[remember_position] == "true" then
				saveconfig(last_pos_x, pos_x)
			end
	
			--open the rom
			choosegame(item[pos_x][pos_y][2], item[pos_x][pos_y][3])
			if rom_path and file_exists(rom_path) == true then
				opengame(rom_path)
			end
		else	
			gui.drawImage(item[pos_x][pos_y][1],0 + x_int/2,0 + y_int/2, x, y)
		end
		return lt_f
	end

	local function mm_find_rom()
		if not file_prompt then return end
		if not fr_f then fr_f = 0 end
		fr_f = fr_f + 1
	
		if item[pos_x][pos_y][5] and type(item[pos_x][pos_y][5]) == 'string' then 
			mm_fr_romname = item[pos_x][pos_y][5]
		else
			mm_fr_romname = "the rom"
		end
	
		gui.drawText(x_max/2, 30, "Please locate a clean copy of", nil,nil, 12,"Arial", nil, "middle")
		gui.drawText(x_max/2, 50, mm_fr_romname, nil,nil, 12,"Arial", nil, "middle")
		--gui.drawText(x_max/2, 75, "• filename doesn't matter \n• must be a .gba file", nil,nil, 12,"Arial", nil, "middle")
	
		if fr_f > 60 then
			gui.drawText(x_max/2, 100, "Press A to continue", nil,nil, 12,"Arial", nil, "middle")
			if c_r_A then 
				mm_fr_continue = true
			end
		end
	
		if mm_fr_continue then
			file_prompt = nil
			fr_f = 0
			--locate rom file and apply patch
			src_rom = forms.openfile()
			if not(src_rom == nil or src_rom == "") then
				applypatch()
			end
		end
	
		mm_fr_continue = nil
		return fr_f
	end

--end of mainmenu functions

local function mainmenu()
	local x = emu.getsystemid()
	if x ~= "NULL" then 
		local y = gameinfo.getromname()
		if y ~= "voidrom" then
			return
		end
	end
	proc_ctrl()

	mm_acceptbutton()
	ct_f = mm_change_title()
	lt_f = mm_launch_title()
	fr_f = mm_find_rom()

	gui.drawImage(nameplate,0,0)
	gui.drawImage(footer,0,0)
	gui.drawImage(tooltips,0,0)

	gui.drawText(120, 22, playername, nil, nil, 16, "Calibri",nil, "middle","bottom")


	--gui.drawText(120, 30, "yeehaw", "white", nil, nil, nil, "middle","top")
end


--settingsmenu functions defined here
	--German translations provided by Zulleyy3
	--Japanese translations provided by exe_race
	--Spanish translations provided by 

	local function sm_init_settings()
		local l = config[language]
		init_tojp()
		--setting names
		username_name = {
		["ENG"] = "Change Name", 
		["ESP"] = "Cambiar Nombre", 
		["JP"] = tojp("名前の変更"),
		["GER"] = "Charakternamen ändern"
		}
		language_name = {
		["ENG"] = "Language", 
		["ESP"] = "Idioma", 
		["JP"] = tojp("言語"),
		["GER"] = "Overlay-Sprache"
		}
		use_translation_patches_name = {
		["ENG"] = "Use Translation Patches", 
		["ESP"] = "Usar Parches de traducción", 
		["JP"] = tojp("翻訳パッチの使用"),
		["GER"] = "(EN) Übersetzung anwenden"
		}
		reduce_movement_name = {
		["ENG"] = "Disable Menu Animations", 
		["ESP"] = "Desactivar animaciones del menú", 
		["JP"] = tojp("スライドアニメーション"),
		["GER"] = "Menüanimationen deaktivieren" 
		}
		remember_position_name = {
		["ENG"] = "Remember Position", 
		["ESP"] = "Mantener Posición", 
		["JP"] = tojp("最後にプレイしたゲームの保存"),
		["GER"] = "Letzte Menüposition speichern"
		}
		remember_version_name = {
		["ENG"] = "Remember Game Version", 
		["ESP"] = "Recordar Versión del Juego", 
		["JP"] = tojp("最後にプレイしたバージョンの保存"),
		["GER"] = "Letzte Spielversion speichern"
		}
	
		--descriptions
		username_desc = {
		["ENG"] = "Other netbattlers will see your \nname when you play online",
		["ESP"] = "Otros netbattlers verán tu nombre \ncuando juegues en línea", 
		["JP"] = tojp("ネット対戦時、対戦相手に表示される\n名前です"),
		["GER"] = "Andere Spieler werden deinen Namen \nsehen, wenn du gegen sie online spielst."
		}
		language_desc = {
		["ENG"] = "Change the language used by \nthe netplay interface",
		["ESP"] = "Cambia el lenguaje utilizado \npor la interfaz del juego",
		["JP"] = tojp("UIの言語を変更します"),
		["GER"] = "Ändere die Sprache, die in der \nNetplay Oberfläche benutzt wird."
		}
		use_translation_patches_desc = {
		["ENG"] = "Automatically apply translation \npatches based on your language \npreference (when available)",
		["ESP"] = "Aplicar Automáticamente traducción \nde parches basado en tu idioma",
		["JP"] = tojp("設定した言語に従って、自動的\nに翻訳パッチを適用します"),
		["GER"] = "Wende (falls verfügbar) automatisch\neine englische Übersetzung auf das\nSpiel an"
		}
		reduce_movement_desc = {
		["ENG"] = "Disable the sliding animation \nwhen moving through the game \nselection screen",
		["ESP"] = "Desactivar animación de deslizamiento \ncuando te mueves en la pantalla de \nselección de juego", 
		["JP"] = tojp("ゲーム選択時のスライドアニメーション\nをオフにします"),
		["GER"] = "Deaktiviere die Animationen bei\nNavigation des Auswahlbildschirms."
		}
		remember_position_desc = {
		["ENG"] = "Remember and return to your \nlast position in the game \nselection screen",
		["ESP"] = "Recordar y regresar a la última posición \nen la pantalla de selección de juego",
		["JP"] = tojp("最後に選択したゲームを記憶します"),
		["GER"] = "Merke und lade die letzte Position\nim Spielauswahlbildschirm."
		}
		remember_version_desc = {
		["ENG"] = "Remember the last selected \nversion for each game",
		["ESP"] = "Recordar la última versión \nseleccionada para cada juego",
		["JP"] = tojp("最後に選択したバージョンを記憶します"),
		["GER"] = "Merke die letzte ausgewählte\nVersion per Spiel."
		}

		close_tojp()

		--options
		-- "checkmark" , "flag", or "function"
		username_opt = {"function", {nil} }
		language_opt = {"flag" , {"ENG", "ESP", "JP", "GER"}}
		bool_opt = {"checkmark", {"true", "false"}}
	
	
		settings = {
			{username_name[l], username, username_opt, username_desc[l]},
			{language_name[l], language, language_opt, language_desc[l]},
			{use_translation_patches_name[l], use_translation_patches, bool_opt, use_translation_patches_desc[l]},
			{reduce_movement_name[l], reduce_movement, bool_opt, reduce_movement_desc[l]},
			{remember_position_name[l], remember_position, bool_opt, remember_position_desc[l]},
			{remember_version_name[l], remember_version, bool_opt, remember_version_desc[l]}
		}
	
		visible_settings = 5
	
	end
	sm_init_settings()
	
	
	local function sm_showicon(pointer, smx_off, smy_off)
		local opt_type = settings[pointer][3][1]
		local current = config[settings[pointer][2]]
		local xoff = 0
		local yoff = 0
		if opt_type == "checkmark" then
			if current == "true" then
				yoff= 1
				
			elseif current == "false" then
				yoff = 0
	
			else
				return
			end
			gui.drawImageRegion(checkmark, 0, yoff*10, 10, 10, smx_off, 3 + smy_off)
	
		elseif opt_type == "flag" then
			if pointer == smpos_y then
				xoff = 1
			else
				xoff = 0
			end
			
			for i=1, #settings[pointer][3][2] do
				if current == settings[pointer][3][2][i] then
					yoff = i - 1
					break
				end
			end
			gui.drawImageRegion(flags, xoff*15, yoff*9, 15, 9, smx_off - 2, 3 + smy_off)
	
		elseif opt_type == "function" then
	
		else
			return
		end
	
	end
	
	
	local function sm_changesetting(pointer)
		local opt_type = settings[pointer][3][1]
		local current = config[settings[pointer][2]]
	
		if opt_type == "checkmark" then
			if current == "true" then
				saveconfig(settings[pointer][2], "false")
			elseif current == "false" then
				saveconfig(settings[pointer][2], "true")
			else
				saveconfig(settings[pointer][2], "false")
			end
	
		elseif opt_type == "flag" then
			local limit = #settings[pointer][3][2]
			for i=1, limit do
				if current == settings[pointer][3][2][i] then
					--increment up by 1, or loop back to 1 if at the max value
					if i == limit then
						saveconfig(settings[pointer][2], settings[pointer][3][2][1])
					else
						saveconfig(settings[pointer][2], settings[pointer][3][2][i+1])
					end
					break
				end
			end

			sm_init_settings()
	
		elseif opt_type == "function" then
	
		else
			return
		end
	end
	
	
	local function sm_acceptbutton()
		if press_delay then return end
		if not smpos_y then smpos_y = 1 end
		if not smpos_x then smpos_x = 1 end
		if not listpos then listpos = 1 end
		p_smpos_y = smpos_y 
		p_smpos_x = smpos_x
		press_delay = 6
	
		if c_r_A then
			--toggle setting
			sm_changesetting(smpos_y)
	
		elseif c_r_Start or c_r_B then
			scene = scene - 1
			smpos_y = 1
			smpos_x = 1
			listpos = 1
	
		elseif c_p_Up or c_h_Up then
			if settings[smpos_y-1] then
				smpos_y = smpos_y - 1
	
				if listpos > 1 then
					listpos = listpos - 1
				end
			end
		elseif c_p_Down or c_h_Down then
			if settings[smpos_y+1] then
				smpos_y = smpos_y + 1
	
				if listpos < visible_settings then
					listpos = listpos + 1
				end
			end
		elseif c_p_Left then
	
		elseif c_p_Right then
	
		end
	
	
		if (smpos_y ~= p_smpos_y) then
			--moved vertically
		elseif (smpos_x ~= p_smpos_x) then
			--moved horizontally
		elseif c_r_A then
			--just here so press_delay gets set
		else
			--a place for idle things
			press_delay = nil
		end
	end
	
	local function sm_sm_pos(sm_sm_v)
		local value = (sm_sm_v*18) -7
		return value
	end
	
	local function sm_showmenu()
		if not listpos then listpos = 1 end

		for i=1, visible_settings do
			local offset = smpos_y + (i - listpos)
			if settings[offset] then
				local indent = 0
				if i == listpos then indent = 5 end
				if settings[offset] then
					gui.drawText(40+indent, sm_sm_pos(i), settings[offset][1],nil,nil,12, "Arial")
				end
				sm_showicon(offset, 25+indent, sm_sm_pos(i))
			end
			--draw arrows when a setting is out of view
			if i == 1 and settings[offset-1] then
				--draw the up arrow
				sm_sm_arrow2, sm_sm_arroff2 = drawArrow(0, sm_sm_arrow2, sm_sm_arroff2, x_max/2, -5)
			end
			if i == visible_settings and settings[offset+1] then
				--draw the down arrow
				sm_sm_arrow1, sm_sm_arroff1 = drawArrow(1, sm_sm_arrow1, sm_sm_arroff1, x_max/2, sm_sm_pos(visible_settings + 1))
			end
		end

		--draw the arrow that shows which setting is currently selected
		--gui.drawImage(arrow_right, 10, sm_sm_pos(listpos) + 2)
		sm_sm_arrow3, sm_sm_arroff3 = drawArrow(3, sm_sm_arrow3, sm_sm_arroff3, 10, sm_sm_pos(listpos) + 0)
	
		--display the description of the currently selected setting
		local description = settings[smpos_y][4]
		-- debug option to show where the best places to insert newlines are
			local middle = 1
			if middle == 1 then
				descdraw_x = x_max/2
				descdraw_origin = "middle"
			else
				descdraw_x = 10
				descdraw_origin = "left"
			end
		--end of debug stuff
		gui.drawText(descdraw_x, 115, description,nil,nil,12, "Arial", nil, descdraw_origin,"top")
		gui.drawImage(settings_footer, 0, 0)

		
		if press_delay then
			press_delay = press_delay - 1
			if press_delay < 1 then
				press_delay = nil
			end
		end
	end
--end of settingsmenu functions


local function settingsmenu()
	local x = emu.getsystemid()
	if x ~= "NULL" then 
		local y = gameinfo.getromname()
		if y ~= "voidrom" then
			return
		end
	end
	proc_ctrl()
	sm_acceptbutton()
	if scene ~= 2 then return end

	sm_showmenu()

end


-- Main Loop
while true do


	if scene == 1 then
		mainmenu()
	elseif scene == 2 then
		settingsmenu()
	else
		scene = 1
	end



--	if src_rom then
--		os.execute('cd /d %~dp0 & start "" ' .. bat_path .." ".. src_rom)
--		newform()
--	end
--
--	if rom_path then
--		if file_exists(rom_path) == true then
--			opengame(rom_path)
--		else
--			emu.frameadvance()
--		end
--		--newform()
--	end

	emu.frameadvance()
end

return