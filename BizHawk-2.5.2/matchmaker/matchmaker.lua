-- matchmaker lua module
local socket = require("socket")
local serializer = require("matchmaker.serializer")

local lib = {
    ip = "",                   -- matchmaker server ip
    port = 0,                  -- matchmaker server port
    timeout = 0,               -- connection timeout
    socket = nil,              -- udp socket
    session_key = "",          -- active session key (host only)
    remote_addr = "",          -- remote connection
    client_hash = "",          -- crypto hash of client to verify authenticity
    sent_packets = {},         -- list of unack'd packaget that had been sent
    errors = {},               -- list of errors
    next_packet_id = 0,        -- our next packet ID
    server_next_packet_id = 0, -- track the next packet from the server
    max_packet_len = 512,      -- max packet len a socket can read
    debug = false,             -- Prints debug information to console
    is_joining = false,       -- indicates whether we were trying to join
    join_status = ""           -- indicates if the last join failed
}

--[[
Packet headers are u16 size
Packet IDs are u32 size
--]]
local PacketHeader = {
    PingPong = 0,
    Ack = 1,
    Create = 2,
    Join = 3 ,
    Close = 4,
    Error = 5    
}

--[[
Packet types are read differently
--]]
local PacketType = {
    AckPacket = 0,
    DataPacket = 1
}

local function send_packet(ctx, packet_id, header, data)
    serializer:clear()

    local littleEndian = serializer:endian() == "Little Endian"

    serializer:write_u32(packet_id, false, littleEndian)
    serializer:write_u16(header, false, littleEndian)

    -- { id: u32 }
    if header == PacketHeader.Ack then
        ctx:_debug_print("Sending Ack Packet")
        serializer:write_u32(data.id, false, littleEndian)
    end

    -- { client_hash: str, password_protected: bool }
    if header == PacketHeader.Create then 
        ctx:_debug_print("Sending Create Packet")

        serializer:write_string(data.client_hash, littleEndian)
        
        local value = 0
        if data.password_protected then
            value = 1
        end

        serializer:write_u8(value)
    end

    -- { client_hash: str, session_key: str }
    if header == PacketHeader.Join then 
        ctx:_debug_print("Sending Join Packet")

        serializer:write_string(data.client_hash, littleEndian)

        if data.session_key ~= nil then
            serializer:write_string(data.session_key, littleEndian)
        else 
            serializer:write_string("", littleEndian)
        end
    end

    --[[
    Packets PingPong and Close only consist of the header 
    --]]

    ctx.next_packet_id = packet_id + 1
    ctx.socket:send(serializer.Buffer)

    -- Do not require ack packets for our ack packets
    if header ~= PacketHeader.Ack then
        ctx.sent_packets[packet_id] = serializer.Buffer
    end
end

