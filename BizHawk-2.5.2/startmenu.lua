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

	if src_rom and patch_file and output_dir then
		--os.execute("cd /d %~dp0 & start \"\" " .. bat_path .." ".. src_rom)
		local echo = "& @echo Generating patched ROM "
		os.execute("cd patches"..echo.."& flips -a "..patch_file.." "..src_rom.." "..output_dir.." & timeout 5")
	else
		if not src_rom then print("src_rom arg is missing for applypatch func") end
		if not patch_file then print("patch_file arg is missing for applypatch func") end
		if not output_dir then print("output_dir arg is missing for applypatch func") end
	end
end



-- This function is the first step when you want to launch a rom. It will read the
-- assigned rom path as well as the path for patching the rom if it doesn't already exist.
-- If this successfully defines an address for a rom that already exists, you can then run opengame()
-- This also defines 2/3 of the file paths required to apply the patch for a rom. (rom_path & patch_file)
function choosegame(game, patch)

	if type(game) == "table" then
		if config[use_translation_patches] == "true" then
			game = game[config[language]]
		else
			game = game["DEFAULT"]
		end
	end

	local validrom
	if file_exists(game) then --can be replaced with something that checks if the ROM md5 is valid (or check both)
		validrom = true
		rom_path = game
	end
	if not validrom then
		if game then
			output_dir = "\"..\\"..game.."\""
		end
		if type(patch) == "table" then
			if config[use_translation_patches] == "true" then
				patch = patch[config[language]]
			else
				patch = patch["DEFAULT"]
			end
		end
		if patch then
			patch_file = "\""..patch.."\""
		end
		new_rom_path = game
		file_prompt = true
	end
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



function savepos(x, y)
	if not tangotime then return end
	SQL.writecommand("REPLACE INTO pos (pos_x, pos_y) VALUES("..x..","..y..");")
end


