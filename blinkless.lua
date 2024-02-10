addon.author = 'Tny5989'
addon.name = 'BlinkLess'
addon.version = '0.1'

require('common')

------------------------------------------------------------------------------------------------------------------------
local slots = {
    Head = { offset = 0x00, getter = function(idx, memory)
        return memory:GetEntity():GetLookHead(idx)
    end, setter = function(idx, gear, memory)
        memory:GetEntity():SetLookHead(idx, gear)
    end },
    Body = { offset = 0x02, getter = function(idx, memory)
        return memory:GetEntity():GetLookBody(idx)
    end, setter = function(idx, gear, memory)
        memory:GetEntity():SetLookBody(idx, gear)
    end },
    Hands = { offset = 0x04, getter = function(idx, memory)
        return memory:GetEntity():GetLookHands(idx)
    end, setter = function(idx, gear, memory)
        memory:GetEntity():SetLookHands(idx, gear)
    end },
    Legs = { offset = 0x06, getter = function(idx, memory)
        return memory:GetEntity():GetLookLegs(idx)
    end, setter = function(idx, gear, memory)
        memory:GetEntity():SetLookLegs(idx, gear)
    end },
    Feet = { offset = 0x08, getter = function(idx, memory)
        return memory:GetEntity():GetLookFeet(idx)
    end, setter = function(idx, gear, memory)
        memory:GetEntity():SetLookFeet(idx, gear)
    end },
    Main = { offset = 0x0A, getter = function(idx, memory)
        return memory:GetEntity():GetLookMain(idx)
    end, setter = function(idx, gear, memory)
        memory:GetEntity():SetLookMain(idx, gear)
    end },
    Sub = { offset = 0x0C, getter = function(idx, memory)
        return memory:GetEntity():GetLookSub(idx)
    end, setter = function(idx, gear, memory)
        memory:GetEntity():SetLookSub(idx, gear)
    end },
    Ranged = { offset = 0x0E, getter = function(idx, memory)
        return memory:GetEntity():GetLookRanged(idx)
    end, setter = function(idx, gear, memory)
        memory:GetEntity():SetLookRanged(idx, gear)
    end },
}

------------------------------------------------------------------------------------------------------------------------
local cache = {
    target_idx = 0,
    sub_target_idx = 0,
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
    local memory_gear = slot.getter(player_idx, memory)

    if (cache[player_idx] == nil) then
        cache[player_idx] = {}
    end

    if (memory_gear == 0) then
        cache[player_idx][slot.offset] = nil
        return packet_gear
    end

    cache[player_idx][slot.offset] = packet_gear

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
local function RestoreGear(player_idx, memory)
    if (player_idx == 0 or cache[player_idx] == nil) then
        return
    end

    local update = false
    for _, value in pairs(slots) do
        local gear = cache[player_idx][value.offset]
        if (gear ~= nil) then
            local current_gear = value.getter(player_idx, memory)
            if (current_gear ~= gear) then
                update = true
                value.setter(player_idx, gear, memory)
            end
        end
    end
    cache[player_idx] = nil

    if (update) then
        memory:GetEntity():SetModelUpdateFlags(player_idx, bit.bor(memory:GetEntity():GetModelUpdateFlags(player_idx), 0x10))
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
    elseif (e.id == 0x00A or e.id == 0x00B) then
        cache = { target_idx = 0, sub_target_idx = 0 }
    end
end)

------------------------------------------------------------------------------------------------------------------------
ashita.events.register('d3d_present', 'bl_present_cb', function()
    local target_idx = GetTarget(0)
    local sub_target_idx = GetTarget(1)
    local memory = AshitaCore:GetMemoryManager()

    if (cache.target_idx ~= target_idx and cache.target_idx ~= sub_target_idx) then
        RestoreGear(cache.target_idx, memory)
    end
    if (cache.sub_target_idx ~= target_idx and cache.sub_target_idx ~= sub_target_idx) then
        RestoreGear(cache.sub_target_idx, memory)
    end

    cache.target_idx = target_idx
    cache.sub_target_idx = sub_target_idx
end)
