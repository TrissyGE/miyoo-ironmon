-- Apply the same preparation as prepare_rom.py to a private staging copy.
-- The caller verifies the ROM and IPS hashes before invoking this script.
local rom = assert(io.open(arg[1], 'r+b'))
local size = assert(rom:seek('end'))
assert(size == 0x1000000, 'Expected a 16 MiB staging ROM')
local patchFile = assert(io.open(arg[2], 'rb'))
local patch = assert(patchFile:read('a'))
patchFile:close()
local spec = dofile(arg[3])
local function writeAt(offset, data)
    assert(offset >= 0 and offset + #data <= size, 'Patch leaves the ROM')
    assert(rom:seek('set', offset))
    assert(rom:write(data))
end
local function readAt(offset, count)
    assert(rom:seek('set', offset))
    local data = assert(rom:read(count))
    assert(#data == count, 'Unexpected end of ROM')
    return data
end
assert(patch:sub(1, 5) == 'PATCH', 'Invalid IPS header')
local pos = 6
while patch:sub(pos, pos + 2) ~= 'EOF' do
    local offset, count
    offset, count, pos = string.unpack('>I3I2', patch, pos)
    if count == 0 then
        local byte
        count, byte, pos = string.unpack('>I2c1', patch, pos)
        writeAt(offset, byte:rep(count))
    else
        assert(pos + count - 1 <= #patch, 'Truncated IPS record')
        writeAt(offset, patch:sub(pos, pos + count - 1))
        pos = pos + count
    end
end
pos = pos + 3
assert(pos == #patch + 1 or (pos + 2 == #patch and string.unpack('>I3', patch, pos) == size), 'Unexpected IPS resize/trailer')
assert(readAt(0x860d5, 2) == '\x60\x00', 'Unsupported Faster FireRed hook')

local settings = {player='RED', rival='BLUE', gender='0'}
for line in io.lines(arg[4]) do
    local key, value = line:match('^(%w+)=(.-)\r?$')
    if key and settings[key] ~= nil then settings[key] = value end
end
local punctuation = {[' ']=0,['!']=0xab,['?']=0xac,['.']=0xad,['-']=0xae,[',']=0xb8,['/']=0xba}
local function encodeName(name)
    assert(#name >= 1 and #name <= 7, 'Names must have 1 to 7 characters')
    local result = name:gsub('.', function(c)
        local b = c:byte()
        if b >= 65 and b <= 90 then return string.char(b - 65 + 0xbb) end
        if b >= 97 and b <= 122 then return string.char(b - 97 + 0xd5) end
        if b >= 48 and b <= 57 then return string.char(b - 48 + 0xa1) end
        return string.char(assert(punctuation[c], 'Unsupported name character'))
    end)
    return result .. ('\xff'):rep(8 - #result)
end
assert(settings.gender == '0' or settings.gender == '1', 'Gender must be 0 or 1')
for _, write in ipairs(spec.writes) do writeAt(write[1], write[2]) end
writeAt(0x780034, encodeName(settings.player))
writeAt(0x78003c, encodeName(settings.rival))
writeAt(0x780044, string.char(tonumber(settings.gender)))
for _, offset in ipairs(spec.shops) do
    local kept, length = {}, 0
    while true do
        local bytes = readAt(offset + length, 2)
        local item = string.unpack('<I2', bytes)
        length = length + 2
        if item == 0 then break end
        assert(item <= 374 and length <= 122, 'Invalid shop table')
        if item <= 12 or item == 83 or item == 84 or item == 86 then kept[#kept + 1] = bytes end
    end
    local data = table.concat(kept)
    writeAt(offset, data .. ('\0'):rep(length - #data))
end
assert(rom:close())
