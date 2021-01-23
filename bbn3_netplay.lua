socket = require("socket.core")

client.displaymessages(false)

InputData = 0x0203B400
InputBufferLocal = InputData
InputBufferRemote = InputData + 0x1
InputStackSize = InputData + 0x3
InputStackLocal = InputData + 0x10
InputStackRemote = InputData + 0x18
SceneIndicator = 0x020097F8
thisispvp = 0

PreloadStats = 0x0200F330 
	PLS_Style = PreloadStats + 0x4
	PLS_HP = PreloadStats + 0x8

debugmessages = 1


local function debug(message)
	if debugmessages == 1 then
		print(message)
	end
end

local function Init_Battle_Vis()
	vis_looptimes = 120


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
	local stylebyte = memory.read_u8(PLS_Style)
	vis_style_R1 = style[1+(bit.band(stylebyte, 0x38)/8)]
	vis_elem_R1 = elem[1+bit.band(stylebyte, 0x7)]

end


local function Battle_Vis()

	--left megaman
	gui.drawText(40, 60, vis_elem_L..vis_style_L, "white", nil, nil, nil, "left","middle")

	--right megaman
	gui.drawText(200, 60, vis_elem_R1..vis_style_R1, "white", nil, nil, nil, "right","middle")

	--vs
	gui.drawText(120, 80, "VS", "white", nil, nil, nil, "center","middle")
end


local function battlestart()
	if memory.read_u8(0x0200188F) == 0x0B then
		thisispvp = 1
		lastsock = nil
	else
		thisispvp = 0
    end
end
event.onmemoryexecute(battlestart,0x080048CC,"battlestart")


local function endbattle()
	thisispvp = 0
end
event.onmemoryexecute(endbattle,0x08006958,"EndBattle")



local function SendStats()
	StallingBattle = true
	memory.write_u8(0x0200F320, 0x1)
	Init_Battle_Vis()
end
event.onmemoryexecute(SendStats,0x0800761A)




cob = "cobber.png"

anim_f = 0
max_f = 1
region = 26
max_k = 6
anim_k = 0


-- Main Loop
while true do


if StallingBattle == true then
	
	if vis_looptimes > 0 and thisispvp == 1 then
		vis_looptimes = vis_looptimes - 1
		Battle_Vis()
	else
		StallingBattle = false
		memory.write_u8(0x0200F320, 0x0)
	end

end



if thisispvp == 1 then 


	gui.drawImageRegion(cob, region * anim_f, 0, region, region, 100, 40)

	if anim_k == max_k then 
		anim_k = 0
		if anim_f == max_f then 
			anim_f = 0
		else
			anim_f = anim_f + 1
		end
	else
		anim_k = anim_k + 1
	end



end
	emu.frameadvance()
end

return