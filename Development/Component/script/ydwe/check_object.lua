local root = fs.ydwe_devpath()

local w3xparser = require 'w3xparser'
local lni       = require 'lni'

local w2l      = root / 'plugin' / 'w3x2lni' / 'core'
local defined  = w2l / 'defined'
local mpq      = root / 'share' / 'mpq'

local info       = lni(assert(io.load(w2l / 'info.ini')), 'info.ini')
local typedefine = {
    aibuffer = 3,
    armortype = 3,
    attackbits = 0,
    attacktype = 3,
    attributetype = 3,
    bool = 0,
    channelflags = 0,
    channeltype = 0,
    combatsound = 3,
    deathtype = 0,
    defensetype = 3,
    defensetypeint = 0,
    detectiontype = 0,
    fullflags = 0,
    int = 0,
    interactionflags = 0,
    itemclass = 3,
    lightningeffect = 3,
    morphflags = 0,
    movetype = 3,
    pathinglistprevent = 3,
    pathinglistrequire = 3,
    pickflags = 0,
    real = 1,
    regentype = 3,
    shadowimage = 3,
    silenceflags = 0,
    spelldetail = 0,
    stackflags = 0,
    targetlist = 3,
    targettype = 3,
    teamcolor = 0,
    techavail = 0,
    unitclass = 3,
    unitrace = 3,
    unreal = 2,
    upgradeclass = 3,
    upgradeeffect = 3,
    versionflags = 0,
    weapontype = 3,
}

local select        = select
local tonumber      = tonumber
local tostring      = tostring
local string_unpack = string.unpack
local string_pack   = string.pack
local string_lower  = string.lower
local string_sub    = string.sub
local math_floor    = math.floor
local table_concat  = table.concat

local buf_pos
local unpack_buf
local unpack_pos
local has_level
local metadata
local check_bufs

local function set_pos(...)
    unpack_pos = select(-1, ...)
    return ...
end

local function unpack(str)
    return set_pos(string_unpack(str, unpack_buf, unpack_pos))
end

local function unpack_data(name)
    local id, type = unpack 'c4l'
    local id = string_unpack('z', id)
    local except
    local meta = metadata[id]
    if meta then
        except = typedefine[string_lower(meta.type)] or 3
    else
        except = type
    end
    if type ~= except then
        if type == 3 or except == 3 then
            except = type
        else
            check_bufs[#check_bufs+1] = string_sub(unpack_buf, buf_pos, unpack_pos - 5)
            check_bufs[#check_bufs+1] = string_pack('l', except)
            buf_pos = unpack_pos
        end
    end
    if has_level then
        unpack 'll'
        if type ~= except then
            check_bufs[#check_bufs+1] = string_sub(unpack_buf, buf_pos, unpack_pos - 1)
            buf_pos = unpack_pos
        end
    end
    local value
    if type == 0 then
        value = unpack 'l'
    elseif type == 1 or type == 2 then
        value = unpack 'f'
    else
        value = unpack 'z'
    end
    if type ~= except then
        local format, newvalue
        if except == 0 then
            format = 'l'
            newvalue = math_floor(value)
        elseif except == 1 or except == 2 then
            format = 'f'
            newvalue = value + 0.0
        end
        check_bufs[#check_bufs+1] = string_pack(format, newvalue)
        buf_pos = unpack_pos
        log.debug(('convert object type:[%s][%s] - [%d][%s] --> [%d][%s]'):format(name, id, type, value, except, newvalue))
    end
    unpack 'l'
end

local function unpack_obj()
    local parent, name, count = unpack 'c4c4l'
    for i = 1, count do
        unpack_data(name == '\0\0\0\0' and parent or name)
    end
end

local function unpack_chunk()
    local count = unpack 'l'
    for i = 1, count do
        unpack_obj()
    end
end

local function unpack_head()
    unpack 'l'
end

local function check(type, buf)
    buf_pos    = 1
    unpack_pos = 1
    unpack_buf = buf
    has_level  = info.key.max_level[type]
    if type == 'doodad' then
        metadata   = w3xparser.slk(io.load(mpq / 'doodads' / info.metadata[type]))
    else
        metadata   = w3xparser.slk(io.load(mpq / 'units' / info.metadata[type]))
    end
    check_bufs = {}

    unpack_head()
    unpack_chunk()
    unpack_chunk()

    if buf_pos > 1 then
        check_bufs[#check_bufs+1] = unpack_buf:sub(buf_pos)
        return table_concat(check_bufs)
    end
    
    return buf
end

local function init()
    local storm = require 'ffi.storm'
    for _, type in ipairs {'ability', 'unit', 'item', 'doodad', 'destructable', 'buff', 'upgrade'} do
        local filename = info.obj[type]
        virtual_mpq.force_watch(filename, function ()
            return check(type, storm.load_file(filename))
        end)
    end
end

init()
