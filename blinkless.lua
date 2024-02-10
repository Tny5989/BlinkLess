addon.author = 'Tny5989'
addon.name = 'BlinkLess'
addon.version = '0.1'

require('common')

------------------------------------------------------------------------------------------------------------------------
local slots = {
    Head = { offset = 0x00, func = function(idx, memory)
        return memory:GetEntity():GetLookHead(idx)
    end },
    Body = { offset = 0x02, func = function(idx, memory)
        return memory:GetEntity():GetLookBody(idx)
    end },
    Hands = { offset = 0x04, func = function(idx, memory)
        return memory:GetEntity():GetLookHands(idx)
    end },
    Legs = { offset = 0x06, func = function(idx, memory)
        return memory:GetEntity():GetLookLegs(idx)
    end },
    Feet = { offset = 0x08, func = function(idx, memory)
        return memory:GetEntity():GetLookFeet(idx)
    end },
    Main = { offset = 0x0A, func = function(idx, memory)
        return memory:GetEntity():GetLookMain(idx)
    end },
    Sub = { offset = 0x0C, func = function(idx, memory)
        return memory:GetEntity():GetLookSub(idx)
    end },
    Ranged = { offset = 0x0E, func = function(idx, memory)
        return memory:GetEntity():GetLookRanged(idx)
    end },
}

------------------------------------------------------------------------------------------------------------------------
local function GetTarget(idx)
    local player_target = AshitaCore:GetMemoryManager():GetTarget()
    if (player_target == nil) then
        return nil
    end

    return player_target:GetTargetIndex(idx)
end

------------------------------------------------------------------------------------------------------------------------
local function GetSelf()
    return AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0)
end

------------------------------------------------------------------------------------------------------------------------
local function GetPatchedValue(data, player_idx, slot, offset, memory)
    local packet_gear = struct.unpack('H', data, offset + slot.offset)
    local memory_gear = slot.func(player_idx, memory)

    if (memory_gear == 0) then
        return packet_gear
    end

    return memory_gear
end

------------------------------------------------------------------------------------------------------------------------
local function PatchPacket0x00D(e, player_idx, memory)
    local packet_data = e.data_modified:totable()
    local prefix = struct.pack(string.rep('B', 74), table.unpack(packet_data, 1, 74))
    local gear = struct.pack(string.rep('H', 8),
            GetPatchedValue(e.data_modified, player_idx, slots.Head, 0x4A + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Body, 0x4A + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Hands, 0x4A + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Legs, 0x4A + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Feet, 0x4A + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Main, 0x4A + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Sub, 0x4A + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Ranged, 0x4A + 1, memory))
    local suffix = struct.pack(string.rep('B', e.size - 74 - (8 * 2)), table.unpack(packet_data, 91, e.size))
    e.data_modified = (prefix + gear + suffix)
end

------------------------------------------------------------------------------------------------------------------------
local function PatchPacket0x051(e, player_idx, memory)
    local packet_data = e.data_modified:totable()
    local prefix = struct.pack(string.rep('B', 6), table.unpack(packet_data, 1, 6))
    local gear = struct.pack(string.rep('H', 8),
            GetPatchedValue(e.data_modified, player_idx, slots.Head, 0x06 + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Body, 0x06 + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Hands, 0x06 + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Legs, 0x06 + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Feet, 0x06 + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Main, 0x06 + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Sub, 0x06 + 1, memory),
            GetPatchedValue(e.data_modified, player_idx, slots.Ranged, 0x06 + 1, memory))
    local suffix = struct.pack(string.rep('B', e.size - 6 - (8 * 2)), table.unpack(packet_data, 22, e.size))
    e.data_modified = (prefix + gear + suffix)
end

------------------------------------------------------------------------------------------------------------------------
local function PatchPacket(e, player_idx, memory)
    if (e.id == 0x00D) then
        PatchPacket0x00D(e, player_idx, memory)
    elseif (e.id == 0x051) then
        PatchPacket0x051(e, player_idx, memory)
    end
end

------------------------------------------------------------------------------------------------------------------------
ashita.events.register('packet_in', 'bl_packet_in_cb', function(e)
    if (e.id == 0x00D) then
        local main_target_idx = GetTarget(0)
        local sub_target_idx = GetTarget(1)
        local player_idx = struct.unpack('H', e.data_modified, 0x08 + 1)
        local flags = struct.unpack('B', e.data_modified, 0x0A + 1)
        local gear_change = bit.band(flags, 0x10)

        if ((main_target_idx ~= player_idx) and (sub_target_idx ~= player_idx)) then
            return
        end

        if (gear_change == 0) then
            return
        end

        PatchPacket(e, player_idx, AshitaCore:GetMemoryManager())
    elseif (e.id == 0x051) then
        local main_target_idx = GetTarget(0)
        local sub_target_idx = GetTarget(1)
        local self_idx = GetSelf()

        if ((main_target_idx ~= self_idx) and (sub_target_idx ~= self_idx)) then
            return
        end

        PatchPacket(e, self_idx, AshitaCore:GetMemoryManager())
    end
end)
