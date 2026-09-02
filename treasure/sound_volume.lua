local bit = require('bit')
local ffi = require('ffi')

ffi.cdef[[
    typedef struct {
        unsigned short wFormatTag;
        unsigned short nChannels;
        unsigned long nSamplesPerSec;
        unsigned long nAvgBytesPerSec;
        unsigned short nBlockAlign;
        unsigned short wBitsPerSample;
        unsigned short cbSize;
    } TREASURE_WAVEFORMATEX;

    typedef struct {
        char* lpData;
        unsigned long dwBufferLength;
        unsigned long dwBytesRecorded;
        void* dwUser;
        unsigned long dwFlags;
        unsigned long dwLoops;
        void* lpNext;
        unsigned long reserved;
    } TREASURE_WAVEHDR;

    long waveOutOpen(void** phwo, unsigned int device_id,
        const TREASURE_WAVEFORMATEX* format, unsigned long callback,
        unsigned long instance, unsigned long flags);
    long waveOutPrepareHeader(void* hwo, TREASURE_WAVEHDR* header, unsigned int size);
    long waveOutWrite(void* hwo, TREASURE_WAVEHDR* header, unsigned int size);
    long waveOutUnprepareHeader(void* hwo, TREASURE_WAVEHDR* header, unsigned int size);
    long waveOutReset(void* hwo);
    long waveOutClose(void* hwo);
]]

local loaded, winmm = pcall(ffi.load, 'winmm')
if not loaded then
    winmm = nil
end
local active
local M = {}

local function cleanup()
    if active == nil then
        return
    end
    if winmm ~= nil and active.handle ~= nil then
        winmm.waveOutReset(active.handle)
        if active.header ~= nil then
            winmm.waveOutUnprepareHeader(
                    active.handle, active.header, ffi.sizeof('TREASURE_WAVEHDR'))
        end
        winmm.waveOutClose(active.handle)
    end
    active = nil
end

local function read_u16(data, offset)
    local lo, hi = data:byte(offset, offset + 1)
    return (lo or 0) + ((hi or 0) * 0x100)
end

local function read_u32(data, offset)
    local b1, b2, b3, b4 = data:byte(offset, offset + 3)
    return (b1 or 0) + ((b2 or 0) * 0x100) + ((b3 or 0) * 0x10000)
            + ((b4 or 0) * 0x1000000)
end

local function read_pcm16_wave(path)
    local file = io.open(path, 'rb')
    if file == nil then
        return nil
    end
    local data = file:read('*all')
    file:close()
    if data == nil or #data < 44 or data:sub(1, 4) ~= 'RIFF'
            or data:sub(9, 12) ~= 'WAVE' then
        return nil
    end

    local format, pcm
    local position = 13
    while position + 8 <= #data do
        local chunk_id = data:sub(position, position + 3)
        local chunk_size = read_u32(data, position + 4)
        local chunk_start = position + 8
        if chunk_start + chunk_size - 1 > #data then
            break
        end
        if chunk_id == 'fmt ' and chunk_size >= 16 then
            format = {
                tag = read_u16(data, chunk_start),
                channels = read_u16(data, chunk_start + 2),
                sample_rate = read_u32(data, chunk_start + 4),
                bytes_per_second = read_u32(data, chunk_start + 8),
                block_align = read_u16(data, chunk_start + 12),
                bits = read_u16(data, chunk_start + 14),
            }
        elseif chunk_id == 'data' then
            pcm = data:sub(chunk_start, chunk_start + chunk_size - 1)
        end
        position = chunk_start + chunk_size + (chunk_size % 2)
    end
    if format == nil or pcm == nil or format.tag ~= 1 or format.bits ~= 16 then
        return nil
    end
    return format, pcm
end

local function scaled_pcm(pcm, multiplier)
    local output = ffi.new('char[?]', #pcm)
    for index = 0, math.floor(#pcm / 2) - 1 do
        local lo, hi = pcm:byte((index * 2) + 1, (index * 2) + 2)
        local sample = (lo or 0) + ((hi or 0) * 0x100)
        if sample >= 0x8000 then
            sample = sample - 0x10000
        end
        sample = math.floor((sample * multiplier) + (sample >= 0 and 0.5 or -0.5))
        sample = math.max(-0x8000, math.min(0x7FFF, sample))
        local unsigned = sample >= 0 and sample or sample + 0x10000
        output[index * 2] = bit.band(unsigned, 0xFF)
        output[(index * 2) + 1] = bit.band(bit.rshift(unsigned, 8), 0xFF)
    end
    return output
end

function M.play(path, volume)
    volume = math.max(0, math.min(100, tonumber(volume) or 100))
    if volume <= 0 then
        return
    end
    if volume == 100 then
        cleanup()
        ashita.misc.play_sound(path)
        return
    end
    if winmm == nil then
        ashita.misc.play_sound(path)
        return
    end

    local format, pcm = read_pcm16_wave(path)
    if format == nil then
        ashita.misc.play_sound(path)
        return
    end
    cleanup()

    local buffer = scaled_pcm(pcm, volume / 100)
    local wave_format = ffi.new('TREASURE_WAVEFORMATEX')
    wave_format.wFormatTag = format.tag
    wave_format.nChannels = format.channels
    wave_format.nSamplesPerSec = format.sample_rate
    wave_format.nAvgBytesPerSec = format.bytes_per_second
    wave_format.nBlockAlign = format.block_align
    wave_format.wBitsPerSample = format.bits
    wave_format.cbSize = 0

    local handle = ffi.new('void*[1]')
    if winmm.waveOutOpen(handle, 0xFFFFFFFF, wave_format, 0, 0, 0) ~= 0 then
        ashita.misc.play_sound(path)
        return
    end

    local header = ffi.new('TREASURE_WAVEHDR')
    header.lpData = buffer
    header.dwBufferLength = #pcm
    if winmm.waveOutPrepareHeader(handle[0], header, ffi.sizeof('TREASURE_WAVEHDR')) ~= 0 then
        winmm.waveOutClose(handle[0])
        ashita.misc.play_sound(path)
        return
    end
    if winmm.waveOutWrite(handle[0], header, ffi.sizeof('TREASURE_WAVEHDR')) ~= 0 then
        winmm.waveOutUnprepareHeader(handle[0], header, ffi.sizeof('TREASURE_WAVEHDR'))
        winmm.waveOutClose(handle[0])
        ashita.misc.play_sound(path)
        return
    end
    active = { handle = handle[0], header = header, buffer = buffer }
end

function M.tick()
    if active ~= nil and active.header ~= nil
            and bit.band(active.header.dwFlags, 0x00000001) ~= 0 then
        cleanup()
    end
end

function M.shutdown()
    cleanup()
end

return M
