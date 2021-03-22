local cjson = require "cjson.safe"

function table.empty(self)
    for _, _ in pairs(self) do
        return false
    end
    return true
end

local function send_msg(msg)
    local encoded_msg = cjson.encode(msg)
    for dst, _ in pairs(__routes.dump()) do
        __api.send_data_to(dst, encoded_msg)
    end
end

local function parse_ip(line)
    local ip = line:match("%bfrom%s([%d]+[.][%d]+[.][%d]+[.][%d]+)")
    if ip ~= nil then return ip else return "-" end
end

local function parse_user(line)
    if string.find(line, "Accepted password") then
        local login = line:match("%bfor%s(%w+)")
        if login ~= nil then
            return login
        end
    elseif string.find(line, "Failed password for invalid user") then
        local login = line:match("%buser%s(%w+)")
        if login ~= nil then
            return login
        end
    elseif string.find(line, "Failed password for ") then
        local login = line:match("%bpassword%sfor%s(%w+)")
        if login ~= nil then
            return login
        end
    elseif string.find(line, "sudo:auth") then
        if string.find(line, "authentication failure") then
            local login = line:match("%buser=(.+?$)") -- check
            if login ~= nil then
                return login
            end
        end
    elseif string.find(line, "user NOT in sudoers") then
        local login = line:match("(%w+) : user NOT in sudoers") -- check
        if login ~= nil then
            return login
        end
    end
    return "-"
end

local function parse_line(line)
    local msg = {}
    if string.find(line, "Accepted password for") then
      msg['type'] = 'ssh'
      msg['status'] = 'success'
      msg['login'] = parse_user(line)
      msg['ip'] = parse_ip(line)
      msg['valid_user'] = true
    elseif string.find(line, "Failed password for invalid user") then
      msg['type'] = 'ssh'
      msg['status'] = 'failed'
      msg['login'] = parse_user(line)
      msg['ip'] = parse_ip(line)
      msg['valid_user'] = false
    elseif string.find(line, "Failed password for") then
      msg['type'] = 'ssh'
      msg['status'] = 'failed'
      msg['login'] = parse_user(line)
      msg['ip'] = parse_ip(line)
      msg['valid_user'] = true
    elseif string.find(line, "sudo:auth") then
        if string.find(line, "authentication failure") then
            msg['type'] = 'sudo'
            msg['status'] = 'failed'
            msg['login'] = parse_user(line)
            msg['ip'] = parse_ip(line)
            msg['valid_user'] = true
        end
    end
    if not table.empty(msg) then
        send_msg(msg)
    end
end

local function worker(ctx, q, e)
    local function await(t)
        if type(t) ~= "number" or t < 0 then
            e:wait()
        elseif t == 0 then
            return
        else
            e:wait(os.time() + 1000/t)
        end
    end

    local function is_close()
        return e:isset()
    end

    local function callback(lines)
        q:push(lines)
    end

    require'reader'
    local reader = CReader(ctx.debug)
    local status, err = reader:open(ctx.file, ctx.method, ctx.follow)
    print("start reader")
    if status then
        reader:read_line_cb(callback, await, is_close)
    else
        print("failed to initialize reader: " .. tostring(err))
    end
    print("stop reader")
	q:push()
end

local thread = require'thread'
local q = thread.queue(1)
local e = thread.event()
local ctx = {
    file = "/var/log/auth.log",
    method = "tail",
    follow = true,
    debug = false,
}
local rth = thread.new(worker, ctx, q, e)

__api.add_cbs({
    data = function(src, data)
        print('receive data: "' .. data .. '" from: ' .. src)
        return true
    end,
    control = function(cmtype, data)
        print('receive control msg: "' .. cmtype .. '" from: ' .. data)
        return true
    end,
})

print("module pam started")
while true do
    local status, lines = q:shift(os.time() + 0.05)
    if __api.is_close() then
        e:set()
    end
    if not status then
        __api.await(50)
    else
        if type(lines) ~= "table" then
            break
        end
        for n = 1, #lines do
            parse_line(lines[n])
        end
    end
end

print("wait reader thread")
rth:join()
q:free()
q = nil
e = nil
rth = nil
print("module pam stoped")

return 'success'