local function read_packet(ctx, bytestream)
    local littleEndian = serializer:endian() == "Little Endian"

    ctx:_debug_print("in read_packet()")
    ctx:_debug_print("bystream has "..#bytestream)

    serializer:set_buffer(bytestream)

    if #bytestream < 7 then
        ctx:_debug_print("Bytestream too small to interpret. Dropping")
        return
    end

    local packetType = serializer:read_u8()
    local packet_id = nil

    if packetType == PacketType.DataPacket then
        packet_id = serializer:read_u32(littleEndian)

        --[[
        -- ignore old packets
        if packet_id < ctx.server_next_packet_id then
            return
        end

        -- expect next packet
        ctx.server_next_packet_id = packet_id + 1
        --]]
    end

    local header = serializer:read_u16(littleEndian)

    if packetType == PacketType.AckPacket then
        -- { id: u32 }
        if header == PacketHeader.Ack then
            ctx:_debug_print("Ack packet recieved")
            local id = serializer:read_u32(littleEndian)
            ctx.sent_packets[id] = nil
        end

        return
    end

    -- {}
    if header == PacketHeader.PingPong then 
        ctx:_debug_print("PingPong packet recieved")
        send_packet(ctx, ctx.next_packet_id, PacketHeader.PingPong, {})
    end


    -- { id: u32, message: str }
    if header == PacketHeader.Error then 
        local id = serializer:read_u32(littleEndian)
        local message = serializer:read_string()
        ctx:_debug_print("Error packet recieved: "..message)
        ctx.sent_packets[id] = nil
        ctx.errors[#ctx.errors+1] = message
    end

    -- { session_key: str }
    if header == PacketHeader.Create then 
        ctx:_debug_print("Create response packet recieved")
        local session_key = serializer:read_string()
        ctx.session_key = session_key
    end

    -- { success: bool, socket_address: str }
    if header == PacketHeader.Join and ctx.is_joining then 
        ctx:_debug_print("Join response package recieved")
        local success = serializer:read_u8()

        if success == 1 then 
            local socket_address = serializer:read_string()
            ctx.remote_addr = socket_address
            ctx.join_status = "success"
        else 
            ctx.join_status = "failed"
        end

        ctx.is_joining = false
    end

    -- send the ack packet to the server
    if packet_id then
        send_packet(ctx, ctx.next_packet_id, PacketHeader.Ack, { id = packet_id })
    else
        print("packet_id was nil")
    end

end

function lib:did_join_fail() 
    return self.join_status == "failed"
end

function lib:did_join_succeed()
    return self.join_status == "success"
end

function lib:is_join_pending()
    return self.join_status == "pending"
end

function lib:get_join_status() 
    return self.join_status
end

function lib:check_config() 
    return string.len(self.ip) > 0 
    and self.port >= 1025 
    and self.port <= 65535 
    and string.len(self.client_hash) > 0 
end

function lib:init(client_hash, ip, port, timeout, debug) 
    self.ip = ip
    self.port = port
    self.client_hash = client_hash
    self.session_key = ""
    self.remote_addr = ""
    self.sent_packets = {}
    self.errors = {}
    self.next_packet_id = 0
    self.server_next_packet_id = 0
    self.is_joining = false 
    self.join_status = "" 

    if timeout ~= nil then
        self.timeout = timeout
    end

    self.debug = debug

    if self:check_config() == false then
        self:_debug_print("Bad config")
    else
        if self.socket then 
            self.socket:close()
        end 

        self.socket = socket.udp()
        self.socket:setoption('reuseaddr',true)
        self.socket:setsockname('*', 0)
        self.socket:setpeername(self.ip, self.port)
        self.socket:settimeout(self.timeout)

        self.next_packet_id = 0

        self:_debug_print("Host machine Endianess is "..serializer:endian())
    end
end

function lib:create_session(password_protected)
    if self:check_config() then
        if self.is_joining then 
            self:_debug_print("You are in the middle of joining, request supressed")
            return
        end

        if string.len(self.session_key) == 0 then
            local data = {
                client_hash = self.client_hash,
                password_protected = password_protected
            }

            send_packet(self, self.next_packet_id, PacketHeader.Create, data)
            self.is_joining = true
            self.join_status = "pending"
        else 
            self:_debug_print("You have a session already @ "..self.session_key)
        end
    end
end

function lib:join_session(password)
    if self:check_config() then
        if self.is_joining then 
            self:_debug_print("You are in the middle of joining, request supressed")
            return
        end

        if string.len(self.session_key) == 0 then
            local data = {
                client_hash = self.client_hash,
                session_key = password
            }
            send_packet(self, self.next_packet_id, PacketHeader.Join, data)
            self.is_joining = true
            self.join_status = "pending"
        else 
            self:_debug_print("You are hosting a session, could not join a session!")
            self.join_status = "failed"
        end
    end
end

function lib:close_session() 
    if self:check_config() then
        if string.len(self.session_key) == 0 then 
            self:_debug_print("No session to close")
            return
        end

        send_packet(self, self.next_packet_id, PacketHeader.Close, {})
        self.session_key = ""
        self.join_status = ""
        self.is_joining = false
    end
end

function lib:close()
    if string.len(self.session_key) > 0 then 
        self:close_session()
    end

    if self.socket then 
        self.socket:close()
    end
end

-- Processes and acks incoming packets 
-- as well as resends drop packets
function lib:poll()
    local chunk, err = self.socket:receive(lib.max_packet_len)

    if err then 
        self:_debug_print("Error polling: "..err)
    else
        read_packet(self, chunk)
    end

    -- resend unacknowledged packets
    self:_debug_print("Resending "..#self.sent_packets.." packets")

    for k,v in pairs(self.sent_packets) do
        self.socket:send(v)
    end
end

function lib:_debug_print(message)
    if self.debug then 
        print(message)
    end
end

function lib:get_session() 
    return self.session_key
end

function lib:get_remote_addr()
    return self.remote_addr
end

function lib:sleep(seconds)
    socket.sleep(seconds)
end

return lib
