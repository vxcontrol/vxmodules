
local ffi = require'ffi'
local rsync = require'librsync'
local fs = require'fs'
local time = require'time'
local lfs = require'lfs'

local _ = string.format

local function mb(bytes)
	return bytes / 1024^2
end

local clock0
local function mbs(bytes)
	if not bytes then
		clock0 = time.clock()
	else
		return mb(bytes) / (time.clock() - clock0)
	end
end

local function log(...)
	print(_(...))
	io.flush()
end

local function log_mbs(bytes, ...)
	log('%7.1fM/s: %s', mbs(bytes), _(...))
end

print(rsync.version())
print(rsync.strerror(rsync.C.RS_RUNNING))

local mem_len = 64 * 1024 * 10
local block_len = 1024
local file1 = (__tmpdir or "./utils") .. "/data/rsync.tar"
local sigfile = file1:gsub('(%.[^%.]+)$', '.sig%1')

local b = rsync.buffers()
local out_len = mem_len
local mem = ffi.new('uint8_t[?]', mem_len)
local out = ffi.new('uint8_t[?]', out_len)

local read_len
local function fill_buffer(f, init)
	if init then
		b.avail_in = 0
		read_len = 0
		return
	elseif b.avail_in ~= 0 then
		return
	end
	b.avail_in = assert(f:read(mem, mem_len))
	b.next_in = mem
	b.eof_in = b.avail_in < mem_len
	read_len = read_len + tonumber(b.avail_in)
end

local write_len
local function write_buffer(f)
	if not f then
		b.next_out = out
		b.avail_out = out_len
		write_len = 0
		return
	end
	local len = out_len - tonumber(b.avail_out)
	if len == 0 then return end
	assert(f:write(out, len))
	b.next_out = out
	b.avail_out = out_len
	write_len = write_len + len
end

mbs()
local f1 = fs.open(file1, 'r')
local sigf = fs.open(sigfile, 'w')
local job = rsync.create_sig_job(block_len)
fill_buffer(f1, true)
write_buffer()
while job:next(b) do
	fill_buffer(f1)
	write_buffer(sigf)
end
f1:close()
sigf:close()
local block_count = math.floor(read_len / block_len)
log_mbs(read_len, 'saved sigs: %d sigs', block_count)
mbs()

return true
