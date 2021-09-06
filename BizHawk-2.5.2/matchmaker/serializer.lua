-- Note: already provided by BizHawk
-- local bit = require("bit")

---Read Functions

local serializer = {
	Buffer = "",
	Position = 0
}

local function bor_ext(...)
	local result = 0x00

	for i, v in ipairs(arg) do 
		result = bit.bor(v, result)
	end

	return result
end

function serializer:endian()
	local function f() end
	
	if string.byte(string.dump(f),7) == 1 then 
		return "Little Endian"
	end

	return "Big Endian"
end

function serializer:lua_byte_size() 
	if(0xfffffffff==0xffffffff) then
		return 32
	end

	return 64
end

function serializer:clear() 
	self.Buffer = ""
	self.Position = 0
end

function serializer:set_buffer(buffer)
	self.Buffer = buffer
	self.Position = 0
end

function serializer:check_bytes(...)
	if type(arg) ~= "table" then
		print("arg type not a table in function `serializer:check_bytes(...)`")
	else
		local i = 0
		for _ in pairs(arg) do 
			i = i + 1
			if arg[i] == 0 then arg[i] = "\0" end
		end
	end

	return unpack(arg)
end

function serializer:read_u8() 
    self.Position = self.Position + 1
    local b = self.Buffer:byte(self.Position)
	-- print("b: "..b)
	return b
end

function serializer:read_u16(reversed)
 
	local l1,l2 = 0
	if reversed then
    	l1 = self:read_u8()
		l2 = bit.lshift(self:read_u8(), 8)
	else
    	l1 = bit.lshift(self:read_u8(), 8)
    	l2 = self:read_u8()	 
	end
	
    return bor_ext(l1, l2)
end
 
function serializer:read_u32(reversed)
	local l1,l2,l3,l4 = 0
	if reversed then
		l1 = self:read_u8()
		l2 = bit.lshift(self:read_u8(), 8)
		l3 = bit.lshift(self:read_u8(), 16)
		l4 = bit.lshift(self:read_u8(), 24)
	else
		l1 = bit.lshift(self:read_u8(), 24)
		l2 = bit.lshift(self:read_u8(), 16)
		l3 = bit.lshift(self:read_u8(), 8)
		l4 = self:read_u8()	 
	end
	
    return bor_ext(l1, l2, l3, l4)
end

function serializer:read_string(reversed)
    local len = self:read_u8()
	local ret = ""
	if len == 0 then
		return ret
	end
	for i = 0, len - 1 do
		local char = self:read_u8()
		if char == nil then break end
		ret = ret ..string.char(char)
	end
 
    return ret
end

--Write Functions
 
function serializer:write_u8(byte, insert)
    self.Position = self.Position + 1
	if type(byte) == "number" then
	   byte = string.char(byte)
	end
	if type(byte) == "boolean" then
		if byte == true then
			byte = 1
		else
			byte = 0
		end

		byte = string.char(byte)
	end

    if insert then
        self.Buffer = self.Buffer:sub(0,self.Position-1)..byte..self.Buffer:sub(self.Position+1)
    else
        self.Buffer = self.Buffer..byte
    end
end

function serializer:write_u16(int16, insert, reverse)
	local l1 = bit.rshift(int16, 8)
	local l2 = int16 - bit.lshift(l1, 8)
	l1,l2 = self:check_bytes(l1,l2)
	
	if not(reverse) then
    	self:write_u8(l1, insert)
    	self:write_u8(l2, insert)
	else 
		self:write_u8(l2, insert)
		self:write_u8(l1, insert)
	end
end
 
function serializer:write_u32(int32, insert, reverse)
	local l1 = bit.rshift(int32, 24)
	local l2 = bit.rshift(int32, 16) - bit.lshift(l1, 8)
	local l3 = bit.rshift(int32, 8) - bit.lshift(l1, 16) - bit.lshift(l2, 8)
	local l4 = int32 - bit.lshift(l1, 24) - bit.lshift(l2, 16) - bit.lshift(l3, 8)
	
	l1,l2,l3,l4 = self:check_bytes(l1,l2,l3,l4)
	
	if not(reverse) then
		self:write_u8(l4, insert)
		self:write_u8(l3, insert)
		self:write_u8(l2, insert)
		self:write_u8(l1, insert)
	else
		self:write_u8(l1, insert)
		self:write_u8(l2, insert)
		self:write_u8(l3, insert)
		self:write_u8(l4, insert)
	end
end

function serializer:write_string(str, reverse)
    local len = str:len()
	self:write_u8(len, false, reverse)
	self.Buffer = self.Buffer..str
end

return serializer