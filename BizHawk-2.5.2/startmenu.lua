startmenu_open = true
socket = require("socket.core")
client.displaymessages(false)
emu.limitframerate(true)
client.speedmode(100)
client.enablerewind(false)
client.frameskip(0)

--JP text converter code
	--UTF8 -> Shift-JIS library sourced from AoiSaya, licensed under MIT
	--https://github.com/AoiSaya/FlashAir_UTF8toSJIS
	UTF8toSJIS = require("UTF8toSjis/UTF8toSJIS")
	UTF8SJIS_table = "UTF8toSjis/Utf8Sjis.tbl"

	function init_tojp()
		fht = io.open(UTF8SJIS_table, "r")
	end
	function close_tojp()
		fht:close()
	end
	function tojp(str)
		if not altjpfix then return str end
		local strSJIS = UTF8toSJIS:UTF8_to_SJIS_str_cnv(fht, str)
		return strSJIS
	end
--end of JP text converter code


function write_file(filename, path)
	if not filename or not path then
		print("missing arg for write_file func")
		return
	end
	local file = io.open(filename, "w")
	file:write(path)
	file:close()
end

function read_file(filename)
	if not filename then
		print("missing arg for read_file func")
		return
	end
	local f = assert(io.open(filename, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

function opengame(path)
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


function applypatch()

	if src_rom and bat_path then
		os.execute("cd /d %~dp0 & start \"\" " .. bat_path .." ".. src_rom)
	else
		if not src_rom then
			print("src_rom arg is missing for applypatch func")
		end
		if not bat_path then
			print("bat_path arg is missing for applypatch func")
		end
	end
end



function choosegame(game, patch)
	if file_exists(game) then --can be replaced with something that checks if the ROM md5 is valid (or check both)
		rom_path = game
		--forms.destroyall()
		--formopen = nil
	else
		bat_path = patch
		file_prompt = true
	end
end



function startmenu()
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

function bootvoidrom()
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



-- cd /d %~dp0
-- flips -a "../patches/BBN3.bps" %1 "../BBN3/BBN3.gba"

--[[function newform()
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
end]]

--local delaymenu = 20
--while delaymenu > 0 do
--	delaymenu = delaymenu - 1
--	emu.frameadvance()
--end
--newform()



function savepos(x, y)
	if not tangotime then return end
	SQL.writecommand("REPLACE INTO pos (pos_x, pos_y) VALUES("..x..","..y..");")
end

function inputs(i,count)
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

function proc_ctrl()
	ctrl = joypad.get()
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



function initstartmenudata()
	void_path = "Netplay\\voidrom.gba"
	
	BBN3_path = "Netplay\\BBN3 Online.gba"
	BBN3_bat = ".\\patches\\patch_BBN3.bat"
	
	BN6f_path = "Netplay\\BN6 Falzar Online.gba"
	BN6f_bat = '".\\patches\\patch_BN6f.bat"'
	
	BN6g_path = "Netplay\\BN6 Gregar Online.gba"
	BN6g_bat = '".\\patches\\patch_BN6g.bat"'
	
	EXE6g_path = "Netplay\\EXE6 Gregar Online.gba"
	EXE6g_bat = '".\\patches\\patch_EXE6g.bat"'
	
	EXE6f_path = "Netplay\\EXE6 Falzar Online.gba"
	EXE6f_bat = '".\\patches\\patch_EXE6f.bat"'
	
	
	--GoldenSun = "BBN3\\notbbn3.gba"


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



	--define the granular values in a different table for each game, then place those tables into a main table
	BBN3 = {{[1] = BBN3_img, [2] = BBN3_path, [3] = BBN3_bat, [4] = "BBN3", [5] = "BN3 Blue (English)"}}

	BN6 = { {[1] = BN6g_img, [2] = BN6g_path, [3] = BN6g_bat, [4] = "BN6 Gregar", [5] = "BN6 Gregar (US)", [6] = "EXE6 Gregar (Japanese)"},
			{[1] = BN6f_img, [2] = BN6f_path, [3] = BN6f_bat, [4] = "BN6 Gregar", [5] = "BN6 Gregar (US)", [6] = "EXE6 Falzar (Japanese)"}}

	EXE6 = { {[1] = EXE6g_img, [2] = EXE6g_path, [3] = EXE6g_bat, [4] = "EXE6 Gregar", [5] = "EXE6 Gregar (Japanese)"},
			 {[1] = EXE6f_img, [2] = EXE6f_path, [3] = EXE6f_bat, [4] = "EXE6 Falzar", [5] = "EXE6 Falzar (Japanese)"}}

	--define the order of the main table
	--item = {[1] = BBN3, [2] = BN6, [3] = EXE6 }
	item = {[1] = BBN3}
end


function drawArrow(direction, arrow_timer, arrow_offset, arr_x, arr_y)
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
	function mm_acceptbutton()
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
	
	function mm_change_title()
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
	
		if config[animate_menu] == "true" then
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
	
	function mm_launch_title()
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

	function mm_find_rom()
		if not file_prompt then return end
		if not fr_f then fr_f = 0 end
		fr_f = fr_f + 1
	
		if item[pos_x][pos_y][5] and type(item[pos_x][pos_y][5]) == 'string' then 
			mm_fr_romname = item[pos_x][pos_y][5]
		else
			--error handling: display a default string if string reference would be nil (avoids fatal error)
			mm_fr_romname = "the rom"
		end
	
		gui.drawText(x_max/2, 40, str_romprompt1, nil,nil, 12,"Arial", nil, "middle")
		gui.drawText(x_max/2, 60, mm_fr_romname, nil,nil, 12,"Arial", nil, "middle")
		--gui.drawText(x_max/2, 75, "• filename doesn't matter \n• must be a .gba file", nil,nil, 12,"Arial", nil, "middle")
	
		if fr_f > 60 then
			gui.drawText(x_max/2, 100, str_romprompt2, nil,nil, 12,"Arial", nil, "middle")
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
				--process the string so it doesn't error from spaces in the name
				src_rom = "\"".. src_rom .. "\""
				applypatch()
			end
		end
	
		mm_fr_continue = nil
		return fr_f
	end
--end of mainmenu functions

function mainmenu()
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

	
	function sm_changename()
		if not printednamechangemsg then
			print("name change is not yet implemented")
			printednamechangemsg = true
		end
		return


	--	local validkey = {
	--	["A"] = "a",["B"] = "b",["C"] = "c",["D"] = "d",["E"] = "e",["F"] = "f",["G"] = "g",["H"] = "h"
	--}
	--	["I" = "i"},["J" = "j"},["K" = "k"},["L" = "l"},["M" = "m"},["N" = "n"},["O" = "o"},["P" = "p"},["Q" = "q"},
	--	["R" = "r"},["S" = "s"},["T" = "t"},["U" = "u"},["V" = "v"},["W" = "w"},["X" = "x"},["Y" = "y"},["Z" = "z"},
	--	["Shift+A" = ""},["Shift+B" = ""},["Shift+C" = ""},["Shift+D" = ""},["Shift+E" = ""},
	--	["Shift+F" = ""},["Shift+G" = ""},["Shift+H" = ""},["Shift+I" = ""},
	--	["Shift+J" = ""},["Shift+K" = ""},["Shift+L" = ""},["Shift+M" = ""},
	--	["Shift+N" = ""},["Shift+P" = ""},["Shift+Q" = ""},["Shift+R" = ""},
	--	{"Shift+S" = ""},["Shift+T" = ""},["Shift+U" = ""},["Shift+V" = ""},
	--	["Shift+W" = ""},["Shift+X" = ""},["Shift+Y" = ""},["Shift+Z" = ""},
	--	{"Minus" = ""},{"Shift+Minus" = ""}
	--}



		--[[while true do
			local pressedbutton = input.get()
			if pressedbutton["A"] == true then --this does work for the specific letter
				print(pressedbutton)
			end

			--if validkey[] then
			--	print(validkey[])
			--end

			emu.frameadvance()
		end]]
	end


	--German translations provided by Zulleyy3
	--Japanese translations provided by exe_race
	--Spanish translations provided by PachecoElSublime & Pit Rjul

	function sm_init_settings()
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
		animate_menu_name = {
		["ENG"] = "Enable Menu Animations", 
		["ESP"] = "Activar animaciones del menú",
		["JP"] = tojp("スライドアニメーション"),
		["GER"] = "Menüanimationen aktivieren" 
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
		["ESP"] = "Aplicar automáticamente parches \nde traducción basado en tu idioma",
		["JP"] = tojp("設定した言語に従って、自動的\nに翻訳パッチを適用します"),
		["GER"] = "Wende (falls verfügbar) automatisch\neine englische Übersetzung auf das\nSpiel an"
		}
		animate_menu_desc = {
		["ENG"] = "Enable the sliding animation \nwhen moving through the game \nselection screen",
		["ESP"] = "Activar animación de deslizamiento \ncuando te mueves en la pantalla de \nselección de juego", 
		["JP"] = tojp("ゲーム選択時のスライドアニメーション\nをオンにします"),
		["GER"] = "Aktiviere die Animationen bei\nNavigation des Auswahlbildschirms."
		}
		remember_position_desc = {
		["ENG"] = "Remember and return to your \nlast position in the game \nselection screen",
		["ESP"] = "Mantener y regresar a la última posición \nen la pantalla de selección de juego",
		["JP"] = tojp("最後に選択したゲームを記憶します"),
		["GER"] = "Merke und lade die letzte Position\nim Spielauswahlbildschirm."
		}
		remember_version_desc = {
		["ENG"] = "Remember the last selected \nversion for each game",
		["ESP"] = "Mantener la última versión \nseleccionada para cada juego",
		["JP"] = tojp("最後に選択したバージョンを記憶します"),
		["GER"] = "Merke die letzte ausgewählte\nVersion per Spiel."
		}


		--options
		-- "checkmark" , "flag", or "function"
		username_opt = {"function", tablefunc = sm_changename }
		language_opt = {"flag" , {"ENG", "ESP", "JP", "GER"}}
		bool_opt = {"checkmark", {"true", "false"}}
	
	
		settings = {
			{username_name[l], username, username_opt, username_desc[l]},
			{language_name[l], language, language_opt, language_desc[l]},
			{use_translation_patches_name[l], use_translation_patches, bool_opt, use_translation_patches_desc[l]},
			{animate_menu_name[l], animate_menu, bool_opt, animate_menu_desc[l]},
			{remember_position_name[l], remember_position, bool_opt, remember_position_desc[l]},
			{remember_version_name[l], remember_version, bool_opt, remember_version_desc[l]}
		}
	
		visible_settings = 5

		--general menu text

		-- "Clean" = unpatched, vanilla, original
		-- This is an incomplete sentence. The next line will display the name of the rom that needs to be located
		str_romprompt1 = {
		["ENG"] = "Please locate a clean copy of",
		["ESP"] = "Por favor busca una copia limpia de",
		["JP"] = "",
		["GER"] = "Wähle eine frische Kopie des Spiels:"
		}

		-- e
		str_romprompt2 = {
		["ENG"] = "Press [ A ] to Locate ROM",
		["ESP"] = "Presiona [ A ] para seleccionarla",
		["JP"] = "",
		["GER"] = "Drücke A, um eine ROM auszuwählen."
		}


		str_romprompt1 = str_romprompt1[l]
		str_romprompt2 = str_romprompt2[l]


		close_tojp()
	--[[	
	{
		["ENG"] = "",
		["ESP"] = "",
		["JP"] = "",
		["GER"] = "",
		}	
	]]
	end

	
	function sm_showicon(pointer, smx_off, smy_off)
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
	
	
	function sm_changesetting(pointer)
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
			local dofunc = settings[pointer][3].tablefunc()
		else
			return
		end
	end
	
	
	function sm_acceptbutton()
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
	
	function sm_sm_pos(sm_sm_v)
		local value = (sm_sm_v*18) -7
		return value
	end
	
	function sm_showmenu()
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


function settingsmenu()
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


function startmenu_mainloop()

	if scene == 1 then
		mainmenu()
	elseif scene == 2 then
		settingsmenu()
	else
		scene = 1
	end

end


function init_voidrom()
	initstartmenudata()
	bootvoidrom()
end


function init_startmenu()
	configdefaults()
	initstartmenudata()
	initdatabase()
	sm_init_settings()
end

--[[-- Main Loop
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
end]]

return