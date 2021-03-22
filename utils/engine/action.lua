require("yaci")
require("strict")
local pp    = require("pp")
local glue  = require("glue")
local cjson = require("cjson.safe")

CActionEngine = newclass("CActionEngine")

function CActionEngine:print(...)
    if self.is_debug then
        local t = glue.pack(...)
        for i, v in ipairs(t) do
            t[i] = pp.format(v)
        end
        print(glue.unpack(t))
    end
end

function CActionEngine:init(agent_id, cfg, is_debug)
    self.is_debug = false
    self.agent_id = ""

    if type(is_debug) == "boolean" then
        self.is_debug = is_debug
    end
    if type(agent_id) == "string" then
        self.agent_id = agent_id
    end
end

function CActionEngine:free()
    self:print("finalize CActionEngine object")
end

function CActionEngine:exec_db(action, info)
    local sinfo = cjson.encode(info)
    self:print("execute action log to DB: ", cjson.encode(action), " : ",  sinfo)
    __api.push_event(self.agent_id, sinfo)
end

function CActionEngine:exec_telegram(action, info)
    local sinfo = cjson.encode(info)
    self:print("execute action send to telegram: ", cjson.encode(action), " : ",  sinfo)
end

function CActionEngine:exec_slack(action, info)
    local sinfo = cjson.encode(info)
    self:print("execute action send to slack: ", cjson.encode(action), " : ",  sinfo)
end

function CActionEngine:exec_email(action, info)
    local sinfo = cjson.encode(info)
    self:print("execute action send to email: ", cjson.encode(action), " : ",  sinfo)
end

function CActionEngine:exec(list)
    for name, data in pairs(list) do
        local actions = data.actions
        for _, action in ipairs(data.actions) do
            if action.type == "db" then
                self:exec_db(action, data.info)
            elseif action.type == "telegram" then
                self:exec_telegram(action, data.info)
            elseif action.type == "slack" then
                self:exec_slack(action, data.info)
            elseif action.type == "email" then
                self:exec_email(action, data.info)
            else
                self:print("unsupported action type: ", action.type)
            end
        end
    end
end
