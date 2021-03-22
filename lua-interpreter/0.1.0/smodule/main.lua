require("engine")
local cjson = require "cjson.safe"

local function get_agent_id(src, atype)
    for client_id, client_info in pairs (__agents.dump()) do
        if client_id == src then
            if tostring(client_info.Type) == atype then
                return tostring(client_info.ID)
            end
        end
    end
    return ""
end

__api.add_cbs({
    data = function(src, data)
        print('receive data: "' .. data .. '" from: ' .. src)
        local msg = cjson.decode(data)
        local vxagent_id = get_agent_id(src, "VXAgent")
        local bagent_id = get_agent_id(src, "Browser")
        if vxagent_id ~= "" then
            if msg.type ~= nil and msg.type == 'response' then
                local browser_id = msg.retaddr
                msg.retaddr = nil
                local encoded_msg = cjson.encode(msg)
                __api.send_data_to(browser_id, encoded_msg)
            end
        else
            -- msg from browser...
            if msg.type ~= nil and msg.type == 'exec' then
                for client_id, client_info in pairs (__agents.dump()) do
                    if tostring(client_info.Type) == "VXAgent" and client_info.ID == bagent_id then
                        msg.retaddr = src
                        local encoded_msg = cjson.encode(msg)
                        __api.send_data_to(client_id, encoded_msg)
                    end
                end
            end
        end
        return true
    end,
    control = function(cmtype, data)
        print('receive control msg: "' .. cmtype .. '" from: ' .. data)
        return true
    end,
})

print("server module lua-interpreter started")
__api.await(-1)
print("server module lua-interpreter stoped")

return 'success'