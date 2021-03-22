local cjson = require "cjson.safe"
local output = ''

function table.pack(...)
  return { n = select("#", ...), ... }
end

local function hooked_print(...)
    local r = ""
    local args = table.pack(...)
    for i=1,args.n do 
       output = output .. tostring(args[i]) .. "\n"
    end
end

__api.add_cbs({
    data = function(src, data)
        print('receive data: "' .. data .. '" from: ' .. src)
        local resp = {}
        local msg = cjson.decode(data)
        if msg.type ~= nil and msg.type == 'exec' then
            local f, err = loadstring(msg.code)
            local response = {['type']='response', ['retaddr']=msg.retaddr}
            if f ~= nil then
                local env = {print=hooked_print}
				setmetatable(env, {__index = _G})
                setfenv(f, env)
                response.status, response.ret, response.err = xpcall(f, debug.traceback)
                response.output = output
            else
                response.err = 'Syntax error : ' .. tostring(err)
            end
            local encoded_response = cjson.encode(response)
            __api.send_data_to(src, encoded_response)
            output = ''
        end

        return true
    end,
    control = function(cmtype, data)
        return true
    end,
})
__api.await(-1)
return 'success'
