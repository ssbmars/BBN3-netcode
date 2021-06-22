


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
		local thisgame = gameinfo.getromname()
		if thisgame == "voidrom" then
			tango_loadstartmenu()
			init_startmenu()
		elseif thisgame == "BBN3 Online" then
			print(thisgame)
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