local cjson = require "cjson.safe"

local arg_keys = {}
for k, _ in pairs(__args) do
    table.insert(arg_keys, k)
end


table.sort(arg_keys)
for i, k in ipairs(arg_keys) do
    local v = __args[k]
    print(i, k, table.getn(v))
    if type(v) == 'table' then
        for j, p in pairs(v) do
            print("\t", j, p)
        end
    end
end

function print_config()
    print(type(__config))
    print(type(__config.get_config_schema))
    print(__config.get_config_schema())
    print(type(__config.get_default_config))
    print(__config.get_default_config())
    print(type(__config.get_current_config))
    print(__config.get_current_config())
    print(type(__config.get_event_data_schema))
    print(__config.get_event_data_schema())
    print(type(__config.get_event_config_schema))
    print(__config.get_event_config_schema())
    print(type(__config.get_default_event_config))
    print(__config.get_default_event_config())
    print(type(__config.get_current_event_config))
    print(__config.get_current_event_config())
    print(type(__config.get_module_info))
    print(__config.get_module_info())
    print(type(__config.set_current_config))
    print(__config.set_current_config("{}"))
    print(type(__config.ctx))
    print(__config.ctx)
    print(__config.ctx.agent_id)
    print(type(__config.ctx.os))
    print(__config.ctx.os)
    for os, arch in ipairs(__config.ctx.os) do
        print("\t", os, arch)
        print("\t", type(arch))
        for i, k in ipairs(arch) do
            print("\t\t", i, k)
        end
    end
    print(__config.ctx.name)
    print(__config.ctx.version)
    print(__config.ctx.last_update)
end

function print_agents()
    print("__agents type: ", type(__agents))
    local agents = __agents.dump()
    print("__agents.dump() type: ", type(agents))
    print("__agents.dump():", agents)
    for i, a in pairs(agents) do
        print("\t", i, a, type(a))
    end
end

function test_clibs()
    print("preload: ", package.preload)
    print("path: ", package.path)
    print("cpath: ", package.cpath)
    local md4 = require'md4'
    local md5 = require'md5'
    local glue = require'glue'
    local sumhex = function(s, lib)
        return glue.tohex(lib.sum(s))
    end

    print("test md4: ", sumhex('test message', md4))
    print("test md5: ", sumhex('test message', md5))
    print("test_clibs successed")
end

function test_fs_data_load()
    print("tmpdir: ", __tmpdir)
    local lfs  = require("lfs")
    local path = (__tmpdir or "") .. "/data/file.dat"

    print("attr: ", lfs.attributes(path))
    local f = io.open(path, "rb")
    if f ~= nul then
        print("content: ", f:read("*all"))
        f:close()
    else
        print("Can't open file")
    end
    print("test_fs_data_load successed")
end

function test_utils()
    local librsync_test = true -- require'tests.librsync_test'
    local vararg_test = require'tests.vararg_test'
    if not librsync_test or not vararg_test then
        print("test_utils failed", librsync_test, vararg_test)
    else
        print("test_utils successed")
    end
end

function add_routes(src)
    local agents = __agents.dump()
    for t, a in pairs(agents) do
        if t ~= src then
            local route_msg_f = cjson.encode({['type'] = 'add_route', ['dst'] = src})
            print("notify ", t, " about new route to: ", src, ": ", __api.send_data_to(t, route_msg_f))
            local route_msg_r = cjson.encode({['type'] = 'add_route', ['dst'] = t})
            print("notify ", src, " about new route to: ", t, ": ", __api.send_data_to(src, route_msg_r))
        end
    end
end

function del_routes(src)
    local agents = __agents.dump()
    for t, a in pairs(agents) do
        if t ~= src then
            local route_msg_f = cjson.encode({['type'] = 'del_route', ['dst'] = src})
            print("notify ", t, " about new route to: ", src, ": ", __api.send_data_to(t, route_msg_f))
        end
    end
end

__api.set_recv_timeout(5000) -- 5s

__api.add_cbs({
    data = function(src, data)
        print('receive data: "' .. data .. '" from: ' .. src)
        local msg = cjson.decode(data)
        if msg['type'] == 'hs_agent' then
            local hs_server_msg = cjson.encode({['type'] = 'hs_server', ['data'] = "hello"})
            __api.await(100)
            print("sent hs server msg to ", src, ": ", __api.send_data_to(src, hs_server_msg))
            add_routes(src)
        else
            local server_resp_msg = cjson.encode({['type'] = 'test_resp', ['data'] = "response"})
            print("sent server response msg to ", src, ": ", __api.send_data_to(src, server_resp_msg))
        end
        return true
    end,
    file = function(src, path, name)
        print('receive file: "' .. path .. '" / "' .. name .. '" from: ' .. src)
        return true
    end,
    text = function(src, text, name)
        print('receive text: "' .. text .. '" / "' .. name .. '" from: ' .. src)
        return true
    end,
    msg = function(src, msg, mtype)
        print('receive msg: "' .. msg .. '" / "' .. tostring(mtype) .. '" from: ' .. src)
        return true
    end,
    control = function(cmtype, data)
        print('receive control msg: "' .. cmtype .. '" from: ' .. data)
        print_agents()
        if cmtype == "agent_connected" then
            -- notify all alive agents that new agent was connected
            -- routes are sould be fixed on handshake
        end
        if cmtype == "agent_disconnected" then
            -- notify all alive agents that agent was disconnected
            del_routes(data)
        end
        return true
    end,
})

test_clibs()
test_fs_data_load()
test_utils()
print_config()

local agents = __agents.dump()
for t, a in pairs(agents) do
    add_routes(t)
    __api.push_event(a.ID, cjson.encode({
        name = "my_test_event",
        data = { key = "val" },
        uniq = "my_test_uniq",
    }))
end

__api.await(-1)
print("module test stoped")

return 'success'
