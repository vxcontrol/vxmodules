require("engine")
local cjson = require "cjson.safe"
local prefix_db = tostring(__config.ctx.agent_id) .. "."
local event_data_schema = __config.get_event_data_schema()
local current_event_config = __config.get_current_event_config()
local module_info = __config.get_module_info()
local event_engine = CEventEngine(event_data_schema, current_event_config, module_info, prefix_db, true)
local action_engine = CActionEngine(__config.ctx.agent_id, {})

__api.add_cbs({
    data = function(src, data)
        print('receive data: "' .. data .. '" from: ' .. src)
        local event_data = cjson.decode(data)
        local event_name = ""
        if event_data.status == "failed" then
            event_name = "pam_unsuccessful_auth"
        else
            event_name = "pam_successful_auth"
        end
        local info = { name = event_name, data = event_data }
        local result, list = event_engine:push_event(info)
        if result then
            action_engine:exec(list)
        end
        return true
    end,
    control = function(cmtype, data)
        print('receive control msg: "' .. cmtype .. '" from: ' .. data)
        return true
    end,
})

print("module pam started")
__api.await(-1)
print("module pam stoped")

return 'success'