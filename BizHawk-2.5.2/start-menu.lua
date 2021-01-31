socket = require("socket.core")
client.displaymessages(false)


--TO DO: verify specific ROM hash, both for vanilla files and patch files. This should be very helpful for smooth operation
local function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

local function write_file(filename, path)
	local file = io.open(filename, "w")
	file:write(path)
	file:close()
end

local function read_file(filename)
	local f = assert(io.open(filename, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

local function opengame(path)
	if userdata.get("last_openrom_path") == path then
		userdata.remove("last_openrom_path")
	else
		userdata.set("last_openrom_path", path)
		client.openrom(path)
	end
	client.openrom(path)
end

local function choosegame(game, patch)
		if file_exists(game) == true then --file_exists() can be replaced with something that checks if the ROM md5 is valid
			rom_path = game
			forms.destroyall()
			formopen = nil
		else
			src_rom = forms.openfile()
			bat_path = patch
			if not(src_rom == nil or src_rom == "") then
				forms.destroyall()
				formopen = nil
			end
		end
end

BBN3_path = "Netplay\\BBN3 Online.gba"
BBN3_bat = '".\\patches\\patch BBN3.bat"'

BN6f_path = "Netplay\\BN6 Falzar Online.gba"
BN6f_bat = '".\\patches\\patch BN6f.bat"'

BN6g_path = "Netplay\\BN6 Gregar Online.gba"
BN6g_bat = '".\\patches\\patch BN6g.bat"'

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


-- cd /d %~dp0
-- flips -a "../patches/BBN3.bps" %1 "../BBN3/BBN3.gba"

function newform()
	thisgame = emu.getsystemid()
	if thisgame ~= "NULL" then 
		formopen = nil
		return 
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
newform()



-- Main Loop
while true do


	if src_rom then
		os.execute('cd /d %~dp0 & start "" ' .. bat_path .." ".. src_rom)
		newform()
	end


	if rom_path then
		if file_exists(rom_path) == true then
			opengame(rom_path)
		else
			emu.frameadvance()
		end
		newform()
	end

	emu.frameadvance()
end

return