function initstartmenudata()
	void_path = "Netplay\\voidrom.gba"
	
	local default = "Netplay\\BBN3 Online.gba"
	BBN3_path = {
			["DEFAULT"] = default,
			["ENG"] = default,
			["ESP"] = "Netplay\\BBN3 Online Spanish.gba",
			["JP"] = default,
			["GER"] = default,
			}

	local default = "BBN3_Online.bps"
	BBN3_patch = {
			["DEFAULT"] = default,
			["ENG"] = default,
			["ESP"] = "BBN3_Online_Spanish.bps",
			["JP"] = default,
			["GER"] = default,
			}
	
	BN6f_path = "Netplay\\BN6 Falzar Online.gba"
	BN6f_patch = "patch_BN6f.bps"
	
	BN6g_path = "Netplay\\BN6 Gregar Online.gba"
	BN6g_patch = "patch_BN6g.bps"
	
	EXE6g_path = "Netplay\\EXE6 Gregar Online.gba"
	EXE6g_patch = "patch_EXE6g.bps"
	
	EXE6f_path = "Netplay\\EXE6 Falzar Online.gba"
	EXE6f_patch = "patch_EXE6f.bps"
	
	
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
	BBN3 = {{[1] = BBN3_img, [2] = BBN3_path, [3] = BBN3_patch, [4] = "BBN3", [5] = "BN3 Blue (English)"}}

	BN6 = { {[1] = BN6g_img, [2] = BN6g_path, [3] = BN6g_patch, [4] = "BN6 Gregar", [5] = "BN6 Gregar (US)", [6] = "EXE6 Gregar (Japanese)"},
			{[1] = BN6f_img, [2] = BN6f_path, [3] = BN6f_patch, [4] = "BN6 Gregar", [5] = "BN6 Gregar (US)", [6] = "EXE6 Falzar (Japanese)"}}

	EXE6 = { {[1] = EXE6g_img, [2] = EXE6g_path, [3] = EXE6g_patch, [4] = "EXE6 Gregar", [5] = "EXE6 Gregar (Japanese)"},
			 {[1] = EXE6f_img, [2] = EXE6f_path, [3] = EXE6f_patch, [4] = "EXE6 Falzar", [5] = "EXE6 Falzar (Japanese)"}}



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
		if not mm_fr_start_rom then
			gui.drawText(x_max/2, 40, str_romprompt1, nil,nil, 12,"Arial", nil, "middle")
			gui.drawText(x_max/2, 60, mm_fr_romname, nil,nil, 12,"Arial", nil, "middle")
			--gui.drawText(x_max/2, 75, "• filename doesn't matter \n• must be a .gba file", nil,nil, 12,"Arial", nil, "middle")
		else
			local maxkf = 3
			local fr_framespd = 3
			local fr_x = 40
			local fr_y = 40
			if not mm_fr_curkf then mm_fr_curkf = 0 end
			if not mm_fr_t3 then mm_fr_t3 = 0 end
			mm_fr_t3 = mm_fr_t3 + 1
			if mm_fr_t3 >= fr_framespd then
				mm_fr_t3 = 0
				mm_fr_curkf = mm_fr_curkf + 1
				if mm_fr_curkf > maxkf then
					mm_fr_curkf = 0
				end
			end

			gui.drawImageRegion("gui_Sprites/aquaspin.png", fr_x*mm_fr_curkf, 0, fr_x,fr_y, 120-fr_x/2, 80-fr_y/2)
		end

		if fr_f > 50 and not(mm_fr_start_rom) then
			local fr_f2max = 110
			local fr_f3max = 2
			if not fr_f2 then fr_f2 = fr_f2max end
			if not fr_f3 then fr_f3 = fr_f3max end

			if fr_f2 > 0 then
				local textcolor
				local transframe = 30
				local alpha_interv = 0xFF/transframe
				local picker
				if (fr_f2max - fr_f2) < transframe then
					-- fade in (val starts from 1 -> transframe)
					picker = fr_f2max - fr_f2 + 1
				elseif (fr_f2max - fr_f2) > (fr_f2max - transframe) then
					-- fade out (val starts at transframe, goes down to 1)
					picker = transframe - ((fr_f2max - fr_f2) - (fr_f2max - transframe))
				end
				if picker then
					text_alpha = bizstring.hex(picker*alpha_interv)
					textcolor = tonumber("0x"..text_alpha.."ffffff")
				end
				fr_f2 = fr_f2 - 1
				gui.drawText(x_max/2, 100, str_romprompt2, textcolor,nil, 12,"Arial", nil, "middle")
			else
				fr_f3 = fr_f3 - 1
				if fr_f3 <= 0 then
					fr_f2 = fr_f2max
					fr_f3 = fr_f3max
				end
			end

			if c_r_A then 
				mm_fr_continue = true
				fr_f2 = nil
				fr_f3 = nil
			end
		end
	
		if mm_fr_patchtime then
			if mm_fr_patchtime_2 then
				applypatch()
				mm_fr_patchtime = nil
				mm_fr_patchtime_2 = nil 
			end
			if not mm_fr_patchtime_2 then mm_fr_patchtime_2 = true end
		end

		if mm_fr_continue then
			fr_f = 0
			--locate rom file and apply patch
			src_rom = forms.openfile()
			if not(src_rom == nil or src_rom == "") then
				--process the string so it doesn't error from spaces in the name
				src_rom = "\"".. src_rom .. "\""
				mm_fr_start_rom = true
				mm_fr_patchtime = true
			end
		end
	
		if mm_fr_start_rom then
			if not mm_fr_t1 then mm_fr_t1 = 0 end
			if not mm_fr_t2 then mm_fr_t2 = 0 end
			local function mm_fr_exit()
				mm_fr_start_rom = nil
				file_prompt = nil
				mm_fr_t1 = nil
				mm_fr_t2 = nil
				mm_fr_t3 = nil	-- this is used by the spinning animations
			end
			local romready
			mm_fr_t1 = mm_fr_t1 + 1

			-- every ten frames, check whether the rom has been created
			if mm_fr_t1 and mm_fr_t1 > 25 then
				mm_fr_t1 = 0
				mm_fr_t2 = mm_fr_t2 + 1
				romready = file_exists(new_rom_path)
			end
			-- once the rom is generated, launch it
			if romready then
				mm_fr_exit()
				gui.clearGraphics()
				opengame(new_rom_path)
			end
			-- exit condition for if the rom isn't found (after 6 unsuccessful checks)
			if mm_fr_t2 and mm_fr_t2 > 2 then
				mm_fr_exit()
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


	function sm_changebuffer(pointer)

		local buffer_val = tonumber(config[delay_buffer])
		local minopt = tonumber(settings[pointer][3][2])
		local maxopt = tonumber(settings[pointer][3][3])
		
		while true do
			proc_ctrl()
			if c_r_A or c_r_B or c_r_Start then
				--update the database then break loop
				saveconfig(delay_buffer, buffer_val)
				proc_ctrl()
				break
			end

			if c_p_Left then
				if not ((buffer_val - 1) < minopt) then
					buffer_val = buffer_val - 1
				end
			elseif c_p_Right then
				if not ((buffer_val + 1) > maxopt) then
					buffer_val = buffer_val + 1
				end
			end

			i1 = 0xffff0000
			i2 = "Yellow"
			i3 = 0xff0eca00
			local colorchart = {i1,i2,i3,i2,i2,i2,i1,i1,i1}
			local numcolor = colorchart[buffer_val]

			gui.drawText(x_center, y_center/2, buffer_val, numcolor,nil,18,"Arial", "Bold", "Center")

			if buffer_val > minopt then
				drawArrow(2, 1, 1, x_center - 16, y_center/2 + 2)
			end
			if buffer_val < maxopt then
				drawArrow(3, 1, 1, x_center + 16, y_center/2 + 2)
			end

			gui.drawText(x_center, y_center/2 - 20, settings[pointer][1],nil,nil,12,"Arial",nil, "Center")

			local description = settings[smpos_y][4]
			gui.drawText(x_max/2, 115, description,nil,nil,12, "Arial", nil, "middle","top")
			gui.drawImage(settings_footer, 0, 0)

			emu.frameadvance()
		end
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
		delay_buffer_name = {
		["ENG"] = "Delay Buffer",
		["ESP"] = "Delay Buffer",
		["JP"] = "Delay Buffer",
		["GER"] = "Delay Buffer",
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
		delay_buffer_desc = {
		["ENG"] = "Higher values will increase input delay\nbut reduce the amount of visual\nhiccups during laggy matches.",
		["ESP"] = "",
		["JP"] = "",
		["GER"] = "",
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
		buffer_opts = {"buffer",1,9, tablefunc = sm_changebuffer}
	
	
		settings = {
			{username_name[l], username, username_opt, username_desc[l]},
			{delay_buffer_name[l], delay_buffer, buffer_opts, delay_buffer_desc[l]},
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
	
		elseif opt_type == "buffer" then
			current = tonumber(current)
			local minopt = tonumber(settings[pointer][3][2])
			local maxopt = tonumber(settings[pointer][3][3])
			i1 = 0xffff0000
			i2 = "Yellow"
			i3 = 0xff0eca00
			local colorchart = {i1,i2,i3,i2,i2,i2,i1,i1,i1}
			local numcolor = colorchart[current]

			gui.drawText(smx_off, smy_off, current, numcolor,nil,12,"Arial","Bold")

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

		elseif opt_type == "buffer" then
			local dofunc = settings[pointer][3].tablefunc(pointer)
	
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
		if not listpos then listpos = 1 
			p_listpos = listpos 
		end
		p_smpos_y = smpos_y
		p_smpos_x = smpos_x
		press_delay = 5

		if c_r_A then
			--toggle setting
			sm_changesetting(smpos_y)

		elseif c_r_Start or c_r_B then
			scene = scene - 1
			smpos_y = 1
			smpos_x = 1
			p_smpos_y = 1
			p_smpos_x = 1
			listpos = 1
			p_listpos = 1

		elseif c_p_Up or c_h_Up then
			if settings[smpos_y-1] then
				smpos_y = smpos_y - 1

				p_listpos = listpos
				if listpos > 1 then
					listpos = listpos - 1
				end
			end
		elseif c_p_Down or c_h_Down then
			if settings[smpos_y+1] then
				smpos_y = smpos_y + 1

				p_listpos = listpos
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
			press_delay = 2
			p_smpos_y = smpos_y
		else
			--a place for idle things
			press_delay = nil
		end
	end
	
	function sm_sm_pos(sm_sm_v)
		local value = (sm_sm_v*18) -7

		local extraval
		if press_delay and (listpos == 1 or listpos == visible_settings) and p_listpos == listpos and p_smpos_y ~= smpos_y then
			extraval = press_delay*3
			if p_smpos_y > smpos_y then
				extraval = -1 * extraval
			end
			value = value + extraval
		end

		return value
	end

	function sm_sm_indent(the_val)
		if press_delay and p_smpos_y ~= smpos_y then 
			if the_val > 0 then
				the_val = the_val + 1 - press_delay
			else
				the_val = the_val - 1 + press_delay
			end
		end
		return the_val
	end
	
	function sm_showmenu()
		if not listpos then listpos = 1 end

		for i=1, visible_settings do
			local offset = smpos_y + (i - listpos)
			if settings[offset] then
				local indent = 0
				if i == listpos then 
					indent = sm_sm_indent(5)
				elseif i == p_listpos or (p_listpos == listpos and math.abs(listpos - i) == 1) then 
					indent = sm_sm_indent(0)
				end
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




return