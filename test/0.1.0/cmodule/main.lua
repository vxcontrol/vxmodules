local cjson = require "cjson.safe"

local arg_keys = {}
for k, _ in pairs(__args) do
    table.insert(arg_keys, k)
end

table.sort(arg_keys)
for i, k in ipairs(arg_keys) do
    local v = __args[k]
    print(i, k, v)
    if type(v) == 'table' then
        for j, p in pairs(v) do
            print("\t", j, p)
        end
    end
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

function handshake(src)
    print("start handshake with ", src)
    __api.await(1000)
    local hs_agent_msg = cjson.encode({['type'] = 'hs_agent', ['data'] = "hello"})
    print("sent hs agent msg to ", src, ": ", __api.send_data_to(src, hs_agent_msg))
    print("received hs server msg from ", src, ": ", __api.recv_data_from(src))
    print("end handshake with ", src)
end

function inf_runner()
    while __api.is_close() == false do
        for dst, src in pairs(__routes.dump()) do
            local test_agent_req = cjson.encode({['type'] = 'test_req', ['data'] = "request"})
            print("sent test agent request to ", dst, ": ", __api.send_data_to(dst, test_agent_req))
        end
        __api.await(10000)
    end
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

__api.set_recv_timeout(30000) -- 30s

__api.add_cbs({
    data = function(src, data)
        print('receive data: "' .. data .. '" from: ' .. src)
        local msg = cjson.decode(data)
        if msg['type'] == 'add_route' then
            local dst = msg['dst']
            local res = __routes.add(dst, __routes.get(src))
            print("add new route to ", dst, ": ", res)

            -- simple handshake to other agent
            __api.await(1000)
            local hs_req_msg = cjson.encode({['type'] = 'hs_request', ['data'] = "hello"})
            print("sent hs req msg to ", dst, ": ", __api.send_data_to(dst, hs_req_msg))
        end
        if msg['type'] == 'del_route' then
            local dst = msg['dst']
            local res = __routes.del(dst)
            print("del route to ", dst, ": ", res)
        end
        if msg['type'] == 'hs_request' then
            local hs_resp_msg = cjson.encode({['type'] = 'hs_response', ['data'] = "hello"})
            print("sent hs resp msg to ", src, ": ", __api.send_data_to(src, hs_resp_msg))
        end
        if msg['type'] == 'hs_response' then
            print("received hs resp msg from ", src)
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
        local src = data
        print('receive control msg: "' .. cmtype .. '" from: ' .. src)
        print_agents()
        if cmtype == "agent_connected" then
            -- It's a simple module handshake
            handshake(src)
        end
        return true
    end,
})

test_utils()
print_agents()
for t, a in pairs(__agents.dump()) do
    handshake(t)
end

inf_runner()
--__api.await(-1)
print("module test stoped")

return 'success'
